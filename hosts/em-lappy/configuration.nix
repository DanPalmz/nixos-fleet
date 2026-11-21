{ ... }:
{
  users.users.carly.extraGroups = [ "wheel" ];
  users.users.paul.extraGroups = [ "wheel" ];
  # The common fleet module supplies Dan's account and groups.
  nixpkgs.config.allowUnfree = true;
}
