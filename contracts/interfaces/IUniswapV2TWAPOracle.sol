// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

interface IUniswapV2TWAPOracle {
    struct Job {
        /// @notice Window size over which to average TWAP price
        uint256 periodSize;
        uint256 lastObservationTimestamp;
        /// @notice The number of measurment points inside the window
        uint256 granularity;
    }

    event JobExecuted(uint256 indexed jobID, uint256 timestamp);
    event JobCreated(uint256 indexed jobID);
    event JobUpdated(uint256 indexed jobID);
    event JobDeleted(uint256 indexed jobID);
    event KeeperRegistryAddressUpdated(address oldAddress, address newAddress);

    error TooSoonToPerform(uint256 jobID);
    error JobIDNotFound(uint256 jobID);
    error BadJobSpec();
    error ZeroAddress();
    error OnlyKeeperRegistry();
    error PairNotFound(address token0, address token1);
    error InsufficientInputAmount();

    function queryPrice(uint256 jobID, address tokenIn, uint256 amountIn, address tokenOut)
        external
        view
        returns (uint256 amountOut);

    function createJob(address token0, address token1, uint256 periodSize, uint256 granularity) external;
    function updateJob(uint256 jobID, uint256 periodSize, uint256 granularity) external;
    function deleteJob(uint256 jobID) external;
    function getActiveJobIDs() external view returns (uint256[] memory);
    function getPairByJobID(uint256 jobID) external view returns (address);
    function getJobById(uint256 jobID) external view returns (Job memory);
    function setKeeperRegistryAddress(address keeperAddress) external;
    function pause() external;
    function unpause() external;
    function initialize(address factory, address keeperAddress) external;
}
