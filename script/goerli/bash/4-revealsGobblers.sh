# call requestRandomSeed() require gasleft() >= 206000
# use --gas-estimate-multiplier to give enough gas (8 times)
forge script script/goerli/RevealsGobblers.s.sol --rpc-url $RPC_URL --private-key $DEPLOY_PK -vvv --broadcast -g 800