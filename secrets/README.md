# Family Wi-Fi enrollment

The shared file is `secrets/family-wifi.yaml`. It is intentionally absent until
you encrypt real credentials. Family hosts retain their existing NetworkManager
connections while it is absent. Adding the encrypted file enables provisioning
on **every** family host: enroll all their recipients before pushing it.

Each machine uses its own `/etc/ssh/ssh_host_ed25519_key` to decrypt. The SSH
server does not need to be running. If the machine does not already have a host
key, generate one locally with `sudo ssh-keygen -A`. Keep the private key on that
machine and in a secure backup, never in this repo.

On each target, obtain its public age recipient:

```sh
nix shell nixpkgs#ssh-to-age -c sh -c \
  'ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub'
```

The repository's `.sops.yaml` includes creation rules for shared family Wi-Fi
and em-lappy's host-local secrets. Replace its **two placeholder recipients**
with your real admin and em-lappy public age recipients before using SOPS.
Add more host recipients to the shared Wi-Fi rule as machines join; host-local
rules should include only that host and its administrators.

Use your existing SOPS admin identity. If it is a PGP identity, use a `pgp:`
entry alongside the `age:` list instead of the illustrated admin age recipient.
Keep an admin recipient so you can edit/recover the secret independently of a
laptop. The `nixarchy secret` wrapper is convenient for per-host secrets; this
shared file uses ordinary SOPS to manage multiple host recipients.

Open an encrypted file directly with SOPS; do not first save plaintext in Git:

```sh
nix shell nixpkgs#sops -c sops secrets/family-wifi.yaml
```

## Multiple networks

Edit `modules/family/wifi-networks.nix` to define the networks shared by all
family hosts. It includes the original family network and a commented second
network example. Names contain only letters, digits, underscores and hyphens.
For example:

```nix
{
  family = {
    ssidVariable = "WIFI_SSID";
    pskVariable = "WIFI_PSK";
    priority = 20;
  };
  farm = {
    ssidVariable = "FARM_WIFI_SSID";
    pskVariable = "FARM_WIFI_PSK";
    priority = 10;
    hidden = false;
  };
}
```

In the SOPS editor, use this structure with the real network details:

```yaml
environment: |
  WIFI_SSID='Your network name'
  WIFI_PSK='Your Wi-Fi password'
  FARM_WIFI_SSID='Your farm network name'
  FARM_WIFI_PSK='Your farm Wi-Fi password'
```

Each declared profile needs its two matching variables. The defaults retain
`WIFI_SSID` and `WIFI_PSK` for compatibility. SSIDs and passwords remain encrypted;
only profile nicknames and environment variable names are in Nix. Higher
`priority` wins when multiple networks are available; equal priorities are tried
by profile-name order during provisioning. A successful connection stops the
fallback attempts. Away from all configured networks, provisioning still succeeds
and existing ad-hoc connections remain available.

For a host-specific network list, set `local.family.wifi.networks` in that
host's configuration. This replaces the shared default list. List all desired
networks there, or merge `(import ../../modules/family/wifi-networks.nix)` with
host-specific entries. Profiles removed from the declaration are fully cleared
on reboot; NetworkManager may retain previously loaded profiles until then.

The block is a systemd EnvironmentFile, not shell code. Single quotes preserve
spaces, dollar signs, backticks, double quotes and backslashes literally. If a
value contains a single quote, use double quotes around it instead and escape
double quotes and backslashes with a backslash. Do not use shell substitutions.
These rules describe the environment-file layer. NetworkManager then parses a
keyfile: for an actual backslash in an SSID/password, put two backslashes in the
single-quoted environment value (for example `WIFI_PSK='path\\word'`). Represent
leading/trailing spaces with keyfile `\s` escapes. Use one variable per line.
This profile supports WPA/WPA2 personal networks;
WPA3-only or enterprise networks require adjusting the profile security settings.

Stage and commit `.sops.yaml` and the **encrypted** YAML. When adding another
host's public recipient to the creation rule, rewrap the existing file:

```sh
nix shell nixpkgs#sops -c sops updatekeys secrets/family-wifi.yaml
```

Push and deploy as usual. sops-nix decrypts on each target, writes a root-only
environment file, and restarts profile provisioning when credentials change.
Build machines need only ciphertext. Removing a recipient does not revoke an
already learned Wi-Fi password: change that password if a machine is compromised.

On the first deployment keep its existing Wi-Fi profile or Ethernet connected
until the new profile works. Do not disable the only working remote connection
before enrollment. Hardware/private key recovery must precede secret-dependent
activation after a reinstall.
