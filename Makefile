-include .env

deploy-sepolia :; forge script scripts/Deploy.s.sol:DeployMidcurve --rpc-url ${BASE_SEPOLIA_RPC} --broadcast --verify -vvvv

read-sepolia :; forge script scripts/Interact.s.sol:ReadScript --rpc-url ${BASE_SEPOLIA_RPC} --broadcast -vvvv