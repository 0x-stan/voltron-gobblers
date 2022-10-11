# deploy on goerli
forge script script/deploy.s.sol -f $ALCHEMY_URL --private-key $DEVELOP_PK -vvvvv --broadcast

# call requestRandomSeed() require gasleft() >= 206000
# use --gas-estimate-multiplier to give enough gas (8 times)
forge script script/mockmint.s.sol -f $ALCHEMY_URL --private-key $DEVELOP_PK -vvvvv --broadcast -g 800


# batch mint mock gobblers, 10 gobblers every batch
# we need more than 581 gobblers for mint legendary gobbler
max=22
for (( i=1; i <= $max; ++i ))
do
    echo "\nbatch mint run $i:"
    forge script script/mockmint.s.sol -f $ALCHEMY_URL --private-key $DEVELOP_PK -vvvvv --broadcast --skip-simulation 
done

gobblersAddress=$(jq .gobblers ./deployment.json -r)
legendaryPrice=$(cast call $gobblersAddress "legendaryGobblerPrice()" --rpc-url $ALCHEMY_URL | cast --to-dec)
gobblerIds="1"
for (( i=2; i <= $legendaryPrice; ++i ))
do
    gobblerIds+=",${i}"
done
    
calldata=$(cast calldata "mintLegendaryGobbler(uint256[])" "[$gobblerIds]")
cast send $gobblersAddress $calldata --rpc-url $ALCHEMY_URL --private-key $DEVELOP_PK
