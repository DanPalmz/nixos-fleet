# Evaluate configuration wiring with a non-secret test fixture; no decryption.
let
  flake = builtins.getFlake (toString ../.);
  lib = flake.inputs.nixarchy.inputs.nixpkgs.lib;
  host = flake.nixosConfigurations.em-lappy.extendModules {
    modules = [ {
      local.family.wifi = {
        enable = true;
        sopsFile = ./fixtures/wifi.yaml;
        networks = {
          home = {
            ssidVariable = "HOME_WIFI_SSID";
            pskVariable = "HOME_WIFI_PSK";
            priority = 20;
          };
          farm = {
            ssidVariable = "FARM_WIFI_SSID";
            pskVariable = "FARM_WIFI_PSK";
            priority = 10;
            hidden = true;
          };
        };
      };
      sops.validateSopsFiles = false;
    } ];
  };
  c = host.config;
  unit = c.systemd.services.NetworkManager-ensure-profiles;
  checks = {
    fileReference = c.networking.networkmanager.ensureProfiles.environmentFiles
      == [ c.sops.secrets.family-wifi-environment.path ];
    multipleNetworks = lib.attrNames c.networking.networkmanager.ensureProfiles.profiles
      == [ "family-wifi-farm" "family-wifi-home" ];
    runtimeSubstitution = c.networking.networkmanager.ensureProfiles.profiles.family-wifi-home.wifi-security.psk == "$HOME_WIFI_PSK"
      && c.networking.networkmanager.ensureProfiles.profiles.family-wifi-farm.wifi.ssid == "$FARM_WIFI_SSID";
    priority = c.networking.networkmanager.ensureProfiles.profiles.family-wifi-home.connection.autoconnect-priority == 20;
    hiddenNetwork = c.networking.networkmanager.ensureProfiles.profiles.family-wifi-farm.wifi.hidden;
    rootOnly = c.sops.secrets.family-wifi-environment.mode == "0400";
    targetKey = builtins.elem "/etc/ssh/ssh_host_ed25519_key" c.sops.age.sshKeyPaths;
    ordering = c.sops.useSystemdActivation
      && builtins.elem "sops-install-secrets.service" unit.after
      && builtins.elem "sops-install-secrets.service" unit.requires
      && c.systemd.services.sops-install-secrets.serviceConfig.Type == "oneshot";
    rotation = builtins.elem "NetworkManager-ensure-profiles.service"
      c.sops.secrets.family-wifi-environment.restartUnits
      && (unit.serviceConfig.RemainAfterExit or false);
    autoconnect = lib.hasInfix "connection up id" unit.postStart
      && lib.hasInfix "family-wifi-home family-wifi-farm" unit.postStart
      && lib.hasInfix "break" unit.postStart;
  };
in
assert lib.assertMsg (builtins.all (x: x) (builtins.attrValues checks))
  "Failed Wi-Fi checks: ${lib.concatStringsSep ", " (lib.attrNames (lib.filterAttrs (_: ok: !ok) checks))}";
checks
