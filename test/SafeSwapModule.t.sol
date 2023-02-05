// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17;

import {Test} from "forge-std/Test.sol";

import {ISwapRequester} from "../src/ISwapRequester.sol";
import {SafeSwapModule} from "../src/SafeSwapModule.sol";
import {FooToken, BarToken} from "./utils/Tokens.sol";

import {Enum} from "@safe/common/Enum.sol";
import {GnosisSafe} from "@safe/GnosisSafe.sol";
import {GnosisSafeProxyFactory} from "@safe/proxies/GnosisSafeProxyFactory.sol";

contract TestEvents {
    event EnabledModule(address module);
    event DisabledModule(address module);
    event ExecutionFailure(bytes32 txHash, uint256 payment);
    event ExecutionSuccess(bytes32 txHash, uint256 payment);
    event ExecutionFromModuleSuccess(address indexed module);
    event ExecutionFromModuleFailure(address indexed module);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event SwapRequestCreated(
        uint256 indexed id,
        address indexed requester,
        ISwapRequester.SwapRequest swap
    );
    event SwapRequestCancelled(
        uint256 indexed id,
        address indexed requester,
        ISwapRequester.SwapRequest swap
    );
    event SwapRequestExecuted(
        uint256 indexed id,
        address indexed requester,
        address source,
        address recipient,
        ISwapRequester.SwapRequest swap
    );
}

/// @notice Sets up the test environment and provides helper functions.
/// @dev These tests are largely incomplete, as this is just a prototype. A
///     finalized design will have signficantly more coverage.
contract BaseSetup is Test, TestEvents {
    uint256 internal constant FOO_TOKEN_SUPPLY = 100;
    uint256 internal constant BAR_TOKEN_SUPPLY = 100;

    FooToken public fooToken;
    BarToken public barToken;

    GnosisSafe public safe;
    SafeSwapModule public module;

    uint256 alicePrKey;
    uint256 bobPrKey;
    uint256 searcherSrcPrKey;
    uint256 searcherRecvPrKey;
    address internal alice;
    address internal bob;
    address internal searcherSrc;
    address internal searcherRecv;

    /// @dev Initializes the test users and contracts.
    function setUp() public {
        // starting owner
        alicePrKey = 0xA11CE;
        alice = vm.addr(alicePrKey);
        vm.label(alice, "Alice");

        // potential owner
        bobPrKey = 0xB22CE;
        bob = vm.addr(bobPrKey);
        vm.label(bob, "Bob");

        // searcher source holds the tokens in the 'to' field of SwapRequest
        searcherRecvPrKey = 0xC33CE;
        searcherSrc = vm.addr(searcherRecvPrKey);
        vm.label(searcherSrc, "MEV Searcher Source");

        // searcher recipient recieves the tokens the SwapRequest execution
        searcherRecvPrKey = 0xD44CE;
        searcherRecv = vm.addr(searcherRecvPrKey);
        vm.label(searcherRecv, "MEV Searcher Recipient");

        // deploy Safe with module and Alice as owner
        GnosisSafe singletonSafe = new GnosisSafe();
        GnosisSafeProxyFactory safeFactory = new GnosisSafeProxyFactory();
        address[] memory owners = new address[](1);
        owners[0] = alice;
        safe = createSafeProxy(singletonSafe, safeFactory, owners);
        vm.label(address(safe), "Safe");
        module = new SafeSwapModule(payable(address(safe)));
        vm.label(address(module), "SafeSwapModule");

        // Safe starts out with FOO tokens
        vm.startPrank(alice);
        fooToken = new FooToken(FOO_TOKEN_SUPPLY);
        fooToken.transfer(payable(address(safe)), FOO_TOKEN_SUPPLY);
        vm.stopPrank();

        // Searcher source starts out with BAR tokens
        vm.startPrank(searcherSrc);
        barToken = new BarToken(BAR_TOKEN_SUPPLY);
        vm.stopPrank();
    }

    function createSafeProxy(
        GnosisSafe singletonSafe,
        GnosisSafeProxyFactory safeFactory,
        address[] memory owners
    ) public returns (GnosisSafe) {
        bytes memory params = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            owners,
            owners.length,
            payable(address(0)),
            0x0,
            address(0),
            address(0),
            0,
            address(0)
        );

        return
            GnosisSafe(
                payable(safeFactory.createProxy(address(singletonSafe), params))
            );
    }

    function enableModule(uint256 _prKey, bool _expectRevert) public {
        bytes memory txEncoded = abi.encodeWithSignature(
            "enableModule(address)",
            address(module)
        );
        bytes32 txEncodedHash = keccak256(txEncoded);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_prKey, txEncodedHash);
        address signer = ecrecover(txEncodedHash, v, r, s);

        if (_expectRevert) {
            vm.expectRevert();
        }
        vm.prank(signer);
        safe.execTransaction(
            address(safe),
            0,
            txEncoded,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            abi.encode(signer, bytes32(0), bytes1(0x01))
        );
    }

    function disableModule(uint256 _prKey, bool _expectRevert) public {
        bytes memory txEncoded = abi.encodeWithSignature(
            "disableModule(address,address)",
            address(0x1),
            address(module)
        );
        bytes32 txEncodedHash = keccak256(txEncoded);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_prKey, txEncodedHash);
        address signer = ecrecover(txEncodedHash, v, r, s);

        if (_expectRevert) {
            vm.expectRevert();
        }
        vm.prank(signer);
        safe.execTransaction(
            address(safe),
            0,
            txEncoded,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            abi.encode(signer, bytes32(0), bytes1(0x01))
        );
    }

    function createSwapRequest(
        uint256 _prKey,
        ISwapRequester.SwapRequest memory _swap,
        bool _expectRevert
    ) public {
        bytes memory txEncoded = abi.encodeWithSelector(
            ISwapRequester.createSwapRequest.selector,
            _swap
        );
        bytes32 txEncodedHash = keccak256(txEncoded);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_prKey, txEncodedHash);
        address signer = ecrecover(txEncodedHash, v, r, s);

        if (_expectRevert) {
            vm.expectRevert();
        }

        vm.expectEmit(false, false, false, false);
        emit ExecutionSuccess(bytes32(0), 0);

        vm.prank(signer);
        safe.execTransaction(
            address(module),
            0,
            txEncoded,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            abi.encode(signer, bytes32(0), bytes1(0x01))
        );
    }

    function cancelSwapRequest(
        uint256 _prKey,
        uint256 _swapId,
        bool _expectRevert
    ) public {
        bytes memory txEncoded = abi.encodeWithSelector(
            ISwapRequester.cancelSwapRequest.selector,
            _swapId
        );
        bytes32 txEncodedHash = keccak256(txEncoded);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_prKey, txEncodedHash);
        address signer = ecrecover(txEncodedHash, v, r, s);

        if (_expectRevert) {
            vm.expectRevert();
        }

        vm.expectEmit(false, false, false, false);
        emit ExecutionSuccess(bytes32(0), 0);

        vm.prank(signer);
        safe.execTransaction(
            address(module),
            0,
            txEncoded,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            abi.encode(signer, bytes32(0), bytes1(0x01))
        );
    }

    function executeSwapRequest(
        uint256 _prKey,
        uint256 _swapId,
        address _source,
        address _recipient,
        bool _expectRevert
    ) public {
        bytes memory txEncoded = abi.encodeWithSelector(
            ISwapRequester.executeSwapRequest.selector,
            _swapId,
            _source,
            _recipient
        );
        bytes32 txEncodedHash = keccak256(txEncoded);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_prKey, txEncodedHash);
        address signer = ecrecover(txEncodedHash, v, r, s);

        if (_expectRevert) {
            vm.expectRevert();
        }

        vm.expectEmit(false, false, false, false);
        emit ExecutionSuccess(bytes32(0), 0);

        vm.prank(signer);
        safe.execTransaction(
            address(module),
            0,
            txEncoded,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            abi.encode(signer, bytes32(0), bytes1(0x01))
        );
    }
}

contract ModuleSetup is BaseSetup {
    function testOkSetup() public {
        assertEq(safe.getThreshold(), 1);
        assertEq(safe.getOwners()[0], alice);
        assertEq(fooToken.balanceOf(address(safe)), FOO_TOKEN_SUPPLY);
        assertEq(barToken.balanceOf(address(safe)), 0);
        assertEq(fooToken.balanceOf(alice), 0);
        assertEq(barToken.balanceOf(alice), 0);
        assertEq(fooToken.balanceOf(bob), 0);
        assertEq(barToken.balanceOf(bob), 0);
        assertEq(fooToken.balanceOf(searcherSrc), 0);
        assertEq(barToken.balanceOf(searcherSrc), BAR_TOKEN_SUPPLY);
        assertEq(fooToken.balanceOf(searcherRecv), 0);
        assertEq(barToken.balanceOf(searcherRecv), 0);
        assertEq(address(module.safe()), address(safe));
    }
}

contract ModuleEnablement is BaseSetup {
    function testOkEnableModule() public {
        vm.expectEmit(true, true, true, true);
        emit EnabledModule(address(module));
        enableModule(alicePrKey, false);
        assertTrue(safe.isModuleEnabled(address(module)));

        (address[] memory modules, ) = safe.getModulesPaginated(address(1), 10);
        assertEq(modules[0], address(module));
    }

    function testOkDisableModule() public {
        vm.expectEmit(true, true, true, true);
        emit EnabledModule(address(module));
        enableModule(alicePrKey, false);
        assertTrue(safe.isModuleEnabled(address(module)));

        vm.expectEmit(true, true, true, true);
        emit DisabledModule(address(module));
        disableModule(alicePrKey, false);
        assertFalse(safe.isModuleEnabled(address(module)));
    }

    function testCannotEnableModuleNotOwner() public {
        enableModule(bobPrKey, true); // not owner
        assertFalse(safe.isModuleEnabled(address(module)));
    }

    function testCannotDisableModuleNotOwner() public {
        vm.expectEmit(true, true, true, true);
        emit EnabledModule(address(module));
        enableModule(alicePrKey, false);
        assertTrue(safe.isModuleEnabled(address(module)));

        disableModule(bobPrKey, true); // not owner
        assertTrue(safe.isModuleEnabled(address(module)));
    }
}

contract ModuleSwap is BaseSetup {
    function testOkSwapRequestCreate() public {
        enableModule(alicePrKey, false);

        ISwapRequester.SwapRequest memory swap = ISwapRequester.SwapRequest({
            fromToken: address(fooToken),
            toToken: address(barToken),
            fromAmount: 10,
            toAmount: 20,
            deadline: 0,
            cancelled: false,
            executed: false
        });

        vm.expectEmit(true, true, true, true);
        emit SwapRequestCreated(1, address(safe), swap);

        vm.prank(alice);
        createSwapRequest(alicePrKey, swap, false);
        assertEq(module.allSwapRequestsLength(), 1);
        ISwapRequester.SwapRequest[] memory all = module.getAllSwapRequests();
        assertEq(all.length, 1);
        assertEq(all[0].fromToken, swap.fromToken);
        assertEq(all[0].toToken, swap.toToken);
        assertEq(all[0].fromAmount, swap.fromAmount);
        assertEq(all[0].toAmount, swap.toAmount);
        assertEq(all[0].deadline, swap.deadline);
        assertFalse(all[0].cancelled);
    }

    function testOkSwapRequestCancel() public {
        enableModule(alicePrKey, false);

        ISwapRequester.SwapRequest memory swap = ISwapRequester.SwapRequest({
            fromToken: address(fooToken),
            toToken: address(barToken),
            fromAmount: 10,
            toAmount: 20,
            deadline: 0,
            cancelled: false,
            executed: false
        });

        vm.expectEmit(true, true, true, true);
        emit SwapRequestCreated(1, address(safe), swap);

        createSwapRequest(alicePrKey, swap, false);

        assertEq(module.allSwapRequestsLength(), 1);
        ISwapRequester.SwapRequest[] memory all = module.getAllSwapRequests();
        assertEq(all.length, 1);
        assertEq(all[0].fromToken, swap.fromToken);
        assertEq(all[0].toToken, swap.toToken);
        assertEq(all[0].fromAmount, swap.fromAmount);
        assertEq(all[0].toAmount, swap.toAmount);
        assertEq(all[0].deadline, swap.deadline);
        assertFalse(all[0].cancelled);

        vm.expectEmit(true, true, true, true);
        emit SwapRequestCancelled(
            0,
            address(safe),
            ISwapRequester.SwapRequest({
                fromToken: address(fooToken),
                toToken: address(barToken),
                fromAmount: 10,
                toAmount: 20,
                deadline: 0,
                cancelled: true,
                executed: false
            })
        );

        cancelSwapRequest(alicePrKey, 0, false);

        assertEq(module.allSwapRequestsLength(), 1);
        all = module.getAllSwapRequests();
        assertEq(all.length, 1);
        assertEq(all[0].fromToken, swap.fromToken);
        assertEq(all[0].toToken, swap.toToken);
        assertEq(all[0].fromAmount, swap.fromAmount);
        assertEq(all[0].toAmount, swap.toAmount);
        assertEq(all[0].deadline, swap.deadline);
        assertTrue(all[0].cancelled);
    }

    function testOkSwapRequestExecute() public {
        enableModule(alicePrKey, false);

        ISwapRequester.SwapRequest memory swap = ISwapRequester.SwapRequest({
            fromToken: address(fooToken),
            toToken: address(barToken),
            fromAmount: 10,
            toAmount: 20,
            deadline: 0,
            cancelled: false,
            executed: false
        });

        createSwapRequest(alicePrKey, swap, false);

        vm.expectEmit(true, true, true, true);
        emit SwapRequestExecuted(
            0,
            address(safe),
            searcherSrc,
            searcherRecv,
            ISwapRequester.SwapRequest({
                fromToken: address(fooToken),
                toToken: address(barToken),
                fromAmount: 10,
                toAmount: 20,
                deadline: 0,
                cancelled: false,
                executed: true
            })
        );

        vm.startPrank(searcherSrc);
        barToken.approve(address(safe), 20);
        vm.stopPrank();

        executeSwapRequest(alicePrKey, 0, searcherSrc, searcherRecv, false);

        assertEq(module.allSwapRequestsLength(), 1);
        ISwapRequester.SwapRequest[] memory all = module.getAllSwapRequests();
        assertEq(all.length, 1);
        assertEq(all[0].fromToken, swap.fromToken);
        assertEq(all[0].toToken, swap.toToken);
        assertEq(all[0].fromAmount, swap.fromAmount);
        assertEq(all[0].toAmount, swap.toAmount);
        assertEq(all[0].deadline, swap.deadline);
        assertTrue(all[0].executed);

        assertEq(fooToken.balanceOf(address(safe)), FOO_TOKEN_SUPPLY - 10);
        assertEq(barToken.balanceOf(address(safe)), 20);
        assertEq(fooToken.balanceOf(address(searcherSrc)), 0);
        assertEq(
            barToken.balanceOf(address(searcherSrc)),
            BAR_TOKEN_SUPPLY - 20
        );
        assertEq(fooToken.balanceOf(address(searcherRecv)), 10);
        assertEq(barToken.balanceOf(address(searcherRecv)), 0);
    }

    // TODO: more cases (non-owner cancels, src never approved,
    //       src has no BAR, multiple-owner, src == recv address, etc)
}
