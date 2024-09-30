# ouroboros-consensus-tools

Tools related to the [Consensus](https://github.com/input-output-hk/ouroboros-consensus/) component of Cardano.

- [beacon](beacon/README.md): a tool used to compare performance of two Consensus versions.

# Benchmarking workflow



## Development

* Create the virtual machine for the runner with `make build-vm`
* Make sure you are authenticated with `gh` by running `gh auth status`, as
`gh` is used to obtain a registration token for the runner.
* Use `gh repo set-default` to set the repository associated with the runner.
* Start the virtual machine with `make start-vm`
