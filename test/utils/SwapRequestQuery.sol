// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17;

import {ISwapRequester} from "../../src/ISwapRequester.sol";

/// @notice A helper contract for querying swap requests, Searchers would
///         use something similar to fetch from multiple ISwapRequesters efficently
///         on chain with one multicall.
contract SwapRequestQuery {
    /// @notice Gets batch swap requests for a given SwapRequester.
    function getSwapRequestsByIndexRange(
        ISwapRequester _swapRequester,
        uint256 _start,
        uint256 _end
    ) external view returns (ISwapRequester.SwapRequest[] memory) {
        uint256 length = _swapRequester.allSwapRequestsLength();
        if (_end > length) {
            _end = length;
        }
        require(_end >= _start, "start cannot come after end");
        ISwapRequester.SwapRequest[] memory all = _swapRequester
            .getAllSwapRequests();
        uint256 qty = _end - _start;
        ISwapRequester.SwapRequest[]
            memory result = new ISwapRequester.SwapRequest[](qty);
        for (uint256 i = 0; i < qty; i++) {
            result[i] = all[_start + i];
        }
        return result;
    }
}
