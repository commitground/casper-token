pragma solidity >=0.4.21 < 0.6.0;

interface IERC1XXX /* is IERC20 */{

    /**
     * @dev Push the message sender to the waiting list for the *d+2* dynasty
     *      if the sender sends more than designated minimum amount of ether.
     *      Later, it should allow ERC20 tokens instead of ether.
     */
    function deposit() external payable;

    /**
     * @dev Register the message sender to the exit queue for the *d+2* dynasty
     *      if the validator set includes the message sender.
     */
    function requestWithdraw() external;

    /**
     * @dev If there's no slash during its withdrawal delay period,
     *      the message sender can withdraw the staked ether.
     */
    function withdraw() external;

    /**
     * @dev An operator can submit a checkpoint with proof of work. The difficulty of the
     *      proof of work is exponential to the message sender's priority
     *      which is decided by the parent checkpoint.
     */
    function propose(
        bytes32 _parent,
        bytes32 _state,
        uint256 _epochNum,
        uint256 _nonce
    ) external ;

    /**
     * @dev Anyone can apply published vote messages by the validators.
     *      The message is a byte array which length is 193 and it contains source hash,
     *      target hash, source epoch number, target epoch number, and the signature.
     *      kIt mints token as many as the checkpoint's priority and transfer them to the
     *      voter.
     */
    function vote(bytes calldata _msg) external;

    /**
     * @dev Several vote messages can be applied at once.
     */
    function batchVote(bytes calldata _msgArr) external;

    /**
     * @dev Anyone can raise a challenge process staking a designated amount of bond.
     */
    function challenge(bytes32 _checkpointHash) external payable;

    /**
     * @dev Anyone can change the state of a checkpoint from submitted to justified
     *      if it secures more than two third of the total stake.
     *      The message sender gets rewarded with newly minted token.
     */
    function justify(bytes32 _checkpointHash) external;

    /**
     * @dev If a validator published double votes or surrond votes,
     *      anyone can punish the validator and get rewards
     */
    function slash(bytes calldata _vote1, bytes calldata _vote2) external;

    /**
     * @dev Returns whether the `validatorAddress` is validator or not
     */
    function isValidator(address _validatorAddress) external view returns (bool);

    /**
     * @dev Returns whether the validator with the address can withdraw its stake or not.
     *      It returns true if the validator is never slashed and out of withdrawal delay
     *      period.
     */
    function isWithdrawable(address _validatorAddress) external view returns (bool);

    /**
     * @dev Returns the difficulty of proposing a new child checkpoint for the `_parent`
     *      value.
     *      It differs by the proposer and the parent hash.
     */
    function difficultyOf(
        bytes32 _parent,
        address _proposer
    ) external view returns (uint256);

    /**
     * @dev Returns the amount of reward for validation. It is exponentially proportional
     *      to the priority of the checkpoint proposer.
     */
    function rewardFor(
        bytes32 _parent,
        address _proposer
    ) external view returns (uint256);

    /**
     * @dev Returns the priority to propose a new checkpoint agaisnt the parent
     *      checkpoint.
     */
    function priorityOf(bytes32 _parent, address _proposer) external view returns (uint8);

    /**
     * @dev Returns whether the nonce value for the priority exponential proof of work is
     *      correct or not.
     */
    function proofOfWork(
        address _proposer,
        bytes32 _parent,
        bytes32 _state,
        uint256 _epochNum,
        uint256 _nonce
    ) external view returns (bool);
    
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
