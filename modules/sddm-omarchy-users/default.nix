# Preserve the upstream theme assets and add account selection for shared PCs.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  theme = pkgs.runCommand "omarchy-sddm-users" { nativeBuildInputs = [ pkgs.patch ]; } ''
    themeDir="$out/share/sddm/themes/omarchy-users"
    mkdir -p "$themeDir"
    cp -r ${config.programs.nixarchy.package}/share/sddm/themes/omarchy/. "$themeDir/"
    chmod -R u+w "$themeDir"
    patch --directory="$themeDir" --strip=1 < ${./user-selector.patch}
    substituteInPlace "$themeDir/Main.qml" \
      --replace-fail '@preferredSessions@' "$(cat ${pkgs.writeText "sddm-user-sessions.json" (builtins.toJSON config.local.sddm.userSessions)})"
  '';
in
{
  options.local.sddm.userSessions = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "Preferred SDDM session display name for each account.";
  };

  config = {
    services.displayManager.sddm.theme = "${theme}/share/sddm/themes/omarchy-users";
    # This cursor is already provided by the desktop; name it explicitly for SDDM.
    services.displayManager.sddm.settings.Theme = {
      CursorTheme = "Bibata-Modern-Classic";
      CursorSize = 32;
    };
    system.build.omarchyUserTheme = theme;
  };
}
