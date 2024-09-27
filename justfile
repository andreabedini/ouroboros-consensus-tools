default:
  just --list

get-new-token:
  gh api --method POST -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" --jq .token /repos/{owner}/{repo}/actions/runners/registration-token

build-container:
  nix build .#nixosConfigurations.container.config.system.build.toplevel -o result-nspawn

start-container: build-container
  sudo SYSTEMD_NSPAWN_UNIFIED_HIERARCHY=1 systemd-nspawn \
    --machine tests-github-runner --boot --ephemeral --network-veth \
    --directory result-nspawn \
    --bind-ro=/nix/store \
    --set-credential=token:$(just get-new-token)

build-vm:
  nix build .#nixosConfigurations.default.config.system.build.vm -o result-vm

start-vm: build-vm
  result-vm/bin/run-nixos-vm \
    -m 4092 \
    -nographic \
    -fw_cfg name=opt/io.systemd.credentials/token,string=$(just get-new-token)

