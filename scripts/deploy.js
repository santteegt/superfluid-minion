require("dotenv").config();
const fs = require('fs')
const { ethers, network, upgrades } = require("hardhat");
const SuperfluidSDK = require("@superfluid-finance/js-sdk");


const ADDRESSES_FILE = './addresses.json';

const main = async () => {

    // let molochAddress;
    // if (network.name === 'rinkeby') {
    //     molochAddress = '0xf0a9bf0a1f19f1b2dd4a0883f24845ebae06bbb0';

    // } else {
    //     throw Error(`Network not yet supported! (${network.name})`);
    // }

    // console.log('Accounts', await ethers.getSigners());
    
    console.log(`Deploying on ${network.name}`);
    console.log('Superfluid SDK Init...');

    const sfVersion = process.env.SF_VERSION || "v1";

    const sf = new SuperfluidSDK.Framework({
        version: sfVersion,
        ethers: ethers.provider,
        // tokens: ["fDAI"]
    });
    await sf.initialize();

    console.log('Superfluid Config', sf.host.address, sf.agreements.cfa.address, sf.resolver.address);

    const App = await ethers.getContractFactory("App");
    const app = await upgrades.deployProxy(
        App,
        [sf.host.address, sf.agreements.cfa.address, sf.resolver.address, sfVersion],
        {
            kind: 'uups',
        });
    await app.deployed();
    console.log("App deployed to:", app.address);

    const SFMinionTemplate = await ethers.getContractFactory("SuperfluidMinion");
    const sfMinionTemplate = await upgrades.deployProxy(
        SFMinionTemplate, 
        [], 
        {
            kind: 'uups',
        });
    await sfMinionTemplate.deployed();
    console.log("SuperfluidMinion template deployed to:", sfMinionTemplate.address);

    const SFMinionFactory = await ethers.getContractFactory("SuperfluidMinionFactory");
    const sfMinionFactory = await SFMinionFactory.deploy(sfMinionTemplate.address);
    console.log("SuperfluidMinionFactory deployed to", sfMinionFactory.address);

    console.log('Finishing deployment...');
    const json = fs.readFileSync(ADDRESSES_FILE);
    const addresses = JSON.parse(json);
    addresses[network.name] = {
        AppProxy: app.address,
        SuperfluidMinionTemplateProxy: sfMinionTemplate.address,
        SuperfluidMinionFactory: sfMinionFactory.address,
    }
    fs.writeFileSync(ADDRESSES_FILE, JSON.stringify(addresses, null, 4));
    
    console.log(`Deployed contract addresses can be found at ${ADDRESSES_FILE}.\nDone!`);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });