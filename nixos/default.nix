{ lib, pkgs, ... }:
let
  repo = "andreabedini/ouroboros-consensus-tools";
  slug = lib.strings.replaceStrings [ "/" ] [ "-" ] repo;
in {
  services.getty.autologinUser = "root";

  services.github-runners.${slug} = {
    enable = true;
    replace = true;

    url = "https://github.com/${repo}";
    tokenFile = "/run/credentials/github-runner-${slug}.service/token";
    serviceOverrides.LoadCredential = [ "token" ];

    extraEnvironment.ACTIONS_RUNNER_HOOK_JOB_STARTED =
      pkgs.writeShellScript "job-started-hook.sh" ''
        set -e
        TIMEOUT_SECS=60*60
        LOCKFILE=/tmp/workbench.lock

        echo "ourboros-consensus-tools"
        echo "Data directory: $STATE_DIRECTORY"
        echo "Lockfile: $LOCKFILE"

        echo "Waiting for lock."
        exec 4<>$RUNTIME_DIRECTORY
        flock --verbose --wait "$TIMEOUT_SECS" 4
        echo "Lock acquired."
      '';

    # extraEnvironment.ACTIONS_RUNNER_HOOK_JOB_COMPLETED =
    #   pkgs.writeShellScript "job-started-hook.sh" ''
    #     echo "XXXXX Job completed"
    #   '';
  };
}
