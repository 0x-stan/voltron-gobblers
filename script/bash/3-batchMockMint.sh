# batch mint mock gobblers, 10 gobblers every batch
# we need more than 581 gobblers for mint legendary gobbler
batchCount=2
for (( i=1; i <= $batchCount; ++i ))
do
    echo "\nbatch mint run $i:"
    forge script script/mockmint.s.sol -f $RPC_URL --private-key $DEPLOY_PK -vvv --broadcast --skip-simulation 
done


# # mint legendary gobbler
# gobblersAddress=$(jq .gobblers ./deployment.json -r)
# legendaryPrice=$(cast call $gobblersAddress "legendaryGobblerPrice()" --rpc-url $RPC_URL | cast --to-dec)
# gobblerIds="1"
# for (( i=2; i <= $legendaryPrice; ++i ))
# do
#     gobblerIds+=",${i}"
# done
    
# calldata=$(cast calldata "mintLegendaryGobbler(uint256[])" "[$gobblerIds]")
# cast send $gobblersAddress $calldata --rpc-url $RPC_URL --private-key $DEPLOY_PK
