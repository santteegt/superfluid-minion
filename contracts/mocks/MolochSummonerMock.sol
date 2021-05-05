// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "./MolochMock.sol";
import "../factory/CloneFactory.sol";

contract MolochSummoner is CloneFactory { 
    
    address payable immutable public template;
    mapping (address => bool) public daos;
    uint daoIdx = 0;
    Moloch private moloch; // moloch contract
    
    constructor(address payable _template) {
        template = _template;
    }
    
    event SummonComplete(address indexed moloch, address[] summoner, address[] tokens, uint256 summoningTime, uint256 periodDuration, uint256 votingPeriodLength, uint256 gracePeriodLength, uint256 proposalDeposit, uint256 dilutionBound, uint256 processingReward, uint256[] summonerShares);
    event Register(uint daoIdx, address moloch, string title, string http, uint version);
     
    function summonMoloch(
        address[] memory _summoner,
        address[] memory _approvedTokens,
        uint256 _periodDuration,
        uint256 _votingPeriodLength,
        uint256 _gracePeriodLength,
        uint256 _proposalDeposit,
        uint256 _dilutionBound,
        uint256 _processingReward,
        uint256[] memory _summonerShares
    ) public returns (address) {
        Moloch baal = Moloch(createClone(template));
        
        baal.init(
            _summoner,
            _approvedTokens,
            _periodDuration,
            _votingPeriodLength,
            _gracePeriodLength,
            _proposalDeposit,
            _dilutionBound,
            _processingReward,
            _summonerShares
        );
       
        emit SummonComplete(address(baal), _summoner, _approvedTokens, block.timestamp, _periodDuration, _votingPeriodLength, _gracePeriodLength, _proposalDeposit, _dilutionBound, _processingReward, _summonerShares);
        
        return address(baal);
    }
    
    function registerDao(
        address _daoAdress,
        string memory _daoTitle,
        string memory _http,
        uint _version
      ) public returns (bool) {
          
      moloch = Moloch(_daoAdress);
      (,,,bool exists,,) = moloch.members(msg.sender);
    
      require(exists == true, "must be a member");
      require(daos[_daoAdress] == false, "dao metadata already registered");

      daos[_daoAdress] = true;
      
      daoIdx = daoIdx + 1;
      emit Register(daoIdx, _daoAdress, _daoTitle, _http, _version);
      return true;
      
    }  
}
