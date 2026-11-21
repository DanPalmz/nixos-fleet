# Family fleet implementation plan

> Execute inline using executing-plans; preserve all pre-existing edits.

**Goal:** Prepare em-lappy and reusable family/farm configuration.
**Architecture:** Opt-in modules, host-local identity and hardware, shared SOPS.
**Tech stack:** NixOS, Nixarchy, Home Manager, LightDM, XFCE, sops-nix.
**Spec:** ../specs/2026-11-21-family-fleet-design.md

## Constraints and review focus

No passwords or private keys in Git. Only carly/paul in wheel. No copied hardware.
Redtail must not gain family settings. Explicit host selection must survive DHCP.
Use uploaded hardware and confirmed /dev/sda whole-disk unencrypted layout;
absent Wi-Fi secrets must allow bootstrap.
Dan must retain Nixarchy despite LightDM's global default-session reset.

## Tasks

- [x] Write evaluation checks for accounts, permissions, sessions, updates,
  hostname and Wi-Fi bootstrap; confirm failure before modules.
- [x] Add family and farm modules and em-lappy with uploaded hardware/storage.
- [x] Add Wi-Fi enrollment and installation documentation.
- [x] Stage only new files for flake visibility; run checks with locked inputs.
- [x] Evaluate all system assertions and derivation construction, including Wi-Fi
  wiring with a non-secret fixture. Do not activate, push, or format any disk.

## Execution notes

The first evaluation failed because em-lappy had no host module. Subsequent
checks caught an omitted module argument, an incorrect expected package name,
and an assumption that Redtail lacked XFCE (it already has it). Full evaluation
caught equal-priority timezone defaults; the family default now outranks the
installer default while remaining overridable by normal host declarations.
Hardware/storage placeholders were replaced after the user supplied the files
and confirmed mode/device/encryption. No hardware values were guessed.
The later-uploaded nixarchy-hardware.nix imports Intel CPU/graphics and laptop
SSD profiles. Configuration checks pass with these modules included. A fresh
review found no important defects; its credential escaping documentation finding
was addressed. Twenty evaluated checks passed. No system activation was run.
Final review of SOPS restart semantics found that its try-restart skips inactive
oneshots. The rotation check was strengthened and failed as expected, then the
provisioning unit gained RemainAfterExit so it can be restarted on rotation.
