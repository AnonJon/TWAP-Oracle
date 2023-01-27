// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {UniswapV2OracleLibrary} from "@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol";
import {FixedPoint} from "@uniswap/lib/contracts/libraries/FixedPoint.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
import {IUniswapV2TWAPOracle} from "./interfaces/IUniswapV2TWAPOracle.sol";

contract UniswapV2TWAPOracle is
    IUniswapV2TWAPOracle,
    AutomationCompatibleInterface,
    OwnableUpgradeable,
    PausableUpgradeable
{
    using EnumerableSet for EnumerableSet.UintSet;
    using FixedPoint for *;

    string public version = "v0.0.1";

    IUniswapV2Factory public uniswapFactory;
    /// @notice jobID => Observation[]
    mapping(uint256 => Observation[]) observations;
    /// @notice jobID => Pair
    mapping(uint256 => Pair) pairs;
    mapping(uint256 => Job) private jobs;
    EnumerableSet.UintSet private activeJobIDs;
    uint256 private nextJobID = 1;
    address public keeperRegistryAddress;

    struct Pair {
        IUniswapV2Pair pairAddress;
        address token0;
        address token1;
    }

    struct Observation {
        uint256 price0Cumulative;
        uint256 price1Cumulative;
        uint256 timestamp;
    }

    /**
     * Modifiers ***********************************************
     */

    modifier onlyKeeperRegistry() {
        if (msg.sender != keeperRegistryAddress) {
            revert OnlyKeeperRegistry();
        }
        _;
    }

    /**
     * @notice Initialize a UniswapV2TWAPAutomation contract
     * @param factory The UniswapV2Factory address
     * @param keeperAddress The address of the KeeperRegistry contract
     */
    function initialize(address factory, address keeperAddress) public initializer {
        if (factory == address(0)) {
            revert ZeroAddress();
        }
        __Ownable_init();
        __Pausable_init();
        setKeeperRegistryAddress(keeperAddress);
        uniswapFactory = IUniswapV2Factory(factory);
    }

    /**
     * Admin ***********************************************************************
     */
    /**
     * @notice Create a new job
     * @param token0 The first token in the pair
     * @param token1 The second token in the pair
     * @param periodSize The period time for automation in seconds
     * @param granularity The number of observations to store
     * @dev granularity must be greater than 1
     */
    function createJob(address token0, address token1, uint256 periodSize, uint256 granularity) external onlyOwner {
        if (token0 == address(0) || token1 == address(0) || granularity <= 1) {
            revert BadJobSpec();
        }

        uint256 jobID = nextJobID;
        nextJobID++;
        activeJobIDs.add(jobID);

        _setJob(jobID, token0, token1, periodSize, granularity);

        emit JobCreated(jobID);
    }

    /**
     * @notice Update a job
     * @param jobID The ID of the job to update
     * @param periodSize The new period size
     */
    function updateJob(uint256 jobID, uint256 periodSize, uint256 granularity) external onlyOwner {
        if (!activeJobIDs.contains(jobID)) {
            revert JobIDNotFound(jobID);
        }
        if (granularity > 1) {
            jobs[jobID].granularity = granularity;
        }
        if (periodSize > 0) {
            jobs[jobID].periodSize = periodSize;
        }

        emit JobUpdated(jobID);
    }

    /**
     * @notice Deletes the job matching the provided id. Reverts if
     * the id is not found.
     * @param jobID the id of the job to delete
     */
    function deleteJob(uint256 jobID) external onlyOwner {
        if (!activeJobIDs.contains(jobID)) {
            revert JobIDNotFound(jobID);
        }
        delete jobs[jobID];
        activeJobIDs.remove(jobID);
        emit JobDeleted(jobID);
    }

    /**
     * @notice Sets the keeper registry address.
     * @param keeperAddress The address of the keeper registry.
     */
    function setKeeperRegistryAddress(address keeperAddress) public onlyOwner {
        require(keeperAddress != address(0));
        emit KeeperRegistryAddressUpdated(keeperRegistryAddress, keeperAddress);
        keeperRegistryAddress = keeperAddress;
    }

    /**
     * @notice Pauses the contract, which prevents executing performUpkeep
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * Automation ***********************************************************************
     */

    /**
     * @notice checks to see if job is ready to be updated
     * @param performData The encoded jobID
     * @dev Multiple upkeeps are needed (1 per pair) to keep gas usage low
     */
    function checkUpkeep(bytes calldata performData)
        external
        view
        override
        whenNotPaused
        returns (bool, bytes memory)
    {
        (uint256 jobID) = abi.decode(performData, (uint256));
        if (!activeJobIDs.contains(jobID)) {
            revert JobIDNotFound(jobID);
        }
        if (jobs[jobID].lastObservationTimestamp + jobs[jobID].granularity > block.timestamp) {
            return (false, bytes(""));
        }
        return (true, performData);
    }

    function performUpkeep(bytes calldata performData) external override onlyKeeperRegistry whenNotPaused {
        (uint256 jobID) = abi.decode(performData, (uint256));

        Job memory job = jobs[jobID];
        if (!activeJobIDs.contains(jobID)) {
            revert JobIDNotFound(jobID);
        } else if (job.lastObservationTimestamp + job.granularity > block.timestamp) {
            revert TooSoonToPerform(jobID);
        }

        (uint256 price0Cumulative, uint256 price1Cumulative,) =
            UniswapV2OracleLibrary.currentCumulativePrices(address(pairs[jobID].pairAddress));
        observations[jobID].push(
            Observation({
                price0Cumulative: price0Cumulative,
                price1Cumulative: price1Cumulative,
                timestamp: block.timestamp
            })
        );

        job.lastObservationTimestamp = block.timestamp;

        emit JobExecuted(jobID, block.timestamp);
    }

    /**
     * External View ******************************************************************
     */

    /**
     * @notice get TWAP price for a given amount of token.
     * @param tokenIn The token to query
     * @param amountIn The amount of tokenIn to query
     * @return amountOut The amount of tokenOut
     */
    function queryPrice(uint256 jobID, address tokenIn, uint256 amountIn, address tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        if (tokenIn == address(0) || tokenOut == address(0)) {
            revert ZeroAddress();
        }
        if (amountIn <= 0) {
            revert InsufficientInputAmount();
        }
        Job memory job = jobs[jobID];
        address pair = uniswapFactory.getPair(pairs[jobID].token0, pairs[jobID].token1);

        Observation memory firstObservation = _getFirstObservationInWindow(job, jobID);

        uint256 timeElapsed = block.timestamp - firstObservation.timestamp;
        require(timeElapsed <= job.periodSize, "SlidingWindowOracle: MISSING_HISTORICAL_OBSERVATION");

        // get current cumalative price
        (uint256 price0Cumulative, uint256 price1Cumulative,) = UniswapV2OracleLibrary.currentCumulativePrices(pair);

        (address token0,) = _sortTokens(tokenIn, tokenOut);
        if (token0 == tokenIn) {
            return _computeAmountOut(firstObservation.price0Cumulative, price0Cumulative, timeElapsed, amountIn);
        } else {
            return _computeAmountOut(firstObservation.price1Cumulative, price1Cumulative, timeElapsed, amountIn);
        }
    }

    /**
     * @notice gets a list of active job IDs
     * @return list of active job IDs
     */
    function getActiveJobIDs() external view returns (uint256[] memory) {
        uint256 length = activeJobIDs.length();
        uint256[] memory jobIDs = new uint256[](length);
        for (uint256 idx = 0; idx < length; idx++) {
            jobIDs[idx] = activeJobIDs.at(idx);
        }
        return jobIDs;
    }

    /**
     * @notice gets the pair address matching the provided id.
     * @param jobID the id of the job to get
     * @return the job matching the provided id
     */
    function getPairByJobID(uint256 jobID) external view returns (address) {
        return address(pairs[jobID].pairAddress);
    }

    function getJobById(uint256 jobID) external view returns (Job memory) {
        return jobs[jobID];
    }

    /**
     * Internal ************************************************************************
     */

    function _setJob(uint256 jobID, address token0, address token1, uint256 periodSize, uint256 granularity) internal {
        if (uniswapFactory.getPair(token0, token1) == address(0)) {
            revert PairNotFound(token0, token1);
        }
        jobs[jobID] = Job({lastObservationTimestamp: block.timestamp, periodSize: periodSize, granularity: granularity});

        pairs[jobID] =
            Pair({pairAddress: IUniswapV2Pair(uniswapFactory.getPair(token0, token1)), token0: token0, token1: token1});
    }

    function _computeAmountOut(uint256 priceStart, uint256 priceEnd, uint256 timeElapsed, uint256 amountIn)
        internal
        pure
        returns (uint256)
    {
        FixedPoint.uq112x112 memory priceAverage = FixedPoint.uq112x112(uint224((priceEnd - priceStart) / timeElapsed));
        return priceAverage.mul(amountIn).decode144();
    }

    function _observationIndexOf(uint256 jobID, uint256 timestamp) internal view returns (uint8) {
        Job memory job = jobs[jobID];
        uint256 epochPeriod = timestamp / job.periodSize;
        return uint8(epochPeriod % job.granularity);
    }

    function _getFirstObservationInWindow(Job memory job, uint256 jobId) internal view returns (Observation storage) {
        uint8 observationIndex = _observationIndexOf(jobId, block.timestamp);
        uint256 firstObservationIndex = (observationIndex + 1) % job.granularity;
        return observations[jobId][firstObservationIndex];
    }

    /**
     * @dev taken from UniswapV2Library
     */
    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "UniswapV2Library: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "UniswapV2Library: ZERO_ADDRESS");
    }
}
