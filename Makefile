-include .env

install:
	forge install Openzeppelin/openzeppelin-contracts Openzeppelin/openzeppelin-contracts-upgradeable \
	foundry-rs/forge-std smartcontractkit/chainlink Uniswap/v2-core Uniswap/v2-periphery

script-local:
	forge script script/GovernanceAutomator.s.sol:GovernanceAutomatorScript \
	--fork-url http://localhost:8545 --verifier-url http://localhost:3000/api/verify --etherscan-api-key blacksmith \
	--broadcast --verify -vvvv