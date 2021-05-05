// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import {
    IConstantFlowAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import "@superfluid-finance/ethereum-contracts/contracts/interfaces/misc/IResolver.sol";
import {
    ISuperfluid,
    ISuperToken
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { ERC20WithTokenInfo } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/tokens/ERC20WithTokenInfo.sol";

/// @title 
/// @notice 
/// @dev 
interface IBaseApp {
    
    function isSuperToken(ERC20WithTokenInfo _token) external view returns (bool);

    function getSuperToken(ERC20WithTokenInfo _token) external view returns (address);

    function superfluidConfig() external view returns (ISuperfluid, IResolver, IConstantFlowAgreementV1, string calldata);

    function createSuperToken(ERC20WithTokenInfo _token) external returns (ISuperToken superToken);
}