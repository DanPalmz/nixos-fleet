{ ... }:
{
  programs.nixarchy.enable = true;
  home.stateVersion = "25.05";

  programs.git = {
    enable = true;
    settings.user.name = "DanPalmz";
    settings.user.email = "dan@danpalmz.com";
  };
}
