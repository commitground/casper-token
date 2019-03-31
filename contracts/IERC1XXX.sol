pragma solidity >=0.4.21 < 0.6.0;

interface IERC1XXX {

    function propose(bytes32 _parent, bytes32 _block, uint256 _nonce) external;

    function participate() external payable;

    function validate(bytes32 targetHash) external;

    function randomness() external view returns (bytes32);
}
