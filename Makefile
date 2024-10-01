BEACON_DATA ?= $(shell git rev-parse --show-toplevel)/beacon-data

gh-auth-status:
	@echo "Just checking if you're authenticated with GitHub..." >&2
	@echo "Use 'make start-vm' to start the VM" >&2
	@gh auth status

.PHONY: get-new-token
get-new-token:
	@echo "Obtaining registration token for $$(gh repo set-default --view)" >&2
	@gh api --method POST -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" --jq .token /repos/{owner}/{repo}/actions/runners/registration-token

build-vm:
	@echo "Building the VM..." >&2
	nix build .#nixosConfigurations.default.config.system.build.vm

start-vm: build-vm
	@echo "Starting the VM..." >&2
	result/bin/run-nixos-vm \
		-m 4092 \
		-nographic \
		-virtfs local,path=$(BEACON_DATA),security_model=mapped-xattr,mount_tag=beacon-data \
		-fw_cfg name=opt/io.systemd.credentials/token,string=$$(make --silent get-new-token)
