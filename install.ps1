# Installs a released `sgt.exe` on Windows, so a new machine has it in seconds and builds
# nothing. The Windows counterpart of install.sh:
#
#   irm https://github.com/Braden1996/sergeant-releases/releases/latest/download/install.ps1 | iex
#
# Every release carries a copy of this file, and the releases are in a repository anyone can
# read, so nothing here needs a token.
#
# What it reads from the environment:
#
#   SGT_VERSION   The release to install, as its tag: `v0.1.0`. Left out, the latest.
#   SGT_INSTALL   The directory `sgt.exe` goes in. Left out, `%LOCALAPPDATA%\sergeant\bin`.
#   SGT_FROM      An address that holds the archives, in place of GitHub: a mirror, or a
#                 directory as a path or a `file:` address. The names under it are a release's.
#   SGT_REPO      The repository that holds the releases, as `owner/name`, when it is another.
#
# The archive is checked against the hash published beside it before anything is installed.
# In a block of its own, so what it names stays out of the shell `iex` runs it in.
& {
  $ErrorActionPreference = 'Stop'
  $ProgressPreference = 'SilentlyContinue'

  $repository = if ($env:SGT_REPO) { $env:SGT_REPO } else { 'Braden1996/sergeant-releases' }
  $version = if ($env:SGT_VERSION) { $env:SGT_VERSION } else { 'latest' }
  $into = if ($env:SGT_INSTALL) { $env:SGT_INSTALL } else { Join-Path $env:LOCALAPPDATA 'sergeant\bin' }

  # Thrown, not exited: run through `iex`, `exit` would close the shell it was run from.
  function Fail($said) { throw "install: $said" }

  # x86-64 only. Windows on Arm runs it as it runs any x86-64 program.
  if (-not [Environment]::Is64BitOperatingSystem) {
    Fail 'no release is built for 32-bit Windows. Build it from source: cargo build --release -p sgt'
  }
  $archive = 'sgt-x86_64-pc-windows-msvc.tar.gz'
  if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
    Fail '`tar` is needed and was not found. Windows has had it since Windows 10 1803'
  }

  $work = Join-Path ([IO.Path]::GetTempPath()) ("sgt-install-" + [Guid]::NewGuid())
  New-Item -ItemType Directory -Path $work | Out-Null
  try {
    # Fetches the release's file `$name` into the work directory.
    function Fetch($name) {
      $to = Join-Path $work $name
      if ($env:SGT_FROM) {
        $from = $env:SGT_FROM.TrimEnd('/', '\')
        if ($from -match '^file:') {
          Copy-Item -LiteralPath (Join-Path ([Uri]$from).LocalPath $name) -Destination $to
        } elseif (Test-Path -LiteralPath $from -PathType Container) {
          Copy-Item -LiteralPath (Join-Path $from $name) -Destination $to
        } else {
          Invoke-WebRequest -UseBasicParsing -Uri "$from/$name" -OutFile $to
        }
      } elseif ($version -eq 'latest') {
        Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/$repository/releases/latest/download/$name" -OutFile $to
      } else {
        Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/$repository/releases/download/$version/$name" -OutFile $to
      }
      $to
    }

    try { $fetched = Fetch $archive } catch { Fail "$archive could not be fetched: $_" }
    try { $hashes = Fetch "$archive.sha256" } catch { Fail "the hash of $archive could not be fetched: $_" }
    $published = ((Get-Content -LiteralPath $hashes -Raw).Trim() -split '\s+')[0]
    $found = (Get-FileHash -LiteralPath $fetched -Algorithm SHA256).Hash
    if ($found -ne $published) {
      Fail "$archive is not the file its release published. Nothing was installed"
    }

    # By names relative to where it unpacks: the tar of Git for Windows, which may come first
    # on PATH, reads `C:\...` as a host to reach.
    Push-Location -LiteralPath $work
    try { tar -xzf $archive } finally { Pop-Location }
    if ($LASTEXITCODE -ne 0) { Fail "$archive could not be unpacked" }
    New-Item -ItemType Directory -Force -Path $into | Out-Null
    $installed = Join-Path $into 'sgt.exe'
    # A program that is running cannot be written over on Windows, but it can be renamed. So the
    # old one is moved aside, and the new one moved into place in one step.
    $aside = Join-Path $into '.sgt.old.exe'
    Remove-Item -LiteralPath $aside -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $installed) { Move-Item -LiteralPath $installed -Destination $aside -Force }
    Move-Item -LiteralPath (Join-Path $work 'sgt.exe') -Destination $installed -Force
    Remove-Item -LiteralPath $aside -Force -ErrorAction SilentlyContinue

    Write-Output "installed: $(& $installed --version) at $installed"
    $onPath = ($env:Path -split ';') | Where-Object { $_.TrimEnd('\') -ieq $into.TrimEnd('\') }
    if (-not $onPath) {
      Write-Output "$into is not on PATH. Add it for this user:"
      Write-Output "  [Environment]::SetEnvironmentVariable('Path', `"$into;`" + [Environment]::GetEnvironmentVariable('Path', 'User'), 'User')"
    }
  } finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
  }
}
