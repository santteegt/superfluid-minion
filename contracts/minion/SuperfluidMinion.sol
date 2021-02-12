// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import {
    ISuperToken
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./SuperApp.sol";
import "../interfaces/IMoloch.sol";

contract SuperfluidMinion { // TODO: Create Minion vanilla interface
    IMOLOCH public moloch;
    address public molochDepositToken;
    bool private initialized; // internally tracks deployment under eip-1167 proxy pattern

    mapping(uint256 => Stream) public streams; // proposalId => Stream

    struct Stream {
        address to;
        IERC20 token;
        ISuperToken superToken;
        uint256 rate;
        uint256 minDeposit;
        address proposer;
        bool executed;
        bool active;
        bytes ctx;
    }

    SuperApp public sfApp; // Superfluid SuperApp

    event ProposeAction(uint256 proposalId, address proposer);
    event ProposeStream(uint256 proposalId, address proposer);
    event ExecuteAction(uint256 proposalId, address executor);
    event ExecuteStream(uint256 proposalId, address executor);
    event WithdrawnFromMoloch(address token, uint256 amount);
    // event CrossWithdraw(address target, address token, uint256 amount);
    event PulledFunds(address moloch, address token, uint256 amount);
    event ActionCanceled(uint256 proposalId);
    
     modifier memberOnly() {
        require(isMember(msg.sender), "Superfluid Minion: not a member");
        _;
    }

    constructor() {
        initialized = false;
    }

    function init(address _moloch, address _sfApp) external {
        require(!initialized, "Superfluid Minion: already initialized"); 
        moloch = IMOLOCH(_moloch);
        molochDepositToken = moloch.depositToken();
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

    // function doWithdraw(address token, uint256 amount) external memberOnly {
    //     moloch.withdrawBalance(token, amount); // withdraw funds from parent moloch
    //     emit DoWithdraw(token, amount);
    // }
    
    // function crossWithdraw(address target, address token, uint256 amount, bool transfer) external memberOnly {
    //     // @Dev - Target needs to have a withdrawBalance functions
    //     IMOLOCH(target).withdrawBalance(token, amount); 
        
    //     // Transfers token into DAO. 
    //     if(transfer) {
    //         bool whitelisted = moloch.tokenWhitelist(token);
    //         require(whitelisted, "not a whitelisted token");
    //         require(IERC20(token).transfer(address(moloch), amount), "token transfer failed");
    //     }
        
    //     emit CrossWithdraw(target, token, amount);
    // }

    function currentTokenBalance(uint256 proposalId) public view returns (uint256 balance) {
        require(address(streams[proposalId].token) != address(0), "Superfluid minion: stream proposal not found");
        balance = IERC20(streams[proposalId].token).balanceOf(address(this));
    }
    
    //  -- Proposal Functions --
    
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
        // TODO: what if Supertoken isn't in the Resolver whitelist?
        address _superToken = sfApp.getSuperToken(_token);
        require(_superToken != address(0), "Superfluid minion: token doesn't have superpowers");

        uint256 proposalId = moloch.submitProposal(
            address(this),
            0,
            0,
            0,
            molochDepositToken,
            _minDeposit, // paymentRequested
            molochDepositToken,
            details
        );

        Stream memory stream = Stream({
            to: _to,
            token: IERC20(_token),
            superToken: ISuperToken(_superToken),
            rate: _rate,
            minDeposit: _minDeposit,
            proposer: msg.sender,
            executed: false,
            active: false,
            ctx: _ctx
        });

        streams[proposalId] = stream;

        emit ProposeAction(proposalId, msg.sender);
        emit ProposeStream(proposalId, msg.sender);
        return proposalId;
    }

    function executeAction(uint256 proposalId) external returns (bytes memory) {
        Stream storage stream = streams[proposalId];
        bool[6] memory flags = moloch.getProposalFlags(proposalId);

        require(!stream.executed, "Superfluid minion: action already executed");
        require(stream.token.balanceOf(address(this)) >= stream.minDeposit, "Superfluid minion: insufficient funds");
        require(flags[2], "Superfluid minion: proposal not passed");

        // execute call
        stream.executed = true;

        bool success = sfApp.startStream(stream);
        require(success, "Superfluid minion: failed to initialize stream");

        // (bool success, bytes memory retData) = action.to.call{value: action.value}(action.data);
        // require(success, "call failure");
        bytes memory retData = new bytes(0);
        emit ExecuteAction(proposalId, msg.sender);
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
    
    //  -- Helper Functions --
    
    function isMember(address user) public view returns (bool) {
        
        (, uint shares,,,,) = moloch.members(user);
        return shares > 0;
    }

    receive() external payable {}

}
