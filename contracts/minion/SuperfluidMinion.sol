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

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IBaseApp } from "../interfaces/IBaseApp.sol";
import { IMOLOCH } from "../interfaces/IMoloch.sol";
import { ISuperfluidMinion } from "../interfaces/ISuperfluidMinion.sol";


/// @title SuperfluidMinion
/// @notice 
/// @dev 
contract SuperfluidMinion is ReentrancyGuard, ISuperfluidMinion {
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

    IBaseApp public sfApp;

    event ProposeStream(uint256 proposalId, address proposer);
    event ExecuteStream(uint256 proposalId, address executor);
    event PulledFunds(address indexed token, uint256 amount);
    event WithdrawBalance(address indexed superToken, address indexed underlyingToken, address indexed withdrawnBy, uint256 amount, bool downgraded);
    event ActionCanceled(uint256 proposalId);
    event StreamCanceled(uint256 proposalId, address canceledBy);
    
     modifier memberOnly() {
        require(isMember(moloch, msg.sender), "SuperfluidMinion: not a DAO member");
        _;
    }

    /// @notice 
    /// @dev 
    constructor() ReentrancyGuard() {
        initialized = false;
    }

    /// @notice 
    /// @dev init method used by proxy factory
    /// @param _moloch MolochDAO address
    /// @param _sfApp App to interacti with the Superfluid contracts
    function init(address _moloch, address _sfApp) external override {
        require(!initialized, "SuperfluidMinion: already initialized"); 
        moloch = IMOLOCH(_moloch);
        sfApp = IBaseApp(_sfApp);
        initialized = true;
    }

    /// @notice pull requested funds from the DAO
    /// @dev
    /// @param token an ERC20 token 
    function _pullFunds(address token) internal {

        uint256 remainingFunds = moloch.userTokenBalances(address(this), token);
        if (remainingFunds > 0) {
            moloch.withdrawBalance(token, remainingFunds); // withdraw funds from parent moloch
            emit PulledFunds(token, remainingFunds);
        }
    }

    /// @notice increase the Minion superToken balance
    /// @dev 
    /// @param _token the underlying token
    /// @param value deposit value
    function upgradeToken(ERC20WithTokenInfo _token, uint256 value) external override memberOnly nonReentrant {
        _pullFunds(address(_token));
        require(_token.balanceOf(address(this)) >= value, "SuperfluidMinion: No enough funds available to upgrade");

        address superToken = sfApp.getSuperToken(_token);
        require(superToken != address(0), "SuperfluidMinion: this token does not have superpowers");

        if (_token.allowance(address(this), superToken) < value) {
            uint256 zero = 0;
            bool success = _token.approve(superToken, zero - 1); // max allowance
            require(success, "SuperfluidMinion: failed to approve allowance to SuperToken");
        }
        
        ISuperToken(superToken).upgrade(value);
    }
   
    /// @notice withdraw any remaining balance and returns it to the DAO
    /// @dev 
    /// @param superToken a SuperToken
    /// @param _downgrade if true returns the balance in underlying token
    function withdrawRemainingFunds(ISuperToken superToken, bool _downgrade) public override memberOnly nonReentrant {

        uint256 remainingBalance = superToken.balanceOf(address(this));
        require(remainingBalance > 0, "SuperfluidMinion: No funds to withdraw");
        ERC20WithTokenInfo underlyingToken = ERC20WithTokenInfo(superToken.getUnderlyingToken());
        
        if (_downgrade) {
            // STEP 1: downgrade from SuperToken then withdraw from token
            superToken.downgrade(uint256(remainingBalance));
        
            // STEP 2: withdraw underlyingToken to Moloch
            remainingBalance = underlyingToken.balanceOf(address(this));
            require(remainingBalance > 0, "SuperfluidMinion: No remaining funds to withdraw");
            
            require(underlyingToken.transfer(address(moloch), remainingBalance), "Superfluid minion: token transfer failed");
        } else {
            require(superToken.transfer(address(moloch), remainingBalance), "Superfluid minion: superToken transfer failed");
        }
        emit WithdrawBalance(address(superToken), address(underlyingToken), msg.sender, remainingBalance, _downgrade);
    }
    
    /// @notice submit a DAO proposal
    /// @dev 
    /// @param _minDeposit requested funds
    /// @param _depositToken a ERC20 token
    /// @param details proposal details
    /// @return proposalId
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
    
    /// @notice creates a streaming proposal
    /// @dev 
    /// @param _to stream recipient
    /// @param _token underlying token to be streamed
    /// @param _rate stream rate
    /// @param _minDeposit minimum deposit
    /// @param _ctx any context to be sent to Superfluid
    /// @param details proposal details
    /// @return proposalId
    function proposeAction(
        address _to,
        address _token,
        uint256 _rate,
        uint256 _minDeposit,
        bytes calldata _ctx,
        string calldata details
    ) external override memberOnly returns (uint256) {

        require(_to != address(0), "Superfluid minion: invalid recipient");
        require(_token != address(0), "Superfluid minion: invalid token");
        require(_minDeposit > _rate, "Superfluid minion: invalid minimum deposit");

        uint256 proposalId = _submitProposal(_minDeposit, _token, details);

        ERC20WithTokenInfo token = ERC20WithTokenInfo(_token);
        address superToken = sfApp.isSuperToken(token) ? _token : sfApp.getSuperToken(token);

        Stream memory stream = Stream({
            to: _to,
            token: token,
            superToken: superToken, // if not in the registry, it will be upgraded during execution
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

    /// @notice starts the stream after a proposal passed
    /// @dev 
    /// @param _proposalId DAO proposal Id
    /// @return ctx returned by Superfluid
    function executeAction(uint256 _proposalId) nonReentrant external override returns (bytes memory) {

        Stream storage stream = streams[_proposalId];
        bool[6] memory flags = moloch.getProposalFlags(_proposalId);

        require(!stream.executed, "SuperfluidMinion: action already executed");
        require(flags[2], "SuperfluidMinion: proposal not passed");
        
        // execute call
        stream.executed = true;
        stream.active = true;
        
        _pullFunds(address(stream.token));
        
        require(stream.token.balanceOf(address(this)) >= stream.minDeposit, "SuperfluidMinion: insufficient funds");
        
        // STEP -1: Ensure token has superpowers
        if (stream.superToken == address(0)) {
            stream.superToken = address(sfApp.createSuperToken(stream.token));
        }
        
        // STEP 0: Approve token to be upgraded
        if (stream.token.allowance(address(this), stream.superToken) < stream.minDeposit) {
            uint256 zero = 0;
            bool success = stream.token.approve(stream.superToken, zero - 1); // max allowance
            require(success, "SuperfluidMinion: failed to approve allowance to SuperToken");
        }
        
        // STEP 1: Give token Superpowers
        ISuperToken(stream.superToken).upgrade(stream.minDeposit);
        
        (ISuperfluid host, /*IResolver r_*/, IConstantFlowAgreementV1 cfa, /*string memory v_*/) = sfApp.superfluidConfig();
        
        // STEP 2: Create CFA
        stream.ctx = host.callAgreement(cfa,
                                        abi.encodeWithSelector(cfa.createFlow.selector,
                                                                stream.superToken,
                                                                stream.to,
                                                                stream.rate,
                                                                new bytes(0) // placeholder
                                                                ),
                                        "0x"
                                        );

        emit ExecuteStream(_proposalId, msg.sender);
        return stream.ctx;
    }
    
    /// @notice cancel proposal
    /// @dev 
    /// @param _proposalId DAO proposal Id
    function cancelAction(uint256 _proposalId) external override {

        Stream memory stream = streams[_proposalId];
        require(msg.sender == stream.proposer, "SuperfluidMinion: not the proposer");
        require(!stream.executed, "SuperfluidMinion: already executed");
        delete streams[_proposalId];
        emit ActionCanceled(_proposalId);
        moloch.cancelProposal(_proposalId);
    }
    
    /// @notice cancel an active stream
    /// @dev 
    /// @param _proposalId DAO proposal Id
    function cancelStream(uint256 _proposalId) external override memberOnly {

        Stream storage stream = streams[_proposalId];
        require(stream.active, "SuperfluidMinion: not an active stream");
        
        stream.active = false;
        
        (ISuperfluid host, /*IResolver r_*/, IConstantFlowAgreementV1 cfa, /*string memory v_*/) = sfApp.superfluidConfig();

        (/*uint256 timestamp*/, int96 flowRate, /*uint256 deposit*/, /*uint256 owedDeposit*/) = cfa.getFlow(ISuperToken(stream.superToken),
                                                                                                            address(this),
                                                                                                            stream.to);

        if (flowRate > 0) {  // TODO: make sure cannot create a new stream proposal before closing a previous one    
            stream.ctx = host.callAgreement(cfa,
                                            abi.encodeWithSelector(cfa.deleteFlow.selector,
                                                                    stream.superToken,
                                                                    address(this),
                                                                    stream.to,
                                                                    new bytes(0) // placeholder
                                                                    ),
                                            "0x"
                                            );
        }
        
        emit StreamCanceled(_proposalId, msg.sender);        
    }
    
    /// @notice verifies if a user is a DAO member
    /// @dev 
    /// @param _moloch DAO address
    /// @param _user user address
    /// @return true if user is a DAO member
    function isMember(IMOLOCH _moloch, address _user) public override view returns (bool) {
        
        (, uint shares,,,,) = _moloch.members(_user);
        return shares > 0;
    }

    receive() external payable {}

}
