# Fork mainnet transfer gobblers from whale
for _id in {1..100}
do
    whale=$(cast call $(jq .gobblers "./deployment.mainnet.json" -r) "ownerOf(uint256)(address)" $_id)
    cast rpc anvil_setBalance $whale 10000000000000000000
    cast rpc anvil_impersonateAccount $whale
    cast send $(jq .gobblers "./deployment.mainnet.json" -r) "transferFrom(address,address,uint256)" \
              $whale $DEPLOY_WALLET $_id --from $whale
    cast rpc anvil_stopImpersonatingAccount $whale
	echo "\nid $_id  whale $whale \n"
done    
