#!/bin/bash
set -e

echo "Activating feature 'serveterm'"

VERSION=${VERSION:-latest}
REPO="0x5341/serveterm"
BINARY_NAME="serveterm"
INSTALL_PATH="/usr/local/bin/${BINARY_NAME}"

UNAME_S="$(uname -s)"
UNAME_M="$(uname -m)"

case "${UNAME_S}" in
  Linux) OS="linux" ;;
  Darwin) OS="darwin" ;;
  *)
    echo "Unsupported OS: ${UNAME_S}" >&2
    exit 1
    ;;
esac

case "${UNAME_M}" in
  x86_64 | amd64) ARCH="amd64" ;;
  aarch64 | arm64) ARCH="arm64" ;;
  i386 | i686) ARCH="386" ;;
  *)
    echo "Unsupported architecture: ${UNAME_M}" >&2
    exit 1
    ;;
esac

if ! command -v curl >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get -y install --no-install-recommends ca-certificates curl tar
  else
    echo "curl and tar are required, and apt-get is not available to install them." >&2
    exit 1
  fi
fi

if [ "${VERSION}" = "latest" ]; then
  DOWNLOAD_URL="https://github.com/${REPO}/releases/latest/download/${BINARY_NAME}_${OS}_${ARCH}.tar.gz"
else
  case "${VERSION}" in
    v*) TAG="${VERSION}" ;;
    *) TAG="v${VERSION}" ;;
  esac
  DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/${BINARY_NAME}_${OS}_${ARCH}.tar.gz"
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
ARCHIVE_PATH="${TMP_DIR}/${BINARY_NAME}.tar.gz"

curl -fsSL "${DOWNLOAD_URL}" -o "${ARCHIVE_PATH}"
tar -xzf "${ARCHIVE_PATH}" -C "${TMP_DIR}"

BINARY_PATH="${TMP_DIR}/${BINARY_NAME}"
if [ ! -f "${BINARY_PATH}" ]; then
  BINARY_PATH="$(find "${TMP_DIR}" -maxdepth 2 -type f -name "${BINARY_NAME}" | head -n 1)"
fi

if [ -z "${BINARY_PATH}" ] || [ ! -f "${BINARY_PATH}" ]; then
  echo "Failed to find '${BINARY_NAME}' in archive: ${DOWNLOAD_URL}" >&2
  exit 1
fi

install -m 0755 "${BINARY_PATH}" "${INSTALL_PATH}"

echo "Installed ${BINARY_NAME} to ${INSTALL_PATH}"

cat << EOF > ${INSTALL_PATH}-onstart
#!/bin/sh
nohup sh -c "${INSTALL_PATH} --address ${PORT} --host ${HOST} --default-command ${DEFAULT_COMMAND} &"
EOF

chmod +x ${INSTALL_PATH}-onstart
