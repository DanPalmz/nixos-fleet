# Fleet-wide policy: every host discovered by flake.nix imports this module.
# Keep optional profiles (family, farm, etc.) in their own opt-in modules.
{ inputs, pkgs, ... }:
{
  imports = [ ../../users/dan ];

  services.openssh.enable = true;

  users.users.dan.extraGroups = [
    "wheel"
    "video"
    "input"
    "i2c"
  ];

  # Remote deployments copy locally built (unsigned) store paths as Dan before
  # sudo activates the system. Wheel membership alone does not grant Nix trust.
  nix.settings.trusted-users = [ "root" "dan" ];

  environment.systemPackages = with pkgs; [
    sops
    (import ../../packages/pangolin-cli.nix { inherit inputs pkgs; })
  ];
}
