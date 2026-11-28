$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$ProgressPreference = 'SilentlyContinue'

if ($env:SGT_WOOF -eq 'true' -and $env:SGT_WOOF_VERSION -cnotmatch '^v[0-9][0-9A-Za-z.+-]*$') {
  throw 'Expected a Woof release tag such as v0.3.0.'
}

$root = Join-Path $env:RUNNER_TEMP ("sergeant-luau-" + [Guid]::NewGuid())
$bin = Join-Path $root 'bin'
New-Item -ItemType Directory -Path $bin -Force | Out-Null

$arch = if ($env:RUNNER_ARCH -eq 'ARM64' -and !$IsWindows) { 'aarch64' } else { 'x86_64' }
$lspArch = if ($arch -eq 'aarch64') { 'arm64' } else { 'x86_64' }
$extension = if ($IsWindows) { '.exe' } else { '' }
if ($IsWindows) {
  $platform = 'windows'
  $woofTarget = 'x86_64-pc-windows-msvc'
  $lspAsset = 'luau-lsp-win64.zip'
} elseif ($IsMacOS) {
  $platform = 'macos'
  $woofTarget = "$arch-apple-darwin"
  $lspAsset = 'luau-lsp-macos.zip'
} elseif ($IsLinux) {
  $platform = 'linux'
  $woofTarget = "$arch-unknown-linux-musl"
  $lspAsset = "luau-lsp-linux-$lspArch.zip"
} else {
  throw 'Expected Linux, macOS, or Windows.'
}

function Install-ZipBinary($repository, $tag, $asset, $tool) {
  $zip = Join-Path $root $asset
  $unpacked = Join-Path $root $tool
  Invoke-WebRequest -Uri "https://github.com/$repository/releases/download/$tag/$asset" -OutFile $zip
  Expand-Archive -LiteralPath $zip -DestinationPath $unpacked
  $filename = "$tool$extension"
  $binary = Get-ChildItem -LiteralPath $unpacked -Recurse -File -Filter $filename
  if (@($binary).Count -ne 1) { throw "Expected one $filename in $asset." }
  Copy-Item -LiteralPath $binary.FullName -Destination $bin
  if (!$IsWindows) { chmod +x (Join-Path $bin $filename) }
}

if ($env:SGT_WOOF -eq 'true') {
  $asset = "woof-$woofTarget.tar.gz"
  $url = "https://github.com/Braden1996/woof/releases/download/$env:SGT_WOOF_VERSION/$asset"
  $archive = Join-Path $root $asset
  Invoke-WebRequest -Uri $url -OutFile $archive
  Invoke-WebRequest -Uri "$url.sha256" -OutFile "$archive.sha256"
  $expected = ((Get-Content -LiteralPath "$archive.sha256" -Raw).Trim() -split '\s+')[0]
  if ((Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash -ne $expected) {
    throw "SHA-256 mismatch for $asset."
  }
  $woof = "woof$extension"
  $tar = if ($IsWindows) { Join-Path $env:SystemRoot 'System32/tar.exe' } else { 'tar' }
  & $tar -xzf $archive -C $bin $woof
  & (Join-Path $bin $woof) --version
}

Install-ZipBinary 'lune-org/lune' 'v0.11.1' "lune-0.11.1-$platform-$arch.zip" 'lune'
Install-ZipBinary 'JohnnyMorganz/luau-lsp' '1.70.1' $lspAsset 'luau-lsp'
Install-ZipBinary 'seaofvoices/darklua' 'v0.17.1' "darklua-$platform-$arch.zip" 'darklua'

function Get-PinnedSource($repository, $commit, $directory) {
  git init --quiet $directory
  git -C $directory fetch --quiet --depth 1 "https://github.com/$repository.git" $commit
  git -C $directory checkout --quiet --detach FETCH_HEAD
}

$luaJit = Join-Path $root 'luajit-src'
Get-PinnedSource 'LuaJIT/LuaJIT' '04dca7911ea255f37be799c18d74c305b921c1a6' $luaJit
if ($IsWindows) {
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
  $vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  if (!$vs) { throw 'Building LuaJIT requires Visual Studio with the x64 C++ tools.' }
  $env:SGT_LUAJIT_VCVARS = Join-Path $vs 'VC/Auxiliary/Build/vcvars64.bat'
  $env:SGT_LUAJIT_SOURCE = Join-Path $luaJit 'src'
  $env:PATH = "$env:SGT_LUAJIT_SOURCE;$(Split-Path -Parent $vswhere);$env:PATH"
  cmd.exe /d /s /c 'call "%SGT_LUAJIT_VCVARS%" && cd /d "%SGT_LUAJIT_SOURCE%" && call ".\msvcbuild.bat" static'
  Copy-Item -LiteralPath (Join-Path $env:SGT_LUAJIT_SOURCE 'luajit.exe') -Destination $bin
  $jitModules = Join-Path $bin 'lua/jit'
  New-Item -ItemType Directory -Path $jitModules -Force | Out-Null
  Copy-Item -Path (Join-Path $env:SGT_LUAJIT_SOURCE 'jit/*.lua') -Destination $jitModules
} else {
  make -C $luaJit -j2 "PREFIX=$root"
  make -C $luaJit install "PREFIX=$root"
}
& (Join-Path $bin "luajit$extension") -v

if ($env:SGT_LUAU_AST -eq 'true') {
  if ($IsWindows) {
    Install-ZipBinary 'luau-lang/luau' '0.748' 'luau-windows.zip' 'luau-ast'
  } elseif ($IsMacOS -and $arch -eq 'aarch64') {
    Install-ZipBinary 'luau-lang/luau' '0.748' 'luau-macos.zip' 'luau-ast'
  } elseif ($IsLinux -and $arch -eq 'x86_64') {
    Install-ZipBinary 'luau-lang/luau' '0.748' 'luau-ubuntu.zip' 'luau-ast'
  } else {
    $luau = Join-Path $root 'luau-src'
    $build = Join-Path $root 'luau-build'
    Get-PinnedSource 'luau-lang/luau' '3d91c9d5c280c95bfc4be63aac46012cf861d394' $luau # 0.748
    cmake -S $luau -B $build -DCMAKE_BUILD_TYPE=Release
    cmake --build $build --target Luau.Ast.CLI --parallel 2
    Copy-Item -LiteralPath (Join-Path $build 'luau-ast') -Destination $bin
  }
}

Add-Content -LiteralPath $env:GITHUB_PATH -Value $bin
