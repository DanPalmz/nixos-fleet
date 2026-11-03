# Your machine. Everything Omarchy needs is in nixarchy's host module; this
# file holds what the installer asked you, and whatever you add later.
#
# Edit, then run `nh os switch`.
{ pkgs, ... }:
let
  switchUser = pkgs.writeShellApplication {
    name = "nixarchy-switch-user";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.systemd
    ];
    text = ''
      omarchy-system-lock

      # A requested lock is not yet a secure Wayland session lock.
      # Never switch away until the compositor confirms it is secure.
      for _ in $(seq 1 100); do
        if omarchy-shell lock status | jq -e '.secure == true' >/dev/null; then
          exec busctl --system call \
            org.freedesktop.DisplayManager \
            /org/freedesktop/DisplayManager/Seat0 \
            org.freedesktop.DisplayManager.Seat SwitchToGreeter
        fi
        sleep 0.05
      done

      echo "Could not confirm a secure session lock; user switch cancelled." >&2
      exit 1
    '';
  };
in
{
  imports = [
    ./hardware-configuration.nix
    ./users.nix
    ../../modules/sddm-omarchy-users
    # nixarchy-apply copies your app selection here. Without this line the
    # menu marks apps enabled and nothing is ever installed.
    ./nixarchy-apps.nix
  ];

  networking.networkmanager.settings = {
    main = {
      hostname-mode = "none";
    };
  };

  time.timeZone = "Australia/Sydney";
  console.keyMap = "us";

  # Most of what the Install menu offers is unfree. nixarchy defaults this on
  # already; it is repeated here because it is your file, and a licence policy
  # you cannot see is one you cannot change. Set it false for nixpkgs' own.
  nixpkgs.config.allowUnfree = true;

  # SDDM is provided by Nixarchy; require an explicit user login.
  services.displayManager.autoLogin.enable = false;

  programs.nixarchy.menu.extraEntries."system.switch-user" = {
    icon = "󰍂";
    label = "Switch user";
    action = "${switchUser}/bin/nixarchy-switch-user";
  };


  home-manager.backupFileExtension = ".hm-backup";

  # A usable emergency shell, when the installer was given a recovery
  # passphrase. `{ }` when it was not, which leaves the NixOS default: the
  # initrd's /etc/shadow is `root:*` and sulogin refuses to open a console.
  #
  # The hash is NOT in this file. boot.initrd.systemd.emergencyAccess would
  # have put it here -- it takes a literal string, spliced into the initrd's
  # /etc/shadow -- and this directory is a git repository that
  # nixarchy-config-repo pushes to GitHub. boot.initrd.secrets instead names a
  # path on the live filesystem, appended to the initrd by systemd-boot at
  # bootloader-install time. systemd-boot sets supportsInitrdSecrets, so the
  # file is not copied into the store either.
  #
  # The initrd still ends up holding the hash, and the initrd is on the ESP,
  # unencrypted -- unavoidably, since it runs before anything is unlocked.
  # That is why the installer asks for a passphrase of its own and refuses one
  # that matches the login password: this credential is meant to be spendable.
  #
  # If the append ever fails, the generated `root:*` stands and the machine is
  # locked out of emergency mode rather than open to it.
  boot.initrd.secrets = {
    "/etc/shadow" = "/var/lib/nixarchy/initrd-shadow";
  };
}
