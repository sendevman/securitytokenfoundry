## Deployment

### HOW TO DEPLOY

1. Add env variables

For `testnet` (mumbai):

```
export ADDRESS=""
export PRIVKEY=""
export RPC_ENDPOINT="https://polygon-mumbai.g.alchemy.com/v2/MCCIWqimX9O297XjAulHt4gfn8WMWY9l"
export CHAIN_ID=80001
```

For `anvil`:

```
export ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
export PRIVKEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
export RPC_ENDPOINT="http://192.168.100.12:8545"
export CHAIN_ID=31337
```

```

2. Deploy

```
forge script script/Deployer.s.sol:Deploy --sig "run(uint256,address)" $PRIVKEY $ADDRESS --rpc-url $RPC_ENDPOINT --broadcast
```

If you get the error `replacement transaction underpriced`, add the flag `--with-gas-price` and increase the gas price to e.g. 4000000000 (4 gwei).

