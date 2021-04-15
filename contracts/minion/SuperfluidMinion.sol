// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import {
    IConstantFlowAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import "@superfluid-finance/ethereum-contracts/contracts/interfaces/misc/IResolver.sol";
import {
    ISuperAgreement,
    ISuperfluid,
    ISuperToken
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { ERC20WithTokenInfo } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/tokens/ERC20WithTokenInfo.sol";

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./SuperApp.sol";
import "../interfaces/IMoloch.sol";

contract SuperfluidMinion is ReentrancyGuard {
    IMOLOCH public moloch;
    
    bool private initialized; // internally tracks deployment under eip-1167 proxy pattern

    mapping(uint256 => Stream) public streams; // proposalId => Stream

    struct Stream {
        address to;
        ERC20WithTokenInfo token;
        address superToken;
        uint256 rate;
        uint256 minDeposit;
        address proposer;
        bool executed;
        bool active;
        bytes ctx;
    }

    SuperApp public sfApp; // Superfluid SuperApp

    event ProposeStream(uint256 proposalId, address proposer);
    event ExecuteStream(uint256 proposalId, address executor);
    event PulledFunds(address moloch, address token, uint256 amount);
    event WithdrawBalance(address superToken, address underlyingToken, uint256 amount);
    event ActionCanceled(uint256 proposalId);
    event StreamCanceled(uint256 proposalId, address canceledBy);
    
     modifier memberOnly() {
        require(isMember(msg.sender), "Superfluid Minion: not a DAO member");
        _;
    }

    constructor() ReentrancyGuard() {
        initialized = false;
    }

    function init(address _moloch, address _sfApp) external {
        require(!initialized, "Superfluid Minion: already initialized"); 
        moloch = IMOLOCH(_moloch);
        sfApp = SuperApp(_sfApp);
        initialized = true;
    }
    
    //  -- Withdraw Functions --

    function pullFunds(address token) internal {
        uint256 remainingFunds = moloch.userTokenBalances(address(this), token);
        if (remainingFunds > 0) {
            moloch.withdrawBalance(token, remainingFunds); // withdraw funds from parent moloch
            emit PulledFunds(address(moloch), token, remainingFunds);
        }
    }
    
    function withdrawRemainingFunds(ISuperToken superToken) public memberOnly nonReentrant {
        
        // STEP 1: downgrade from SuperToken then withdraw from token
        (int256 remainingBalance, , ,) = superToken.realtimeBalanceOfNow(address(this));
        if (remainingBalance > 0) {
            superToken.downgrade(uint256(remainingBalance));
        }
        
        // STEP 2: withdraw underlyingToken to Moloch
        ERC20WithTokenInfo underlyingToken = ERC20WithTokenInfo(superToken.getUnderlyingToken());
        uint256 balance = underlyingToken.balanceOf(address(this));
        require(balance > 0, "Superfluid minion: No remaining funds to withdraw");
        
        require(underlyingToken.transfer(address(moloch), balance), "Superfluid minion: token transfer failed");
        emit WithdrawBalance(address(superToken), address(underlyingToken), balance);
    }

    function currentTokenBalance(uint256 proposalId) public view returns (uint256 deposit, uint256 owedDeposit) {
        Stream memory stream = streams[proposalId];
        require(address(stream.token) != address(0), "Superfluid minion: stream proposal not found");
        (/*ISuperfluid host*/, /*IResolver r_*/, IConstantFlowAgreementV1 cfa, /*string memory v_*/) = sfApp.superfluidConfig(); 
        (/*uint256 timestamp*/, /*int96 flowRate*/, deposit, owedDeposit) = cfa.getFlow(ISuperToken(stream.superToken), address(this), stream.to);
        // balance = ERC20WithTokenInfo(streams[proposalId].token).balanceOf(address(this));
    }
    
    //  -- Proposal Functions --
    function _submitProposal(
        uint256 _minDeposit,
        address _depositToken,
        string calldata details
    ) internal returns (uint256 proposalId) {

        proposalId = moloch.submitProposal(
            address(this),
            0,
            0,
            0,
            moloch.depositToken(),
            _minDeposit, // paymentRequested
            _depositToken,
            details
        );
    }
    
    function proposeStream(
        address _to,
        address _token,
        uint256 _rate,
        uint256 _minDeposit,
        bytes calldata _ctx,
        string calldata details
    ) external memberOnly returns (uint256) {

        require(_to != address(0), "Superfluid minion: invalid recipient");
        require(_token != address(0), "Superfluid minion: invalid token");
        require(_minDeposit > _rate, "Superfluid minion: invalid minimum deposit");

        uint256 proposalId = _submitProposal(_minDeposit, _token, details);

        Stream memory stream = Stream({
            to: _to,
            token: ERC20WithTokenInfo(_token),
            superToken: sfApp.getSuperToken(ERC20WithTokenInfo(_token)), // if not in the registry, it will be upgraded during execution
            rate: _rate,
            minDeposit: _minDeposit,
            proposer: msg.sender,
            executed: false,
            active: false,
            ctx: _ctx
        });

        streams[proposalId] = stream;

        emit ProposeStream(proposalId, msg.sender);
        return proposalId;
    }

    function executeAction(uint256 proposalId) nonReentrant external returns (bytes memory) {
        Stream storage stream = streams[proposalId];
        bool[6] memory flags = moloch.getProposalFlags(proposalId);

        require(!stream.executed, "Superfluid minion: action already executed");
        require(flags[2], "Superfluid minion: proposal not passed");
        
        // execute call
        stream.executed = true;
        stream.active = true;
        
        pullFunds(address(stream.token));
        
        require(stream.token.balanceOf(address(this)) >= stream.minDeposit, "Superfluid minion: insufficient funds");
        
        // STEP -1: Ensure token has superpowers
        if (stream.superToken == address(0)) {
            stream.superToken = address(sfApp.createSuperToken(stream.token));
        }
        
        // STEP 0: Approve token to be upgraded
        if (stream.token.allowance(address(this), address(stream.superToken)) < stream.minDeposit) {
            uint256 zero = 0;
            bool success = stream.token.approve(address(stream.superToken), zero - 1); // max allowance
            require(success, "SuperApp: failed to approve allowance to SuperToken");
        }
        
        // STEP 1: Give token Superpowers
        ISuperToken(stream.superToken).upgrade(stream.minDeposit);
        
        (ISuperfluid host, /*IResolver r_*/, IConstantFlowAgreementV1 cfa, /*string memory v_*/) = sfApp.superfluidConfig();
        
        // STEP 2: Create CFA
        bytes memory retData = host.callAgreement(cfa,
                                                  abi.encodeWithSelector(cfa.createFlow.selector,
                                                                         stream.superToken,
                                                                         stream.to, // TODO: 
                                                                         stream.rate,
                                                                         new bytes(0) // placeholder
                                                                        ),
                                                 "0x"
                                                 );

        // (bool success, bytes memory retData) = sfApp.startStream(stream);
        // require(success, "Superfluid minion: failed to initialize stream");
        stream.ctx = retData;
        
        // (bool success, bytes memory retData) = action.to.call{value: action.value}(action.data);
        // require(success, "call failure");
        // bytes memory retData = new bytes(0);
        emit ExecuteStream(proposalId, msg.sender);
        return retData;
    }
    
    function cancelAction(uint256 _proposalId) external {
        Stream memory stream = streams[_proposalId];
        require(msg.sender == stream.proposer, "Superfluid minion: not the proposer");
        require(!stream.executed, "Superfluid minion: already executed");
        delete streams[_proposalId];
        emit ActionCanceled(_proposalId);
        moloch.cancelProposal(_proposalId);
    }
    
    function cancelStream(uint256 _proposalId) external memberOnly {
        Stream storage stream = streams[_proposalId];
        require(stream.active, "Superfluid minion: not an active stream");
        
        stream.active = false;
        
        (ISuperfluid host, /*IResolver r_*/, IConstantFlowAgreementV1 cfa, /*string memory v_*/) = sfApp.superfluidConfig();
        
        bytes memory retData = host.callAgreement(cfa,
                                                  abi.encodeWithSelector(cfa.deleteFlow.selector,
                                                                         stream.superToken,
                                                                         address(this),
                                                                         stream.to,
                                                                         new bytes(0) // placeholder
                                                                        ),
                                                 "0x"
                                                 );
                                                 
         stream.ctx = retData;
        
        emit StreamCanceled(_proposalId, msg.sender);        
    }
    
    //  -- Helper Functions --
    
    function isMember(address user) public view returns (bool) {
        
        (, uint shares,,,,) = moloch.members(user);
        return shares > 0;
    }

    receive() external payable {}

}
