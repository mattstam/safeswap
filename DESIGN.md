# [SafeSwap Design](#safeswap-design)

> Active discussion at https://forum.gnosis-safe.io/t/design-safeswap-module/2674

### Summary
Allow users to signal an intent to trade tokens in their Safe via a [SwapRequest](https://github.com/mattstam/safeswap/blob/f7db5203d0e5ad0fe1b7f37c3d826bea683e77bc/src/ISwapRequester.sol#L19-L27), and take advantage of [MEV Searchers](https://ethereum.org/en/developers/docs/mev/) to execute it.

### Background
A non crypto-native user's first interaction with Web3 will often be trying to trade an ERC20 token. However, the UX in making a trade is unsatisfactory for those who have limited DeFi experience. These users are overwhelmed with the complex decision-making process that goes in to trying to perform an optimal trade on a decentralized exchange (DEX).

This process is can be enough to give the user a sense of choice paralysis, where they choose to simply not interact with Web3 at all. [SafeSwap](https://github.com/mattstam/safeswap) attempts to remove the overburdening barriers-to-entry that these users face when attempting to execute trades.

### Goals
* Provide a simple, accessible, and secure UX for swapping tokens directly from their Safe.
* Reduce the amount of Web3 & DeFi knowledge required to swap tokens and participate in the trading ecosystem.

### Design
After the SafeSwap [module](https://docs.gnosis-safe.io/contracts/modules-1) is attached to a Safe, users can signal the intent and ability for someone else to transfer the assets that are held within their Safe in order to make the desired swap via a [SwapRequest](https://github.com/mattstam/safeswap/blob/f7db5203d0e5ad0fe1b7f37c3d826bea683e77bc/src/ISwapRequester.sol#L19-L27) creation:
```Solidity
struct SwapRequest {
    bool cancelled;
    bool executed;
    address fromToken;
    address toToken;
    uint256 fromAmount;
    uint256 toAmount;
    uint256 deadline;
}
```

With this, a user effectively says:
> "I have X $TKA in my wallet, and want Y $TKB instead."

This intent can then be used by [MEV Searchers](https://ethereum.org/en/developers/docs/mev/) to incorporate into their trading strategy, who will actually to do the transfer of the desired tokens when it meets their needs.

For [MEV arbitrage](https://ethereum.org/en/developers/docs/mev/#mev-examples-dex-arbitrage), typical strategies involve multiple swaps across a range of DEXs and token pairs. [Example 1](https://etherscan.io/tx/0xd4868be6bd3a36fc55e6d77d5a07e363121943ade4c05e19f26ec7cb74d6e119) and [Example 2](https://etherscan.io/tx/0xd4868be6bd3a36fc55e6d77d5a07e363121943ade4c05e19f26ec7cb74d6e119) do *9 token swaps* in a single transaction:
> DEX Swap → DEX Swap → ... → DEX Swap → DEX Swap

By incorporating active [SwapRequests](https://github.com/mattstam/safeswap-module/blob/f7db5203d0e5ad0fe1b7f37c3d826bea683e77bc/src/SafeSwapModule.sol#L22) from multiple Safes into their strategy, there will be even more opportunities for profitable transactions by using this new avaliable liquidity:
> DEX Swap → SwapRequest Swap → ... → DEX Swap → SwapRequest Swap → DEX Swap

To help signal this intent to MEV Searchers, an [event](https://github.com/mattstam/safeswap-module/blob/f7db5203d0e5ad0fe1b7f37c3d826bea683e77bc/src/ISwapRequester.sol#L29) gets [emitted](https://github.com/mattstam/safeswap-module/blob/f7db5203d0e5ad0fe1b7f37c3d826bea683e77bc/src/SafeSwapModule.sol#L41)which they can incorporate as part of their strategy. They can also iterate over [an array of SwapRequests](https://github.com/mattstam/safeswap-module/blob/f7db5203d0e5ad0fe1b7f37c3d826bea683e77bc/src/SafeSwapModule.sol#L22) (ensuring to filter `cancelled` and `executed` swaps appropriately).

If an MEV Searcher can use an active SwapRequest, they can [executeSwapRequest()](https://github.com/mattstam/safeswap-module/blob/f7db5203d0e5ad0fe1b7f37c3d826bea683e77bc/src/SafeSwapModule.sol#L64) on the module, which will do the appropriate transfers.

### Implementation
A quick proof-of-concept: https://github.com/mattstam/safeswap

### User Experience
The main is to massively improve the UX of swapping ERC20 tokens by reducing the level of knowledge and decisions required to make an optimal trade. 

To see how SafeSwap achieves this, consider this scenario for a new Web3 user:
> "I was airdropped 10 UNI tokens, now I want to exchange them for WETH"
	
###### Without SafeSwap:
1. Choose CEX or DEX
	* If CEX: incur additional fees, trust a third party to handle your assets
	* If DEX:
		* Choose an appropriate DEX that has this pair available (Uniswap, Balancer, CoWSwap, ...)
		* If multiple pairs exist on different DEXs, weigh pro/cons of each
		* If concerned with front-running:
			* Learn how submit Flashbots bundles for private TX
2. Calculate slippage and additional fees to use for the UNI swap
3. Submit swap

###### With SafeSwap:
0. add SwapSwap Module (if not already added)
1. Calculate the appropriate about of WETH for the UNI
2. Submit swap

All of these steps can have frontend incorporated to make the UX seemless. (0) adding modules already has support, and (1) can look up current trade ratios to suggest an appropriate price.

### Benefits & Drawbacks
Pros:
* No necessary understanding of finance or DeFi protocols
* No interactions with external contracts
	* Only ever interact with trusted, secure Safe + SafeSwap Module contracts, both of which Safe can provide a UI for
* Lower possible gas cost initial gas costs
	* Storage write + event emit to signal trade
	* Searcher pays gas for the actual transfers
* Zero slippage (you specify an exact `tokenOut`)
* No trade fee*
* Limited gas fee*
* Expiration/cancellation flexibility (e.g. GTC)
* Set-and-forget experience
* No address whitelist management (for every DEX address)
* No potential for getting sandwich attacked

Cons:
* Needs x amount of users to adopt before searchers add these to their strategy
* Usually not executed as quickly as using a DEX directly

### Challenges
The main barrier for getting this scheme to work at scale is getting enough MEV Searchers to include it in their arbitrage bot logic.

To overcome this, this design will take advantage of Safe's unique characteristics:
1. popularity
2. indexability

##### 1. Popularity
For MEV Searchers to look for these opportunities, a sufficient number of users have to be utilizing the module. This is a classic [two-sided marketplace](https://reasonstreet.co/business-model-two-sided-marketplace/) problem, where the initial effort required is getting both sides sufficient usage. Consider the example of ride-sharing app in a new city: 
* without drivers, riders never use the app
* without available riders, nobody becomes a driver

By using the popularity of Safe, along with the ease-of-use of attaching new Modules, it is possible for this scheme to gain widespread adoption.

The upside is, once both sides of the marketplace have reached sufficient capacity, this scheme runs itself with no necessary intervention. As more MEV Searchers include these swaps, the UX becomes better as SwapRequests will be fulfilled at a quicker rate.

##### 2. Indexablity
This is a property that MEV Searchers need to be able to easily create a local cache of all possible swaps, which makes building a strategy viable utilizing SwapRequests.

This is similar to when a MEV Searcher needs to cache all known UniswapV2 pairs. So they look at [IUniswapV2Factory](https://raw.githubusercontent.com/Uniswap/v2-core/master/contracts/interfaces/IUniswapV2Factory.sol).

Safe utilizes a similar factory, and tracking down existing Safes is easy (which was useful for [the SAFE airdrop](https://forum.gnosis-safe.io/t/proposal-safe-distribution-for-users/369)). MEV searchers will *already have experience* with this pattern, which should help them adapt.

### Risks
If a sufficient number of SwapRequests is not achieved, then few MEV Searchers will include it in their arbitration bot logic, and users will be dissatisfied that their SwapRequest never gets executed.

To circumvent this, it may make sense to offer a SAFE token incentivization program that rewards users for executing creating SwapRequests or getting them executed. It may also make sense to choose to reward MEV Searchers for executing, but incentivizing just the Safe users should be enough.

The [unallocated airdropped SAFE tokens](https://forum.gnosis-safe.io/t/sep-5-redistributing-unredeemed-tokens-from-user-airdrop-allocation/2172) could be used for this purpose, though it is not necassary to use that source specifically

### Questions

###### Are there any similar protocols?
Closest comparison is with "meta-DEX" like CoWSwap, which also:
* utilizes existing DEX protocols
* abstracts away gas cost
* avoids MEV sandwich attacks

But SafeSwap is different in a few very important ways:
* doesn't require *additional* off-chain actors
* removes any "external" calls to protocols

###### Will this be as cost-effective as an equivalent, perfectly-timed DEX trade?
Generally, no. Since the MEV Searcher needs to make enough profit to pay for overhead, the actual DEX price at the time a SwapRequest is executed is always going to be at a better *ratio* than what the SwapRequest is for.

But this gap will be minimal due to the competitiveness of MEV Searchers, and will only shrink as more MEV Searchers include this in their arbitration bot logic.

### Future
[SwapRequests](https://github.com/mattstam/safeswap/blob/f7db5203d0e5ad0fe1b7f37c3d826bea683e77bc/src/ISwapRequester.sol#L19-L27) are generalizable to all smart contract wallet implementations, and therefor should be made as an EIP to preserve compatibility and interoperability.