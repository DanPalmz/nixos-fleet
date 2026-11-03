{ pkgs, ... }:
{
  programs.nixarchy.enable = false;

  xfconf = {
    enable = true;
    settings.xfwm4 = {
      "general/click_to_focus" = true;
      "general/focus_new" = true;
      "general/raise_on_click" = true;
      "general/wrap_workspaces" = false;
    };
  };
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    (lutris.override {
      extraPkgs = p: [
        p.wineWow64Packages.stable
        p.winetricks
      ];
    })
    prismlauncher
  ];
}
