# [SafeSwap](#safeswap)

A [Safe Module](https://docs.gnosis-safe.io/contracts/modules-1) that allows users to submit a token swap request that may be executed by anyone. The tokens are only ever transferred to and from their Safe wallet directly.

The [SwapRequest](https://github.com/mattstam/safeswap/blob/f7db5203d0e5ad0fe1b7f37c3d826bea683e77bc/src/ISwapRequester.sol#L19-L27) can then be fulfilled by [MEV Searchers](https://ethereum.org/en/developers/docs/mev/) as part of their trading strategy.

Please see [DESIGN.md](DESIGN.md) for more details.

### [Developer Guide](#developer-guide)
##### [Install Foundry](#install-foundry)

```sh
curl -L https://foundry.paradigm.xyz | bash
```

Then, in a new terminal session or after reloading your `PATH`, run this to get
the latest [`forge`](https://book.getfoundry.sh/reference/forge/forge) and [`cast`](https://book.getfoundry.sh/reference/cast/cast) binaries:

```sh
foundryup
```

##### [Run the unit tests with Forge](#run-the-unit-tests-with-forge)

```sh
forge test
```

### [Security](#security)

This repository is a proof-of-concept, and these contracts have not been audited or been through any
formal security review. DO NOT use these contracts in production.
