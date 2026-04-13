# eSim Summer Fellowship 2026 - Task 4 Report

## Candidate Details

| Field | Details |
| --- | --- |
| Name | Aijaz Vali |
| Task | Task 4 - eSim Upgradation |
| Branch | installers |
| Repository Type | Forked GitHub repository |

## Objective

The aim of this task was to install eSim 2.5 on Ubuntu 25.04, note the issues that came up during installation, fix as many as possible, and document the process in a way that can be repeated by another user.

## Test Environment

| Component | Version / Details |
| --- | --- |
| OS | Ubuntu 25.04 |
| Codename | plucky |
| Kernel | 6.14.0-37-generic |
| Python | 3.13.3 |
| Git | 2.48.1 |
| GCC | 14.2.0 |
| Make | 4.4.1 |
| Execution Environment | Virtual machine / Ubuntu desktop environment |

## Files Modified

- `Ubuntu/install-eSim.sh`
- `Ubuntu/install-eSim-scripts/install-eSim-24.04.sh`

## Installation Command Used

I ran the installer from the Ubuntu installer directory:

```bash
bash install-eSim.sh --install
```

## Issue Index

| Issue | Title | Status |
| --- | --- | --- |
| 1 | Ubuntu 25.04 not supported by top-level installer | Fixed |
| 2 | Invalid apt-get command for xz-utils | Fixed |
| 3 | Wrong KiCad PPA selected for Ubuntu 25.04 | Fixed |
| 4 | Stale KiCad 6.0 PPA remained after failed installation | Fixed |
| 5 | KiCad 8.0 PPA dependency mismatch on Ubuntu 25.04 | Fixed |
| 6 | Missing runtime asset `library/kicadLibrary.tar.xz` | Identified, not fixed |

## Issues Found

### Issue 1: Ubuntu 25.04 Not Supported by Top-Level Installer

#### What I Observed

The main installer script failed immediately on Ubuntu 25.04. It did not select any version-specific installer script, so the installation stopped before reaching the dependency installation steps.

```text
Detected Ubuntu Version:
Unsupported Ubuntu version: 25.04 ()
```

#### Why It Happened

- The `FULL_VERSION` regex expected a three-part version string such as `22.04.4`.
- Ubuntu 25.04 exposed only `25.04`, so version extraction failed.
- The `case` block in the dispatcher did not include support for Ubuntu 25.04.

#### Fix Applied

I changed the `FULL_VERSION` regex from:

```bash
\d+\.\d+\.\d+
```

to:

```bash
\d+\.\d+(\.\d+)?
```

I also added a case entry for `25.04` and mapped it to `install-eSim-24.04.sh` for compatibility testing:

```bash
"25.04")
    SCRIPT="$SCRIPT_DIR/install-eSim-24.04.sh"
    ;;
```

#### Result

The installer moved past the unsupported-version failure and started running the version-specific script.

Status: fixed

### Issue 2: Invalid apt-get Command for xz-utils

#### What I Observed

After fixing Ubuntu version detection, the installer moved further but failed while preparing `volare`.

```text
Installing volare
E: Invalid operation xz-utils
```

#### Why It Happened

- The script used `sudo apt-get xz-utils`, which is not a valid `apt-get` command.
- The `install` subcommand was missing.

#### Fix Applied

I replaced:

```bash
sudo apt-get xz-utils
```

with:

```bash
sudo apt-get install -y xz-utils
```

#### Result

The installer progressed beyond the `volare` preparation step.

Status: fixed

### Issue 3: Wrong KiCad PPA Selected for Ubuntu 25.04

#### What I Observed

The installer tried to use the KiCad 6.0 PPA on Ubuntu 25.04.

```text
The repository 'https://ppa.launchpadcontent.net/kicad/kicad-6.0-releases/ubuntu plucky Release' does not have a Release file.
```

#### Why It Happened

- Inside `installKicad()`, only Ubuntu 24.04 was mapped to the KiCad 8.0 path.
- Ubuntu 25.04 fell into the fallback branch, which used `kicad/kicad-6.0-releases`.
- That PPA does not provide a valid `plucky` release file for Ubuntu 25.04.

#### Fix Applied

I updated the KiCad version-selection logic so that Ubuntu 25.04 no longer falls into the old KiCad 6.0 branch.

#### Result

The installer stopped selecting the obsolete KiCad 6.0 PPA for Ubuntu 25.04.

Status: fixed

### Issue 4: Stale KiCad 6.0 PPA Remained After Failed Installation

#### What I Observed

Even after correcting the KiCad branch logic, `apt update` still failed because the old KiCad 6.0 source was still present on the system.

```text
apt update continued to fail due to the old kicad-6.0-releases source
```

#### Why It Happened

- A previous failed installer run had already added the outdated PPA to `/etc/apt/sources.list.d/`.
- Changing the installer script did not automatically remove the old source file from the machine.

#### Fix Applied

I removed the stale KiCad 6.0 source file from:

```text
/etc/apt/sources.list.d/
```

This was a system cleanup step, not a repository code change.

#### Result

`apt update` no longer failed because of the old KiCad 6.0 repository.

Status: fixed

### Issue 5: KiCad 8.0 PPA Dependency Mismatch on Ubuntu 25.04

#### What I Observed

After moving away from the KiCad 6.0 PPA, the installer still failed with unmet dependencies while trying to install KiCad from the KiCad 8.0 PPA.

```text
kicad : Depends: libgit2-1.8 (>= 1.8.0) but it is not installable
```

#### Why It Happened

- The KiCad package from the PPA required `libgit2-1.8`.
- Ubuntu 25.04 provides `libgit2-1.9` instead.
- The Ubuntu 25.04 repository already contains a distro-native KiCad package that is compatible with `libgit2-1.9`.

#### Fix Applied

I modified `installKicad()` so that Ubuntu 25.04 uses the distro KiCad package instead of the KiCad PPA. I also removed the KiCad 8.0 PPA source file so that `apt` would select the Ubuntu repository candidate.

#### Result

KiCad 8.0.8 and its required dependencies installed successfully from the Ubuntu 25.04 repository.

Status: fixed

### Issue 6: Missing Runtime Asset library/kicadLibrary.tar.xz

#### What I Observed

After KiCad installation completed successfully, the installer failed while trying to extract the custom KiCad library tarball.

```text
tar (child): library/kicadLibrary.tar.xz: Cannot open: No such file or directory
tar: Child returned status 2
tar: Error is not recoverable: exiting now
```

#### Why It Happened

- The installer expects runtime assets such as `library/kicadLibrary.tar.xz`, `images/logo.png`, and `src/frontEnd/Application.py`.
- The current `installers` branch checkout does not contain the expected library payload.
- Git history indicates that `kicadLibrary.tar.xz` existed earlier, which suggests a branch layout regression or a missing installer asset.

#### Fix Applied

No code fix has been applied for this issue yet. I have documented it as the current blocker.

#### Result

The issue is identified and documented, but it still needs to be fixed.

Status: identified, not fixed

## Git Workflow

| Step | Status |
| --- | --- |
| Forked the FOSSEE/eSim repository | Done |
| Configured `upstream` as the original repository | Done |
| Configured `origin` as the personal fork | Done |
| Pushed the `installers` branch to the fork | Done |

## Summary

| Item | Count |
| --- | --- |
| Total issues identified | 6 |
| Issues fixed | 5 |
| Issues pending | 1 |

Main outcomes from this work:

- Enabled Ubuntu 25.04 support in the top-level installer.
- Fixed malformed `apt-get` usage for `xz-utils`.
- Corrected KiCad repository selection logic.
- Resolved stale PPA conflicts from earlier failed runs.
- Switched Ubuntu 25.04 KiCad installation to distro packages.
- Identified missing runtime assets in the `installers` branch.

## Current Status

The installation now proceeds much further on Ubuntu 25.04 than it did initially. Multiple compatibility issues have been fixed, including the Ubuntu version dispatcher, the `xz-utils` installation command, and the KiCad repository selection path.

The remaining blocker is the missing custom KiCad library asset expected by the installer:

```text
library/kicadLibrary.tar.xz
```

Until this asset is restored or the installer is updated to handle its absence, the installation cannot complete fully on Ubuntu 25.04.
