# Upstream uses nixpkgs.legacyPackages, whose allowUnfree policy is independent
# of NixOS. Evaluate its unchanged recipe with this host's configured packages.
# Version, vendorHash and build flags continue to come from the locked input.
{ inputs, pkgs }:
let
  system = pkgs.stdenv.hostPlatform.system;
  upstreamNixpkgs = inputs.pangolin-cli.inputs.nixpkgs;
  upstream = (import "${inputs.pangolin-cli}/flake.nix").outputs {
    nixpkgs = upstreamNixpkgs // {
      legacyPackages = upstreamNixpkgs.legacyPackages // {
        ${system} = pkgs;
      };
    };
  };
in
upstream.packages.${system}.default.overrideAttrs (previous: {
  # The unmodified recipe also installs its documentation generator and scripts.
  subPackages = [ "." ];
  postInstall = (previous.postInstall or "") + ''
    # Go names the root module binary "cli"; upstream's user-facing name is
    # "pangolin", while its Nix meta.mainProgram is "pangolin-cli".
    mv "$out/bin/cli" "$out/bin/pangolin"
    ln -s pangolin "$out/bin/pangolin-cli"
  '';
})
