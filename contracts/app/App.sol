// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import {
    IConstantFlowAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import "@superfluid-finance/ethereum-contracts/contracts/interfaces/misc/IResolver.sol";
import {
    ISuperfluid,
    ISuperToken,
    ISuperTokenFactory
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { ERC20WithTokenInfo } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/tokens/ERC20WithTokenInfo.sol";

import { Initializable } from "@openzeppelin/contracts/proxy/Initializable.sol";

import "../interfaces/IBaseApp.sol";


/// @title BaseApp
/// @notice BaseApp to interact with Superfluid protocol
/// @dev contains the mimimal code for the SFMinion to interact with Superfluid protocol
abstract contract BaseApp is Initializable, IBaseApp {
    
    ISuperfluid internal _host; // Superfluid host address
    IConstantFlowAgreementV1 internal _cfa; // Superfluid Constant Flow Agreement address
    IResolver internal _resolver; // Superfluid resolver
    string internal _version; // Superfluid version

    mapping (address => address) public superTokenRegistry;  // token registry for non-official tokens
    
    /// @notice 
    /// @dev 
    /// @param _sfHost Superfluid host contract
    /// @param _sfCFA CFA agreement contract
    /// @param _sfResolver Superfluid Resolver contract
    /// @param _sfVersion Superfluid protocol version
    function __BaseApp_init_unchained(address _sfHost, address _sfCFA, address _sfResolver, string memory _sfVersion) internal initializer {
        _host = ISuperfluid(_sfHost);
        _cfa =  IConstantFlowAgreementV1(_sfCFA);
        _resolver = IResolver(_sfResolver);
        _version = _sfVersion;
    }

    /// @notice 
    /// @dev 
    /// @param _token a token
    /// @return true
    function isSuperToken(ERC20WithTokenInfo _token) public override view returns (bool) {
        string memory tokenId = string(abi.encodePacked('supertokens', '.', _version, '.', _token.symbol()));
        return _resolver.get(tokenId) == address(_token);
    }

    /// @notice 
    /// @dev 
    /// @param _token an underlying token
    /// @return tokenAddress
    function getSuperToken(ERC20WithTokenInfo _token) public override view returns (address tokenAddress) {
        string memory tokenId = string(abi.encodePacked('supertokens', '.', _version, '.', _token.symbol(), 'x'));
        tokenAddress = _resolver.get(tokenId);
        if (tokenAddress == address(0)) { // Look on the App registry if there's already a "non-oficially registered" Supertoken
            tokenAddress = superTokenRegistry[address(_token)];
        }
    }

    /// @notice 
    /// @dev 
    /// @return Superfluid contracts
    function superfluidConfig() external override view returns (ISuperfluid, IResolver, IConstantFlowAgreementV1, string memory) {
        return (_host, _resolver, _cfa, _version);
    }
    
    /// @notice 
    /// @dev 
    /// @param _token underlying token
    /// @return superToken newly created SuperToken
    function createSuperToken(ERC20WithTokenInfo _token) public override returns (ISuperToken superToken) {
        if (superTokenRegistry[address(_token)] != address(0)) {
            superToken = ISuperToken(superTokenRegistry[address(_token)]);
        } else {
            ISuperTokenFactory factory = _host.getSuperTokenFactory();
            string memory name = string(abi.encodePacked('Super ', _token.name()));
            string memory symbol = string(abi.encodePacked(_token.symbol(), 'x'));
            superToken = factory.createERC20Wrapper(_token, ISuperTokenFactory.Upgradability.FULL_UPGRADABE, name, symbol);
            superTokenRegistry[address(_token)] = address(superToken);
        }
    }
}


/// @title App
/// @notice App to interact with Superfluid protocol
/// @dev non-upgradable
contract App is BaseApp {

    constructor(address _sfHost, address _sfCFA, address _sfResolver, string memory _sfVersion) {
        BaseApp.__BaseApp_init_unchained(_sfHost, _sfCFA, _sfResolver, _sfVersion);
    }
}