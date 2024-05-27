-include .env

deploy-begin-sepolia :; forge script scripts/testnet/Deploy.s.sol:DeployMidcurveTestAndBegin --rpc-url ${BLAST_SEPOLIA_RPC} --skip-simulation --broadcast --verify -vvvv

test-gas :; forge test -vvv --gas-report

interface :; cast interface ./out/Midcurve.sol/Midcurve.json -o ./contracts/IMidcurve.sol

verify-sepolia :; forge verify-contract --rpc-url ${BLAST_SEPOLIA_RPC} ${BLAST_SEPOLIA_ADDRESS} ./contracts/Midcurve.sol:Midcurve --guess-constructor-args --watch