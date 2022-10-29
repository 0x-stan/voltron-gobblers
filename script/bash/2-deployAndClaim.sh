whitelistNum=20

# deploy
forge script script/deploy.s.sol -f $RPC_URL --private-key $DEPLOY_PK -vvv --broadcast
sleep 1

# whitelist claim
PK=$DEPLOY_PK
claimgas=800000000000000
for (( i=0; i < $whitelistNum; ++i ))
do
    newWallet=$(cast wallet address $PK)
    newWallet=${newWallet:9:51}
    echo "addrs[$i] = $newWallet;"
    
    balance=$(cast balance $newWallet --rpc-url $RPC_URL)
    if test $balance -lt $claimgas
    then
        echo "transfer ether to $newWallet"
        cast send $newWallet --value $claimgas --rpc-url $RPC_URL --private-key $DEPLOY_PK
        sleep 1
    fi

    forge script script/WhitelistClaim.s.sol -f $RPC_URL --private-key $PK -vvv --broadcast

    PK=$(cast keccak $PK)
    # echo "\nfrom new wallet $newWallet"
    sleep 1

done
