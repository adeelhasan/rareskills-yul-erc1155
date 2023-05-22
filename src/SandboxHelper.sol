pragma solidity 0.8.15;

interface ISandbox {
    function power(uint256 x, uint256 exp) external returns (uint256 result);
    function getPreDefinedString() external returns (string memory);
    function revertWithString() external;
    function setString(string memory stringToStore) external;
    function getStoredString() external returns (string memory);
}

contract SandboxHelper {
    ISandbox public target;
    constructor(ISandbox _target) {
        target = _target;
    }

    function getPreDefinedString() external returns (string memory) {
        return target.getPreDefinedString();
    }

    function revertWithString() external {
        target.revertWithString();
    }

    function setString(string memory stringToStore) external {
        target.setString(stringToStore);
    }

    function getStoredString() external returns (string memory) {
        return target.getStoredString();
    }

    function power(uint256 x, uint256 exp) external returns (uint256 result){
        result = target.power(x, exp);
    }
}

