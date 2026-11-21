# Run: nix eval --impure --json --file tests/family-fleet.nix
let
  flake = builtins.getFlake (toString ../.);
  lib = flake.inputs.nixarchy.inputs.nixpkgs.lib;
  c = flake.nixosConfigurations.em-lappy.config;
  redtail = flake.nixosConfigurations.redtail.config;
  normal = lib.filterAttrs (_: user: user.isNormalUser) c.users.users;
  wheel = lib.attrNames (lib.filterAttrs (_: user: builtins.elem "wheel" user.extraGroups) normal);
  checks = {
    accounts = lib.attrNames normal == [ "carly" "dan" "emily" "ned" "paul" ];
    permissions = wheel == [ "carly" "dan" "paul" ];
    fleetDan = builtins.all (host: host.config.users.users.dan.isNormalUser
      && builtins.elem "wheel" host.config.users.users.dan.extraGroups
      && host.config.home-manager.users.dan.programs.nixarchy.enable)
      (builtins.attrValues flake.nixosConfigurations);
    farmGroup = builtins.all (name: builtins.elem "primrosevalleyfarm" c.users.users.${name}.extraGroups)
      [ "emily" "ned" "carly" "paul" ];
    noPasswords = builtins.all (user:
      user.initialPassword == null && user.initialHashedPassword == null
      && user.password == null && user.hashedPassword == null
      && user.hashedPasswordFile == null) (builtins.attrValues normal);
    desktop = c.services.xserver.desktopManager.xfce.enable
      && c.services.xserver.displayManager.lightdm.enable
      && c.services.xserver.displayManager.lightdm.greeters.gtk.enable
      && !c.services.displayManager.sddm.enable
      && c.services.displayManager.defaultSession == "xfce"
      && !c.services.displayManager.autoLogin.enable;
    danSession = c.home-manager.users.dan.programs.nixarchy.enable
      && lib.hasInfix "SetSession s omarchy" c.services.displayManager.generic.preStart
      && lib.hasInfix "SetSessionType s wayland" c.services.displayManager.generic.preStart;
    apps = builtins.all (name: builtins.elem name
      (map lib.getName c.environment.systemPackages)) [ "firefox" "bitwarden-desktop" ];
    identity = c.networking.hostName == "em-lappy"
      && c.networking.networkmanager.settings.main.hostname-mode == "none"
      && !c.systemd.services.nixarchy-set-hostname.enable;
    updates = c.system.autoUpgrade.enable
      && c.system.autoUpgrade.flake == "github:DanPalmz/nixos-fleet#em-lappy"
      && builtins.elem "--refresh" c.system.autoUpgrade.flags
      && c.system.autoUpgrade.persistent && !c.system.autoUpgrade.allowReboot;
    wifiBootstrap = !(flake.nixosConfigurations.em-lappy.extendModules {
      modules = [ { local.family.wifi.sopsFile = ./fixtures/not-enrolled.yaml; } ];
    }).config.local.family.wifi.enable;
    storage = c.disko.devices.disk.main.device == "/dev/sda"
      && c.fileSystems."/".fsType == "btrfs"
      && c.boot.initrd.luks.devices == { };
    timezone = c.time.timeZone == "Australia/Sydney";
    redtailIsolation = redtail.services.displayManager.sddm.enable
      && !(redtail.users.users ? emily)
      && !redtail.system.autoUpgrade.enable;
  };
in
assert lib.assertMsg (builtins.all (x: x) (builtins.attrValues checks))
  "Failed checks: ${lib.concatStringsSep ", " (lib.attrNames (lib.filterAttrs (_: ok: !ok) checks))}";
checks
