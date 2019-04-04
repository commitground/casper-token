pragma solidity >=0.4.21 < 0.6.0;

interface IERC1XXX /* is IERC20 */{ 
    function deposit() external payable;

    function requestWithdraw() external;

    function withdraw() external;

    function propose(bytes32 _parent, bytes32 _state, uint256 _epochNum, uint256 _nonce) external ;

    function vote(bytes calldata _msg) external;

    function directVote(bytes32 _source, bytes32 _target, uint256 _sourceEpoch, uint256 _targetEpoch) external;
   
    function batchVote(bytes calldata _msgArr) external;

    function challenge(bytes32 _checkpointHash) external payable;

    function justify(bytes32 _checkpointHash) external;

    function slash(bytes calldata _vote1, bytes calldata _vote2) external;

    function isValidator(address _validatorAddress) external view returns (bool);

    function isWithdrawable(address _validatorAddress) external view returns (bool);

    function difficultyOf(bytes32 _parent, address _proposer) external view returns (uint256);

    function rewardFor(bytes32 _parent, address _proposer) external view returns (uint256);

    function priorityOf(bytes32 _parent, address _proposer) external view returns (uint8);

    function proofOfWork(address _proposer, bytes32 _parent, bytes32 _state, uint256 _epochNum, uint256 _nonce) external view returns (bool);
    
    event Deposit(
        address indexed _from,
        uint256 _startDynasty,
        uint256 _amount
    ); // amount: wei

    event Vote(
        address indexed _from,
        bytes32 indexed _targetHash,
        uint256 _targetEpoch,
        uint256 _sourceEpoch
    );

    event Logout(
        address indexed _from,
        uint256 _endDynasty
    );

    event Withdraw(
        address indexed _to,
        uint256 _amount
    ); // amount: wei

    event Slash(
        address indexed _from,
        address indexed _offender,
        uint256 indexed _offenderIndex,
        uint256 _bounty
    ); // bounty: wei 

    event Epoch(
        uint256 indexed _number,
        bytes32 indexed _checkpointHash,
        bool _isJustified,
        bool _isChallenged,
        bool _isFinalized
    );

    event Dynasty(
        uint256 indexed _number,
        bytes32 indexed _checkpointHash
    );

}
