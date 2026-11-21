# Fleet-wide policy: every host discovered by flake.nix imports this module.
# Keep optional profiles (family, farm, etc.) in their own opt-in modules.
{ inputs, pkgs, ... }:
{
  imports = [ ../../users/dan ];

  users.users.dan.extraGroups = [
    "wheel"
    "video"
    "input"
    "i2c"
  ];

  environment.systemPackages = with pkgs; [
    sops
    (import ../../packages/pangolin-cli.nix { inherit inputs pkgs; })
  ];
}
