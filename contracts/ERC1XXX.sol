pragma solidity >=0.4.21 < 0.6.0;
import "./IERC1XXX.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";

library Casper {
    struct Checkpoint {
        address proposer;
        bytes32 parent;
        bytes32 state;
        uint256 epochNum;
        uint256 nonce;
        uint256 timestamp;
        bytes32 randomness;
        bool justified;
        bool finalized;
        bool accused;
        bool slashed;
        uint256 votes;
    }

    function hash(Checkpoint memory obj) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                obj.proposer,
                obj.parent, 
                obj.state, 
                obj.epochNum,
                obj.nonce)
        );
    }

    function getStartingPoint(Checkpoint memory obj, uint8 len) internal pure returns (uint8) {
        return uint8(uint256(keccak256(abi.encodePacked(hash(obj),obj.randomness))) % len);
    }

    function has(uint256 bitFilter, uint8 id) public pure returns (bool) {
        return (bitFilter & (uint256(1) << id)) != 0;
    }

    function append(uint256 bitFilter, uint8 id) public pure returns (uint256 updatedFilter) {
        uint256 position = uint256(1) << id;
        require(bitFilter & position == 0);
        return bitFilter | position;
    }

    struct Validator {
        address addr;
        uint8 id; // It can be changed dynamically
        uint256 stake; // wei
        uint256 startDynasty; // The dynasty number to start validation
        uint256 endDynasty; // The dynasty number to end validation
        uint256 withdrawable; // Restricted to participate in until this timestamp value
        uint256 reward; // Reward
        bool slashed;
    }

    function isInitialized(Validator memory obj) internal pure returns(bool) {
        return obj.addr != address(0);
    } 

    struct VoteMsg {
        bytes32 source;
        bytes32 target;
        uint256 sourceEpoch;
        uint256 targetEpoch;
        address signer;
    }

    function toVote(bytes memory voteMsg) internal pure returns(VoteMsg memory) {
        (
            bytes32 source, 
            bytes32 target,
            uint256 sourceEpoch,
            uint256 targetEpoch, 
            bytes32 r,
            bytes32 s,
            uint8 v
        ) = abi.decode(voteMsg,(bytes32, bytes32, uint256, uint256, bytes32, bytes32, uint8));

        bytes32 voteHash = keccak256(abi.encodePacked(source, target, sourceEpoch, targetEpoch));
        bytes32 ethMessage = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", voteHash));
        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "Malleable signature");
        require(v == 27 || v == 28, "Malleable signature");
        address signer = ecrecover(ethMessage, v, r, s);
        return VoteMsg(source, target, sourceEpoch, targetEpoch, signer);
    }

    function toBatchVotes(bytes memory batchVotes) internal pure returns(VoteMsg[] memory) {
        require(batchVotes.length % 193 == 0);
        VoteMsg[] memory messages = new VoteMsg[](batchVotes.length / 193);
        bytes32 source;
        bytes32 target;
        uint256 sourceEpoch;
        uint256 targetEpoch; 
        bytes32 r;
        bytes32 s;
        uint8 v;
        bytes32 voteHash;
        bytes32 ethMessage;
        address signer;
        for(uint i = 0; i < batchVotes.length / 193; i++) {
            assembly {
                source := mload(add(batchVotes, add(mul(i, 0xc1), 0x20)))
                target := mload(add(batchVotes, add(mul(i, 0xc1), 0x40)))
                sourceEpoch := mload(add(batchVotes, add(mul(i, 0xc1), 0x60)))
                targetEpoch := mload(add(batchVotes, add(mul(i, 0xc1), 0x80)))
                r := mload(add(batchVotes, add(mul(i, 0xc1), 0xa0)))
                s := mload(add(batchVotes, add(mul(i, 0xc1), 0xc0)))
                v := mload(add(batchVotes, add(mul(i, 0xc1), 0xc1)))
            }
            voteHash = keccak256(abi.encodePacked(source, target, sourceEpoch, targetEpoch));
            ethMessage = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", voteHash));
            require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "Malleable signature");
            require(v == 27 || v == 28, "Malleable signature");
            signer = ecrecover(ethMessage, v, r, s);
            messages[i] = VoteMsg(source, target, sourceEpoch, targetEpoch, signer);
        }
    }
}

contract ERC1XXX is IERC1XXX, ERC20, ERC20Detailed {
    using Casper for Casper.Checkpoint;
    using Casper for Casper.Validator;
    using Casper for Casper.VoteMsg;
    using Casper for bytes;
    using Casper for uint256; 

    uint256 public constant MAXIMUM_REWARD = 1 ether;

    mapping(uint256 => uint256) votes;

    // Meta data
    uint256 public withdrawalDelay = 10368000; // 4months (4 * 30 * 24 * 60 * 60)
    uint256 public minimumStake = 32 ether;
    uint256 public challengePeriod = 540; // (15 sec * 12 confirmation * 3)
    uint256 public minimumBond = 32 ether;

    // Checkpoints
    mapping(bytes32 => bytes32) checkpointTree; // child => parent
    mapping(bytes32 => Casper.Checkpoint) checkpoints; // detail for the checkpoint
    bytes32 finalizedCheckpoint;

    // Dynasty
    uint256 dynastyNum;
    uint256 totalStake;
    uint256 slashedIds;

    // Validator
    address[] validatorList;
    mapping(address => Casper.Validator) validators;

    // dynastyNum => new validator set
    mapping(uint256 => address[]) validatorQueue;
    // dynastyNum => validator set to remove
    mapping(uint256 => address[]) exitingQueue;
    // Blacklist
    mapping(address => bool) slashed;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _minimumStake,
        uint256 _withdrawalDelay,
        uint256 _challengePeriod
    ) public ERC20Detailed(_name, _symbol, _decimals) {
        minimumStake = _minimumStake;
        withdrawalDelay = _withdrawalDelay;
        challengePeriod = _challengePeriod;
        // TODO genesis checkpoint
    }

    function deposit() external payable {
        // Should send exact amount of stake
        require(msg.value >= minimumStake, "Send the exact amount of stake");

        Casper.Validator storage _newbie = validators[msg.sender];
        // Assure the validator has valid state to participate in
        require(!_newbie.isInitialized(), "Should not be initialized");
        // Check the address was slashed before
        require(!slashed[msg.sender], "Should never been slashed before");

        // Set the stake amount
        validators[msg.sender].stake = msg.value;

        if(dynastyNum == 0) {
            // Before it is launched, put the message sender into the validator set immediately
            _newbie.startDynasty = dynastyNum;
            _activateValidator(msg.sender);
        } else {
            // Set start dynasty
            _newbie.startDynasty = dynastyNum + 2;
            // After the launching, add to the validator queue and update later
            validatorQueue[dynastyNum + 2].push(msg.sender);
        }
        _newbie.endDynasty = uint256(0) - 1;
        emit Deposit(msg.sender, _newbie.startDynasty, _newbie.stake);
    }

    function requestWithdraw() external {
        // Should be a validator
        require(_isValidator(msg.sender) && !slashed[msg.sender]);
        // Set end dynasty for the validator
        validators[msg.sender].endDynasty = dynastyNum + 2;
        exitingQueue[dynastyNum + 2].push(msg.sender);
    }

    function withdraw() external {
        // Should be withdrawable
        require(_isWithdrawable(msg.sender));

        Casper.Validator storage _withdrawer = validators[msg.sender];
        // Transfer Ether to the message sender;
        msg.sender.transfer(_withdrawer.stake);
        // Delete _withdrawer information
        delete validators[msg.sender];
    }

    function propose(bytes32 _parent, bytes32 _state, uint256 _epochNum, uint256 _nonce) external {
        // Should have permission to propose
        require(_isValidator(msg.sender)); 

        // Get parent & check epoch num
        require(checkpoints[_parent].epochNum + 1 == _epochNum, "Should be a direct child");

        // Init checkpoint
        Casper.Checkpoint memory _checkpoint = Casper.Checkpoint(
            msg.sender,
            _parent, 
            _state, 
            _epochNum, 
            _nonce, 
            now,
            _newRandomness(),
            false,
            false,
            false,
            false,
            0
        );

        // Get hash of the checkpoint
        bytes32 newChildHash = _checkpoint.hash();

        // Should submit PoW nonce
        require(_proofOfWork(msg.sender, _parent, _state, _epochNum, _nonce));

        // Add branch to the checkpoint tree
        checkpointTree[newChildHash] = _parent;
        checkpoints[newChildHash] = _checkpoint;

        // TODO mint token
    }

    function vote(bytes calldata _msg) external {
        Casper.VoteMsg memory _voteMsg = _msg.toVote();
        _applyVote(_voteMsg);
    }

    function batchVote(bytes calldata _msgArr) external {
        Casper.VoteMsg[]  memory _voteMessages = _msgArr.toBatchVotes();
        for(uint i = 0; i < _voteMessages.length; i ++) {
            _applyVote(_voteMessages[i]);
        }
    }

    function challenge(bytes32 _checkpointHash) external payable {
        // Should send exact amount of stake for the challenge
        require(msg.value >= minimumBond, "Send the exact amount of stake");
        Casper.Checkpoint storage _checkpointToAccuse = checkpoints[_checkpointHash];
        Casper.Checkpoint memory _finalizedCheckpoint = checkpoints[finalizedCheckpoint];
        require(_finalizedCheckpoint.epochNum < _checkpointToAccuse.epochNum, "Can not be challenged");
        require(_checkpointToAccuse.justified);
        _checkpointToAccuse.accused = true;
        emit Epoch(
            _checkpointToAccuse.epochNum, 
            _checkpointHash, 
            _checkpointToAccuse.justified, 
            _checkpointToAccuse.accused, 
            _checkpointToAccuse.finalized 
        );
    }

    function justify(bytes32 _checkpointHash) external {
        Casper.Checkpoint storage _checkpoint = checkpoints[_checkpointHash];
        if(_checkpoint.justified) return;

        // Checkpoint should be out of disputing period
        require(_checkpoint.timestamp + challengePeriod < now, "Still in dispute period");

        // apply stitching mechanism
        uint256 _foreStake;
        uint256 _rearStake;
        Casper.Validator memory _validator;
        for(uint i = 0; i < 256 && i < validatorList.length - 1; i++) {
            // Start to slash validator backwards
            if(_checkpoint.votes.has(uint8(i)) && !slashedIds.has(uint8(i))) {
                _validator = validators[validatorList[i]];
                if(_isForeValidator(_validator)) {
                    _foreStake += _validator.stake;
                }
                if(_isRearValidator(_validator)) {
                    _rearStake += _validator.stake;
                }
            }
        }
        require(_foreStake >= (totalStake / 3) * 2, "Fore-validation failed");
        require(_rearStake >= (totalStake / 3) * 2, "Rear-validation failed");

        // Change the current checkpoint as justified
        _checkpoint.justified = true;
        emit Epoch(_checkpoint.epochNum, _checkpointHash, _checkpoint.justified, _checkpoint.accused, _checkpoint.finalized);

        // Try to finalize the parent checkpoint if the direct parent is also justified
        Casper.Checkpoint storage _parent = checkpoints[_checkpoint.parent];  
        if(_parent.justified) {
            _finalize(_parent);
        }
    }

    function slash(bytes calldata _vote1, bytes calldata _vote2) external {
        Casper.VoteMsg memory _voteMsg1 = _vote1.toVote();
        Casper.VoteMsg memory _voteMsg2 = _vote2.toVote();
        require(_voteMsg1.signer == _voteMsg2.signer);

        bool slashable;
        if(_voteMsg1.targetEpoch == _voteMsg2.targetEpoch) {
            // Check double vote
            slashable = true;
        } else if(_voteMsg1.targetEpoch > _voteMsg2.targetEpoch && _voteMsg1.sourceEpoch < _voteMsg2.sourceEpoch) {
            // Check vote1 surrounds vote2
            slashable = true;
        } else if(_voteMsg2.targetEpoch > _voteMsg1.targetEpoch && _voteMsg2.sourceEpoch < _voteMsg1.sourceEpoch) {
            // Check vote2 surrounds vote1
            slashable = true;
        }

        if(slashable) {
            _slashValidator(_voteMsg1.signer);
        }
    }

    function isValidator(address _validatorAddress) external view returns (bool) {
        return _isValidator(_validatorAddress);
    }

    function isWithdrawable(address _validatorAddress) external view returns (bool) {
        return _isWithdrawable(_validatorAddress);
    }

    function difficultyOf(bytes32 _parent, address _proposer) external view returns (uint256) {
        return _difficultyOf(_parent, _proposer);
    }

    function rewardFor(bytes32 _parent, address _proposer) external view returns (uint256) {
        return _rewardFor(_parent, _proposer);
    }

    function priorityOf(bytes32 _parent, address _proposer) external view returns (uint8) {
        return _priorityOf(_parent, _proposer);
    }

    function proofOfWork(address _proposer, bytes32 _parent, bytes32 _state, uint256 _epochNum, uint256 _nonce) external view returns (bool) {
        return _proofOfWork(_proposer, _parent, _state, _epochNum,_nonce);
    }


    function _isValidator(address _validatorAddress) internal view returns (bool) {
        Casper.Validator storage _validator = validators[_validatorAddress];
        if(_validator.addr == address(0)) return false;
        return _isForeValidator(_validator) || _isRearValidator(_validator);
    }


    function _isWithdrawable(address _validatorAddress) internal view returns (bool) {
        Casper.Validator storage validator = validators[_validatorAddress];
        return validator.endDynasty <= dynastyNum && validator.withdrawable != 0 && validator.withdrawable < now && !slashed[_validatorAddress];
    }

    function _difficultyOf(bytes32 _parent, address _proposer) internal view returns (uint256) {
        uint8 _priority = _priorityOf(_parent, _proposer);
        return uint256(bytes32(uint256(0) - 1) >> 4 * _priority);
    }


    function _rewardFor(bytes32 _parent, address _proposer) internal view returns (uint256){
        uint256 reward = MAXIMUM_REWARD >> _priorityOf(_parent, _proposer);
        return reward;
    }

    function _priorityOf(bytes32 _parent, address _proposer) internal view returns (uint8) {
        Casper.Checkpoint memory parentCheckpoint = checkpoints[_parent];
        // It should have own randomness value
        require(parentCheckpoint.randomness != bytes32(0));

        // Get the starting point
        uint8 _startingPoint = parentCheckpoint.getStartingPoint(uint8(validatorList.length));

        // Get the order of the proposer
        Casper.Validator memory _validator = validators[_proposer];
        require(_validator.isInitialized());

        // Use underflow & overflow
        uint8 _priority;
        if(_validator.id >= _startingPoint) {
            _priority = _validator.id - _startingPoint;
        } else {
            _priority = uint8(validatorList.length) + _validator.id - _startingPoint;
        }
        return _priority;
    }

    function _proofOfWork(
        address _proposer,
        bytes32 _parent,
        bytes32 _state,
        uint256 _epochNum,
        uint256 _nonce
    ) internal view returns (bool) {
        bytes32 _root = keccak256(
            abi.encodePacked(
            _proposer,
            _parent,
            _state,
            _epochNum,
            _nonce)
        );
        bytes32 _randomness = checkpoints[_parent].randomness;
        return uint256(keccak256(abi.encodePacked(_root, _randomness))) < _difficultyOf(_parent, _proposer);
    }

    function _applyVote(Casper.VoteMsg memory _vote) internal {
        // Check the input param validity
        Casper.Checkpoint storage _source = checkpoints[_vote.source];
        Casper.Checkpoint storage _target = checkpoints[_vote.target];
        require(_source.epochNum == _vote.sourceEpoch, "Invalid source epoch");
        require(_source.justified, "Source is not justified");
        require(_target.epochNum == _vote.targetEpoch, "Invalid target epoch");

        Casper.Validator storage _validator = validators[_vote.signer];
        // The signer should be a validator
        require(_isValidator(_validator.addr));

        // Not able to vote for same height checkpoint
        require(!votes[_vote.targetEpoch].has(_validator.id), "Already voted");

        // Record the vote
        votes[_vote.targetEpoch] = votes[_vote.targetEpoch].append(_validator.id);
        _target.votes = _target.votes.append(_validator.id);

        // Record reward
        uint256 reward = _rewardFor(_target.parent, _target.proposer);
        _validator.reward += reward;
        // TODO mint token

        // Emit vote event
        emit Vote(_vote.signer, _vote.target, _vote.targetEpoch, _vote.sourceEpoch);
    }

    function _slashInvalidCheckPoint(Casper.Checkpoint storage _checkpoint) internal {
        _checkpoint.slashed = true;
        for(uint i = 0; i < 256 && i < validatorList.length - 1; i++) {
            // Start to slash validator backwards
            if(_checkpoint.votes.has(uint8(i))) {
                _slashValidator(validatorList[i]);
            }
        }
        slashedIds |= _checkpoint.votes;
    }

    function _slashValidator(address _addr) internal returns (bool){
        if(slashed[_addr]) {
            // Already slashed
            return false;
        }

        Casper.Validator storage _validator = validators[_addr];
        // Give all stake to the slasher
        msg.sender.transfer(_validator.stake);
        // Add to the blacklist
        slashed[_addr] = true;
        // Remove the information
        totalStake -= _validator.stake;
        _validator.stake = 0;
        _validator.slashed = true;
    }

    function _finalize(Casper.Checkpoint memory _checkpoint) internal {
        // Give rewards 
        // 1. using bloom filter => if exist give reward (lucky drop may exist)
        // 2. do while it discover the former finalized block
        // Conditions 1. There should be no checkpoint in dispute among its ancestors
        // 2. It should be justified
        // 3. Its direct parent also should be justified

        require(_checkpoint.justified);
        // Assure that there's no ancestor block in dispute
        bool disputingBranch = false;
        Casper.Checkpoint memory ancestor = _checkpoint;
        while(!ancestor.finalized) {
            if(ancestor.accused) {
                disputingBranch = true;
                break;
            }
            ancestor = checkpoints[ancestor.parent];
            //TODO genesis checkpoint should be justified & finalized
        }

        // It can be finalized when only the branch is not in dispute
        if(!disputingBranch) {
            Casper.Checkpoint storage _parent = checkpoints[_checkpoint.parent];
            _parent.finalized = true;
            finalizedCheckpoint = _checkpoint.parent;
            emit Epoch(_parent.epochNum, _checkpoint.parent, _parent.justified, _parent.accused, _parent.finalized);

            // increase dynasty
            _increaseDynasty();
            emit Dynasty(dynastyNum, _checkpoint.parent);
        }
    }

    function _isForeValidator(Casper.Validator memory _validator) internal view returns (bool) {
        if(_validator.addr == address(0)) return false;
        return _validator.startDynasty <= dynastyNum && dynastyNum < _validator.endDynasty && !slashed[_validator.addr];
    }

    function _isRearValidator(Casper.Validator memory _validator) internal view returns (bool) {
        if(_validator.addr == address(0)) return false;
        return _validator.startDynasty < dynastyNum && dynastyNum <= _validator.endDynasty && !slashed[_validator.addr];
    }

    function _newRandomness() internal view returns(bytes32) {
        return keccak256(
            abi.encodePacked(
                block.timestamp, 
                block.coinbase, 
                blockhash(block.number -1))
        );
    }

    /**
     * @dev This increases dynasty and update validator list
     */
    function _increaseDynasty() internal {
        // If any checkpoint has been slashed during current dynasty
        if(slashedIds != 0) {
            // Gather the slashed addresses
            address[] memory _slashedValidators = new address[](256);
            uint8 _count = 0;
            for(uint i = 0; i < 256 && i < validatorList.length - 1; i++) {
                if(slashedIds.has(uint8(i))) {
                    _slashedValidators[_count] = validatorList[i];
                    _count++;
                }
            }
            // Remove the gathered addresses from the validator set
            Casper.Validator memory _validator;
            while(_count != 0) {
                _count--;
                _validator = validators[_slashedValidators[_count]];
                _removeFromValidatorSet(_validator);
            }
            // Reset slashed id filter
            slashedIds = 0;
        }


        // Increase dynasty
        dynastyNum++;

        // Deactivate validators
        address[] storage _exiters = exitingQueue[dynastyNum];
        for(uint i = 0; i < _exiters.length; i++) {
            _deactivateValidator(_exiters[i]);
        }
        delete exitingQueue[dynastyNum];

        // Activate validators
        address[] storage _newValidators = validatorQueue[dynastyNum];
        for(uint j = 0; j < _newValidators.length; j++) {
            _activateValidator(_newValidators[j]);
        }
        delete validatorQueue[dynastyNum];
    }

    /**
     * @dev This function pushes the address into the current vaildator list
     */
    function _activateValidator(address _validator) internal {
        require(validatorList.length < 256); // uint8
        Casper.Validator storage _validatorToAdd = validators[_validator];
        // Add to the validator list
        validatorList.push(_validator);
        // Set id as the index in the list
        _validatorToAdd.id = uint8(validatorList.length - 1);
        // Increase the total stake
        totalStake += _validatorToAdd.stake;
    }

    /**
     * @dev This function removes the address from the current vaildator list
     */
    function _deactivateValidator(address _validator) internal {
        Casper.Validator storage _validatorToPop = validators[_validator];
        // It should be able to be removed from the validator after the end dynasty
        require(_validatorToPop.endDynasty <= dynastyNum);
        // Set withdrawable time
        _validatorToPop.withdrawable = now + withdrawalDelay;
        // Remove from the validator set
        _removeFromValidatorSet(_validatorToPop);
    }

    function _removeFromValidatorSet(Casper.Validator memory _validator) internal {
        // Decrease the total stake
        totalStake -= _validator.stake;

        // Delete the validator address from the validator list and shrink the list
        if(_validator.id == validatorList.length - 1) {
            // When the item to remove is the last item
            delete validatorList[_validator.id];
        } else {
            // Replace the item to remove with the last item
            address _lastValidator = validatorList[validatorList.length - 1];
            validatorList[_validator.id] = _lastValidator;
            validators[_lastValidator].id = _validator.id;
            // Delete the last item
            delete validatorList[validatorList.length - 1];
        }
        validatorList.length --;

        // Delete the details of the validator
        delete validators[_validator.addr];
    }
}
