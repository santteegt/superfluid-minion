require("dotenv").config();
const fs = require('fs');
const { ethers, network, upgrades } = require("hardhat");
const SuperfluidSDK = require("@superfluid-finance/js-sdk");


const ADDRESSES_FILE = './addresses.json';

const main = async () => {
    
    console.log(`Deploying on ${network.name}`);
    console.log('Superfluid SDK Init...');

    const sfVersion = process.env.SF_VERSION || "v1";

    const sf = new SuperfluidSDK.Framework({
        version: sfVersion,
        ethers: ethers.provider,
    });
    await sf.initialize();

    console.log('Superfluid Config', sf.host.address, sf.agreements.cfa.address, sf.resolver.address);

    const App = await ethers.getContractFactory("App");
    const app = await App.deploy(sf.host.address, sf.agreements.cfa.address, sf.resolver.address, sfVersion);
    console.log("App deployed to:", app.address);

    const SuperfluidMinion = await ethers.getContractFactory("SuperfluidMinion");
    const sfMinionTemplate = await SuperfluidMinion.deploy();
    console.log("SuperfluidMinion template deployed to:", sfMinionTemplate.address);

    const SFMinionFactory = await ethers.getContractFactory("SuperfluidMinionFactory");
    const sfMinionFactory = await SFMinionFactory.deploy(sfMinionTemplate.address);
    console.log("SuperfluidMinionFactory deployed to", sfMinionFactory.address);

    console.log('Finishing deployment...');
    const json = fs.readFileSync(ADDRESSES_FILE);
    const addresses = JSON.parse(json);
    addresses[network.name] = {
        App: app.address,
        SuperfluidMinionTemplate: sfMinionTemplate.address,
        SuperfluidMinionFactory: sfMinionFactory.address,
    };
    fs.writeFileSync(ADDRESSES_FILE, JSON.stringify(addresses, null, 4));
    
    console.log(`Deployed contract addresses can be found at ${ADDRESSES_FILE}.\nDone!`);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });