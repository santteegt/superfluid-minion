const SuperApp = artifacts.require("SuperApp"); 
const Factory = artifacts.require("SuperfluidMinionFactory");
const MinionTemplate = artifacts.require("SuperfluidMinion");

module.exports = async (deployer, network) => {
  if (network.startsWith('rinkeby')) {
    const sfHostAddress = "0xeD5B5b32110c3Ded02a07c8b8e97513FAfb883B6";
    const sfCFAAddress = "0xF4C5310E51F6079F601a5fb7120bC72a70b96e2A";
    const sfResolver = "0x659635Fab0A0cef1293f7eb3c7934542B6A6B31A";
    const sfVersion = "v1";
    await deployer.deploy(SuperApp, sfHostAddress, sfCFAAddress, sfResolver, sfVersion);
    await deployer.deploy(MinionTemplate);
    console.log('Template', MinionTemplate.address);
    await deployer.deploy(Factory, MinionTemplate.address);
  }
};
