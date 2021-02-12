const SuperApp = artifacts.require("SuperApp");
const Factory = artifacts.require("SuperfluidMinionFactory");
const MinionTemplate = artifacts.require("SuperfluidMinion");

module.exports = async (deployer, network) => {
  const superApp = await SuperApp.deployed();
  const factory = await Factory.deployed();
  const template = await MinionTemplate.deployed();
  console.log('SuperApp at', superApp.address)
  console.log('Factory at', factory.address)
  console.log('Template match?', template.address, await factory.template());

  if (network.startsWith('rinkeby')) {
    const molochAddress = "0xf0a9bf0a1f19f1b2dd4a0883f24845ebae06bbb0";
    const details = "streamr minion1";
    await factory.summonMinion(molochAddress, superApp.address, details);
    const events = await factory.getPastEvents('SummonMinion', { filter: { 'moloch': molochAddress } });
    console.log('New Minion', events)
  }
};
