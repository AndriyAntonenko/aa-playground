-include .env


.PHONY: deploy-anvil

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

all: remove build test

# Clean the repo
clean :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install foundry-rs/forge-std --no-commit && forge install openzeppelin/openzeppelin-contracts --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 10 --chain-id 1337

coverage :; forge coverage

coverage-report :; forge coverage --report debug > coverage-report.txt

deploy-anvil :; forge script script/Deploy.s.sol \
	--private-key ${DEFAULT_ANVIL_KEY} \
	--rpc-url http://localhost:8545 \
	--broadcast
