// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {HdpExecutionStore} from "../../src/hdp/HdpExecutionStore.sol";
import {BlockSampledDatalake, BlockSampledDatalakeCodecs} from "../../src/hdp/datatypes/BlockSampledDatalakeCodecs.sol";
import {ComputationalTask, ComputationalTaskCodecs} from "../../src/hdp/datatypes/ComputationalTaskCodecs.sol";

import {IFactsRegistry} from "../../src/interfaces/IFactsRegistry.sol";
import {ISharpFactsAggregator} from "../../src/interfaces/ISharpFactsAggregator.sol";
import {IAggregatorsFactory} from "../../src/interfaces/IAggregatorsFactory.sol";
import {Uint256Splitter} from "../../src/lib/Uint256Splitter.sol";

contract MockFactsRegistry is IFactsRegistry {
    mapping(bytes32 => bool) public isValid;

    function markValid(bytes32 fact) public {
        isValid[fact] = true;
    }
}

contract MockAggregatorsFactory is IAggregatorsFactory {
    mapping(uint256 => ISharpFactsAggregator) public aggregatorsById;

    function createAggregator(
        uint256 id,
        ISharpFactsAggregator aggregator
    ) external {
        aggregatorsById[id] = aggregator;
    }
}

contract MockSharpFactsAggregator is ISharpFactsAggregator {
    function aggregatorState() external view returns (AggregatorState memory) {
        bytes32 root = 0x067e9e103829fd281d8f72d911d8f7c4b146854f79a42a292be46f52a1404ca0;
        return
            AggregatorState({
                poseidonMmrRoot: root,
                keccakMmrRoot: bytes32(0),
                mmrSize: 209371,
                continuableParentHash: bytes32(0)
            });
    }
}

contract HreExecutionStoreTest is Test {
    using BlockSampledDatalakeCodecs for BlockSampledDatalake;
    using ComputationalTaskCodecs for ComputationalTask;

    address proverAddress = address(12);

    HdpExecutionStore private hdp;

    IFactsRegistry private factsRegistry;
    IAggregatorsFactory private aggregatorsFactory;
    ISharpFactsAggregator private sharpFactsAggregator;

    function setUp() public {
        // Registery for facts that has been processed through SHARP
        factsRegistry = new MockFactsRegistry();
        // Factory for creating SHARP facts aggregators
        aggregatorsFactory = new MockAggregatorsFactory();
        // Mock SHARP facts aggregator
        sharpFactsAggregator = new MockSharpFactsAggregator();
        hdp = new HdpExecutionStore(factsRegistry, aggregatorsFactory);

        // Step 0. Create mock SHARP facts aggregator mmr id 24
        aggregatorsFactory.createAggregator(24, sharpFactsAggregator);

        assertTrue(hdp.hasRole(keccak256("OPERATOR_ROLE"), address(this)));
        bytes32 admin_role = hdp.getRoleAdmin(keccak256("OPERATOR_ROLE"));
        console.logBytes32(admin_role);
        hdp.grantRole(keccak256("OPERATOR_ROLE"), proverAddress);
    }

    function test_ExecutionOfTaskWithBlockSampledDatalake() public {
        // [1 Request = N Tasks] Request execution of task with block sampled datalake
        BlockSampledDatalake memory datalake = BlockSampledDatalake({
            blockRangeStart: 10399990,
            blockRangeEnd: 10400000,
            increment: 1,
            sampledProperty: BlockSampledDatalakeCodecs
                .encodeSampledPropertyForHeaderProp(15)
        });

        ComputationalTask memory computationalTask1 = ComputationalTask({
            aggregateFnId: uint256(bytes32("avg")),
            aggregateFnCtx: ""
        });
        ComputationalTask memory computationalTask2 = ComputationalTask({
            aggregateFnId: uint256(bytes32("sum")),
            aggregateFnCtx: ""
        });
        // =================================

        // Emit the event in there when call request
        hdp.requestExecutionOfTaskWithBlockSampledDatalake(
            datalake,
            computationalTask1,
            24
        );

        // Emit the event in there when call request
        hdp.requestExecutionOfTaskWithBlockSampledDatalake(
            datalake,
            computationalTask2,
            24
        );

        // Compute commitment of the datalake and the task
        bytes32 datalakeCommitment = datalake.commit();
        bytes32 task1Commitment = computationalTask1.commit(datalakeCommitment);
        bytes32 task2Commitment = computationalTask2.commit(datalakeCommitment);

        // Check if the task state is PENDING
        HdpExecutionStore.TaskStatus task1Status = hdp.getTaskStatus(
            task1Commitment
        );
        assertEq(
            uint(task1Status),
            uint(HdpExecutionStore.TaskStatus.SCHEDULED)
        );
        HdpExecutionStore.TaskStatus task2Status = hdp.getTaskStatus(
            task2Commitment
        );
        assertEq(
            uint(task2Status),
            uint(HdpExecutionStore.TaskStatus.SCHEDULED)
        );

        // Encode datalakes
        bytes[] memory encodedDatalakes = new bytes[](2);
        encodedDatalakes[0] = datalake.encode();
        encodedDatalakes[1] = datalake.encode();

        // Encode tasks
        bytes[] memory computationalTasksSerialized = new bytes[](2);
        computationalTasksSerialized[0] = computationalTask1.encode();
        computationalTasksSerialized[1] = computationalTask2.encode();

        // TODO: Get serialized result
        bytes[] memory computationalTasksResult = new bytes[](2);
        computationalTasksResult[0] = bytes("result1");
        computationalTasksResult[1] = bytes("result2");

        // =================================

        (bytes32 tasksRoot, bytes32 resultsRoot) = processBatchThroughFFI(
            encodedDatalakes,
            computationalTasksSerialized
        );

        uint256 tasksRootUint = uint256(tasksRoot);
        (uint256 tasksRootLow, uint256 tasksRootHigh) = Uint256Splitter
            .split128(tasksRootUint);

        uint256 resultsRootUint = uint256(resultsRoot);
        (uint256 resultsRootLow, uint256 resultsRootHigh) = Uint256Splitter
            .split128(resultsRootUint);

        // Output from Cairo Program
        uint256 usedMmrId = 24;
        uint256 usedMmrSize = 209371;
        // root of tasks merkle tree
        uint128 scheduledTasksBatchMerkleRootLow = uint128(tasksRootLow);
        uint128 scheduledTasksBatchMerkleRootHigh = uint128(tasksRootHigh);
        // root of result merkle tree
        uint128 batchResultsMerkleRootLow = uint128(resultsRootLow);
        uint128 batchResultsMerkleRootHigh = uint128(resultsRootHigh);

        // Fetch from Rust HDP
        // proof of the task
        bytes32[] memory batchInclusionMerkleProofOfTask = new bytes32[](2);
        // proof of the result
        bytes32[] memory batchInclusionMerkleProofOfResult = new bytes32[](2);

        // Check if the request is valid in the SHARP Facts Registry
        // If valid, Store the task result
        vm.prank(proverAddress);
        hdp.authenticateTaskExecution(
            usedMmrId,
            usedMmrSize,
            batchResultsMerkleRootLow,
            batchResultsMerkleRootHigh,
            scheduledTasksBatchMerkleRootLow,
            scheduledTasksBatchMerkleRootHigh,
            batchInclusionMerkleProofOfTask,
            batchInclusionMerkleProofOfResult,
            computationalTasksSerialized,
            computationalTasksResult
        );

        // Check if the task state is FINALIZED
        HdpExecutionStore.TaskStatus task1StatusAfter = hdp.getTaskStatus(
            task1Commitment
        );
        assertEq(
            uint(task1StatusAfter),
            uint(HdpExecutionStore.TaskStatus.FINALIZED)
        );
        HdpExecutionStore.TaskStatus task2StatusAfter = hdp.getTaskStatus(
            task2Commitment
        );
        assertEq(
            uint(task2StatusAfter),
            uint(HdpExecutionStore.TaskStatus.FINALIZED)
        );

        // Check if the task result is stored
        bytes memory task1Result = hdp.getFinalizedTaskResult(task1Commitment);
        assertEq(task1Result, computationalTasksResult[0]);
        bytes memory task2Result = hdp.getFinalizedTaskResult(task2Commitment);
        assertEq(task2Result, computationalTasksResult[1]);
    }

    function processBatchThroughFFI(
        bytes[] memory encodedDatalakes,
        bytes[] memory encodedComputationalTasks
    ) internal returns (bytes32 tasksRoot, bytes32 resultsRoot) {
        // Ensure length match
        require(
            encodedDatalakes.length == encodedComputationalTasks.length,
            "Length mismatch"
        );

        string[] memory inputsExtended = new string[](3);
        inputsExtended[0] = "hdp run";
        inputsExtended[1] = string(abi.encode(encodedDatalakes));
        inputsExtended[2] = string(abi.encode(encodedComputationalTasks));

        bytes memory outputExtended = vm.ffi(inputsExtended);
    }
}
