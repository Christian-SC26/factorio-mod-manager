#!/usr/bin/env bash
set -e

# Factorio Mod Manager (FMM) Installer
INSTALL_DIR="${HOME}/.local/share/factorio-mod-manager"
BIN_DIR="${HOME}/.local/bin"
REPO_URL="https://github.com/USERNAME/factorio-mod-manager.git"

echo "==> Installing Factorio Mod Manager (FMM)..."

# Ensure python3 is available
if ! command -v python3 >/dev/null 2>&1; then
    echo "[ERROR] Python 3 is required but not installed." >&2
    exit 1
fi

mkdir -p "${BIN_DIR}"

if [ -d "${INSTALL_DIR}" ]; then
    echo "==> Updating existing installation..."
    git -C "${INSTALL_DIR}" pull --quiet || true
else
    echo "==> Downloading repository..."
    if command -v git >/dev/null 2>&1; then
        git clone --depth 1 "${REPO_URL}" "${INSTALL_DIR}" --quiet
    else
        mkdir -p "${INSTALL_DIR}"
        curl -fsSL "https://github.com/USERNAME/factorio-mod-manager/archive/refs/heads/main.tar.gz" | tar -xz -C "${INSTALL_DIR}" --strip-components=1
    fi
fi

chmod +x "${INSTALL_DIR}/fmm.py"
ln -sf "${INSTALL_DIR}/fmm.py" "${BIN_DIR}/fmm"

echo ""
echo "[OK] Factorio Mod Manager installed successfully!"
echo "     Executable link: ${BIN_DIR}/fmm"

# Check PATH
case ":$PATH:" in
    *":${BIN_DIR}:"*) ;;
    *)
        echo ""
        echo "[NOTE] Add ${BIN_DIR} to your PATH by adding this line to your ~/.zshrc or ~/.bashrc:"
        echo "       export PATH=\"\$HOME/.local/bin:\$PATH\""
        ;;
esac

echo ""
echo "Run 'fmm' to start."
