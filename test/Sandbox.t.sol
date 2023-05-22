// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "./lib/YulDeployer.sol";
import "src/SandboxHelper.sol";

contract SandboxTest is Test {
    YulDeployer yulDeployer = new YulDeployer();

    SandboxHelper sh;

    function setUp() public {
        //s = Sandbox(yulDeployer.deployContract("Sandbox"));
        sh = new SandboxHelper(ISandbox(address(yulDeployer.deployContract("Sandbox"))));
    }

    function testPreDefinedString() public {
        string memory result = sh.getPreDefinedString();
        require(keccak256(abi.encodePacked(result)) == keccak256(abi.encodePacked("new string")), "string not as expected");
    }

    function testRevertWithCustomString() public {
        vm.expectRevert(bytes("my error string"));
        sh.revertWithString();
    }

    function testStoredString() public {
        //string memory testString = "this is my string and it gets longer and longer and longer than necessary wouldnt you say so and so and so";
        //string memory testString = "abcdef12345abcdef12345abc12345613";
        //console.log("testing");
        //sh.setString(testString);
        //string memory result = sh.getStoredString();
        //require(keccak256(abi.encodePacked(result)) == keccak256(abi.encodePacked(testString)), "string didn't match");
    }

    function testExponent() public {
        require(sh.power(2, 3) == 8, "exponent not as expected");

/*         bytes memory callDataBytes = abi.encodeWithSignature("power(uint256,uint256)", 2, 3);
        (bool success, bytes memory data) = address(exampleContract).call{gas: 100000, value: 0}(callDataBytes);
        uint256 result = abi.decode(data, (uint256));
        assertEq(result, 8);
 */    }
}
