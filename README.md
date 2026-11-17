# Sergeant releases

Released binaries of `sgt`, the Sergeant build system. There is no source in this
repository.

Each release holds `sgt` for Linux on x86-64 and on arm64, linked statically so that it runs
whatever C library a machine or a container has, and a sha256 beside each archive.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/Braden1996/sergeant-releases/main/install.sh | sh
```

This fetches the archive for the machine it runs on, checks it against its published hash,
and puts `sgt` in `~/.local/bin`. No token is needed.

| Variable | What it does |
| --- | --- |
| `SGT_VERSION` | The release to install, as its tag: `v0.1.0`. Left out, the latest. |
| `SGT_INSTALL` | The directory `sgt` goes in. Left out, `~/.local/bin`. |
| `SGT_FROM` | An address that holds the archives in place of GitHub: a mirror or a bucket. |

In a workflow or a container, pin the version:

```sh
curl -fsSL https://raw.githubusercontent.com/Braden1996/sergeant-releases/main/install.sh | SGT_VERSION=v0.1.0 sh
```
