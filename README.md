# [SafeSwap Module](#safeswap-module)

A [Safe Module](https://docs.gnosis-safe.io/contracts/modules-1) that allows users to submit a token swap request that may be executed by anyone on the chain. The tokens are only ever transferred to and from the Safe directly.

#### [Install Foundry](#install-foundry)

```sh
curl -L https://foundry.paradigm.xyz | bash
```

Then, in a new terminal session or after reloading your `PATH`, run this to get
the latest [`forge`](https://book.getfoundry.sh/reference/forge/forge) and [`cast`](https://book.getfoundry.sh/reference/cast/cast) binaries:

```sh
foundryup
```

#### [Run the unit tests with Forge](#run-the-unit-tests-with-forge)

```sh
forge test
```

### [Security](#security)

This repository is a proof-of-concept, and these contracts have not been audited or been through any
formal security review. DO NOT use these contracts in production.
