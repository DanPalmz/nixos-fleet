# em-lappy

This host imports the opt-in `modules/family` profile. That profile imports
`modules/primrosevalleyfarm` for Emily, Ned, Carly and Paul. Another machine can
import the farm module alone for the accounts, or family for accounts, desktop,
Wi-Fi and daily updates. This is a configuration profile and a Unix group, not a
separate fleet management service.

Every family host must declare `networking.hostName` matching its host directory.
When importing Nixarchy's installer host module, use `lib.mkForce` as in this
host to override that module's empty hostname. Family disables the installer's
runtime hostname restoration and NetworkManager hostname changes.

All users can run Firefox and Bitwarden. Carly, Paul and Dan are the wheel
members on this host. New users have no passwords declared and remain locked
until an administrator sets them locally with `sudo passwd USER`. Dan has his
existing SSH public key, Home Manager configuration and wheel/video/input/i2c
groups through `modules/common`. His password remains host-local. Set Carly/Paul's passwords while an existing
administrator session is still available before the first switch.

LightDM GTK lists accounts and offers session selection. XFCE is the default;
Dan defaults to the Nixarchy/Hyprland (`omarchy`) session. No autologin is enabled.

## Storage and initial validation

The uploaded `hardware-configuration.nix` has CPU/kernel settings.
`nixarchy-hardware.nix` imports the Intel CPU, Intel graphics and laptop SSD
profiles detected on this machine. Its mounts
come from the uploaded `disk-config.nix`, imported by `storage.nix` with the
confirmed install-time settings: `mode = "whole"`, `device = "/dev/sda"`,
`encrypt = false`. Normal rebuilding does not format disks; running disko's
formatting commands would. Keep hardware and storage settings local to each host.

Once storage is configured and all new files are staged:

```sh
nixos-rebuild build --flake /etc/nixos#em-lappy
```

To activate on the laptop when ready:

```sh
sudo nixos-rebuild switch --flake /etc/nixos#em-lappy
```

The explicit fragment works even before the hostname fix is activated. The host
declares `em-lappy`, disables NetworkManager hostname changes, and disables the
installer's restoration from `/etc/nixarchy/hostname`. Subsequent hostname-based
Nixarchy commands use the stable name. Log out and back in after switching to
refresh Nixarchy's session environment.

## Shared Wi-Fi and updates

Follow [Wi-Fi enrollment](../../secrets/README.md). No credentials are committed
by this setup. Each family host must be a recipient before provisioning is enabled.
Shared network definitions live in `modules/family/wifi-networks.nix`; each
network references its own pair of encrypted SSID/PSK environment variables.

Updates pull `github:DanPalmz/nixos-fleet#em-lappy` daily with `--refresh`, a
45-minute random delay, catch-up after missed runs, and no automatic reboot.
Only committed and pushed changes reach the laptop. Unpushed local configuration
can be superseded by the remote system configuration at the next timer run;
the timer does not perform a Git pull into the local checkout.

Until em-lappy's configuration is committed and pushed, do not activate its
automatic updater: the remote repository will not yet have the host attribute.
Failure diagnostics:

```sh
cat /var/lib/nixarchy/upgrade-failed
systemctl status nixos-upgrade.service
journalctl -u nixos-upgrade.service -b
```
