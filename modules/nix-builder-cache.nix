# Ready-to-import NixOS module for enrolling internal NixOS hosts (redtail,
# swordfish) into:
#   1. The internal (int-starbird :5000) and centralised (syd-sn3 ssh-ng)
#      Harmonia binary caches, with asynchronous post-build uploads to syd-sn3.
#   2. Distributed Nix builds across the internal peers (redtail, swordfish,
#      int-starbird at higher priority speedFactor = 4) and syd-sn3 (lower
#      priority overflow at speedFactor = 2).
#   3. Accepting incoming distributed Nix builds from the other internal hosts
#      via the restricted `nix-builder` system account.
#
# Note for int-starbird (10.196.20.100):
#   int-starbird runs Fedora uCore (not NixOS) and is managed via
#   `playbooks/int-starbird-guest.yml`, which configures the matching
#   `nix-builder` user, `/etc/nix/builder_ed25519`, `/etc/hosts`,
#   `/etc/ssh/ssh_known_hosts`, and `/etc/nix/machines` entries (`redtail` and
#   `swordfish` at speedFactor 4, `syd-sn3` at speedFactor 2).
#
# Usage on NixOS (redtail & swordfish):
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
  nixBuilderPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFExp/ntJTeEuA/sjN1TySRVLbi2sGr1iANa1AhRTpRG nix-builder@syd-sn2";
  nixBin = "${config.nix.package}/bin/nix";
  nixDaemonBin = "${config.nix.package}/bin/nix-daemon";
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

  allBuildMachines = [
    {
      hostName = "redtail";
      protocol = "ssh-ng";
      sshUser = "nix-builder";
      sshKey = sydSn3BuilderKey;
      system = "x86_64-linux";
      maxJobs = 8;
      speedFactor = 4;
      supportedFeatures = [ "big-parallel" "nixos-test" "benchmark" "kvm" ];
    }
    {
      hostName = "swordfish";
      protocol = "ssh-ng";
      sshUser = "nix-builder";
      sshKey = sydSn3BuilderKey;
      system = "x86_64-linux";
      maxJobs = 8;
      speedFactor = 4;
      supportedFeatures = [ "big-parallel" "nixos-test" "benchmark" "kvm" ];
    }
    {
      hostName = "int-starbird";
      protocol = "ssh-ng";
      sshUser = "nix-builder";
      sshKey = sydSn3BuilderKey;
      system = "x86_64-linux";
      maxJobs = 8;
      speedFactor = 4;
      supportedFeatures = [ "big-parallel" "benchmark" "kvm" ];
    }
    {
      hostName = "syd-sn3";
      protocol = "ssh-ng";
      sshUser = "nix-builder";
      sshKey = sydSn3BuilderKey;
      system = "x86_64-linux";
      maxJobs = 12;
      speedFactor = 2;
      supportedFeatures = [ "big-parallel" ];
    }
  ];
in
{
  users.groups.nix-builder = { };
  users.users.nix-builder = {
    isSystemUser = true;
    group = "nix-builder";
    useDefaultShell = true;
    description = "Dedicated remote Nix distributed build account";
    openssh.authorizedKeys.keys = [
      ''restrict,command="${nixDaemonBin} --stdio" ${nixBuilderPubKey}''
    ];
  };

  # Compute runner SSH concurrency and OpenSSH 9.8+/10.x PerSourcePenalties
  # exemption for parallel test-remote.mjs, sb-cargo-remote, and nix-daemon
  # handshakes from syd-sn2, syd-sn3, and internal compute peers.
  services.openssh.settings = {
    MaxStartups = "64:30:128";
    MaxSessions = 64;
    PerSourcePenaltyExemptList = "100.64.0.0/10,10.196.0.0/16,10.11.196.0/24,127.0.0.0/8";
  };

  # Authorize fleet compute/agent worker keys on test-runner1 so remote test lanes
  # (scripts/test-remote.mjs, sb-cargo-remote, rch) can connect from syd-sn2 and syd-sn3.
  users.users.test-runner1.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMX2PrYuSi+LzKEWNEmTGlHhwYTvwDbxA4BXbmScDeU4 burrai-agent@syd-sn2"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIMEQnkrR7Poo3k5Dg2ftd1FBePI85R1uVBchcXqy2xQ starbird-agent@syd-sn2"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFMKI+KiVueqPJGlx9GBMXf7++/Bo/iUA2yBq/1ZtLTN test-runner1@syd-sn2"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINzhrfC/3I8oKbDSnbVy8D3JvfwiHC2EUrWKzdfl4JjR rch-build@syd-sn2"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM1sTiQBr5ClOaQ0EgEt46oeiBlP6QoGNNhEvdV/BRoR sb-svc@syd-sn2"
  ];

  networking.hosts = {
    "10.11.196.5" = [
      "redtail"
      "redtail.compute.internal"
    ];
    "10.11.196.240" = [
      "swordfish"
      "swordfish.compute.internal"
    ];
    "10.196.20.100" = [
      "int-starbird"
      "int-starbird.compute.internal"
    ];
    "66.63.172.33" = [
      "syd-sn3"
      "syd-sn3.compute.internal"
    ];
  };

  programs.ssh.knownHosts = {
    "redtail" = {
      hostNames = [
        "redtail"
        "redtail.compute.internal"
        "10.11.196.5"
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIlvmThl8Z4NuZEBc1PUxCohuznf87Ix7oHC1mXH9tft";
    };
    "swordfish" = {
      hostNames = [
        "swordfish"
        "swordfish.compute.internal"
        "10.11.196.240"
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGy5xMM+g6bllsEQUrmZszO5suDMEHCVBufVT88mAOZM";
    };
    "int-starbird" = {
      hostNames = [
        "int-starbird"
        "int-starbird.compute.internal"
        "10.196.20.100"
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFqtlwibMp9BJowNPnYaj5aCtwtEl7U1wiRhg5ivlNjE";
    };
    "syd-sn3" = {
      hostNames = [
        "syd-sn3"
        "syd-sn3.compute.internal"
        "syd-sn3.handsontech.au"
        "66.63.172.33"
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHtQfGKZ8ZuJw6y4P+UkNUctAiHTTR4yyHprBNmuaeug";
    };
  };

  nix.distributedBuilds = true;
  # Exclude the local host automatically so the same module works on both redtail and swordfish.
  nix.buildMachines = lib.filter (m: m.hostName != config.networking.hostName) allBuildMachines;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "nix-builder" "test-runner1" "starbird-agent" ];
    builders-use-substitutes = true;
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
