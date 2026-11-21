# Import on family desktops; farm accounts can also be imported independently.
{ config, lib, pkgs, ... }:
let
  wifi = config.local.family.wifi;
  profileName = name: if name == "family" then "family-wifi" else "family-wifi-${name}";
  connectionId = name: if name == "family" then "Family Wi-Fi" else profileName name;
  preferredNetworks = lib.sort
    (a: b: wifi.networks.${a}.priority > wifi.networks.${b}.priority)
    (lib.attrNames wifi.networks);
  # The NixOS LightDM module first selects defaultSession for all accounts.
  # Override Dan afterwards using the same AccountsService API.
  danSession = ''
    user_path=$(${pkgs.systemd}/bin/busctl --system --json=short call \
      org.freedesktop.Accounts /org/freedesktop/Accounts \
      org.freedesktop.Accounts FindUserByName s dan | ${pkgs.jq}/bin/jq -er '.data[0]')
    ${pkgs.systemd}/bin/busctl --system call org.freedesktop.Accounts "$user_path" \
      org.freedesktop.Accounts.User SetXSession s omarchy
    ${pkgs.systemd}/bin/busctl --system call org.freedesktop.Accounts "$user_path" \
      org.freedesktop.Accounts.User SetSession s omarchy
    ${pkgs.systemd}/bin/busctl --system call org.freedesktop.Accounts "$user_path" \
      org.freedesktop.Accounts.User SetSessionType s wayland
  '';
in
{
  imports = [ ../primrosevalleyfarm ];

  options.local.family.wifi = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = builtins.pathExists wifi.sopsFile;
      description = "Provision family Wi-Fi once its encrypted credentials have been enrolled.";
    };
    sopsFile = lib.mkOption {
      type = lib.types.path;
      default = ../../secrets/family-wifi.yaml;
      description = "SOPS YAML containing an environment key with the configured networks' SSID/PSK variables.";
    };
    networks = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          ssidVariable = lib.mkOption {
            type = lib.types.strMatching "[A-Za-z_][A-Za-z0-9_]*";
            description = "Environment variable containing the SSID, supplied by the encrypted environment block.";
          };
          pskVariable = lib.mkOption {
            type = lib.types.strMatching "[A-Za-z_][A-Za-z0-9_]*";
            description = "Environment variable containing the WPA PSK, supplied by the encrypted environment block.";
          };
          priority = lib.mkOption {
            type = lib.types.ints.between (-999) 999;
            default = 0;
            description = "Autoconnect priority; prefer networks with higher values.";
          };
          hidden = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether the network hides its SSID.";
          };
        };
      });
      default = import ./wifi-networks.nix;
      description = "Named Wi-Fi profiles shared by family hosts. Names may contain letters, digits, underscores and hyphens.";
    };
  };

  config = lib.mkMerge [
    {
      assertions = [ {
        assertion = config.networking.hostName != "";
        message = "Family hosts must declare networking.hostName to match their hosts/<name> directory.";
      } ];
      # Installer host.nix also uses mkDefault (UTC). Win over that default
      # while still yielding to an ordinary per-host assignment.
      time.timeZone = lib.mkOverride 900 "Australia/Sydney";
      console.keyMap = lib.mkDefault "us";
      networking.networkmanager.enable = true;
      networking.networkmanager.settings.main.hostname-mode = "none";
      systemd.services.nixarchy-set-hostname.enable = false;

      programs.nixarchy.displayManager = false;
      services.displayManager = {
        sddm.enable = false;
        autoLogin.enable = false;
        defaultSession = lib.mkDefault "xfce";
        generic.preStart = lib.mkIf (config.users.users ? dan)
          (lib.mkAfter danSession);
      };
      services.xserver = {
        enable = true;
        desktopManager.xfce.enable = true;
        displayManager.lightdm = {
          enable = true;
          greeters.gtk.enable = true;
          extraSeatDefaults = ''
            greeter-hide-users=false
            greeter-show-manual-login=true
          '';
        };
      };

      environment.systemPackages = with pkgs; [ firefox bitwarden-desktop ];

      programs.nixarchy.fleet = {
        enable = true;
        url = lib.mkDefault "github:DanPalmz/nixos-fleet#${config.networking.hostName}";
        dates = lib.mkDefault "daily";
      };
      system.autoUpgrade.allowReboot = false;
      home-manager.backupFileExtension = lib.mkDefault ".hm-backup";
    }
    (lib.mkIf wifi.enable {
      assertions = [
        {
          assertion = wifi.networks != { };
          message = "Family Wi-Fi is enabled but local.family.wifi.networks is empty.";
        }
        {
          assertion = builtins.all (name: builtins.match "[A-Za-z0-9_-]+" name != null)
            (lib.attrNames wifi.networks);
          message = "Family Wi-Fi network names may contain only letters, digits, underscores and hyphens.";
        }
      ];
      sops.useSystemdActivation = true;
      # Existing SSH host identity; no sshd listener is needed for decryption.
      sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      sops.secrets.family-wifi-environment = {
        sopsFile = wifi.sopsFile;
        key = "environment";
        mode = "0400";
        restartUnits = [ "NetworkManager-ensure-profiles.service" ];
      };
      networking.networkmanager.ensureProfiles = {
        environmentFiles = [ config.sops.secrets.family-wifi-environment.path ];
        profiles = lib.mapAttrs' (name: network: lib.nameValuePair (profileName name) {
          connection = {
            id = connectionId name;
            type = "wifi";
            autoconnect = true;
            autoconnect-priority = network.priority;
            permissions = "";
          };
          wifi = {
            mode = "infrastructure";
            ssid = "$" + network.ssidVariable;
            hidden = network.hidden;
          };
          wifi-security = {
            key-mgmt = "wpa-psk";
            psk = "$" + network.pskVariable;
          };
          ipv4.method = "auto";
          ipv6.method = "auto";
        }) wifi.networks;
      };
      systemd.services.NetworkManager-ensure-profiles = {
        after = [ "sops-install-secrets.service" ];
        requires = [ "sops-install-secrets.service" ];
        # SOPS uses try-restart for changed secrets; an inactive oneshot would
        # otherwise be skipped and retain its old generated credentials.
        serviceConfig.RemainAfterExit = true;
        # Reloading newly generated keyfiles alone may not autoconnect at boot.
        # Being away from the family network must not fail the provisioning unit.
        postStart = ''
          for profile in ${lib.escapeShellArgs (map connectionId preferredNetworks)}; do
            if ${config.networking.networkmanager.package}/bin/nmcli --wait 15 \
              connection up id "$profile"; then
              break
            fi
          done
        '';
      };
    })
  ];
}
