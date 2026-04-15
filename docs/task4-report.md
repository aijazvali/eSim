# eSim Summer Fellowship 2026 - Task 4 Report

## Candidate Details

| Field | Details |
| --- | --- |
| Name | Aijaz Vali |
| Task | Task 4 - eSim Upgradation |
| Working branch | `post-date` |
| Repository type | Forked GitHub repository |

## Objective

The aim of this task was to make the eSim 2.5 Ubuntu installer work properly on Ubuntu 25.04.

I had first managed to install eSim on one Ubuntu 25.04 machine, but that install was not a reliable proof. Some files had already been edited locally, some dependencies were already present, and the extracted NGHDL folder had state from earlier attempts. When I tried the same thing on a fresh Ubuntu 25.04 machine, the installer failed again.

So the goal was not only to make my own machine work. The goal was to turn those manual fixes into a repeatable installer change.

## Test Environment

| Component | Version / Details |
| --- | --- |
| OS | Ubuntu 25.04 |
| Codename | plucky |
| Python | 3.13.3 |
| GCC | 14.2.0 |
| Main fresh test setup | Ubuntu 25.04 virtual machine |
| eSim release payload checked | `/home/aijaz/Downloads/eSim-2.5` |

## Final File Layout

The final change keeps the Ubuntu 24.04 installer untouched.

Ubuntu 25.04 support is handled in its own installer script:

```text
Ubuntu/install-eSim-scripts/install-eSim-25.04.sh
```

The top-level installer dispatches Ubuntu 25.04 to that script:

```text
Ubuntu/install-eSim.sh
```

The 24.04 file was restored and left as it was:

```text
Ubuntu/install-eSim-scripts/install-eSim-24.04.sh
```

## Files Changed

The relevant code changes are:

```text
Ubuntu/install-eSim.sh
Ubuntu/install-eSim-scripts/install-eSim-25.04.sh
```

Documentation added or updated:

```text
docs/task4-report.md
docs/ubuntu-25.04-installer-fix.md
```

## Installation Command Used

The installer was tested from the Ubuntu installer directory:

```bash
cd /home/vboxuser/Desktop/test/eSim/Ubuntu
./install-eSim.sh --install
```

The 25.04 installer was also written to detect the real eSim release root when it is launched from the `Ubuntu/` folder.

## Issues Found And Fixed

### 1. Ubuntu 25.04 was not handled cleanly

The first failure was at the top-level installer:

```text
Detected Ubuntu Version:
Unsupported Ubuntu version: 25.04 ()
```

Ubuntu 25.04 reports a two-part version such as `25.04`. The old parsing and dispatcher logic did not handle that properly.

Fix:

- Read the version from `/etc/os-release` and `lsb_release -rs`.
- Add a `25.04` case in the dispatcher.
- Route Ubuntu 25.04 to `install-eSim-25.04.sh`.

Final dispatch:

```bash
"25.04")
    SCRIPT="$SCRIPT_DIR/install-eSim-25.04.sh"
    ;;
```

### 2. The 24.04 installer should not be disturbed

At one stage, fixes were tried inside the 24.04 script. That was not the right final approach because it could affect existing Ubuntu 24.04 users.

Final decision:

- Restore `install-eSim-24.04.sh`.
- Keep Ubuntu 25.04 fixes in `install-eSim-25.04.sh`.

This makes the change easier to review and keeps the compatibility work separate.

### 3. Running from an installer-only checkout failed late

On a fresh machine, I first ran the installer from an `Ubuntu/` folder that did not have the full eSim runtime payload above it.

The missing files were:

```text
nghdl.zip
library/kicadLibrary.tar.xz
images/logo.png
src/frontEnd/Application.py
```

Earlier, this kind of problem showed up later as a tar extraction failure. That was confusing because many apt and pip steps had already run.

Fix:

- Add a preflight check in the 25.04 installer.
- Show all missing payload files before starting dependency installation.
- Print the eSim release directory that was checked.
- Explain that the installer must be run from, or copied into, a complete eSim release folder.

The complete release folder I checked locally was:

```text
/home/aijaz/Downloads/eSim-2.5
```

It contains the required payload files.

### 4. The installer needed to find the real eSim root

The old scripts assume the current working directory is the eSim release root.

On the fresh test machine I ran:

```bash
cd /home/vboxuser/Desktop/test/eSim/Ubuntu
./install-eSim.sh --install
```

In that case, the current directory is `Ubuntu/`, not the release root.

Fix:

- The 25.04 script now checks the current directory, the installer directory parent, and the repository/release root candidate.
- It uses the nearest directory that contains release payload files.
- It then changes into that directory before continuing.

### 5. KiCad PPAs are not suitable for Ubuntu 25.04

The older KiCad 6.0 PPA does not support Ubuntu 25.04 `plucky`.

The KiCad 8.0 PPA also caused dependency mismatch problems on Ubuntu 25.04. The observed issue was around the PPA expecting an older `libgit2`, while Ubuntu 25.04 provides a newer one.

Fix:

- For Ubuntu 25.04, install KiCad from the Ubuntu distro repository.
- Enable `universe`.
- Disable stale KiCad PPA source files before running `apt update`.
- Check that `kicad` has an apt candidate before installing it.

This avoids depending on a PPA that was meant for a different Ubuntu release.

### 6. Python 3.13 changed dependency behavior

Ubuntu 25.04 uses Python 3.13.

Problems found:

- `python3-distutils` is not available.
- The old PyPI `hdlparse` package fails because it uses removed `use_2to3` setup behavior.
- Installing PyQt5 and matplotlib from pip is more fragile on this distro.

Fix:

- Install PyQt5, matplotlib, psutil, pip, venv, and setuptools from apt.
- Create the eSim virtual environment with system site packages visible.
- Install only the eSim-specific Python tools using pip.
- Use the maintained `hdl/pyhdlparser` source.
- Do not install the obsolete PyPI `hdlparse` package.

### 7. KiCad config path was hardcoded to 6.0

The older installer copied eSim symbols into:

```text
~/.config/kicad/6.0
```

On Ubuntu 25.04, the distro KiCad package is KiCad 8.

Fix:

- Detect the newest KiCad config folder.
- If no KiCad config folder exists yet, create and use `8.0`.

### 8. NGHDL changes must survive a fresh unzip

One reason the first machine worked was that files inside the already-extracted `nghdl/` folder had been edited.

That does not help a fresh install because the eSim installer extracts `nghdl.zip` again.

Fix:

- Remove stale extracted `nghdl/`.
- Extract `nghdl.zip`.
- Patch the extracted NGHDL installer at runtime for Ubuntu 25.04.

This means the fix is applied every time, even when the machine has no previous extracted NGHDL folder.

### 9. GHDL 4.1.0 failed with Ubuntu 25.04's default LLVM

Ubuntu 25.04 defaults to LLVM 20.

The bundled GHDL 4.1.0 build did not work with LLVM 20. The build needed LLVM 18.

Fix:

- Install LLVM 18 packages:

```text
llvm-18
llvm-18-dev
clang-18
```

- Use:

```text
/usr/bin/llvm-config-18
```

### 10. Fresh machine did not have unversioned clang++

After LLVM was pinned correctly, the fresh machine still failed during GHDL build:

```text
LLVM_CONFIG="/usr/bin/llvm-config-18" CXX="clang++"
clang++: not found
```

This happened because the GHDL build generated `CXX="clang++"`, but a fresh Ubuntu 25.04 system with `clang-18` may only have `clang++-18`.

Fix:

- Patch the extracted NGHDL installer so GHDL configure and make use the versioned compiler directly:

```bash
CC=clang-18 CXX=clang++-18 ./configure --with-llvm-config="$llvm_config"
make CC=clang-18 CXX=clang++-18 -j$(nproc)
```

The patch was tested against the real `nghdl.zip` from the eSim 2.5 release folder.

### 11. Removed GTK2 canberra package

Ubuntu 25.04 does not provide:

```text
libcanberra-gtk-module
```

Fix:

- Use `libcanberra-gtk3-module` for Ubuntu 25.04.

### 12. SKY130 install should not depend on root-owned Volare state

The old SKY130 flow used `/usr/share/local` directly as the Volare root. That can leave root-owned intermediate state and makes reruns less clean.

Fix:

- Download the PDK into a user-writable staging directory under `~/.esim`.
- Copy the final PDK into `/usr/share/local`.
- Skip the download if `/usr/share/local/sky130_fd_pr` already exists.

## How To Reproduce The Installation

Use a complete eSim release directory. It must contain:

```text
nghdl.zip
library/kicadLibrary.tar.xz
images/logo.png
src/frontEnd/Application.py
```

If the installer repository is separate from the release folder, copy the installer files into the release root:

```bash
FULL=/path/to/eSim-2.5

cp /path/to/installer-repo/Ubuntu/install-eSim.sh "$FULL/"
cp -r /path/to/installer-repo/Ubuntu/install-eSim-scripts "$FULL/"

cd "$FULL"
./install-eSim.sh --install
```

If the release payload is one level above the `Ubuntu/` folder, this also works:

```bash
cd /path/to/eSim/Ubuntu
./install-eSim.sh --install
```

## Verification Done

Syntax check:

```bash
bash -n Ubuntu/install-eSim.sh \
    Ubuntu/install-eSim-scripts/install-eSim-24.04.sh \
    Ubuntu/install-eSim-scripts/install-eSim-25.04.sh
```

Whitespace check:

```bash
git diff --check
```

Payload check:

```bash
ls /home/aijaz/Downloads/eSim-2.5/nghdl.zip
ls /home/aijaz/Downloads/eSim-2.5/library/kicadLibrary.tar.xz
ls /home/aijaz/Downloads/eSim-2.5/images/logo.png
ls /home/aijaz/Downloads/eSim-2.5/src/frontEnd/Application.py
```

NGHDL patch check:

- Extracted and inspected the real `nghdl.zip` from `/home/aijaz/Downloads/eSim-2.5`.
- Confirmed the 25.04 installer patch rewrites the GHDL build to use LLVM 18 and `clang++-18`.

Fresh machine testing:

- The installer correctly selected `install-eSim-25.04.sh`.
- The preflight check correctly caught installer-only runs.
- After using the full payload, the install progressed into the GHDL build.
- The `clang++` failure found there was fixed by forcing `clang++-18` in the patched NGHDL build commands.

## Current Status

The Ubuntu 25.04 installer work is now separated from Ubuntu 24.04.

The 24.04 installer is not changed.

The 25.04-specific script handles:

- Ubuntu 25.04 dispatch
- full release payload checks
- release-root detection
- KiCad distro package installation
- stale KiCad PPA cleanup
- Python 3.13 dependency handling
- KiCad 8 config path handling
- NGHDL runtime patching
- LLVM 18 pinning
- `clang++-18` GHDL build
- removed GTK2 canberra dependency
- safer SKY130 staging

The remaining practical step is to rerun the installer on the fresh Ubuntu 25.04 VM after pulling the latest `install-eSim-25.04.sh` change.
