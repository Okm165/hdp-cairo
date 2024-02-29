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
import {HexStringConverter} from "../../src/lib/HexStringConverter.sol";

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
    function aggregatorState() external pure returns (AggregatorState memory) {
        bytes32 root = 0x0614c2c4abb1e3b1f4a2c69c320b10cb78466800b62ee52a8476f9986925ac06;
        return
            AggregatorState({
                poseidonMmrRoot: root,
                keccakMmrRoot: bytes32(0),
                mmrSize: 2397,
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

        // Step 0. Create mock SHARP facts aggregator mmr id 2
        aggregatorsFactory.createAggregator(2, sharpFactsAggregator);

        assertTrue(hdp.hasRole(keccak256("OPERATOR_ROLE"), address(this)));

        hdp.grantRole(keccak256("OPERATOR_ROLE"), proverAddress);
    }

     function test_SingleBlockSingleBlockSampledDatalake() public {
        // Note: Step 1. HDP Server receives a request
        // [1 Request = N Tasks] Request execution of task with block sampled datalake
        BlockSampledDatalake memory datalake = BlockSampledDatalake({
            blockRangeStart: 4952100,
            blockRangeEnd: 4952100,
            increment: 1,
            sampledProperty: BlockSampledDatalakeCodecs
                .encodeSampledPropertyForAccount(address(0x7f2C6f930306D3AA736B3A6C6A98f512F74036D4), uint8(0))
        });

        ComputationalTask memory computationalTask = ComputationalTask({
            aggregateFnId: uint256(bytes32("sum")),
            aggregateFnCtx: ""
        });

        // =================================

        // Note: Step 2. HDP Server call [`requestExecutionOfTaskWithBlockSampledDatalake`] before processing
        hdp.requestExecutionOfTaskWithBlockSampledDatalake(
            datalake,
            computationalTask
        );

        // =================================

        // Note: This step is mocking requestExecutionOfTaskWithBlockSampledDatalake
        // create identifier to check request done correctly
        bytes32 datalakeCommitment = datalake.commit();
        bytes32 taskCommitment = computationalTask.commit(datalakeCommitment);
      
        assertEq(
            taskCommitment,
            bytes32(
                0x46296bc9cb11408bfa46c5c31a542f12242db2412ee2217b4e8add2bc1927d0b
            )
        );
      
        // Check the task state is PENDING
        HdpExecutionStore.TaskStatus task1Status = hdp.getTaskStatus(
            taskCommitment
        );
        assertEq(
            uint(task1Status),
            uint(HdpExecutionStore.TaskStatus.SCHEDULED)
        );

        // =================================

        // Note: Step 3. HDP Server process the request sending the tasks to the Rust HDP
        // This step is mocking cli call to Rust HDP

        // Request to cli

        // =================================

        // Encode datalakes
        bytes[] memory encodedDatalakes = new bytes[](1);
        encodedDatalakes[0] = datalake.encode();

        // Encode tasks
        bytes[] memory computationalTasksSerialized = new bytes[](1);
        computationalTasksSerialized[0] = computationalTask.encode();

        // =================================

        // Response from cli

        // Evaluation Result Key from cli
        bytes32[] memory taskCommitments = new bytes32[](1);
        taskCommitments[0] = taskCommitment;

        // Evaluation Result value from cli
        bytes32[] memory computationalTasksResult = new bytes32[](1);
        computationalTasksResult[0] = bytes32(uint256(6776));

        bytes32 taskResultCommitment1 = keccak256(
            abi.encode(taskCommitment, computationalTasksResult[0])
        );

        console.logBytes32(taskResultCommitment1);

        // Tasks and Results Merkle Tree Information
        // proof of the tasks merkle tree
        bytes32[][] memory batchInclusionMerkleProofOfTasks = new bytes32[][](
            1
        );
        bytes32[] memory InclusionMerkleProofOfTask1 = new bytes32[](0);     
        batchInclusionMerkleProofOfTasks[0] = InclusionMerkleProofOfTask1;
     

        // proof of the result
        bytes32[][] memory batchInclusionMerkleProofOfResults = new bytes32[][](
            1
        );
        bytes32[] memory InclusionMerkleProofOfResult1 = new bytes32[](0);
        batchInclusionMerkleProofOfResults[0] = InclusionMerkleProofOfResult1;

       
        uint256 taskMerkleRoot = uint256(
            bytes32(
                0x0030ce873e657283a8e03a3e83ba95a0bf1ad049e8ac1cb8148280aca2b1adc7
            )
        );
        (uint256 taskRootLow, uint256 taskRootHigh) = Uint256Splitter.split128(
            taskMerkleRoot
        );
        uint128 scheduledTasksBatchMerkleRootLow = 0xbf1ad049e8ac1cb8148280aca2b1adc7;
        uint128 scheduledTasksBatchMerkleRootHigh = 0x0030ce873e657283a8e03a3e83ba95a0;
        assertEq(scheduledTasksBatchMerkleRootLow, taskRootLow);
        assertEq(scheduledTasksBatchMerkleRootHigh, taskRootHigh);

        uint256 resultMerkleRoot = uint256(
            bytes32(
                0xee5ce36fcbe3272adfaee606c1fa7cb6030952ad8335425a83ca271685eef146
            )
        );
        (uint256 resultRootLow, uint256 resultRootHigh) = Uint256Splitter
            .split128(resultMerkleRoot);
        uint128 batchResultsMerkleRootLow = 0x030952ad8335425a83ca271685eef146;
        uint128 batchResultsMerkleRootHigh = 0xee5ce36fcbe3272adfaee606c1fa7cb6;
        assertEq(batchResultsMerkleRootLow, resultRootLow);
        assertEq(batchResultsMerkleRootHigh, resultRootHigh);

        // MMR metadata
        uint256 usedMmrId = 2;
        uint256 usedMmrSize = 56994;

        // =================================

        // Cache MMR root
        hdp.cacheMmrRoot(usedMmrId);

        // Mocking Cairo Program, insert the fact into the registry
        bytes32 factHash = getFactHash(
            usedMmrId,
            usedMmrSize,
            batchResultsMerkleRootLow,
            batchResultsMerkleRootHigh,
            scheduledTasksBatchMerkleRootLow,
            scheduledTasksBatchMerkleRootHigh
        );
        console.logBytes32(factHash);
        factsRegistry.markValid(factHash);
        bool is_valid = factsRegistry.isValid(factHash);
        assertEq(is_valid, true);

        // =================================

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
            batchInclusionMerkleProofOfTasks,
            batchInclusionMerkleProofOfResults,
            computationalTasksResult,
            taskCommitments
        );

        // Check if the task state is FINALIZED
        HdpExecutionStore.TaskStatus task1StatusAfter = hdp.getTaskStatus(
            taskCommitment
        );
        assertEq(
            uint(task1StatusAfter),
            uint(HdpExecutionStore.TaskStatus.FINALIZED)
        );

        // Check if the task result is stored
        bytes32 task1Result = hdp.getFinalizedTaskResult(taskCommitment);
        assertEq(task1Result, computationalTasksResult[0]);
    }


    function getFactHash(
        uint256 usedMmrId,
        uint256 usedMmrSize,
        uint128 batchResultsMerkleRootLow,
        uint128 batchResultsMerkleRootHigh,
        uint128 scheduledTasksBatchMerkleRootLow,
        uint128 scheduledTasksBatchMerkleRootHigh
    ) internal view returns (bytes32) {
        // Load MMRs root  
        bytes32 usedMmrRoot = hdp.loadMmrRoot(usedMmrId, usedMmrSize);
        // Initialize an array of uint256 to store the program output
        uint256[] memory programOutput = new uint256[](6);

        // Assign values to the program output array
        programOutput[0] = uint256(usedMmrRoot);
        programOutput[1] = uint256(usedMmrSize);
        programOutput[2] = uint256(batchResultsMerkleRootLow);
        programOutput[3] = uint256(batchResultsMerkleRootHigh);
        programOutput[4] = uint256(scheduledTasksBatchMerkleRootLow);
        programOutput[5] = uint256(scheduledTasksBatchMerkleRootHigh);

        // Compute program output hash
        bytes32 programOutputHash = keccak256(abi.encodePacked(programOutput));

        // Compute GPS fact hash
        bytes32 programHash = 0x001c8cc7762ed906ffd62867aa102adce05db50358a0224524f657ef23d0b7a5;
        bytes32 gpsFactHash = keccak256(
            abi.encode(
                programHash,
                programOutputHash
            )
        );

        return gpsFactHash;
    }
}
