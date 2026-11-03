{ ... }:
{
  programs.nixarchy.enable = true;
  home.stateVersion = "25.05";

  programs.git = {
    enable = true;
    userName = "DanPalmz";
    userEmail = "dan@danpalmz.com";
  };
}
