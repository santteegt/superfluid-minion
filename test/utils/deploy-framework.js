const assert = require("assert").strict;
const { ethers } = require("hardhat");
const Transaction = require("ethereumjs-tx").Transaction;
const ethUtils = require("ethereumjs-util");
const ERC1820Registry = require("@superfluid-finance/ethereum-contracts/artifacts/ERC1820Registry.json");

const { builtTruffleContractLoader } = require("./contractUtils");

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

let resetSuperfluidFramework;
let testResolver;

async function deployAndRegisterContractIf(
    Contract_,
    resolverKey,
    cond,
    deployFunc,
    signer,
) {
    let contractDeployed;
    const contractName = Contract_.name;
    const contractAddress = await testResolver.get(resolverKey);
    console.log(`${resolverKey} address`, contractAddress);
    if (resetSuperfluidFramework || (await cond(contractAddress))) {
        console.log(`${contractName} needs new deployment.`);
        contractDeployed = await deployFunc();
        console.log(`${resolverKey} deployed to`, contractDeployed.address);
        await testResolver.set(resolverKey, contractDeployed.address);
    } else {
        console.log(`${contractName} does not need new deployment.`);
        // contractDeployed = await Contract.at(contractAddress);
        contractDeployed = new ethers.Contract(contractAddress, Contract_.abi, signer);
    }
    return contractDeployed;
}

const hasCode = async (provider, address) => {
    const code = await provider.getCode(address);
    return code.length > 3;
};

const deployERC1820 = async (callback, { provider, from } = {}) => {
    try {
        const rawTransaction = {
            nonce: 0,
            gasPrice: 100000000000,
            value: 0,
            data: "0x" + ERC1820Registry.bin,
            gasLimit: 800000,
            v: 27,
            r:
                "0x1820182018201820182018201820182018201820182018201820182018201820",
            s:
                "0x1820182018201820182018201820182018201820182018201820182018201820",
        };
        const tx = new Transaction(rawTransaction);
        const res = {
            sender: ethUtils.toChecksumAddress(
                "0x" + tx.getSenderAddress().toString("hex")
            ),
            rawTx: "0x" + tx.serialize().toString("hex"),
            contractAddr: ethUtils.toChecksumAddress(
                "0x" +
                    ethUtils
                        .generateAddress(
                            tx.getSenderAddress(),
                            ethUtils.toBuffer(0)
                        )
                        .toString("hex")
            ),
        };
        assert.equal("0xa990077c3205cbDf861e17Fa532eeB069cE9fF96", res.sender);
        assert.equal(
            "0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24",
            res.contractAddr
        );

        console.log("Checking ERC1820 deployment at", res.contractAddr);
        if (!(await hasCode(provider, res.contractAddr))) {
            console.log("Deploying...");
            const account = from.address;
            console.log("Step 1: send ETH");
            await from.sendTransaction({
                to: res.sender,
                value: ethers.utils.parseEther("0.1"),
            });
            // await provider.sendTransaction(signedTx);
            // await provider.sendTransaction({
            //     from: account,
            //     to: res.sender,
            //     value: "100000000000000000", //web3.utils.toWei(0.1)
            // });
            console.log("Step 2: send signed transaction");
            // await provider.sendSignedTransaction(res.rawTx);
            await provider.sendTransaction(res.rawTx);
            console.log("Deployment done.");
        } else {
            console.log("ERC1820 is already deployoed.");
        }
        callback();
    } catch (err) {
        callback(err);
    }
}

/**
 * @dev Deploy the superfluid framework
 * @param {Web3} options.ethers  Injected web3 instance
 * @param {Address} options.from Address to deploy contracts from
 * @param {boolean} options.newTestResolver Force to create a new resolver (overridng env: NEW_TEST_RESOLVER)
 * @param {boolean} options.useMocks Use mock contracts instead (overridng env: USE_MOCKS)
 * @param {boolean} options.nonUpgradable Deploy contracts configured to be non-upgradable
 *                  (overridng env: NON_UPGRADABLE)
 * @param {boolean} options.appWhiteListing Deploy contracts configured to require app white listing
 *                  (overridng env: ENABLE_APP_WHITELISTING)
 * @param {boolean} options.resetSuperfluidFramework Reset the superfluid framework deployment
 *                  (overridng env: RESET_SUPERFLUID_FRAMEWORK)
 * @param {boolean} options.protocolReleaseVersion Specify the protocol release version to be used
 *                  (overriding env: RELEASE_VERSION)
 *
 * Usage: npx truffle exec scripts/deploy-framework.js
 */
module.exports = async function (callback, options = {}) {
    try {
        console.log("======== Deploying superfluid framework ========");

        // const provider = options.ethers;
        const provider = ethers.provider;
        // console.log('net', network);

        // await eval(`(${detectTruffleAndConfigure.toString()})(options)`);
        let {
            newTestResolver,
            useMocks,
            nonUpgradable,
            appWhiteListing,
            protocolReleaseVersion,
        } = options;
        resetSuperfluidFramework = options.resetSuperfluidFramework;

        const CFAv1_TYPE = ethers.utils.id(
            "org.superfluid-finance.agreements.ConstantFlowAgreement.v1"
        );

        const IDAv1_TYPE = ethers.utils.id(
            "org.superfluid-finance.agreements.InstantDistributionAgreement.v1"
        );

        protocolReleaseVersion =
            protocolReleaseVersion || process.env.RELEASE_VERSION || "test";
        const chainId = (await provider.getNetwork()).chainId;
        console.log("reset superfluid framework: ", resetSuperfluidFramework);
        console.log("chain ID: ", chainId);
        console.log("protocol release version:", protocolReleaseVersion);

        await deployERC1820(
            (err) => {
                if (err) throw err;
            },
            { provider, ...(options.from ? { from: options.from } : {}) }
        );

        const contracts = [
            "IERC20",
            "TokenInfo",
            "ERC20WithTokenInfo",
            "TestToken",
            "IResolver",
            "ISuperfluid",
            "ISuperToken",
            "ISuperTokenFactory",
            "ISuperAgreement",
            "ISuperfluidGovernance",
            "IConstantFlowAgreementV1",
            "IInstantDistributionAgreementV1",
            "ISETH",
            //
            "TestResolver",
            "Superfluid",
            "SuperTokenFactory",
            "SuperTokenFactoryHelper",
            "TestGovernance",
            "ISuperfluidGovernance",
            "UUPSProxy",
            "UUPSProxiable",
            "ConstantFlowAgreementV1",
            "InstantDistributionAgreementV1",
        ];
        const mockContracts = [
            "SuperfluidMock",
            "SuperTokenFactoryMock",
            "SuperTokenFactoryMockHelper",
        ];

        const {
            TestResolver,
            Superfluid,
            SuperfluidMock,
            SuperTokenFactory,
            SuperTokenFactoryHelper,
            SuperTokenFactoryMock,
            SuperTokenFactoryMockHelper,
            TestGovernance,
            ISuperfluidGovernance,
            UUPSProxy,
            UUPSProxiable,
            ConstantFlowAgreementV1,
            InstantDistributionAgreementV1,
        } = Object.assign(...(contracts.concat(useMocks ? mockContracts : []).map(name => { return {[name]:  builtTruffleContractLoader(name) } } )));

        const ResolverFactory = await ethers.getContractFactory(TestResolver.abi, TestResolver.bytecode, options.from);
        testResolver = await ResolverFactory.deploy();
        // make it available for the sdk for testing purpose
        process.env.TEST_RESOLVER_ADDRESS = testResolver.address;
        console.log("Resolver address", testResolver.address);

        // deploy new governance contract
        let governanceInitializationRequired = false;
        let governance = await deployAndRegisterContractIf(
            TestGovernance,
            `TestGovernance.${protocolReleaseVersion}`,
            // async (contractAddress) =>
            //     await codeChanged(web3, TestGovernance, contractAddress),
            async (contractAddress) => contractAddress == ZERO_ADDRESS,
            async () => {
                governanceInitializationRequired = true;
                // return await web3tx(TestGovernance.new, "TestGovernance.new")();
                const GovernanceFactory = await ethers.getContractFactory(TestGovernance.abi, TestGovernance.bytecode, options.from);
                return await GovernanceFactory.deploy();
            },
            options.from
        );

        // deploy new superfluid host contract
        const SuperfluidLogic = useMocks ? SuperfluidMock : Superfluid;
        let superfluid = await deployAndRegisterContractIf(
            SuperfluidLogic,
            `Superfluid.${protocolReleaseVersion}`,
            async (contractAddress) => contractAddress == ZERO_ADDRESS,
            async () => {
                governanceInitializationRequired = true;
                let superfluidAddress;
                
                const SuperfluidFactory = await ethers.getContractFactory(SuperfluidLogic.abi, SuperfluidLogic.bytecode, options.from);
                const superfluidLogic = await SuperfluidFactory.deploy(!!nonUpgradable, !!appWhiteListing);

                console.log(
                    `Superfluid new code address ${superfluidLogic.address}`
                );
                if (!nonUpgradable) {
                    const ProxyFactory = await ethers.getContractFactory(UUPSProxy.abi, UUPSProxy.bytecode, options.from);
                    const proxy = await ProxyFactory.deploy();

                    await proxy.initializeProxy(superfluidLogic.address);
                    superfluidAddress = proxy.address;
                } else {
                    superfluidAddress = superfluidLogic.address;
                }
                const superfluid = new ethers.Contract(superfluidAddress, SuperfluidLogic.abi, options.from);
                await superfluid.initialize(governance.address);
                // if (!nonUpgradable) {
                //     if (
                //         await codeChanged(
                //             web3,
                //             SuperfluidLogic,
                //             await superfluid.getCodeAddress()
                //         )
                //     ) {
                //         throw new Error(
                //             "Unexpected code change from fresh deployment"
                //         );
                //     }
                // }
                return superfluid;
            },
            options.from
        );

        // initialize the new governance
        if (governanceInitializationRequired) {
            console.log('governanceInitializationRequired?', governanceInitializationRequired);
            await governance.initialize(
                superfluid.address,
                // let rewardAddress the first account
                options.from.address,
                // liquidationPeriod
                3600,
                [])
        }

        // replace with new governance
        // if ((await superfluid.getGovernance.call()) !== governance.address) {
        //     const currentGovernance = await ISuperfluidGovernance.at(
        //         await superfluid.getGovernance.call()
        //     );
        //     await web3tx(
        //         currentGovernance.replaceGovernance,
        //         "governance.replaceGovernance"
        //     )(superfluid.address, governance.address);
        // }

        // list CFA v1
        const deployCFAv1 = async () => {
            const CFAFactory = await ethers.getContractFactory(ConstantFlowAgreementV1.abi, ConstantFlowAgreementV1.bytecode, options.from);
            const agreement = await CFAFactory.deploy();
            console.log(
                "New ConstantFlowAgreementV1 address",
                agreement.address
            );
            return agreement;
        };
        if (!(await superfluid.isAgreementTypeListed(CFAv1_TYPE))) {
            const cfa = await deployCFAv1();
            await governance.registerAgreementClass(superfluid.address, cfa.address);
        }

        // list IDA v1
        const deployIDAv1 = async () => {
            const IDAFactory = await ethers.getContractFactory(InstantDistributionAgreementV1.abi, InstantDistributionAgreementV1.bytecode, options.from);
            const agreement = await IDAFactory.deploy();
            console.log(
                "New InstantDistributionAgreementV1 address",
                agreement.address
            );
            return agreement;
        };
        if (!(await superfluid.isAgreementTypeListed(IDAv1_TYPE))) {
            const ida = await deployIDAv1();
            await governance.registerAgreementClass(superfluid.address, ida.address);
        }

        let superfluidNewLogicAddress = ZERO_ADDRESS;
        const agreementsToUpdate = [];
        // if (!nonUpgradable) {
        //     if (await superfluid.NON_UPGRADABLE_DEPLOYMENT()) {
        //         throw new Error("Superfluid is not upgradable");
        //     }
        //     // deploy new superfluid host logic
        //     superfluidNewLogicAddress = await deployNewLogicContractIfNew(
        //         web3,
        //         SuperfluidLogic,
        //         await superfluid.getCodeAddress(),
        //         async () => {
        //             if (
        //                 !(await isProxiable(UUPSProxiable, superfluid.address))
        //             ) {
        //                 throw new Error("Superfluid is non-upgradable");
        //             }
        //             const superfluidLogic = await web3tx(
        //                 SuperfluidLogic.new,
        //                 "SuperfluidLogic.new"
        //             )(nonUpgradable, appWhiteListing);
        //             return superfluidLogic.address;
        //         }
        //     );

        //     // deploy new CFA logic
        //     const cfaNewLogicAddress = await deployNewLogicContractIfNew(
        //         web3,
        //         ConstantFlowAgreementV1,
        //         await (
        //             await UUPSProxiable.at(
        //                 await superfluid.getAgreementClass.call(CFAv1_TYPE)
        //             )
        //         ).getCodeAddress(),
        //         async () => (await deployCFAv1()).address
        //     );
        //     if (cfaNewLogicAddress !== ZERO_ADDRESS)
        //         agreementsToUpdate.push(cfaNewLogicAddress);

        //     // deploy new IDA logic
        //     const idaNewLogicAddress = await deployNewLogicContractIfNew(
        //         web3,
        //         InstantDistributionAgreementV1,
        //         await (
        //             await UUPSProxiable.at(
        //                 await superfluid.getAgreementClass.call(IDAv1_TYPE)
        //             )
        //         ).getCodeAddress(),
        //         async () => (await deployIDAv1()).address
        //     );
        //     if (idaNewLogicAddress !== ZERO_ADDRESS)
        //         agreementsToUpdate.push(idaNewLogicAddress);
        // }

        // deploy new super token factory logic
        // const SuperTokenFactoryLogic = useMocks
        //     ? SuperTokenFactoryMock
        //     : SuperTokenFactory;
        // const superTokenFactoryNewLogicAddress = await deployNewLogicContractIfNew(
        //     web3,
        //     SuperTokenFactoryLogic,
        //     await superfluid.getSuperTokenFactoryLogic.call(),
        //     async () => {
        //         let superTokenLogic;
        //         if (useMocks) {
        //             const helper = await web3tx(
        //                 SuperTokenFactoryMockHelper.new,
        //                 "SuperTokenFactoryMockHelper.new"
        //             )();
        //             superTokenLogic = await web3tx(
        //                 SuperTokenFactoryMock.new,
        //                 "SuperTokenFactoryMock.new"
        //             )(superfluid.address, helper.address);
        //         } else {
        //             const helper = await web3tx(
        //                 SuperTokenFactoryHelper.new,
        //                 "SuperTokenFactoryHelper.new"
        //             )();
        //             superTokenLogic = await web3tx(
        //                 SuperTokenFactory.new,
        //                 "SuperTokenFactory.new"
        //             )(superfluid.address, helper.address);
        //         }
        //         return superTokenLogic.address;
        //     }
        // );

        let superTokenLogic;
        if (useMocks) {
            const STFactoryHelperMock = await ethers.getContractFactory(SuperTokenFactoryMockHelper.abi, SuperTokenFactoryMockHelper.bytecode, options.from);
            const helper = await STFactoryHelperMock.deploy();
            const STFactoryMock = await ethers.getContractFactory(SuperTokenFactoryMock.abi, SuperTokenFactoryMock.bytecode, options.from);
            superTokenLogic = await STFactoryMock.deploy(superfluid.address, helper.address);
        } else {
            const STFactoryHelper = await ethers.getContractFactory(SuperTokenFactoryHelper.abi, SuperTokenFactoryHelper.bytecode, options.from);
            const helper = await STFactoryHelper.deploy();
            const STFactory = await ethers.getContractFactory(SuperTokenFactory.abi, SuperTokenFactory.bytecode, options.from);
            superTokenLogic = await STFactory.deploy(superfluid.address, helper.address);
        }
        const superTokenFactoryNewLogicAddress = superTokenLogic.address;

        if (
            superfluidNewLogicAddress !== ZERO_ADDRESS ||
            agreementsToUpdate.length > 0 ||
            superTokenFactoryNewLogicAddress !== ZERO_ADDRESS
        ) {
            await governance.updateContracts(
                superfluid.address,
                superfluidNewLogicAddress,
                agreementsToUpdate,
                superTokenFactoryNewLogicAddress
            );
        }

        console.log("======== Superfluid framework deployed ========");

        if (process.env.TEST_RESOLVER_ADDRESS) {
            console.log(
                "=============== TEST ENVIRONMENT RESOLVER ======================"
            );
            console.log(
                `export TEST_RESOLVER_ADDRESS=${process.env.TEST_RESOLVER_ADDRESS}`
            );
        }

        callback();
    } catch (err) {
        callback(err);
    }
};