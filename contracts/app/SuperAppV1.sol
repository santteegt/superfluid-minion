// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import {
    SuperAppBase
} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";
import {
    IConstantFlowAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import "@superfluid-finance/ethereum-contracts/contracts/interfaces/misc/IResolver.sol";
import {
    ISuperAgreement,
    SuperAppDefinitions,
    ISuperfluid,
    ISuperToken,
    ISuperTokenFactory
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { ERC20WithTokenInfo, TokenInfo } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/tokens/ERC20WithTokenInfo.sol";

import { Initializable } from "@openzeppelin/contracts/proxy/Initializable.sol";

import "./App.sol";


/// @title SuperApp
/// @notice SuperApp to be used along with SuperfluidMinion
/// @dev still under development
contract SuperAppV1 is BaseApp, SuperAppBase {

    // ISuperfluid.Operation[] private batchCalls;
    
    function initialize(address _sfHost, address _sfCFA, address _sfResolver, string memory _sfVersion) external initializer {
        BaseApp.__BaseApp_init_unchained(_sfHost, _sfCFA, _sfResolver, _sfVersion);
        // NOTE: this may be incorrect
        uint256 configWord = SuperAppDefinitions.APP_LEVEL_FINAL;
        _host.registerApp(configWord);
    }
    
    // function startStream(SuperfluidMinion.Stream memory stream) external returns (bool success, bytes memory newCtx) {
        
    //     // uint256 zero = 0;
    //     // // STEP 0: Approve token to be upgraded
    //     // success = stream.token.approve(address(stream.superToken), zero - 1); // max allowance
    //     // require(success, "SuperApp: failed to approve allowance to SuperToken");
        

    //     // abi.encodeWithSelector(
    //     //         cfa.deleteFlow.selector,
    //     //         superToken,
    //     //         address(this),
    //     //         bidder,
    //     //         new bytes(0)
    //     //     ),
        
    //     // STEP 1: Give token Superpowers
    //     // ISuperfluid.Operation memory upgradeTokens = ISuperfluid.Operation({
    //     //     operationType: 1 + 100, // upgrade 100 daix to play the game
    //     //     target: address(stream.superToken),
    //     //     data: abi.encode(stream.minDeposit)
    //     // });
    //     // batchCalls.push(upgradeTokens);
    //     // stream.superToken.upgrade(stream.minDeposit);

    //     // ISuperfluid.Operation memory createFlow = ISuperfluid.Operation({
    //     //     operationType: 1 + 200, // create constant flow
    //     //     target: address(_cfa),
    //     //     data: abi.encode(
    //     //         abi.encodeWithSelector(
    //     //             _cfa.createFlow.selector,
    //     //             address(stream.superToken),
    //     //             address(this),
    //     //             stream.rate,
    //     //             new bytes(0)
    //     //         ),
    //     //         new bytes(0)
    //     //     )
    //     // });
    //     // batchCalls.push(createFlow);
    //     // STEP 2: Create CFA
    //     newCtx = _host.callAgreement(_cfa,
    //                                  abi.encodeWithSelector(_cfa.createFlow.selector,
    //                                                       address(stream.superToken),
    //                                                       stream.to,
    //                                                       stream.rate,
    //                                                       new bytes(0) // placeholder
    //                                                       ),
    //                                  "0x"
    //                                 );

    //     // _host.batchCall(batchCalls);
    //     // delete batchCalls;
    //     success = true;
    // }

    // /**************************************************************************
    //  * SuperApp callbacks
    //  *************************************************************************/

    // function beforeAgreementCreated(
    //     ISuperToken superToken,
    //     address agreementClass,
    //     bytes32 /*agreementId*/,
    //     bytes calldata /*agreementData*/,
    //     bytes calldata ctx
    // )
    //     external view override
    //     onlyHost
    //     onlyExpected(superToken, agreementClass)
    //     returns (bytes memory cbdata)
    // {
    //     address sender = _host.decodeCtx(ctx).msgSender;
    //     cbdata = abi.encode(sender);
    //     // cbdata = _beforePlay(ctx);
    // }

    // function afterAgreementCreated(
    //     ISuperToken /* superToken */,
    //     address agreementClass,
    //     bytes32 agreementId,
    //     bytes calldata /*agreementData*/,
    //     bytes calldata cbdata,
    //     bytes calldata ctx
    // )
    //     external override
    //     onlyHost
    //     returns (bytes memory newCtx)
    // {
    //     address sender = _host.decodeCtx(ctx).msgSender;
    //     newCtx = abi.encode(sender);
    //     // return _play(ctx, agreementClass, agreementId, cbdata);
    // }

    // function beforeAgreementUpdated(
    //     ISuperToken superToken,
    //     address agreementClass,
    //     bytes32 /*agreementId*/,
    //     bytes calldata /*agreementData*/,
    //     bytes calldata ctx
    // )
    //     external view override
    //     onlyHost
    //     onlyExpected(superToken, agreementClass)
    //     returns (bytes memory cbdata)
    // {
    //     address sender = _host.decodeCtx(ctx).msgSender;
    //     cbdata = abi.encode(sender);
    //     // cbdata = _beforePlay(ctx);
    // }

    // function afterAgreementUpdated(
    //     ISuperToken /* superToken */,
    //     address agreementClass,
    //     bytes32 agreementId,
    //     bytes calldata /*agreementData*/,
    //     bytes calldata cbdata,
    //     bytes calldata ctx
    // )
    //     external override
    //     onlyHost
    //     returns (bytes memory newCtx)
    // {
    //     address sender = _host.decodeCtx(ctx).msgSender;
    //     newCtx = abi.encode(sender);
    //     // return _play(ctx, agreementClass, agreementId, cbdata);
    // }

    // function beforeAgreementTerminated(
    //     ISuperToken superToken,
    //     address agreementClass,
    //     bytes32 /*agreementId*/,
    //     bytes calldata /*agreementData*/,
    //     // bytes calldata /*ctx*/
    //     bytes calldata ctx //TODO: remove this
    // )
    //     external view override
    //     onlyHost
    //     returns (bytes memory cbdata)
    // {
    //     address sender = _host.decodeCtx(ctx).msgSender;
    //     cbdata = abi.encode(sender);
    //     // // According to the app basic law, we should never revert in a termination callback
    //     // if (!_isSameToken(superToken) || !_isCFAv1(agreementClass)) return abi.encode(true);
    //     // return abi.encode(false);
    // }

    // ///
    // function afterAgreementTerminated(
    //     ISuperToken /* superToken */,
    //     address /* agreementClass */,
    //     bytes32 /* agreementId */,
    //     bytes calldata /*agreementData*/,
    //     bytes calldata cbdata,
    //     bytes calldata ctx
    // )
    //     external override
    //     onlyHost
    //     returns (bytes memory newCtx)
    // {
    //     address sender = _host.decodeCtx(ctx).msgSender;
    //     newCtx = abi.encode(sender);
    //     // // According to the app basic law, we should never revert in a termination callback
    //     // (bool shouldIgnore) = abi.decode(cbdata, (bool));
    //     // if (shouldIgnore) return ctx;
    //     // return _quit(ctx);
    // }

    // // function _isSameToken(ISuperToken superToken) private view returns (bool) {
    // //     return address(superToken) == address(_acceptedToken);
    // // }

    // function _isCFAv1(address agreementClass) private view returns (bool) {
    //     return ISuperAgreement(agreementClass).agreementType()
    //         == keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");
    // }

    // modifier onlyHost() {
    //     require(msg.sender == address(_host), "LotterySuperApp: support only one host");
    //     _;
    // }

    // modifier onlyExpected(ISuperToken superToken, address agreementClass) {
    //     // require(_isSameToken(superToken), "LotterySuperApp: not accepted token");
    //     require(_isCFAv1(agreementClass), "LotterySuperApp: only CFAv1 supported");
    //     _;
    // }
}
