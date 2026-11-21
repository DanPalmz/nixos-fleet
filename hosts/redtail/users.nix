# Accounts enabled on Redtail, with credentials and permissions local to it.
{ ... }:
{
  imports = [
    ../../users/nathan
    ../../users/agents
    ../../users/test-runners
  ];

  users.users.dan = {
    # Keep the password hash outside both git and the world-readable Nix store.
    hashedPasswordFile = "/var/lib/nixarchy/password.hash";
  };

  users.users.nathan.extraGroups = [
    "video"
    "input"
  ];

  security.sudo.enable = true;
  security.sudo.extraRules = [
    {
      groups = [ "agents" ];
      runAs = "root";
      commands = [
        { command = "ALL"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];
   
}
