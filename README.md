# Reasonally releases

Reasonally is an agent-first native IDE built with Rust and GPUI. This repository
hosts public downloads, installation instructions, release notes and bug reports.
Development takes place in a separate private repository; each published binary
release includes its matching application source archive and license notices.

**Status: preparing the first macOS beta. No application downloads are available
yet.** Signed packages must pass notarization and release validation before they
are published here. Linux and Windows are not supported release targets yet.

## Download

When available, choose a release from [Releases](https://github.com/aldojsicilia/Reasonally-Releases/releases):

- `Reasonally-aarch64.dmg`: Apple Silicon Macs.
- `Reasonally-x86_64.dmg`: Intel Macs.

Open the disk image and drag Reasonally to Applications. Use the app's
**Install CLI** command to enable terminal access.

## Terminal installation

For a published beta, download `install.sh` from that release's assets, inspect
it, then select the version explicitly. For example, after version 0.1.0 is
published:

```sh
sh install.sh --version 0.1.0
```

After a stable release is available, install the latest stable version with:

```sh
curl --proto '=https' --tlsv1.2 --fail --location \
  https://github.com/aldojsicilia/Reasonally-Releases/releases/latest/download/install.sh \
  --output install-reasonally.sh && sh install-reasonally.sh
```

Beta releases are excluded from the default stable installer. The installer
requires macOS's standard command-line tools, not Rust or Python. It selects
Apple Silicon or Intel, verifies the downloaded disk image's SHA-256 checksum,
checks its signature and Apple trust assessment, and verifies the app identifier
and version before installation.

Terminal installs use `~/Applications/Reasonally.app` and
`~/.local/bin/reasonally`, without `sudo`. Add `~/.local/bin` to your shell's PATH:

```sh
export PATH="$HOME/.local/bin:$PATH"
reasonally .
```

For zsh, save the export in `~/.zshrc`. To use other absolute paths, set
`REASONALLY_INSTALL_DIR` and `REASONALLY_BIN_DIR` when running the installer.

## Upgrade and remove

Quit Reasonally before rerunning the installer. A failed download or validation
leaves the installed app unchanged, and a failed CLI check restores the previous
app. Your settings and conversations are retained. Automatic in-app updates are
not enabled.

If you installed by dragging from a disk image, replace that same app when
upgrading, or use `REASONALLY_INSTALL_DIR=/Applications` with the installer if
your account can write there. Avoid keeping two copies of Reasonally.

To remove a terminal installation, move its app to Trash and remove the matching
`~/.local/bin/reasonally` symlink. This keeps your settings and conversations.

## Source, verification and licenses

Every application release includes:

- Signed, notarized disk images for both supported architectures.
- `install.sh` and `SHA256SUMS`.
- `reasonally-vX.Y.Z-source.tar.gz`, containing the matching application source,
  lockfile, build scripts, source licenses and build instructions.
- `SOURCE.json`, recording the application source repository, tag and exact commit.

GitHub's automatically generated **Source code** downloads contain this
publication repository. Use the separately attached `reasonally-vX.Y.Z-source.tar.gz`
for the application source. The release tag in this repository identifies the
publication snapshot; `SOURCE.json` identifies the application revision.

Reasonally is based on open-source [Zed](https://github.com/zed-industries/zed)
and is not affiliated with or endorsed by Zed Industries. Application code is
primarily [GPL-3.0-or-later](LICENSE-GPL); GPUI and components marked accordingly
use [Apache-2.0](LICENSE-APACHE). Original copyrights and third-party notices are
preserved in the source archive and the app's bundled license document.

## Report a problem

[Open an issue](https://github.com/aldojsicilia/Reasonally-Releases/issues/new/choose) with the Reasonally version, macOS
version, Mac architecture, reproduction steps and relevant logs. Remove API keys
and private project content from anything you share. Describe whether the problem
occurs during download, installation, launch, editing or agent use.
