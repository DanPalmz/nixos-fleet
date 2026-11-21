# Ready-to-import NixOS module for enrolling NixOS hosts (e.g. redtail, swordfish)
# into the centralised syd-sn3 Harmonia binary cache over ssh-ng.
#
# Usage:
#   1. Copy to /etc/nixos/nix-cache-syd-sn3.nix and add ./nix-cache-syd-sn3.nix
#      to `imports` in /etc/nixos/configuration.nix.
#   2. Install the `nix-builder` private SSH key from
#      `secrets/compute-workers/nix-builder.sops.env` (PRIVATE_KEY_B64) to
#      /etc/nix/builder_ed25519 (owner root:root, mode 0400).
#   3. Run `sudo nixos-rebuild switch`.
{ config, lib, pkgs, ... }:

let
  sydSn3BuilderKey = "/etc/nix/builder_ed25519";
  sydSn3RemoteStore = "ssh-ng://nix-builder@syd-sn3";
  nixBin = "${config.nix.package}/bin/nix";
  uploadHook = pkgs.writeShellScript "upload-to-syd-sn3-cache" ''
    set -euo pipefail

    # Invoked by nix-daemon with $OUT_PATHS after a local build completes.
    if [ -z "''${OUT_PATHS:-}" ] || [ ! -r "${sydSn3BuilderKey}" ]; then
      exit 0
    fi

    export PATH="${lib.makeBinPath [ pkgs.openssh pkgs.util-linux ]}:$PATH"

    (
      if ! err=$("${nixBin}" --extra-experimental-features 'nix-command' copy \
        --to "${sydSn3RemoteStore}?ssh-key=${sydSn3BuilderKey}" \
        $OUT_PATHS 2>&1); then
        logger -t nix-cache-upload "upload to ${sydSn3RemoteStore} failed: $err" || true
      fi
    ) </dev/null >/dev/null 2>&1 &
  '';
in
{
  networking.hosts."66.63.172.33" = [
    "syd-sn3"
    "syd-sn3.compute.internal"
  ];

  programs.ssh.knownHosts."syd-sn3" = {
    hostNames = [
      "syd-sn3"
      "syd-sn3.compute.internal"
      "syd-sn3.handsontech.au"
      "66.63.172.33"
    ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHtQfGKZ8ZuJw6y4P+UkNUctAiHTTR4yyHprBNmuaeug";
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "test-runner1" "starbird-agent" ];
    extra-substituters = [
      "http://10.196.20.100:5000?priority=20"
      "${sydSn3RemoteStore}?ssh-key=${sydSn3BuilderKey}&priority=30"
    ];
    extra-trusted-public-keys = [
      "int-starbird-cache-1:nsqrVYWODpzzrm/7l7sAY0IMHE8Phsj6wFPWg0unI9w="
      "syd-sn3-cache-1:/BICs58OuQqQoFPEoJ5CjOAiZpWHRMYX9QgO7VewY+U="
    ];
    fallback = true;
    connect-timeout = 5;
    stalled-download-timeout = 30;
    post-build-hook = "${uploadHook}";
  };
}
