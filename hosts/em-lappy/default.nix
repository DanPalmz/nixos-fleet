{ inputs, lib, ... }:
{
  imports = [
    (args@{ pkgs, ... }:
      let
        host = import "${inputs.self}/installer/host.nix" {
          hostname = "em-lappy";
          username = "dan";
        } args;
      in
      builtins.removeAttrs host [ "users" ] // {
        home-manager = builtins.removeAttrs host.home-manager [ "users" ];
      })
    ./configuration.nix
    ./hardware-configuration.nix
    ./nixarchy-hardware.nix
    ./storage.nix
    ./nixarchy-apps.nix
    ../../modules/family
  ];

  # The installer module sets an empty hostname to share prebuilt closures.
  # This fleet instead owns its identity declaratively.
  networking.hostName = lib.mkForce "em-lappy";
}
