# Portable account definition. Hosts supply credentials and local permissions.
{ ... }:
{
  users.users.dan = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBfOETOuOlDVOKg4aS9oZtFqSNJ62SxP6E4WLNwz/Zki dan@danpalmz.com"
    ];
  };

  home-manager.users.dan = import ./home.nix;
}
