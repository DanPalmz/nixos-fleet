# Shared SSH-only accounts. Import on each host that needs test runners.
{ lib, ... }:
let
  authorizedKeys = [
    # Dan's existing authorized key and Redtail public key.
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBfOETOuOlDVOKg4aS9oZtFqSNJ62SxP6E4WLNwz/Zki dan@danpalmz.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIifA6sbYb4hv1//bkyJudQ8ZfgxuFtpRwXyQ7UeqorV dan@redtail"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM7MaD6Ou2aHM+DYnxt0eRr0Tx9RfMeHGzpJMO685MTb flywheel@syd-sn2"
  ];
in
{
  users.users = lib.genAttrs [ "test-runner1" "test-runner2" "test-runner3" ] (name: {
    isNormalUser = true;
    linger = true;
    description = "Test runner ${lib.removePrefix "test-runner" name}";
    openssh.authorizedKeys.keys = authorizedKeys;
  });
}
