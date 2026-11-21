# What this machine is, as nixos-hardware modules.
#
# GENERATED at install time by detecting this hardware. Safe to edit:
# nothing regenerates it behind you. Everything these modules set is
# lib.mkDefault, so anything you write elsewhere wins.
#
# NVIDIA is deliberately absent even on a machine that has one: the
# driver choice (open vs legacy_580) and the PRIME bus ids are not
# things to guess, and getting them wrong is a machine with no screen.
# Run: nixarchy doctor -- it computes both and prints the lines.
#
# The 412 machine-specific modules (dell-xps-13-9310, framework-13-
# 7040-amd, ...) are not chosen automatically either: they key on DMI
# product strings with no machine-readable table, so a fuzzy match
# risks importing the quirks of the model next to yours. Browse
# https://github.com/NixOS/nixos-hardware and add yours here.
{ inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel-cpu-only
    inputs.nixos-hardware.nixosModules.common-gpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
  ];
}
