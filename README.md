# superfluid-minion

A hackathon project for ETHDenver 2021

## Demo

* [Video](https://youtu.be/KZyFOaqvOiQ)

## Installation instructions

### DAOHaus UI (Pokemol)

* You need to clone and run the UI from this [repository](https://github.com/santteegt/pokemol-web/tree/ethdenver)

```
git clone https://github.com/santteegt/pokemol-web -b ethdenver
cd pokemol-web
yarn install
```

* Create an `.env` file with the following:

```
REACT_APP_MAINNET_RPC_URI=https://rinkeby.infura.io/v3/<INFURA_APIKEY>
REACT_APP_PORTIS_ID=
REACT_APP_FORTMATIC_KEY=
REACT_APP_HAUS_KEY=
REACT_APP_INFURA_KEY=<INFURA_APIKEY>
REACT_APP_ETHERSCAN_KEY=<ETHERSCAN_APIKEY>
REACT_APP_RPC_URI=https://rinkeby.infura.io/v3/<INFURA_APIKEY>
```

* Deploy the frontend locally:

```
yarn start
```

* In order to test the Superfluid Minion, you need to connect to Rinkeby, and summon a DAO with [fDAI](https://rinkeby.etherscan.io/address/0x15f0ca26781c3852f8166ed2ebce5d18265cceb7) (0x15F0Ca26781C3852f8166eD2ebce5D18265cceb7) as the DAO token

### Superfluid Minion

* Smart contracts are already deployed on Rinkeby (see below). But, uou can use this repo if you want to deploy the smart contracts on another chain using `truffle migrate`

## Deployments

### Rinkeby

* SuperApp: [0x4d313dfec90f96fF1aabcb2c2dd48406e7Acf9ce](https://rinkeby.etherscan.io/address/0x4d313dfec90f96fF1aabcb2c2dd48406e7Acf9ce) 
* SuperfluidMinionFactory: [0xce14094520008c00EF4CD794Fea98653eAAaDAca](https://rinkeby.etherscan.io/address/0xce14094520008c00EF4CD794Fea98653eAAaDAca)
* SuperfluidMinion: [0xab59BFC8Cac06974e3d953F92A7650a485Dd5A27](https://rinkeby.etherscan.io/address/0xab59BFC8Cac06974e3d953F92A7650a485Dd5A27)

## Licence

[MIT](LICENSE)
