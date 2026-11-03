# Portable account definition. Hosts supply credentials and local permissions.
{ ... }:
{
  users.groups.agents = {};

  users.users."starbird-paperclip" = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJdg9VNqQXhio2I/tO5Ngj8TOwa5jLyH89aYpsVSYJBx sisko@starbird-paperclip"
    ];
    isNormalUser = true;
    extraGroups = [ "agents" ];
  };

  users.users."handsontech-paperclip" = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILX8EuoUZqb44z1oX+kXVeiem1FJp9nqfR+8dUUu8e9g handsontech-deployed-iac-trip-nix-controller-2026-10-30"
    ];
    isNormalUser = true;
    extraGroups = [ "agents" ];
  };

}
