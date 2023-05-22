// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "src/ERC1155Helper.sol";
import "./lib/YulDeployer.sol";

interface ERC1155 {}

contract ERC1155Test is Test {
    YulDeployer yulDeployer = new YulDeployer();

    ERC1155 c;
    ERC1155Helper ch;

    address testAccount1;
    address testAccount2;
    address testAccount3;

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event URI(string _value, uint256 indexed _id);

    function setUp() public {
        c = ERC1155(yulDeployer.deployContract("ERC1155"));
        ch = new ERC1155Helper(IERC1155(address(c)));

        testAccount1 = vm.addr(0xABCD);
        testAccount2 = vm.addr(0xBCDA);
        testAccount3 = vm.addr(0xCDAB);

    }

    function testOwnership() public {
        require(ch.owner() == address(yulDeployer), "ownership check failed");
    }

    function testMintSingle() public {
        address owner = address(yulDeployer);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(owner, address(0), address(this), 1, 20);

        ch.mint(address(this), 1, 20);

        uint256 balance = ch.balanceOf(address(this), 1);
        require(balance == 20, "balance not as expected");
    }

    uint256[] ids = [1, 2, 3];
    uint256[] amounts = [10, 20, 30];    //
    function testMintBatch() public {
        
        bytes memory data = "";

        ch.mintBatch(testAccount1, ids, amounts, data);
        require(ch.balanceOf(testAccount1, 1) == 10, "balance not as expected");
        require(ch.balanceOf(testAccount1, 2) == 20, "balance not as expected");
        require(ch.balanceOf(testAccount1, 3) == 30, "balance not as expected");

    }

    function testSafeTransferFrom() public {

        ch.mint(testAccount1, 1, 20);

        vm.prank(testAccount1);
        ch.safeTransferFrom(testAccount1, testAccount2, 1, 10, "");

        require(ch.balanceOf(testAccount2, 1) == 10, "balance not as expected");

    }

    //test mint with a receiver check
    //test transfer with a receiver check
    // why is the event URI skipped in implementations? 
    function testUri() public {
        string memory uri = "http://www.merrygoaround.com";
        // vm.expectEmit(true, false, true, false);
        // emit URI(uri, 1);
        ch.setUri(uri);

        string memory result = ch.uri();
        require(keccak256(abi.encodePacked(result)) == keccak256(abi.encodePacked(uri)), "string not as expected");
    }


    function testBalance() public {
        // uint256 balance = ch.balanceOf(address(this),1);
        // require(balance > 0, "balance was unexpected");
    }

}


        // bytes memory callDataBytes = abi.encodeWithSignature("mint()");
        // (bool success, bytes memory data) = address(c).call{gas: 100000, value: 0}(callDataBytes);
        // require(success,"mint failed");
        // callDataBytes = abi.encodeWithSignature("balanceOf()");
        // (success, data) = address(c).call{gas: 100000, value: 0}(callDataBytes);
        // uint256 result = abi.decode(data, (uint256));
        // assertEq(result, 2);

        //console.logBytes(data);
