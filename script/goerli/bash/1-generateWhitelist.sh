whitelistNum=20

# generate whitelist wallets address, save at whitelist.txt
PK=$DEPLOY_PK
whitelistData=""
for (( i=0; i < $whitelistNum; ++i ))
do
    newWallet=$(cast wallet address $PK)
    newWallet=${newWallet:9:51}
    echo "new whitelist wallet = $newWallet;"
    
    whitelistData="$whitelistData$newWallet\n"

    PK=$(cast keccak $PK)
done

echo $whitelistData > whitelist.txt

# generate merkle proof of whitelist addresses
forge script script/goerli/utils/GenerateMerkle.sol

