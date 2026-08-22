# eSim Task 4 Submission

## eSim 2.5 on Ubuntu 25.04

**Candidate:** Mohd Aijaz Vali  
**Repository:** [aijazvali/eSim](https://github.com/aijazvali/eSim)  
**Branch:** `installers`

## Executive summary

The eSim 2.5 installer did not work correctly on Ubuntu 25.04 because several checks and dependencies were outdated. I updated the installer, completed the installation, and launched eSim successfully. The corrected scripts and automated test are available in the linked GitHub repository.

## 1. Objective

Make the official eSim 2.5 installer work reliably on Ubuntu 25.04 without changing the application itself.

## 2. Changes made

| Change | Problem | Fix |
| --- | --- | --- |
| Ubuntu routing | The main installer did not recognize Ubuntu 25.04. | Added a 25.04 route to the compatible Ubuntu installer. |
| Version detection | The old check depended on `lsb_release` and expected a longer version number. | Read `VERSION_ID` from `/etc/os-release` and validated it before continuing. |
| KiCad source | The fallback PPA path was not suitable for Ubuntu 25.04. | Used Ubuntu's own KiCad packages instead of the PPA. |
| KiCad libraries | The PPA build expected an older `libgit2` package. | Kept KiCad and its libraries within Ubuntu's matching package set. |
| Python setup | Python modules were being installed in different environments. | Created one environment with `python3 -m venv` and installed runtime modules there. |
| HDL parser | The old PyPI package failed with current Python packaging tools. | Removed the old package and installed the maintained source version. |
| KiCad config | The symbol table was copied to a KiCad 6 directory. | Detected the installed KiCad version and used its active configuration directory. |
| Rerun safety | A repeated installation could fail while recreating `config.ini`. | Made directory and file creation safe to run more than once. |
| NGHDL routing | The bundled NGHDL installer did not recognize Ubuntu 25.04. | Directed it to the compatible Ubuntu installer path. |
| LLVM and GTK | GHDL did not support the default LLVM version, and an old GTK package was unavailable. | Selected LLVM 18 and retained only the supported GTK3 package. |
| GUI launch | The application was missing an XCB library and failed with the Qt Wayland backend. | Installed the XCB dependency and launched eSim with the XCB Qt backend. |

## 3. Steps followed

1. Ran the original installer and noted where it stopped on Ubuntu 25.04.
2. Checked the top-level installer and added correct Ubuntu 25.04 detection and routing.
3. Tested package resolution and replaced the incompatible KiCad source with Ubuntu's packages.
4. Rebuilt the Python environment with `venv`, installed the maintained HDL parser, and corrected the KiCad configuration path.
5. Traced the NGHDL failure, selected its compatible installer path, and used LLVM 18.
6. Investigated the GUI startup error, added the missing XCB package, and selected the XCB Qt backend.
7. Ran the complete installer again, launched eSim, and added the automated smoke test.

## 4. Verification

- The full installer completed successfully.
- The `esim` command opened the application.
- The Ubuntu 25.04 [GitHub Actions test](https://github.com/aijazvali/eSim/actions/runs/32525366733) passed.

## 5. Files changed

| File | Purpose |
| --- | --- |
| `Ubuntu/install-eSim.sh` | Ubuntu 25.04 detection and dispatch |
| `Ubuntu/install-eSim-scripts/install-eSim-24.04.sh` | Dependency and launch fixes |
| `Ubuntu/tests/test-ubuntu-25.04-installer.sh` | Installer checks |
| `.github/workflows/ubuntu-25.04-installer-smoke.yml` | Automated test |

## 6. Conclusion

The corrected installer now installs and launches eSim 2.5 successfully on Ubuntu 25.04. The changes are limited to installer compatibility and are available in the `installers` branch.
