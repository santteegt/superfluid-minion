// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import { ERC20WithTokenInfo } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/tokens/ERC20WithTokenInfo.sol";
import {
    ISuperToken
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import { IMOLOCH } from "../interfaces/IMoloch.sol";

/// @title 
/// @notice 
/// @dev 
interface ISuperfluidMinion {

    function init(address _moloch, address _sfApp) external;

    function upgradeToken(ERC20WithTokenInfo token, uint256 value) external;

    function withdrawRemainingFunds(ISuperToken _superToke, bool _downgrade) external;

    function proposeAction(
        address _to,
        address _token,
        uint256 _rate,
        uint256 _minDeposit,
        bytes calldata _ctx,
        string calldata _details
    ) external returns (uint256);

    function executeAction(uint256 _proposalId) external returns (bytes calldata);

    function cancelAction(uint256 _proposalId) external;

    function cancelStream(uint256 _proposalId) external;

    function isMember(IMOLOCH _moloch, address _user) external view returns (bool);

}