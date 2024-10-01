{ lib, pkgs, modulesPath, ... }:
let
  repo = "andreabedini/ouroboros-consensus-tools";
  slug = lib.strings.replaceStrings [ "/" ] [ "-" ] repo;
in {
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

  virtualisation = {
    diskSize = 64 * 1024;
    memorySize = 4096;
    mountHostNixStore = true;
    writableStore = true;
    writableStoreUseTmpfs = false;
    sharedDirectories.beacon-data = {
      source = "/home/andrea/work/ouroboros-consensus-tools/beacon-data";
      target = "/mnt/beacon-data";
    };
  };

  services.github-runners.${slug} = {
    enable = true;
    replace = true;

    url = "https://github.com/${repo}";
    tokenFile = "/run/credentials/github-runner-${slug}.service/token";
    serviceOverrides.LoadCredential = [ "token" ];
    extraPackages = [ pkgs.curl pkgs.util-linux ];
  };
}
