# Import this module on each Nixarchy host Nathan uses, including his desktop.
{ ... }:
{
  imports = [ ../../modules/sddm-omarchy-users ];

  services.xserver = {
    enable = true;
    desktopManager.xfce.enable = true;
  };
  local.sddm.userSessions.nathan = "Xfce Session";

  users.users.nathan = {
    isNormalUser = true;
    description = "Nathan";
    # No initial password: set one locally with sudo passwd nathan.
  };

  home-manager.users.nathan = import ./home.nix;
}
