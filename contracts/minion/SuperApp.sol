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
    ISuperfluid,
    ISuperToken,
    ISuperAgreement,
    SuperAppDefinitions
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import "@superfluid-finance/ethereum-contracts/contracts/interfaces/tokens/TokenInfo.sol";

import "./SuperfluidMinion.sol";

contract SuperApp is SuperAppBase {
    
    string private _version;
    ISuperfluid private _host; // Superfluid host address
    IConstantFlowAgreementV1 private _cfa; // Superfluid Constant Flow Agreement address
    IResolver private _resolver; // Superfluid resolver

    ISuperfluid.Operation[] private batchCalls;
    
    constructor(address _sfHost, address _sfCFA, address _sfResolver, string memory _sfVersion) {
        _host = ISuperfluid(_sfHost);
        _cfa =  IConstantFlowAgreementV1(_sfCFA);
        _resolver = IResolver(_sfResolver);
        _version = _sfVersion;
        // NOTE: this may be incorrect
        uint256 configWord = SuperAppDefinitions.APP_LEVEL_FINAL;
        _host.registerApp(configWord);
    }

    function getSuperToken(address _token) public view returns (address) {
        string memory tokenId = string(abi.encodePacked('supertokens', '.', _version, '.', TokenInfo(_token).symbol(), 'x'));
        return _resolver.get(tokenId);
    }

    function superfluidConfig() external view returns (address, address, address, string memory) {
        return (address(_host), address(_resolver), address(_cfa), _version);
    }

    function startStream(SuperfluidMinion.Stream memory stream) external returns (bool success) {
        
        uint256 zero = 0;
        success = stream.token.approve(address(stream.superToken), zero - 1); // max allowance
        require(success, "SuperApp: failed to approve allowance to SuperToken");
        // Upgrade min deposit
        // stream.superToken.operationUpgrade(address(this), stream.minDeposit);

        // abi.encodeWithSelector(
        //         cfa.deleteFlow.selector,
        //         superToken,
        //         address(this),
        //         bidder,
        //         new bytes(0)
        //     ),

        // ISuperfluid.Operation[] calldata batchCalls;
        ISuperfluid.Operation memory upgradeTokens = ISuperfluid.Operation({
            operationType: 1 + 100, // upgrade 100 daix to play the game
            target: address(stream.superToken),
            data: abi.encode(stream.minDeposit)
        });
        batchCalls.push(upgradeTokens);

        ISuperfluid.Operation memory createFlow = ISuperfluid.Operation({
            operationType: 1 + 200, // create constant flow
            target: address(_cfa),
            data: abi.encode(
                abi.encodeWithSelector(
                    _cfa.createFlow.selector,
                    address(stream.superToken),
                    address(this),
                    stream.rate,
                    new bytes(0)
                ),
                new bytes(0)
            )
        });
        batchCalls.push(createFlow);

        _host.batchCall(batchCalls);

        delete batchCalls;

        success = true;
    }

    /**************************************************************************
     * SuperApp callbacks
     *************************************************************************/

    function beforeAgreementCreated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 /*agreementId*/,
        bytes calldata /*agreementData*/,
        bytes calldata ctx
    )
        external view override
        onlyHost
        onlyExpected(superToken, agreementClass)
        returns (bytes memory cbdata)
    {
        address sender = _host.decodeCtx(ctx).msgSender;
        cbdata = abi.encode(sender);
        // cbdata = _beforePlay(ctx);
    }

    function afterAgreementCreated(
        ISuperToken /* superToken */,
        address agreementClass,
        bytes32 agreementId,
        bytes calldata /*agreementData*/,
        bytes calldata cbdata,
        bytes calldata ctx
    )
        external override
        onlyHost
        returns (bytes memory newCtx)
    {
        address sender = _host.decodeCtx(ctx).msgSender;
        newCtx = abi.encode(sender);
        // return _play(ctx, agreementClass, agreementId, cbdata);
    }

    function beforeAgreementUpdated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 /*agreementId*/,
        bytes calldata /*agreementData*/,
        bytes calldata ctx
    )
        external view override
        onlyHost
        onlyExpected(superToken, agreementClass)
        returns (bytes memory cbdata)
    {
        address sender = _host.decodeCtx(ctx).msgSender;
        cbdata = abi.encode(sender);
        // cbdata = _beforePlay(ctx);
    }

    function afterAgreementUpdated(
        ISuperToken /* superToken */,
        address agreementClass,
        bytes32 agreementId,
        bytes calldata /*agreementData*/,
        bytes calldata cbdata,
        bytes calldata ctx
    )
        external override
        onlyHost
        returns (bytes memory newCtx)
    {
        address sender = _host.decodeCtx(ctx).msgSender;
        newCtx = abi.encode(sender);
        // return _play(ctx, agreementClass, agreementId, cbdata);
    }

    function beforeAgreementTerminated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 /*agreementId*/,
        bytes calldata /*agreementData*/,
        // bytes calldata /*ctx*/
        bytes calldata ctx //TODO: remove this
    )
        external view override
        onlyHost
        returns (bytes memory cbdata)
    {
        address sender = _host.decodeCtx(ctx).msgSender;
        cbdata = abi.encode(sender);
        // // According to the app basic law, we should never revert in a termination callback
        // if (!_isSameToken(superToken) || !_isCFAv1(agreementClass)) return abi.encode(true);
        // return abi.encode(false);
    }

    ///
    function afterAgreementTerminated(
        ISuperToken /* superToken */,
        address /* agreementClass */,
        bytes32 /* agreementId */,
        bytes calldata /*agreementData*/,
        bytes calldata cbdata,
        bytes calldata ctx
    )
        external override
        onlyHost
        returns (bytes memory newCtx)
    {
        address sender = _host.decodeCtx(ctx).msgSender;
        newCtx = abi.encode(sender);
        // // According to the app basic law, we should never revert in a termination callback
        // (bool shouldIgnore) = abi.decode(cbdata, (bool));
        // if (shouldIgnore) return ctx;
        // return _quit(ctx);
    }

    // function _isSameToken(ISuperToken superToken) private view returns (bool) {
    //     return address(superToken) == address(_acceptedToken);
    // }

    function _isCFAv1(address agreementClass) private view returns (bool) {
        return ISuperAgreement(agreementClass).agreementType()
            == keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");
    }

    modifier onlyHost() {
        require(msg.sender == address(_host), "LotterySuperApp: support only one host");
        _;
    }

    modifier onlyExpected(ISuperToken superToken, address agreementClass) {
        // require(_isSameToken(superToken), "LotterySuperApp: not accepted token");
        require(_isCFAv1(agreementClass), "LotterySuperApp: only CFAv1 supported");
        _;
    }
}
