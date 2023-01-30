-include .env

install:
	forge install Openzeppelin/openzeppelin-contracts Openzeppelin/openzeppelin-contracts-upgradeable \
	foundry-rs/forge-std smartcontractkit/chainlink uniswap/v2-core=Uniswap/v2-core uniswap/v2-periphery=Uniswap/v2-periphery uniswap/lib=Uniswap/solidity-lib

run-node:
	anvil --fork-url ${MAINNET_RPC_URL}

script-factory-local:
	forge script script/UniswapV2TWAPFactory.s.sol:UniswapV2TWAPFactoryScript \
	--fork-url http://localhost:8545 --verifier-url http://localhost:3000/api/verify --etherscan-api-key linkpool \
	--broadcast --verify -vvvv

clean:
	remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"