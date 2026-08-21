# eSim Semester Long Internship - Autumn 2026

## Task 4: eSim Upgradation on Ubuntu 25.04

**Candidate:** Aijaz Vali  
**Repository:** [aijazvali/eSim](https://github.com/aijazvali/eSim)  
**Working branch:** [`installers`](https://github.com/aijazvali/eSim/tree/installers)  
**Upstream:** [FOSSEE/eSim](https://github.com/FOSSEE/eSim)

## Executive summary

This work investigated the eSim 2.5 Ubuntu installer on Ubuntu 25.04 (Plucky Puffin), reproduced installation failures, and implemented focused fixes in the `installers` branch. Eleven issues were documented and fixed. The corrected installer was then run end to end in a clean Ubuntu 25.04 desktop virtual machine, and eSim 2.5 was launched successfully. The most important changes are:

- Ubuntu 25.04 is now recognized by the top-level installer without requiring `lsb_release`.
- Ubuntu 25.04 uses the distribution-provided KiCad 8.0.8 packages instead of an incompatible PPA build.
- Python dependencies are installed in a Python 3.13-compatible virtual environment created with the standard `venv` module.
- The obsolete PyPI `hdlparse` release, which fails with modern packaging tools, is replaced by the maintained upstream source.
- The eSim symbol table is written to the active KiCad major-version directory instead of the obsolete KiCad 6.0 directory.
- Interrupted installations can be rerun without failing while recreating `~/.esim/config.ini`.
- Ubuntu 25.04's nested NGHDL installer uses LLVM 18, the newest LLVM release supported by GHDL 4.1, rather than the distribution's incompatible LLVM 20 default.
- The retired GTK2 Canberra package is no longer requested.
- The launcher installs the missing XCB runtime and selects the compatible Qt XCB backend under GNOME/Wayland.

The repository also includes a repeatable Ubuntu 25.04 CI smoke test. This test checks the installer dispatcher, shell syntax, KiCad dependency resolution, and the maintained Hdlparse installation on Python 3.13.

## 1. Objective and scope

The screening task requires candidates to install eSim 2.5 on Ubuntu 25.04, identify dependency or installer problems, fix at least one issue, and document the methodology clearly.

The work covered:

1. Verifying the official eSim 2.5 distribution.
2. Reproducing installer failures on Ubuntu 25.04.
3. Inspecting `install-eSim.sh` and the Ubuntu version-specific installer.
4. Applying minimal Bash changes that preserve the official eSim 2.5 package layout.
5. Validating the corrected logic locally and in an Ubuntu 25.04 container on GitHub Actions.

## 2. Test material and integrity check

The official Linux archive was downloaded from the [FOSSEE eSim downloads page](https://esim.fossee.in/downloads).

| Item | Value |
| --- | --- |
| File | `eSim-2.5.zip` |
| Release date | 03 July 2025 |
| Local size | 100,868,880 bytes |
| Published SHA-256 | `b9860ae26f026930bae589520761f4a57b85d593a2e2cd1ac83d5e5db2f281ed` |
| Calculated SHA-256 | `b9860ae26f026930bae589520761f4a57b85d593a2e2cd1ac83d5e5db2f281ed` |
| Integrity result | Match |

The official ZIP contains the runtime payload expected by the installer, including:

- `library/kicadLibrary.tar.xz`
- `library/sky130_fd_pr.tar.xz`
- `nghdl.zip`
- `images/logo.png`
- `src/frontEnd/Application.py`

This distinction matters: the `installers` branch stores packaging scripts, while the downloadable ZIP is the installable eSim 2.5 product. Installer validation must use the scripts together with the official ZIP payload.

## 3. Test environment

### 3.1 Target platform

| Component | Version / detail |
| --- | --- |
| Operating system | Ubuntu 25.04 |
| Codename | `plucky` |
| Python | 3.13.3 |
| Git | 2.48.1 |
| GCC | 14.2.0 |
| Make | 4.4.1 |
| Desktop test environment | Hyper-V Generation 2 virtual machine |
| VM resources | 4 virtual CPUs, 8 GB RAM, 60 GB virtual disk |
| Installation media | Official `ubuntu-25.04-desktop-amd64.iso` |
| Automated execution environment | Official `ubuntu:25.04` container on a GitHub-hosted runner |

The complete installer was executed in the desktop VM on 22 August 2026 using the verified official eSim 2.5 archive. Installation reached `eSim Installed Successfully`, the plain `esim` launcher opened the workspace selector, and the eSim 2.5 main window rendered successfully.

### 3.2 Repeatable automated validation

The branch includes `.github/workflows/ubuntu-25.04-installer-smoke.yml`, which runs inside the official `ubuntu:25.04` container and verifies:

- Ubuntu 25.04 dispatch to the correct version-specific installer.
- Bash syntax for both modified scripts.
- Availability and dependency resolution of the Ubuntu KiCad packages.
- Creation of a Python 3.13 virtual environment.
- Installation and import of maintained Hdlparse source.

The final automated run completed successfully on commit `f9e81f7` ([workflow evidence](https://github.com/aijazvali/eSim/actions/runs/32473693730)).

## 4. Methodology

1. Downloaded `eSim-2.5.zip` from the official FOSSEE page.
2. Calculated SHA-256 and compared it with the published checksum.
3. Extracted the archive, confirmed the expected runtime payload, and reviewed the documented installation entry point:

   ```bash
   chmod +x install-eSim.sh
   ./install-eSim.sh --install
   ```

4. Reproduced the blocking dependency and dispatcher failures before changing the script.
5. Located the responsible function or command in the installer.
6. Applied one focused change at a time.
7. Repeated syntax, dispatch, dependency, and package-resolution tests.
8. Added automated smoke tests so future changes can be checked on Ubuntu 25.04.
9. Installed the full eSim stack in the Ubuntu 25.04 desktop VM and launched the GUI from the installed `/usr/bin/esim` entry point.

## 5. Issue index

| ID | Issue | Impact | Status |
| --- | --- | --- | --- |
| ESIM-25-01 | Ubuntu 25.04 missing from the top-level dispatcher | Installer stops immediately | Fixed |
| ESIM-25-02 | Version detection depends on `lsb_release` and a three-part version regex | Minimal installs fail or return an empty version | Fixed |
| ESIM-25-03 | Ubuntu 25.04 falls back to an obsolete KiCad PPA path | `apt update` or KiCad installation fails | Fixed |
| ESIM-25-04 | KiCad PPA requires `libgit2-1.8`, but Plucky provides `libgit2-1.9` | Main schematic/PCB dependency cannot install | Fixed |
| ESIM-25-05 | Python environment mixes system packages, `virtualenv`, and environment-local pip | Modules may be unavailable to eSim on Python 3.13 | Fixed |
| ESIM-25-06 | Obsolete PyPI `hdlparse` is installed after the maintained source | Installation aborts with `use_2to3 is invalid` | Fixed |
| ESIM-25-07 | KiCad symbol table is copied to `~/.config/kicad/6.0` | KiCad 8 does not load eSim symbols from the intended table | Fixed |
| ESIM-25-08 | Recreating `config.ini` fails after an interrupted installation | Installer is not safely rerunnable | Fixed |
| ESIM-25-09 | Nested NGHDL dispatcher rejects Ubuntu 25.04 | NGHDL installation stops during the full installer run | Fixed |
| ESIM-25-10 | Ubuntu 25.04 defaults to LLVM 20 and no longer provides the GTK2 Canberra module | GHDL 4.1 build fails and the package transaction cannot resolve | Fixed |
| ESIM-25-11 | PyQt5 GUI lacks `libxcb-xinerama0` and aborts on the bundled Wayland plugin | `esim` terminates before the main window opens | Fixed |

## 6. Detailed findings and fixes

### ESIM-25-01: Ubuntu 25.04 missing from the dispatcher

**Observed behavior**

```text
Unsupported Ubuntu version: 25.04 ()
```

**Cause**

The `case` statement in `Ubuntu/install-eSim.sh` handled 22.04, 23.04, and 24.04 only.

**Fix**

Added an explicit Ubuntu 25.04 case and routed it to the compatible 24.04-family installer, where Plucky-specific KiCad behavior is handled.

**Result**

The dispatcher now reaches the version-specific installation script on Ubuntu 25.04.

### ESIM-25-02: Fragile version detection

**Observed behavior**

The original regular expression expected a three-component version such as `22.04.4`. Ubuntu 25.04 reports `25.04`, so `FULL_VERSION` was empty. The same function also required the optional `lsb_release` command.

**Fix**

The installer now sources `/etc/os-release`, the standard OS identification file available on Ubuntu, and validates `VERSION_ID` before continuing. `ESIM_OS_RELEASE_FILE` can override the file path for automated tests.

**Result**

Version detection works on desktop and minimal Ubuntu installations and is directly testable without modifying `/etc`.

### ESIM-25-03 and ESIM-25-04: Wrong KiCad source and libgit2 mismatch

**Observed behavior**

The fallback path selected an old KiCad PPA. A later KiCad 8 PPA attempt still failed with:

```text
kicad : Depends: libgit2-1.8 (>= 1.8.0) but it is not installable
```

Ubuntu 25.04 provides KiCad 8.0.8 linked against `libgit2-1.9`. The PPA package and the Plucky library set were therefore incompatible.

**Fix**

Ubuntu 25.04 now bypasses KiCad PPAs and installs the distribution packages:

```bash
sudo apt-get install -y --no-install-recommends \
  kicad kicad-footprints kicad-libraries kicad-symbols kicad-templates
```

**Result**

The dependency solver selects the coherent Plucky package set, including KiCad 8.0.8 and `libgit2-1.9`.

### ESIM-25-05: Mixed Python dependency locations

**Observed behavior**

The original script created a `virtualenv` but installed some modules through `apt` and others through whichever `pip3` appeared first on `PATH`. A normal virtual environment does not expose system Python packages, so eSim could start without modules such as `psutil` even though the corresponding Ubuntu package had been installed.

**Fix**

- Install the standard `python3-venv` package.
- Recreate the environment deterministically with `python3 -m venv`.
- Invoke pip as `python -m pip` after activation.
- Install eSim runtime Python modules, including `psutil`, inside the same environment.

**Result**

The launcher and dependency installer now use the same Python environment.

### ESIM-25-06: Obsolete PyPI Hdlparse release

**Observed behavior**

The script installed maintained Hdlparse source and then immediately attempted to replace it with the older PyPI release:

```text
error in hdlparse setup command: use_2to3 is invalid
```

The failure was reproduced with:

```bash
python -m pip install hdlparse==1.0.4
```

The maintained source installed successfully:

```bash
python -m pip install \
  https://github.com/hdl/pyhdlparser/tarball/master
```

**Fix**

Removed the duplicate obsolete PyPI installation and retained the maintained upstream source installation once.

**Result**

Hdlparse builds and imports with modern pip/setuptools and is verified in the Ubuntu 25.04 CI job.

### ESIM-25-07: KiCad 6.0 configuration path used with KiCad 8

**Observed behavior**

The installer always copied `sym-lib-table` to:

```text
~/.config/kicad/6.0/
```

The Plucky package installs KiCad 8.0.8, so this configuration is not the active KiCad profile.

**Fix**

Read the installed KiCad major version using `dpkg-query`, create `~/.config/kicad/<major>.0`, and copy the symbol table there. The default is KiCad 8 if version discovery is unavailable.

**Result**

eSim symbols are registered in the configuration directory used by the installed KiCad version.

### ESIM-25-08: Interrupted-install configuration failure

**Observed behavior**

If `~/.esim` existed but `config.ini` did not, `rm ~/.esim/config.ini` returned an error. Because the installer uses `set -e`, the rerun could abort before dependency installation.

**Fix**

Use idempotent directory and file creation:

```bash
mkdir -p "$config_dir"
: > "$config_dir/$config_file"
```

**Result**

The configuration file is created or replaced safely on both clean and interrupted installations.

### ESIM-25-09 and ESIM-25-10: NGHDL dispatcher and toolchain incompatibilities

**Observed behavior**

The complete installer reached the bundled NGHDL package, whose own dispatcher did not recognize Ubuntu 25.04. Calling its 24.04 implementation then selected Ubuntu 25.04's default LLVM 20 packages, but GHDL 4.1 supports LLVM only through 18.1. The same script also requested the retired GTK2 `libcanberra-gtk-module` package.

**Fix**

For Ubuntu 25.04, the eSim installer invokes the compatible nested 24.04 implementation, patches that temporary extracted script to install `llvm-18` and `llvm-18-dev`, selects `/usr/bin/llvm-config-18`, and retains only `libcanberra-gtk3-module`.

**Result**

The full run built GHDL 4.1.0, NGHDL, Verilator 4.210, and the customized ngspice stack successfully.

### ESIM-25-11: PyQt platform plugin failure on GNOME/Wayland

**Observed behavior**

The first `esim` launch aborted with Qt's platform-plugin error. Dependency inspection of PyQt5's `libqxcb.so` showed `libxcb-xinerama.so.0 => not found`; selecting the bundled Wayland plugin also aborted before the application window was initialized.

**Fix**

Install `libxcb-xinerama0` with the other system prerequisites and export `QT_QPA_PLATFORM=xcb` in the generated `/usr/bin/esim` launcher.

**Result**

The plain `esim` command now opens the workspace prompt and eSim 2.5 main window under Ubuntu 25.04's default GNOME/Wayland session through XWayland.

## 7. Environmental cleanup noted during testing

A failed PPA attempt can leave a KiCad source file under `/etc/apt/sources.list.d/`. Changing the installer does not remove repository entries already created by an earlier run. During troubleshooting, the stale KiCad PPA entry was removed before repeating `apt update`.

This cleanup is documented separately and is not counted as an installer code fix.

## 8. Files changed

| File | Purpose |
| --- | --- |
| `Ubuntu/install-eSim.sh` | Robust OS detection and Ubuntu 25.04 dispatch |
| `Ubuntu/install-eSim-scripts/install-eSim-24.04.sh` | Plucky KiCad path, Python dependencies, Hdlparse, NGHDL/LLVM compatibility, Qt launcher, KiCad config, rerun safety |
| `Ubuntu/tests/test-ubuntu-25.04-installer.sh` | Dispatcher and shell smoke tests |
| `.github/workflows/ubuntu-25.04-installer-smoke.yml` | Automated Ubuntu 25.04 validation |
| `.gitattributes` | Enforce Linux line endings for shell and workflow files |
| `docs/task4-report.md` | Reproducible technical report |

## 9. Validation results

| Check | Result |
| --- | --- |
| Official eSim ZIP SHA-256 | Pass |
| Required runtime assets present in official ZIP | Pass |
| Ubuntu 25.04 dispatcher test | Pass |
| Bash syntax check for modified scripts | Pass |
| Obsolete PyPI Hdlparse failure reproduced | Pass |
| Maintained Hdlparse source installation | Pass |
| Ubuntu KiCad 8.0.8 package metadata and `libgit2-1.9` dependency confirmed | Pass |
| Automated Ubuntu 25.04 workflow | Pass — [run 32473693730](https://github.com/aijazvali/eSim/actions/runs/32473693730) |
| Full installer in Ubuntu 25.04 desktop VM | Pass — installer reported success |
| eSim launcher and main-window rendering | Pass — plain `esim` command |
| Installed KiCad | Pass — 8.0.8 |
| Installed GHDL | Pass — 4.1.0 |
| Installed Verilator | Pass — 4.210 |
| Installed ngspice | Pass — 35 |
| SKY130 PDK payload | Pass — 670 MB installed |

Local smoke-test output:

```text
Detected Ubuntu Version: 25.04 (Plucky Puffin)
Running script: .../install-eSim-24.04.sh --install
Ubuntu 25.04 dispatcher and installer smoke tests passed.
```

## 10. Reproduction instructions

### Test the modified installer with the official eSim 2.5 ZIP

1. Download and extract `eSim-2.5.zip` from the FOSSEE downloads page.
2. Replace the ZIP's two Ubuntu installer scripts with the corresponding files from the fork's `installers` branch.
3. From the extracted eSim directory, run:

   ```bash
   chmod +x install-eSim.sh
   ./install-eSim.sh --install
   ```

4. When installation completes, start eSim with:

   ```bash
   esim
   ```

### Run the repository smoke test

```bash
bash Ubuntu/tests/test-ubuntu-25.04-installer.sh
```

### Review automated evidence

Open the fork's [GitHub Actions page](https://github.com/aijazvali/eSim/actions) and select **Ubuntu 25.04 installer smoke test**.

## 11. Limitations and next steps

- The CI job is intentionally a dependency and installer-logic smoke test; desktop rendering was validated separately in the Hyper-V VM.
- The acceptance run validated installation and eSim startup. A representative schematic simulation can be added as a deeper functional regression test.
- For long-term maintainability, a dedicated `install-eSim-25.04.sh` can be introduced if future Plucky-specific logic grows beyond the current targeted branch.
- Dependency versions should eventually be pinned or recorded in a lock file to reduce changes caused by upstream Python packages.

## 12. Conclusion

The original eSim 2.5 installer did not recognize Ubuntu 25.04 and encountered high-impact KiCad and Python dependency problems. The corrected installer now selects a coherent Plucky KiCad package set, uses a single Python environment, avoids the broken Hdlparse release, places KiCad configuration in the correct version directory, and supports safe reruns.

Eleven issues were documented and fixed. The repository includes the implementation, repeatable automated checks, and evidence from a complete Ubuntu 25.04 desktop installation and GUI launch, so another user can understand the failures, reproduce the methodology, and verify the fixes.

