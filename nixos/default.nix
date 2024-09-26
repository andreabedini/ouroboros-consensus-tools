{ lib, pkgs, ... }:
let
  repo = "andreabedini/ouroboros-consensus-tools";
  slug = lib.strings.replaceStrings [ "/" ] [ "-" ] repo;
in {
  services.getty.autologinUser = "root";

  nix.settings = {
    accept-flake-config = true;
    allow-import-from-derivation = true;
    extra-substituters = "https://cache.iog.io";
    extra-trusted-public-keys = "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=";
  };

  services.github-runners.${slug} = {
    enable = true;
    replace = true;

    url = "https://github.com/${repo}";
    tokenFile = "/run/credentials/github-runner-${slug}.service/token";
    serviceOverrides.LoadCredential = [ "token" ];

    # flock
    extraPackages = [ pkgs.util-linux ];

    extraEnvironment.ACTIONS_RUNNER_HOOK_JOB_STARTED =
      pkgs.writeShellScript "job-started-hook.sh" ''
        set -e
        TIMEOUT_SECS=$(( 60*60 ))
        LOCKFILE=/tmp/workbench.lock

        echo "ourboros-consensus-tools"
        echo "Data directory: $STATE_DIRECTORY"
        echo "Lockfile: $LOCKFILE"

        echo "Waiting for lock."
        exec 4<>$LOCKFILE
        flock --verbose --wait "$TIMEOUT_SECS" 4
        echo "Lock acquired."
      '';

    # extraEnvironment.ACTIONS_RUNNER_HOOK_JOB_COMPLETED =
    #   pkgs.writeShellScript "job-started-hook.sh" ''
    #     echo "XXXXX Job completed"
    #   '';
  };
}
