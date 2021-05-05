const { ethers } = require("hardhat");
const SuperfluidSDK = require("@superfluid-finance/js-sdk");

const { builtTruffleContractLoader } = require("./contractUtils");

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

function parseColonArgs(argv) {
    const argIndex = argv.indexOf(":");
    if (argIndex < 0) {
        throw new Error("No colon arguments provided");
    }
    const args = argv.slice(argIndex + 1);
    console.log("Colon arguments", args);
    return args;
}

/**
 * @dev Deploy test token (Mintable ERC20) to the network.
 * @param {Array} argv Overriding command line arguments
 * @param {boolean} options.isTruffle Whether the script is used within native truffle framework
 * @param {Web3} options.web3  Injected web3 instance
 * @param {Address} options.from Address to deploy contracts from
 * @param {boolean} options.resetToken Reset the token deployment
 *
 * Usage: npx truffle exec scripts/deploy-test-token.js : {TOKEN_NAME}
 */
module.exports = async function (callback, argv, options = {}) {
    try {
        console.log("======== Deploying test token ========");

        // await eval(`(${detectTruffleAndConfigure.toString()})(options)`);
        let { resetToken } = options;

        const provider = ethers.provider;

        const args = parseColonArgs(argv || process.argv);
        if (args.length !== 1) {
            throw new Error("Not enough arguments");
        }
        const tokenName = args.pop();
        console.log("Token name", tokenName);

        resetToken = resetToken || !!process.env.RESET_TOKEN;
        // const chainId = await web3.eth.net.getId(); // TODO use eth.getChainId;
        const chainId = (await provider.getNetwork()).chainId;
        // const config = getConfig(chainId);
        const config = SuperfluidSDK.getConfig(chainId);
        console.log("reset token: ", resetToken);
        console.log("chain ID: ", chainId);
        console.log('config', config);

        const contracts = [
            "TestResolver",
            "TestToken",
        ];
        const {
            TestResolver,
            TestToken,
        } = Object.assign(...(contracts.map(name => { return {[name]:  builtTruffleContractLoader(name) } } )));

        const testResolver = new ethers.Contract(config.resolverAddress, TestResolver.abi, options.from);
        console.log("Resolver address", testResolver.address);

        // deploy test token and its super token
        const name = `tokens.${tokenName}`;
        let testTokenAddress = await testResolver.get(name);
        if (
            resetToken || testTokenAddress === ZERO_ADDRESS
        ) {
            console.log('no token found');
            const TokenFactory = await ethers.getContractFactory(TestToken.abi, TestToken.bytecode, options.from);
            const testToken = await TokenFactory.deploy(tokenName + " Fake Token", tokenName, 18);
            testTokenAddress = testToken.address;
            testResolver.set(name, testTokenAddress);
        } else {
            console.log("Token already deployed");
        }
        console.log(`Token ${tokenName} address`, testTokenAddress);

        console.log("======== Test token deployed ========");
        callback();
    } catch (err) {
        callback(err);
    }
};
