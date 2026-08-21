#!/usr/bin/env bash

set -euo pipefail

ubuntu_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

mkdir -p "$work_dir/bin"
cat > "$work_dir/os-release" <<'EOF'
NAME="Ubuntu"
VERSION="25.04 (Plucky Puffin)"
VERSION_ID="25.04"
VERSION_CODENAME=plucky
EOF

cat > "$work_dir/bin/bash" <<'EOF'
#!/usr/bin/bash
printf '%s\n' "$*" > "$ESIM_CAPTURE_FILE"
EOF
chmod +x "$work_dir/bin/bash"

capture_file="$work_dir/dispatch.txt"
ESIM_OS_RELEASE_FILE="$work_dir/os-release" \
ESIM_CAPTURE_FILE="$capture_file" \
PATH="$work_dir/bin:$PATH" \
/usr/bin/bash "$ubuntu_dir/install-eSim.sh" --install

grep -q 'install-eSim-24.04.sh --install' "$capture_file"
/usr/bin/bash -n "$ubuntu_dir/install-eSim.sh"
/usr/bin/bash -n "$ubuntu_dir/install-eSim-scripts/install-eSim-24.04.sh"

dependency_script="$ubuntu_dir/install-eSim-scripts/install-eSim-24.04.sh"
grep -q 'python3 -m venv' "$dependency_script"
grep -q 'github.com/hdl/pyhdlparser/tarball/master' "$dependency_script"
if grep -Eq 'pip3 install hdlparse|python -m pip install hdlparse' "$dependency_script"; then
    echo "Obsolete PyPI hdlparse installation is still present" >&2
    exit 1
fi

grep -q 'nghdl_ubuntu_version=.*os-release' "$dependency_script"
grep -q 'nghdl_installer="install-nghdl-scripts/install-nghdl-24.04.sh"' "$dependency_script"
grep -q 'bash "$nghdl_installer" --install' "$dependency_script"
grep -q 'Ubuntu 25.04 also retired the GTK2 Canberra module' "$dependency_script"
grep -q 'llvm-18 llvm-18-dev' "$dependency_script"
grep -q 'llvm-config-18' "$dependency_script"
grep -q 'libxcb-xinerama0' "$dependency_script"
grep -q 'export QT_QPA_PLATFORM=xcb' "$dependency_script"

echo "Ubuntu 25.04 dispatcher and installer smoke tests passed."

