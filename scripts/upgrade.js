require("dotenv").config();
const fs = require('fs')
const { ethers, network, upgrades } = require("hardhat");
const SuperfluidSDK = require("@superfluid-finance/js-sdk");


const ADDRESSES_FILE = './addresses.json';

NewAppContractName = "SuperAppV1";
NewSfMinionContractName = "";

const main = async () => {

    const json = fs.readFileSync(ADDRESSES_FILE);
    const addresses = JSON.parse(json);
    if (addresses[network.name]) {
        console.log(`Upgrading contracts on ${network.name}...`);
        

        if (NewAppContractName) {
            console.log('Superfluid SDK Init...');
            const sfVersion = process.env.SF_VERSION || "v1";

            const sf = new SuperfluidSDK.Framework({
                version: sfVersion,
                ethers: ethers.provider,
            });
            await sf.initialize();

            const appProxyAddress = addresses[network.name].AppProxy;
            console.log(`Upgrading App to ${NewAppContractName} with Proxy ${appProxyAddress}`);
            const App = await ethers.getContractFactory(NewAppContractName);
            await upgrades.upgradeProxy(appProxyAddress, App);
            console.log('Upgrade Done!');
        }
        if (NewSfMinionContractName) {
            
            const minionProxyAddress = addresses[network.name].SuperfluidMinionTemplateProxy;
            console.log(`Upgrading App to ${NewSfMinionContractName} with Proxy ${minionProxyAddress}`);
            const SFMinionTemplate = await ethers.getContractFactory(NewSfMinionContractName);
            await upgrades.upgradeProxy(minionProxyAddress, SFMinionTemplate);
            console.log('Upgrade Done!');
        }

        console.log('Done');

    } else {
        throw new Error(`No existing contracts for network ${network.name}`);
    }
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });