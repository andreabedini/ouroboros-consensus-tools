all:
	@echo "Hello, World!"

gh-auth-status:
	@gh auth status

.PHONY: get-new-token
get-new-token:
	@echo "Obtaining registration token for $$(gh repo set-default --view)" >/dev/stderr
	@gh api --method POST -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" --jq .token /repos/{owner}/{repo}/actions/runners/registration-token

build-vm:
	nix build .#nixosConfigurations.default.config.system.build.vm

start-vm: gh-auth-status build-vm
	result/bin/run-nixos-vm \
		-m 4092 \
		-nographic \
		-fw_cfg name=opt/io.systemd.credentials/token,string=$$(make --silent get-new-token)
