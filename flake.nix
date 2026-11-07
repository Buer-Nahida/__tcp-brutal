{
  description = "TCP Brutal - TCP congestion control algorithm";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      version = self.shortRev or self.dirtyShortRev or "unknown";
      mkTcpBrutal = pkgs: kernel: pkgs.stdenv.mkDerivation {
        pname = "tcp-brutal";
        inherit version;
        src = ./.;
        nativeBuildInputs = kernel.moduleBuildDependencies;
        # Use Kbuild's module installation to sign modules and emit .ko.cer.
        makeFlags = kernel.commonMakeFlags ++ [
          "KBUILD_OUTPUT=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
          "DEPMOD=true"
          "INSTALL_MOD_STRIP=1"
          "INSTALL_MOD_PATH=${placeholder "out"}"
          "INSTALL_MOD_DIR=extra"
        ];
        buildFlags = [
          "-C"
          "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
          "M=$(PWD)"
          "modules"
        ];
        installFlags = [
          "-C"
          "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
          "M=$(PWD)"
        ];
        installTargets = [ "modules_install" ];
        meta = with pkgs.lib; {
          description = "TCP Brutal congestion control algorithm";
          homepage = "https://github.com/HyNetworks/tcp-brutal";
          license = licenses.gpl3Only;
          platforms = platforms.linux;
        };
      };
      # Rule management tool
      mkBrutalctl = pkgs: pkgs.stdenv.mkDerivation {
        pname = "brutalctl";
        inherit version;
        src = ./tools;
        installPhase = ''
          runHook preInstall
          install -Dm755 brutalctl $out/bin/brutalctl
          runHook postInstall
        '';
        meta = with pkgs.lib; {
          description = "Manage TCP Brutal destination rules";
          homepage = "https://github.com/HyNetworks/tcp-brutal";
          license = licenses.gpl3Only;
          platforms = platforms.linux;
          mainProgram = "brutalctl";
        };
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; }; in {
        packages.default = mkTcpBrutal pkgs pkgs.linuxPackages.kernel;
        packages.brutalctl = mkBrutalctl pkgs;
        lib.mkTcpBrutal = mkTcpBrutal pkgs;
      }
    ) // {
      nixosModules.default = { config, lib, pkgs, ... }: {
        options.boot.tcp-brutal.enable = lib.mkEnableOption "tcp-brutal kernel module";
        config = lib.mkIf config.boot.tcp-brutal.enable {
          boot.extraModulePackages = [ (self.outputs.lib.${pkgs.system}.mkTcpBrutal config.boot.kernelPackages.kernel) ];
          boot.kernelModules = [ "brutal" ];
          environment.systemPackages = [ self.packages.${pkgs.system}.brutalctl ];
        };
      };
    };
}
