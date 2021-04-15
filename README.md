# superfluid-minion

Enabling money streaming on DAOS using Superfluid. This A hackathon project for ETHDenver 2021

## Tech Stack

* Superfluid
* DAOHaus Pokemol UI
* Moloch DAO
* Moloch Minion

## Demo

* [Video](https://youtu.be/KZyFOaqvOiQ)

## Installation instructions

### DAOHaus UI (Pokemol)

* You need to clone and run a custom Pokemol UI from this [repository](https://github.com/santteegt/pokemol-web/tree/ethdenver)

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

* In order to test the Superfluid Minion, you need to connect to Rinkeby, and summon a DAO with [fDAI](https://rinkeby.etherscan.io/address/0x15f0ca26781c3852f8166ed2ebce5d18265cceb7)(0x15F0Ca26781C3852f8166eD2ebce5D18265cceb7) as the DAO token (optional)

### Superfluid Minion

* Smart contracts are already deployed on Rinkeby (see below). But, uou can use this repo if you want to deploy the smart contracts on another chain using `truffle migrate`

## Deployments

### Rinkeby

* SuperApp: [0xcf7ce0023C4dA08c6b8065BB52032bC7951f2D43](https://rinkeby.etherscan.io/address/0xcf7ce0023C4dA08c6b8065BB52032bC7951f2D43) 
* SuperfluidMinionFactory: [0xc4fe30611474Aa737b5B1DBC81aB4Eb9E8959DE1](https://rinkeby.etherscan.io/address/0xc4fe30611474Aa737b5B1DBC81aB4Eb9E8959DE1)
* SuperfluidMinion (Template): [0xf138e3e64dF1e3B01B684d583079E444b8B5A275](https://rinkeby.etherscan.io/address/0xf138e3e64dF1e3B01B684d583079E444b8B5A275)

## Licence

[MIT](LICENSE)
