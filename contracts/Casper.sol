pragma solidity >=0.4.21 < 0.6.0;

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
