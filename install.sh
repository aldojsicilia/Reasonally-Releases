#!/usr/bin/env sh
set -eu

main() {
    case "${1:-}" in
        --help|-h)
            printf '%s\n' 'Usage: install.sh [--version X.Y.Z]' \
                'macOS: install a verified stable release into ~/Applications and ~/.local/bin.' \
                'Set REASONALLY_INSTALL_DIR and REASONALLY_BIN_DIR to use other absolute paths.' \
                'Linux: set ZED_BUNDLE_PATH to a locally built archive.'
            return
            ;;
    esac
    platform="$(uname -s)"
    arch="$(uname -m)"
    if [ "$platform" = Darwin ]; then
        macos "$@"
        return
    fi
    if [ "$#" -ne 0 ]; then
        echo 'Options are only supported by the macOS installer. Use --help for usage.' >&2
        exit 1
    fi
    channel="${ZED_CHANNEL:-stable}"
    ZED_VERSION="${ZED_VERSION:-latest}"
    # Use TMPDIR if available (for environments with non-standard temp directories)
    if [ -n "${TMPDIR:-}" ] && [ -d "${TMPDIR}" ]; then
        temp="$(mktemp -d "$TMPDIR/reasonally-XXXXXX")"
    else
        temp="$(mktemp -d "/tmp/reasonally-XXXXXX")"
    fi
    trap 'rm -rf "$temp"' 0
    trap 'exit 130' INT
    trap 'exit 143' TERM

    if [ "$platform" = "Darwin" ]; then
        platform="macos"
    elif [ "$platform" = "Linux" ]; then
        platform="linux"
    else
        echo "Unsupported platform $platform"
        exit 1
    fi

    case "$platform-$arch" in
        macos-arm64* | linux-arm64* | linux-aarch64)
            arch="aarch64"
            ;;
        macos-x86* | linux-x86*)
            arch="x86_64"
            ;;
        *)
            echo "Unsupported platform or architecture"
            exit 1
            ;;
    esac

    if command -v curl >/dev/null 2>&1; then
        curl () {
            command curl -fL "$@"
        }
    elif command -v wget >/dev/null 2>&1; then
        curl () {
            wget -O- "$@"
        }
    else
        echo "Could not find 'curl' or 'wget' in your path"
        exit 1
    fi

    "$platform" "$@"

    if [ "$(command -v reasonally)" = "$HOME/.local/bin/reasonally" ]; then
        echo "Reasonally has been installed. Run with 'reasonally'"
    else
        echo "To run Reasonally from your terminal, you must add ~/.local/bin to your PATH"
        echo "Run:"

        case "${SHELL:-}" in
            *zsh)
                echo "   echo 'export PATH=\$HOME/.local/bin:\$PATH' >> ~/.zshrc"
                echo "   source ~/.zshrc"
                ;;
            *fish)
                echo "   fish_add_path -U $HOME/.local/bin"
                ;;
            *)
                echo "   echo 'export PATH=\$HOME/.local/bin:\$PATH' >> ~/.bashrc"
                echo "   source ~/.bashrc"
                ;;
        esac

        echo "To run Reasonally now, '~/.local/bin/reasonally'"
    fi
}

linux() {
    if [ -n "${ZED_BUNDLE_PATH:-}" ]; then
        cp "$ZED_BUNDLE_PATH" "$temp/reasonally-linux-$arch.tar.gz"
    else
        echo 'Set ZED_BUNDLE_PATH to a locally built Reasonally Linux archive. Hosted downloads are not configured.' >&2
        exit 1
    fi

    suffix=""
    if [ "$channel" != "stable" ]; then
        suffix="-$channel"
    fi

    appid=""
    case "$channel" in
      stable)
        appid="com.reasonally.app"
        ;;
      nightly)
        appid="com.reasonally.app.nightly"
        ;;
      preview)
        appid="com.reasonally.app.preview"
        ;;
      dev)
        appid="com.reasonally.app.dev"
        ;;
      *)
        echo "Unknown release channel: ${channel}. Using stable app ID."
        appid="com.reasonally.app"
        ;;
    esac

    # Unpack
    rm -rf "$HOME/.local/reasonally$suffix.app"
    mkdir -p "$HOME/.local/reasonally$suffix.app"
    tar -xzf "$temp/reasonally-linux-$arch.tar.gz" -C "$HOME/.local/"

    reasonally_editor="$HOME/.local/reasonally$suffix.app/libexec/reasonally"
    if [ -f "$reasonally_editor" ] && command -v ldd >/dev/null 2>&1; then
        missing="$(ldd "$reasonally_editor" 2>/dev/null | sed -n 's/^[[:space:]]*\(.*\) => not found$/\1/p')"
        if [ -n "$missing" ]; then
            echo "Warning: your system is missing libraries that Reasonally needs:"
            echo "$missing" | sed 's/^/    /'
            echo "Install them with your package manager, or Reasonally will fail to start."
        fi
    fi

    # Setup ~/.local directories
    mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"

    # Link the binary
    if [ -f "$HOME/.local/reasonally$suffix.app/bin/reasonally" ]; then
        ln -sf "$HOME/.local/reasonally$suffix.app/bin/reasonally" "$HOME/.local/bin/reasonally"
    else
        # support for versions before 0.139.x.
        ln -sf "$HOME/.local/reasonally$suffix.app/bin/cli" "$HOME/.local/bin/reasonally"
    fi

    # Copy .desktop file
    desktop_file_path="$HOME/.local/share/applications/${appid}.desktop"
    src_dir="$HOME/.local/reasonally$suffix.app/share/applications"
    if [ -f "$src_dir/${appid}.desktop" ]; then
        cp "$src_dir/${appid}.desktop" "${desktop_file_path}"
    else
        # Fallback for older tarballs
        cp "$src_dir/reasonally$suffix.desktop" "${desktop_file_path}"
    fi
    sed -i "s|Icon=reasonally|Icon=$HOME/.local/reasonally$suffix.app/share/icons/hicolor/512x512/apps/reasonally.png|g" "${desktop_file_path}"
    sed -i "s|Exec=reasonally|Exec=$HOME/.local/reasonally$suffix.app/bin/reasonally|g" "${desktop_file_path}"
}

macos() (
    fail() { printf 'Reasonally installer: %s\n' "$*" >&2; exit 1; }
    download() {
        command curl --proto '=https' --proto-redir '=https' --tlsv1.2 \
            --fail --location --silent --show-error --retry 3 "$@"
    }
    version="${REASONALLY_VERSION:-latest}"
    if [ "$#" -gt 0 ]; then
        [ "$#" -eq 2 ] && [ "$1" = --version ] || fail 'Usage: install.sh [--version X.Y.Z]'
        version="$2"
    fi
    [ "$(id -u)" -ne 0 ] || fail 'Run this installer as your normal user, without sudo.'
    for dependency in curl shasum hdiutil codesign spctl ditto; do
        command -v "$dependency" >/dev/null 2>&1 || fail "Missing required command: $dependency"
    done
    repository="${REASONALLY_REPOSITORY:-aldojsicilia/Reasonally-Releases}"
    printf '%s\n' "$repository" | LC_ALL=C grep -Eq '^[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+$' || fail 'Invalid release repository.'
    if [ "$version" = latest ]; then
        latest_url="$(download --output /dev/null --write-out '%{url_effective}' "https://github.com/$repository/releases/latest")" || \
            fail 'No public stable release is available. Check the repository Releases page.'
        case "$latest_url" in
            "https://github.com/$repository/releases/tag/v"*) version="${latest_url##*/}" ;;
            *) fail 'Could not resolve the latest release tag.' ;;
        esac
    fi
    version="${version#v}"
    printf '%s\n' "$version" | LC_ALL=C grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || fail 'Expected a stable version such as 0.1.0.'
    case "$(uname -m)" in
        arm64|aarch64) architecture=aarch64 ;;
        x86_64)
            architecture=x86_64
            if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" = 1 ]; then
                architecture=aarch64
            fi
            ;;
        *) fail 'Only Apple Silicon and Intel Macs are supported.' ;;
    esac
    install_dir="${REASONALLY_INSTALL_DIR:-$HOME/Applications}"
    bin_dir="${REASONALLY_BIN_DIR:-$HOME/.local/bin}"
    case "$install_dir:$bin_dir" in
        /*:/*) ;;
        *) fail 'Install and binary directories must be absolute paths.' ;;
    esac
    app="$install_dir/Reasonally.app"
    launcher="$bin_dir/reasonally"
    if [ -e "$launcher" ] || [ -L "$launcher" ]; then
        [ -L "$launcher" ] && [ "$(readlink "$launcher")" = "$app/Contents/MacOS/cli" ] || \
            fail "Refusing to replace an unrelated launcher at $launcher. Choose REASONALLY_BIN_DIR."
    fi
    [ ! -L "$app" ] || fail "Refusing to replace a symlink at $app."
    if [ -e "$app" ]; then
        [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" = com.reasonally.app ] || \
            fail "Refusing to replace an unrelated app at $app."
        if pgrep -f "$app/Contents/MacOS/reasonally" >/dev/null 2>&1; then
            fail 'Quit Reasonally before upgrading, then run the installer again.'
        fi
    fi
    mkdir -p "$install_dir" "$bin_dir"
    lock="$install_dir/.reasonally-install-lock"
    mkdir "$lock" 2>/dev/null || fail "Another installation may be running. If it stopped, remove $lock and retry."
    temporary=''
    stage=''
    mounted=false
    replacement=false
    committed=false
    cleanup() {
        status=$?
        trap - 0
        if [ "$committed" = false ]; then
            if [ -n "$stage" ] && [ -d "$stage/previous.app" ]; then
                rm -rf "$app"
                mv "$stage/previous.app" "$app" || { echo "Restore the previous app from $stage/previous.app" >&2; exit 1; }
            elif [ "$replacement" = true ]; then
                rm -rf "$app"
            fi
        fi
        if [ "$mounted" = true ]; then
            hdiutil detach "$temporary/mount" -quiet || { echo "Could not unmount $temporary/mount; temporary files were retained." >&2; rmdir "$lock"; exit 1; }
        fi
        [ -z "$temporary" ] || rm -rf "$temporary"
        [ -z "$stage" ] || rm -rf "$stage"
        rmdir "$lock"
        exit "$status"
    }
    trap 'cleanup' 0
    trap 'exit 130' INT
    trap 'exit 143' TERM
    temporary="$(mktemp -d "${TMPDIR:-/tmp}/reasonally-download.XXXXXX")"
    stage="$(mktemp -d "$install_dir/.reasonally-stage.XXXXXX")"
    asset="Reasonally-$architecture.dmg"
    release_url="https://github.com/$repository/releases/download/v$version"
    printf 'Downloading Reasonally %s for %s…\n' "$version" "$architecture"
    download "$release_url/SHA256SUMS" --output "$temporary/SHA256SUMS"
    download "$release_url/$asset" --output "$temporary/$asset"
    expected="$(awk -v asset="$asset" '$2 == asset { digest = $1; count++ } END { if (count != 1) exit 1; print digest }' "$temporary/SHA256SUMS")" || \
        fail 'The release must contain exactly one checksum for this disk image.'
    printf '%s\n' "$expected" | LC_ALL=C grep -Eq '^[0-9a-f]{64}$' || fail 'Invalid release checksum.'
    actual="$(shasum -a 256 "$temporary/$asset" | awk '{print $1}')"
    [ "$actual" = "$expected" ] || fail 'Checksum mismatch. The installed app was not changed.'
    spctl --assess --type open --context context:primary-signature "$temporary/$asset"
    mkdir "$temporary/mount"
    hdiutil attach "$temporary/$asset" -readonly -nobrowse -mountpoint "$temporary/mount" -quiet
    mounted=true
    source_app="$temporary/mount/Reasonally.app"
    [ -d "$source_app" ] && [ ! -L "$source_app" ] || fail 'The disk image does not contain Reasonally.app.'
    codesign --verify --deep --strict "$source_app"
    spctl --assess --type execute "$source_app"
    [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$source_app/Contents/Info.plist")" = com.reasonally.app ] || \
        fail 'Unexpected application identifier.'
    [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$source_app/Contents/Info.plist")" = "$version" ] || \
        fail 'The app version does not match the release tag.'
    [ -x "$source_app/Contents/MacOS/cli" ] && [ -x "$source_app/Contents/MacOS/reasonally" ] || fail 'The app is incomplete.'
    ditto "$source_app" "$stage/Reasonally.app"
    codesign --verify --deep --strict "$stage/Reasonally.app"
    hdiutil detach "$temporary/mount" -quiet
    mounted=false
    if [ -d "$app" ]; then
        mv "$app" "$stage/previous.app"
    fi
    replacement=true
    mv "$stage/Reasonally.app" "$app"
    "$app/Contents/MacOS/cli" --version
    ln -s "$app/Contents/MacOS/cli" "$stage/reasonally"
    mv -fh "$stage/reasonally" "$launcher"
    committed=true
    printf 'Installed Reasonally %s at %s\n' "$version" "$app"
    case ":$PATH:" in
        *":$bin_dir:"*) printf 'Open a project with: reasonally .\n' ;;
        *) printf 'Add this directory to your PATH: %s\nRun now: "%s" .\n' "$bin_dir" "$launcher" ;;
    esac
    cleanup
)

main "$@"
