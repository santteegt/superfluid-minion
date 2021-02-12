// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "./CloneFactory.sol";
import "../minion/SuperfluidMinion.sol";

contract SuperfluidMinionFactory is CloneFactory {
    address payable immutable public template; // fixed template for minion using eip-1167 proxy pattern
    address[] public minionList; 
    mapping (address => AMinion) public minions;
    
    event SummonMinion(address indexed minion, address indexed moloch, string details, string minionType);
    
    struct AMinion {
        address moloch;
        address sfApp;
        string details;
    }
    
    constructor(address payable _template) {
        template = _template;
    }
    
    function summonMinion(address moloch,
                          address _sfApp,
                          string memory details) external returns (address) {
        SuperfluidMinion minion = SuperfluidMinion(createClone(template));
        
        minion.init(moloch, _sfApp);
        string memory minionType = "Superfluid minion";
        
        minions[address(minion)] = AMinion(moloch, _sfApp, details);
        minionList.push(address(minion));
        emit SummonMinion(address(minion), moloch, details, minionType);
        
        return(address(minion));
        
    }
}