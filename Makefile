-include .env

deploy-sepolia :; forge script scripts/Deploy.s.sol:DeployMidcurve --rpc-url ${BASE_SEPOLIA_RPC} --broadcast --verify -vvvv

read-sepolia :; forge script scripts/Interact.s.sol:ReadScript --rpc-url ${BASE_SEPOLIA_RPC} --broadcast -vvvv

begin-game-sepolia :; forge script scripts/Interact.s.sol:BeginGame --rpc-url ${BASE_SEPOLIA_RPC} --broadcast -vvvv

deploy-begin-90-sepolia :; forge script scripts/Deploy.s.sol:DeployMidcurveTestAndBegin --rpc-url ${BASE_SEPOLIA_RPC} --broadcast --verify -vvvv

test-gas :; forge test -vvv --gas-report