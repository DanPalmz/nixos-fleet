{ config, lib, pkgs, ... }:
let
  cfg = config.local.e2b-embed;
  state = "/var/lib/e2b-embed";
  lanAddress = if cfg.lan.address == null then "127.0.0.1" else cfg.lan.address;
  dashboardHost = if cfg.lan.enable then lanAddress else "localhost";
  configureDashboard = pkgs.writeShellScript "e2b-dashboard-address" ''
    exec ${pkgs.openssh}/bin/ssh -T \
      -i ${state}/id_ed25519 -p ${toString cfg.sshPort} \
      -o BatchMode=yes -o IdentitiesOnly=yes -o ConnectTimeout=10 \
      -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${state}/known_hosts \
      ubuntu@127.0.0.1 sudo bash -s <<'GUEST'
    set -euo pipefail
    # Wait for initial provisioning to finish before reconciling the dashboard.
    systemctl is-active --quiet e2b-embed.service
    cd /opt/e2b
    if ! grep -qx 'E2B_DASHBOARD_HOST=${dashboardHost}' .env; then
      sed -i '/^E2B_DASHBOARD_HOST=/d' .env
      printf '%s\n' 'E2B_DASHBOARD_HOST=${dashboardHost}' >> .env
    fi
    docker compose up -d --no-deps --wait --wait-timeout 120 dashboard
    GUEST
  '';
  image = pkgs.fetchurl {
    url = cfg.imageUrl;
    sha256 = cfg.imageSha256;
  };
  bootstrap = lib.replaceStrings [ "@runtimeRevision@" ] [ cfg.runtimeRevision ]
    (builtins.readFile ./bootstrap.sh);
  cloudConfig = pkgs.writeText "e2b-cloud-config.json" (builtins.toJSON {
    hostname = "e2b-embed";
    manage_etc_hosts = true;
    ssh_pwauth = false;
    disable_root = true;
    users = [ "default" ];
    write_files = [
      {
        path = "/usr/local/sbin/e2b-bootstrap";
        permissions = "0700";
        content = bootstrap;
      }
      {
        path = "/etc/systemd/system/e2b-embed.service";
        content = ''
          [Unit]
          Description=E2B Embed Compose stack
          Wants=network-online.target
          After=network-online.target
          StartLimitIntervalSec=0

          [Service]
          Type=oneshot
          RemainAfterExit=yes
          WorkingDirectory=/
          ExecStart=/usr/local/sbin/e2b-bootstrap
          ExecStop=/usr/bin/docker compose --project-directory /opt/e2b down --timeout 60
          TimeoutStartSec=45min
          TimeoutStopSec=120
          Restart=on-failure
          RestartSec=60

          [Install]
          WantedBy=multi-user.target
        '';
      }
    ];
    runcmd = [
      [ "systemctl" "daemon-reload" ]
      [ "systemctl" "enable" "--now" "--no-block" "e2b-embed.service" ]
    ];
  });
  ssh = pkgs.writeShellApplication {
    name = "e2b-embed-ssh";
    text = ''
      exec ${config.security.wrapperDir}/sudo -u e2b-embed ${pkgs.openssh}/bin/ssh \
        -i ${state}/id_ed25519 \
        -o IdentitiesOnly=yes \
        -o StrictHostKeyChecking=accept-new \
        -o UserKnownHostsFile=${state}/known_hosts \
        -p ${toString cfg.sshPort} ubuntu@127.0.0.1 "$@"
    '';
  };
  stop = pkgs.writeShellScript "e2b-vm-stop" ''
    # ACPI power button lets Ubuntu stop Compose before the disk is closed.
    printf '%s\n' '{"execute":"qmp_capabilities"}' '{"execute":"system_powerdown"}' \
      | ${pkgs.socat}/bin/socat - UNIX-CONNECT:/run/e2b-embed/qmp.sock || true
    for _ in $(${pkgs.coreutils}/bin/seq 1 150); do
      kill -0 "$1" 2>/dev/null || exit 0
      ${pkgs.coreutils}/bin/sleep 1
    done
  '';
in
{
  options.local.e2b-embed = {
    enable = lib.mkEnableOption "E2B Embed in a dedicated Ubuntu KVM guest";
    memoryMiB = lib.mkOption {
      type = lib.types.ints.between 12288 1048576;
      default = 12288;
      description = "Guest memory; includes E2B's default 4 GiB hugepage pool.";
    };
    vcpus = lib.mkOption { type = lib.types.ints.positive; default = 6; };
    diskGiB = lib.mkOption {
      type = lib.types.ints.between 40 4096;
      default = 80;
      description = "Initial sparse disk capacity. Changing this does not resize an existing disk.";
    };
    sshPort = lib.mkOption { type = lib.types.port; default = 2222; };
    lan = {
      enable = lib.mkEnableOption "LAN access to E2B API, dashboard and sandbox proxy";
      address = lib.mkOption {
        type = lib.types.nullOr (lib.types.strMatching "([0-9]{1,3}\\.){3}[0-9]{1,3}");
        default = null;
        description = "Host LAN IPv4 address on which to bind ports 3000–3002.";
      };
      subnet = lib.mkOption {
        type = lib.types.nullOr (lib.types.strMatching "([0-9]{1,3}\\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])");
        default = null;
        description = "IPv4 CIDR allowed through the firewall to E2B LAN ports.";
      };
    };
    runtimeRevision = lib.mkOption {
      type = lib.types.strMatching "[a-f0-9]{7,40}";
      default = "78d5ff9";
      description = "Immutable runtime commit used on first installation; see README for upgrades.";
    };
    imageUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img";
      description = "Ubuntu 24.04 cloud image URL; SHA256 pins its content even if the URL changes.";
    };
    imageSha256 = lib.mkOption {
      type = lib.types.str;
      default = "04e8f2461a16a44e78a370284471f29616cdd9baf1893df25807b71f985b6c94";
      description = "Ubuntu published SHA256 for the 20261017 amd64 cloud image.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.lan.enable || (cfg.lan.address != null && cfg.lan.subnet != null);
        message = "E2B LAN access requires local.e2b-embed.lan.address and lan.subnet.";
      }
      {
        assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
        message = "local.e2b-embed currently supports x86_64-linux hosts.";
      }
      {
        assertion = !(builtins.elem cfg.sshPort [ 3000 3001 3002 5008 ]);
        message = "e2b-embed SSH port must differ from its application ports.";
      }
    ];

    # Nested KVM is needed because Firecracker runs inside the Ubuntu VM.
    boot.kernelModules = [ "kvm-intel" "kvm-amd" ];
    boot.extraModprobeConfig = ''
      options kvm_intel nested=1
      options kvm_amd nested=1
    '';
    users.groups.e2b-embed = { };
    users.users.e2b-embed = {
      isSystemUser = true;
      group = "e2b-embed";
      extraGroups = [ "kvm" ];
    };
    environment.systemPackages = [ ssh ];

    networking.firewall = lib.mkIf cfg.lan.enable (
      if config.networking.nftables.enable then {
        extraInputRules = ''
          ip saddr ${toString cfg.lan.subnet} ip daddr ${lanAddress} tcp dport { 3000, 3001, 3002 } accept
        '';
      } else {
        extraCommands = ''
          iptables -w -A nixos-fw -s ${lib.escapeShellArg (toString cfg.lan.subnet)} -d ${lanAddress} -p tcp -m multiport --dports 3000,3001,3002 -j nixos-fw-accept
        '';
      }
    );

    systemd.services.e2b-embed = {
      description = "E2B Embed Ubuntu VM";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      unitConfig.ConditionPathExists = "/dev/kvm";
      path = [ pkgs.coreutils pkgs.qemu pkgs.openssh pkgs.cloud-utils pkgs.python3 ];
      preStart = ''
        cd ${state}
        if [ ! -e disk.qcow2 ]; then
          cp --reflink=auto ${image} disk.qcow2.tmp
          chmod 0600 disk.qcow2.tmp
          qemu-img resize disk.qcow2.tmp ${toString cfg.diskGiB}G
          mv disk.qcow2.tmp disk.qcow2
        fi
        if [ ! -e id_ed25519 ]; then
          ssh-keygen -q -t ed25519 -N "" -f id_ed25519
        fi
        python3 - ${cloudConfig} <<'PY'
        import json, pathlib, sys
        data = json.loads(pathlib.Path(sys.argv[1]).read_text())
        data["ssh_authorized_keys"] = [pathlib.Path("id_ed25519.pub").read_text().strip()]
        pathlib.Path("user-data").write_text("#cloud-config\n" + json.dumps(data))
        PY
        printf '%s\n' 'instance-id: e2b-embed-v1' 'local-hostname: e2b-embed' > meta-data
        cloud-localds seed.img user-data meta-data
      '';
      serviceConfig = {
        User = "e2b-embed";
        Group = "e2b-embed";
        SupplementaryGroups = [ "kvm" ];
        StateDirectory = "e2b-embed";
        StateDirectoryMode = "0700";
        RuntimeDirectory = "e2b-embed";
        WorkingDirectory = state;
        UMask = "0077";
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.qemu}/bin/qemu-system-x86_64"
          "-name e2b-embed -machine q35,accel=kvm -cpu host"
          "-m ${toString cfg.memoryMiB} -smp ${toString cfg.vcpus}"
          "-display none -serial stdio -monitor none"
          "-qmp unix:/run/e2b-embed/qmp.sock,server=on,wait=off"
          "-drive file=${state}/disk.qcow2,if=virtio,format=qcow2"
          "-drive file=${state}/seed.img,if=virtio,format=raw,readonly=on"
          "-netdev user,id=net0,hostfwd=tcp:127.0.0.1:${toString cfg.sshPort}-:22"
          "-device virtio-net-pci,netdev=net0"
        ];
        ExecStop = "${stop} $MAINPID";
        Restart = "on-failure";
        RestartSec = 10;
        TimeoutStopSec = 180;
        KillMode = "mixed";
      };
    };

    # Upstream binds several endpoints to guest loopback. Forward over SSH,
    # since QEMU hostfwd targets the guest NIC rather than guest loopback.
    systemd.services.e2b-embed-proxy = {
      description = "Local E2B Embed endpoints";
      wantedBy = [ "multi-user.target" ];
      requires = [ "e2b-embed.service" ];
      after = [ "e2b-embed.service" ];
      partOf = [ "e2b-embed.service" ];
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig = {
        User = "e2b-embed";
        Group = "e2b-embed";
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.openssh}/bin/ssh -N -T"
          "-i ${state}/id_ed25519 -p ${toString cfg.sshPort}"
          "-o BatchMode=yes -o IdentitiesOnly=yes -o ExitOnForwardFailure=yes"
          "-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${state}/known_hosts"
          "-o ServerAliveInterval=15 -o ServerAliveCountMax=3"
          "-L 127.0.0.1:3000:127.0.0.1:3000"
          "-L 127.0.0.1:3001:127.0.0.1:3001"
          "-L 127.0.0.1:3002:127.0.0.1:3002"
          (lib.optionalString cfg.lan.enable "-L ${lanAddress}:3000:127.0.0.1:3000 -L ${lanAddress}:3001:127.0.0.1:3001 -L ${lanAddress}:3002:127.0.0.1:3002")
          "-L 127.0.0.1:5008:127.0.0.1:5008"
          "ubuntu@127.0.0.1"
        ];
        Restart = "always";
        RestartSec = 10;
        UMask = "0077";
      };
    };

    # Cloud-init runs only once. Reconcile browser routing over SSH so this
    # setting also applies to an already provisioned guest without restarting it.
    systemd.services.e2b-embed-settings = {
      description = "Configure E2B dashboard sandbox address";
      wantedBy = [ "multi-user.target" ];
      requires = [ "e2b-embed.service" ];
      after = [ "e2b-embed.service" ];
      partOf = [ "e2b-embed.service" ];
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "e2b-embed";
        Group = "e2b-embed";
        ExecStart = configureDashboard;
        Restart = "on-failure";
        RestartSec = 15;
        TimeoutStartSec = 180;
      };
    };
  };
}
