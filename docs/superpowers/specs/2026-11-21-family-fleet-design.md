# Family fleet

Approved in conversation: add em-lappy, reusable family and primrosevalleyfarm
profiles, LightDM GTK, XFCE, Dan's Nixarchy session, shared SOPS Wi-Fi with
individual machine recipients, and unattended remote updates.

Use ordinary opt-in NixOS modules rather than applying family policy globally.
The farm profile owns four accounts; family owns desktop, apps, networking and
updates. Only Carly and Paul get wheel on em-lappy. No passwords are declared.
Dan's portable account is included without Redtail's permissions or credentials.

Each host keeps its own hardware configuration. The user uploaded em-lappy's
hardware and disk modules and confirmed whole-disk /dev/sda without encryption.

Use a fixed hostname and explicit remote flake fragment. Disable the installer's
runtime hostname restoration so stale install metadata cannot override it.
Updates apply remote configuration daily without automatic reboot.

Shared encrypted Wi-Fi is enrolled using each machine's public age recipient and
an administrator recovery recipient. Private keys remain off-repository. Until
the encrypted file exists, retain the machine's existing NetworkManager profiles.

Alternatives considered: stock SDDM versus LightDM (LightDM selected); per-host
Wi-Fi copies or imperative profiles versus one SOPS file (shared SOPS selected).
Recipient enrollment remains an operator step because recipient keys and Wi-Fi
credentials are unavailable. GitHub reports the repository is public, so pulls
need no separate Git authentication.
