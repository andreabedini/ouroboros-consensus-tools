{
  inputs = {
    nixpkgs.follows = "haskellNix/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    haskellNix = {
      url = "github:input-output-hk/haskell.nix";
      inputs.hackage.follows = "hackageNix";
    };
    hackageNix = {
      url = "github:input-output-hk/hackage.nix";
      flake = false;
    };
    CHaP = {
      url = "github:intersectmbo/cardano-haskell-packages?ref=repo";
      flake = false;
    };
    iohkNix = {
      url = "github:input-output-hk/iohk-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-2405.url = "github:NixOS/nixpkgs/nixos-24.05";
  };
  outputs = inputs:
    let
      supportedSystems = [
        "x86_64-linux"
        "x86_64-darwin"
        #"aarch64-linux" # no CI machines yet
        "aarch64-darwin"
      ];
      inherit (inputs.nixpkgs) lib;

    in inputs.flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = import inputs.nixpkgs {
          inherit system;
          inherit (inputs.haskellNix) config;
          overlays = [
            inputs.iohkNix.overlays.crypto
            inputs.haskellNix.overlay
            inputs.iohkNix.overlays.haskell-nix-crypto
          ];
        };
        inherit (pkgs) lib;

        defaultCompiler = "ghc966";

        cabalProject = pkgs.haskell-nix.cabalProject' {
          src = ./.;
          compiler-nix-name = defaultCompiler;
          inputMap = {
            "https://input-output-hk.github.io/cardano-haskell-packages" =
              inputs.CHaP;
          };
          modules = let
            # from https://github.com/input-output-hk/haskell.nix/issues/298#issuecomment-767936405
            forAllProjectPackages = cfg:
              args@{ lib, ... }: {
                options.packages = lib.mkOption {
                  type = lib.types.attrsOf (lib.types.submodule
                    ({ config, ... }: {
                      config = lib.mkIf config.package.isProject (cfg args);
                    }));
                };
              };
          in [ (forAllProjectPackages (_: { ghcOptions = [ "-Werror" ]; })) ];
          shell = {
            tools = {
              cabal = "latest";
              haskell-language-server = {
                src = inputs.haskellNix.inputs."hls-2.9";
                configureArgs = "--disable-benchmarks --disable-tests";
              };
            };
            nativeBuildInputs = [
              pkgs.fd
              pkgs.ghcid
              pkgs.haskellPackages.cabal-fmt
              pkgs.nixpkgs-fmt
              pkgs.stylish-haskell
            ];
            withHoogle = true;
          };
        };
        flake = lib.recursiveUpdate cabalProject.flake' {
          # add formatting checks to Hydra CI, but only for one system
          hydraJobs.formatting = lib.optionalAttrs (system == "x86_64-linux")
            (import ./nix/formatting.nix pkgs);
        };
      in lib.recursiveUpdate flake {
        project = cabalProject;
        packages.default = flake.packages."beacon:exe:beacon";
        hydraJobs.required = pkgs.releaseTools.aggregate {
          name = "required-consensus-tools";
          constituents = lib.collect lib.isDerivation flake.hydraJobs;
        };
      }) // {
        nixosConfigurations.default = inputs.nixos-2405.lib.nixosSystem {
          pkgs = inputs.nixos-2405.legacyPackages.x86_64-linux;
          system = "x86_64-linux";
          modules = [ ./nixos ];
        };
      };
  nixConfig = {
    extra-substituters = [ "https://cache.iog.io" ];
    extra-trusted-public-keys =
      [ "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=" ];
    allow-import-from-derivation = true;
  };
}
