# Portable accounts. Hosts decide who can administer that particular machine.
{ lib, ... }:
{
  users.groups.primrosevalleyfarm = { };
  users.users = lib.genAttrs [ "emily" "ned" "carly" "paul" ] (name: {
    isNormalUser = true;
    description = {
      emily = "Emily";
      ned = "Ned";
      carly = "Carly";
      paul = "Paul";
    }.${name};
    extraGroups = [ "primrosevalleyfarm" ];
    # No initial password: a new account stays locked until one is set locally.
  });
}
