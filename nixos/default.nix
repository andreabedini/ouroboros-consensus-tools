{ pkgs, ... }:

let
  m = { config, ... }: {
    enable = true;
    replace = true;

    url = "https://github.com/andreabedini/${config.name}";

    tokenFile =
      "/run/credentials/github-runner-${config.name}.service/${config.name}-token";

    serviceOverrides.LoadCredential = [ "${config.name}-token" ];

    extraEnvironment.ACTIONS_RUNNER_HOOK_JOB_STARTED =
      pkgs.writeShellScript "job-started-hook.sh" ''
        set -e
        TIMEOUT_SECS=60*60

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

in {
  services.getty.autologinUser = "root";

  networking.hosts = { "2403:580e:e231:0:770:6ce6:26de:9774" = [ "spesso" ]; };

  services.github-runners.tests-github-runner = m;
  # services.github-runners.ouroboros-consensus-tools = m;
}
