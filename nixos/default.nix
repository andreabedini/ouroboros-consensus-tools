{ lib, pkgs, modulesPath, ... }: {

  # General NixOS configuration

  imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];
  services.getty.autologinUser = "root";

  nix.settings = {
    accept-flake-config = true;
    allow-import-from-derivation = true;
    extra-experimental-features = [ "nix-command flakes" ];
    extra-substituters = "https://cache.iog.io";
    extra-trusted-public-keys =
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=";
  };

  # This is only needed for testing the runner and the workflow

  virtualisation = {
    diskSize = 64 * 1024;
    memorySize = 4096;
    mountHostNixStore = true;
    writableStore = true;
    writableStoreUseTmpfs = false;
  };

  # This is the GitHub runner configuration

  services.github-runners = let
    # NOTE: This needs to be changed
    repo = "andreabedini/ouroboros-consensus-tools";
    slug = lib.strings.replaceStrings [ "/" ] [ "-" ] repo;
  in {
    ${slug} = {
      enable = true;
      replace = true;

      url = "https://github.com/${repo}";
      tokenFile = "/run/credentials/github-runner-${slug}.service/token";
      serviceOverrides.LoadCredential = [ "token" ];

      extraPackages = [
        # used by beacon itself
        pkgs.curl
        # flock is provided by util-linux
        pkgs.util-linux
      ];

      # NOTE: This might need to be changed
      extraEnvironment.BEACON_DATA = "/mnt/beacon-data";
    };
  };
}
