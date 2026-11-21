# Match the existing installation; do not run disko formatting on this machine.
{ ... }:
{
  imports = [
    (import ./disk-config.nix {
      mode = "whole";
      device = "/dev/sda";
      encrypt = false;
    })
  ];
}
