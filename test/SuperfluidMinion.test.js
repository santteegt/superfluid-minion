const { expect } = require("chai");
const { ethers, network } = require("hardhat"); // explicit, however already available in the global scope
const deployFramework = require("./utils/deploy-framework");
const deployTestToken = require("./utils/deploy-test-token");
const deploySuperToken = require("./utils/deploy-super-token");
const SuperfluidSDK = require("@superfluid-finance/js-sdk");

const MolochABI = require("../artifacts/contracts/mocks/MolochMock.sol/Moloch.json").abi;
const SFMinionABI = require("../artifacts/contracts/minion/SuperfluidMinion.sol/SuperfluidMinion.json").abi;

const timeTravel = async (time) => {
    
    const startBlock = await ethers.provider.getBlock(await ethers.provider.getBlockNumber());
    await network.provider.send("evm_increaseTime", [time]);
    await network.provider.send("evm_mine");
    const endBlock = await ethers.provider.getBlock(await ethers.provider.getBlockNumber());

    console.log(`Time Travelled ${time} (sec) => FROM ${startBlock.timestamp} TO ${endBlock.timestamp}`);
};

const DAO_PERIOD_DURATION = "60";
const DAO_VOTING_PERIOD_LENGTH = "1";
const DAO_GRACE_PERIOD_LENGTH = "1";
const DAO_PROPOSAL_DEPOSIT = ethers.utils.parseEther("1");
const DAO_GUILD = ethers.utils.getAddress("0x000000000000000000000000000000000000dead");
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

describe("SuperfluidMinion", () => {
    console.log('enter');

    const errorHandler = err => {
        if (err) throw err;
    };

    const sfVersion = process.env.SF_VERSION || "test";
    const tokenSymbol = "fDAI";

    let admin;
    let alice;
    let bob;
    let sf;
    let dai;
    let daix;
    let molochSummoner;
    let minionFactory;
    let dao;
    let app;
    let sfMinion;
    let proposalId;

    before(async function() {
        [admin, alice, bob] = await ethers.getSigners();

        console.log('=====Deploying SF Protocol=====');

        await deployFramework(errorHandler, {
            ethers: ethers.provider,
            network: network,
            from: admin
        });

        await deployTestToken(errorHandler, [":", tokenSymbol], {
            from: admin
        });
        await deploySuperToken(errorHandler, [":", tokenSymbol], {
            from: admin
        });

        sf = new SuperfluidSDK.Framework({
            ethers: ethers.provider,
            version: sfVersion,
            // tokens: ["fDAI"],
        });
        await sf.initialize();

        const {
            ISuperToken,
            TestToken,
        } = sf.contracts;

        const daiAddress = await sf.resolver.get(`tokens.${tokenSymbol}`);
        const daixAddress = await sf.resolver.get(`supertokens.${sfVersion}.${tokenSymbol}x`);

        dai = await TestToken.at(daiAddress);
        daix = await ISuperToken.at(daixAddress);

        console.log('===============================');

        console.log('=====Deploying Proxy Factories=====');

        const MolochTemplate = await ethers.getContractFactory("Moloch");
        const molochTemplate = await MolochTemplate.deploy();
        console.log('Moloch template', molochTemplate.address);

        const MolochSummoner = await ethers.getContractFactory("MolochSummoner");
        molochSummoner = await MolochSummoner.deploy(molochTemplate.address);
        console.log('molochSummoner', molochSummoner.address);

        const SFMinionTemplate = await ethers.getContractFactory("SuperfluidMinion");
        const minionTemplate = await SFMinionTemplate.deploy();
        console.log('SFMinion template', minionTemplate.address);

        const SFMinionFactory = await ethers.getContractFactory("SuperfluidMinionFactory");
        minionFactory = await SFMinionFactory.deploy(minionTemplate.address);
        console.log('minionFactory', molochSummoner.address);

        console.log('===================================');

        console.log('=====Summoning a DAO=====');

        const daoAddress = await molochSummoner
            .connect(alice).callStatic['summonMoloch(address[],address[],uint256,uint256,uint256,uint256,uint256,uint256,uint256[])'](
                [alice.address], //_summoner
                [dai.address], //_approvedTokens
                DAO_PERIOD_DURATION,
                DAO_VOTING_PERIOD_LENGTH,
                DAO_GRACE_PERIOD_LENGTH,
                ethers.utils.parseEther("1"), //_proposalDeposit
                "3", //_dilutionBound
                ethers.utils.parseEther("1"), //_processingReward
                ["10"], //_summonerShares
        );
        console.log('daoAddress', daoAddress);

        await molochSummoner.connect(alice).summonMoloch(
            [alice.address], //_summoner
            [dai.address], //_approvedTokens
            DAO_PERIOD_DURATION,
            DAO_VOTING_PERIOD_LENGTH,
            DAO_GRACE_PERIOD_LENGTH,
            DAO_PROPOSAL_DEPOSIT, //_proposalDeposit
            "3", //_dilutionBound
            ethers.utils.parseEther("1"), //_processingReward
            ["10"], //_summonerShares
        );

        await molochSummoner.connect(alice).registerDao(
            daoAddress,
            "Superfluid DAO",
            "https://superfluid.finance",
            "2"
        );

        dao = new ethers.Contract(daoAddress, MolochABI, alice);
        
        console.log('=========================');

        console.log('=====Summoning a SFMinon=====');

        const App = await ethers.getContractFactory("App");
        app = await App.deploy(
            sf.host.address,
            sf.agreements.cfa.address,
            sf.resolver.address,
            sf.version
        );
        console.log('App', app.address);

        const sfMinionAddress = await minionFactory.connect(alice).callStatic['summonMinion(address,address,string)'](
            dao.address,
            app.address,
            "CFA Minion"
        )
        console.log('sfMinionAddress', sfMinionAddress);

        await minionFactory.connect(alice).summonMinion(
            dao.address,
            app.address,
            "CFA Minion"
        );

        sfMinion = new ethers.Contract(sfMinionAddress, SFMinionABI, alice);

        console.log('=============================');

    });

    async function printRealtimeBalance(label, account) {
        const b = await daix.realtimeBalanceOfNow(account);
        console.log(
            `${label} realtime balance`,
            ethers.utils.formatEther(b.availableBalance.toString()),
            ethers.utils.formatEther(b.deposit.toString()),
            ethers.utils.formatEther(b.owedDeposit.toString())
        );
        return b;
    }

    beforeEach(async () => {
        console.log('beforeEach');

    });

    it("Should collect initial token funds", async () => {
        const deposit = ethers.utils.parseEther("100");
        console.log('=====Initial Balances=====');
        await dai.mint(dao.address, deposit);
        await dai.mint(alice.address, deposit);
        console.log('DAO balance', ethers.utils.formatEther((await dai.balanceOf(dao.address))));
        console.log('Alice balance', ethers.utils.formatEther((await dai.balanceOf(dao.address))));
        console.log('==========================');
        await dao.connect(alice).collectTokens(dai.address);
        expect((await dao.userTokenBalances(DAO_GUILD, dai.address)).toString()).to.equal(deposit);
    });

    it("Should create a CFA Proposal", async () => {
        proposalId = await sfMinion.connect(alice).callStatic['proposeAction(address,address,uint256,uint256,bytes,string)'](
            bob.address, //_to
            dai.address, //_token
            "3858024691358", //_rate 10 / month
            ethers.utils.parseEther("10"), //_minDeposit
            "0x",
            "A stream"
        );

        await sfMinion.connect(alice).proposeAction(
            bob.address, //_to
            dai.address, //_token
            "3858024691358", //_rate 10 / month
            ethers.utils.parseEther("10"), //_minDeposit
            "0x",
            "A stream"
        );

        console.log('Current Stream proposal:', proposalId.toString());

        const proposal = await dao.proposals(proposalId);
        expect(proposal.applicant).to.be.equal(sfMinion.address);
        expect(proposal.proposer).to.be.equal(sfMinion.address);
        expect(proposal.sponsor).to.be.equal(ZERO_ADDRESS);

    });

    it("Should sponsor a CFA Proposal and wait for voting", async () => {

        await dai.connect(alice).approve(dao.address, DAO_PROPOSAL_DEPOSIT);
        expect((await dai.allowance(alice.address, dao.address)).toString()).to.be.equal(DAO_PROPOSAL_DEPOSIT);

        await dao.connect(alice).sponsorProposal(proposalId);
        const proposal = await dao.proposals(proposalId);
        expect(proposal.sponsor).to.be.equal(alice.address);

        await timeTravel(+DAO_PERIOD_DURATION);
    });

    it("Should be able to vote on the CFA Proposal", async () => {

        await dao.connect(alice).submitVote(proposalId, "1");

        const proposal = await dao.proposals(proposalId);
        expect(+(proposal.yesVotes.toString())).to.greaterThan(0);

        await timeTravel(+DAO_PERIOD_DURATION * +DAO_VOTING_PERIOD_LENGTH);
    });

    it("Should be able to process the CFA Proposal", async () => {

        await timeTravel(+DAO_PERIOD_DURATION * +DAO_GRACE_PERIOD_LENGTH);

        const bobBalance = await printRealtimeBalance("Bob", bob.address);
        expect(+bobBalance.availableBalance.toString()).to.equal(0);
        
        const balanceBefore = await dao.userTokenBalances(sfMinion.address, dai.address);
        await dao.connect(alice).processProposal(proposalId);
        const balanceAfter = await dao.userTokenBalances(sfMinion.address, dai.address);
        expect(+balanceAfter.toString()).to.greaterThan(+balanceBefore.toString());

        const flags = await dao.getProposalFlags(proposalId);
        expect(flags[2]).to.equal(true); // proposal passed

    });

    it("Should be able to start the Stream", async () => {

        await sfMinion.executeAction(proposalId);

        expect(+(await dai.balanceOf(sfMinion.address)).toString()).to.equal(0);

        const superTokenBalance = await daix.balanceOf(sfMinion.address);
        console.log('DAO SuperToken Balance', ethers.utils.formatEther(superTokenBalance.toString()));
        expect(+superTokenBalance.toString()).to.lessThan(+ethers.utils.parseEther("100"));

        const flow = await sf.agreements.cfa.getFlow(daix.address, sfMinion.address, bob.address);
        expect(flow.deposit.add(superTokenBalance).toString()).to.equal(ethers.utils.parseEther("10").toString());
        
    });

    let lastBobStreamBalance;

    it("Should time travel and start collecting streaming funds", async () => {

        await timeTravel(3600);

        const minionBalance = await printRealtimeBalance("Minion", sfMinion.address);
        console.log('Minion balance', ethers.utils.formatEther(minionBalance.availableBalance.toString()));

        const bobBalance = await printRealtimeBalance("Bob", bob.address);
        expect(+bobBalance.availableBalance.toString()).to.greaterThan(0);
        lastBobStreamBalance = bobBalance;
    });

    it("Should time travel and start running out of funds", async () => {

        await timeTravel((3600 * 24 * 30) - 3600);
        const minionBalance = await printRealtimeBalance("Minion", sfMinion.address);
        console.log('Minion balance', ethers.utils.formatEther(minionBalance.availableBalance.toString()));
        expect(+minionBalance.availableBalance.toString()).to.lessThan(0); // should have a debt of 1 hour deposit

        const bobBalance = await printRealtimeBalance("Bob", bob.address);
        expect(+bobBalance.availableBalance.toString()).to.greaterThan(+lastBobStreamBalance.availableBalance.toString());
        lastBobStreamBalance = bobBalance;
    });

    it("Should be able to upgrade more underlying token to continue the stream", async () => {

        const deposit = ethers.utils.parseEther("10");
        await dai.mint(sfMinion.address, deposit);

        await sfMinion.upgradeToken(dai.address, deposit.toString());

        const minionBalance = await printRealtimeBalance("Minion", sfMinion.address);
        console.log('Minion balance', ethers.utils.formatEther(minionBalance.availableBalance.toString()));
        expect(+minionBalance.availableBalance.toString()).to.greaterThan(0); // should have a debt of 1 hour deposit

    });

    it("Should time travel and start running out of funds AGAIN", async () => {

        await timeTravel((3600 * 24 * 30) - 3600);
        const minionBalance = await printRealtimeBalance("Minion", sfMinion.address);
        console.log('Minion balance', ethers.utils.formatEther(minionBalance.availableBalance.toString()));
        expect(+minionBalance.availableBalance.toString()).to.lessThan(0); // should have a debt of 1 hour deposit

        const bobBalance = await printRealtimeBalance("Bob", bob.address);
        expect(+bobBalance.availableBalance.toString()).to.greaterThan(+lastBobStreamBalance.availableBalance.toString());
        lastBobStreamBalance = bobBalance;
    });

    it("Should be able to to continue the stream by sending superTokens direcly", async () => {

        const deposit = ethers.utils.parseEther("10");
        await dai.connect(alice).approve(daix.address, deposit);
        await daix.connect(alice).upgrade(deposit);
        await daix.connect(alice).transfer(sfMinion.address, deposit);
        const minionBalance = await printRealtimeBalance("Minion", sfMinion.address);
        console.log('Minion balance', ethers.utils.formatEther(minionBalance.availableBalance.toString()));
        expect(+minionBalance.availableBalance.toString()).to.greaterThan(0); // should have a debt of 1 hour deposit

    });

    it("Should time travel 20 days", async () => {

        await timeTravel((3600 * 24 * 20));
        const minionBalance = await printRealtimeBalance("Minion", sfMinion.address);
        console.log('Minion balance', ethers.utils.formatEther(minionBalance.availableBalance.toString()));
        expect(+minionBalance.availableBalance.toString()).to.greaterThan(0); // should have a debt of 1 hour deposit

        const bobBalance = await printRealtimeBalance("Bob", bob.address);
        expect(+bobBalance.availableBalance.toString()).to.greaterThan(+lastBobStreamBalance.availableBalance.toString());
        lastBobStreamBalance = bobBalance;
    });

    it("Should be able to cancel the strem", async () => {
        await sfMinion.cancelStream(proposalId);
        const flow = await sf.agreements.cfa.getFlow(daix.address, sfMinion.address, bob.address);

        expect(flow.flowRate.toString()).to.equal("0");

    });

    it("Should be able to withdraw the remaining balance", async () => {

        const minionBalanceBefore = await daix.balanceOf(sfMinion.address);
        const daoBalanceBefore = await dai.balanceOf(dao.address);
        console.log('SFMinion DAIx Balance Before', ethers.utils.formatEther(minionBalanceBefore.toString()));
        console.log('DAO DAI Balance Before', ethers.utils.formatEther(daoBalanceBefore.toString()));
        await sfMinion.withdrawRemainingFunds(daix.address, true);
        const minionBalanceAfter = await daix.balanceOf(sfMinion.address);
        const daoBalanceAfter = await dai.balanceOf(dao.address);
        console.log('SFMinion DAIx Balance After', ethers.utils.formatEther(minionBalanceAfter.toString()));
        console.log('DAO DAI Balance After', ethers.utils.formatEther(daoBalanceAfter.toString()));

        expect(+daoBalanceAfter.sub(daoBalanceBefore).toString()).to.greaterThan(0);

    });
});