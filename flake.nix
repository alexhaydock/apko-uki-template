{
  description = "Nix Flake for building Alpine bootable initramfs with apko";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    supportedSystems = [
      "x86_64-linux"
    ];

    forEachSupportedSystem = f:
      inputs.nixpkgs.lib.genAttrs supportedSystems (
        system:
          f {
            pkgs = import inputs.nixpkgs {inherit system;};
          }
      );
  in {
    devShells = forEachSupportedSystem (
      {pkgs}: let
        apkoPatched = pkgs.stdenvNoCC.mkDerivation {
          # Pull in the patched version of apko I maintain downstream
          # which has lockfile support added for build-cpio.
          #
          # This is lazy and only works for x86_64 because it's a
          # prebuilt binary, but I'm hoping I don't need to do it for
          # too long and that the apko project accepts my PR to add
          # cpio locking support:
          #   https://github.com/chainguard-dev/apko/pull/2101
          pname = "apko";
          version = "b87f3ba-with-lockfile-support";
          src = pkgs.fetchurl {
            url = "https://github.com/alexhaydock/apko/releases/download/b87f3ba-with-lockfile/apko";
            sha256 = "sha256-LIJdAPRm47QZPyxmbCMiP/VuUx3jzkyyKSPYwP4WHnw=";
          };
          dontUnpack = true;
          installPhase = ''
            mkdir -p $out/bin
            cp $src $out/bin/apko
            chmod +x $out/bin/apko
          '';
        };
      in {
        default = pkgs.mkShellNoCC {
          packages = with pkgs; [
            apkoPatched
            bubblewrap
            just
            melange
            OVMF # We want OVMFFull if we want the Secure-Boot-signed firmware & vars
            qemu_kvm # Installs QEMU only for native architecture for minmalism purposes
            systemdUkify
          ];

          env = {
            OVMF_VARS = "${pkgs.OVMF.variables}";
            OVMF_FIRMWARE = "${pkgs.OVMF.firmware}";
          };
        };
      }
    );

    formatter = nixpkgs.lib.genAttrs supportedSystems (
      system: nixpkgs.legacyPackages.${system}.alejandra
    );
  };
}
