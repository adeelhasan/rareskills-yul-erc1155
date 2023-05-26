// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "src/ERC1155Helper.sol";
import "./lib/YulDeployer.sol";
import "lib/solmate/src/tokens/ERC1155.sol";


//copied from 
contract ReceiverHelper is ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }    

    function grantApprovalForAllTo(address erc1155Contract, address operator, bool approved) public {
        ERC1155(erc1155Contract).setApprovalForAll(operator, approved);
    }
}

contract NonReceiverHelper {}

contract ERC1155Test is Test {
    YulDeployer yulDeployer = new YulDeployer();

    IERC1155 c;
    ERC1155Helper ch;

    address testAccount1;
    address testAccount2;
    address testAccount3;

    ReceiverHelper receiverContract;
    address receiverContractAddress; 
    
    uint256[] ids = [1, 2, 3];
    uint256[] amounts = [10, 20, 30];

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event URI(string _value, uint256 indexed _id);

    function setUp() public {
        c = IERC1155(yulDeployer.deployContract("ERC1155"));
        ch = new ERC1155Helper(c);

        testAccount1 = vm.addr(0xABCD);
        testAccount2 = vm.addr(0xBCDA);
        testAccount3 = vm.addr(0xCDAB);

        receiverContract = new ReceiverHelper();
        receiverContractAddress = address(receiverContract);
    }

    function testOwnership() public {
        require(ch.owner() == address(yulDeployer), "ownership check failed");
    }

    function testMintSingle() public {
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(yulDeployer), address(0), testAccount1, 1, 20);

        ch.mint(testAccount1, 1, 20);

        uint256 balance = ch.balanceOf(testAccount1, 1);
        require(balance == 20, "balance not as expected");
    }

    function testMintBatch() public {
        
        bytes memory data = "";

        ch.mintBatch(testAccount1, ids, amounts, data);
        require(ch.balanceOf(testAccount1, 1) == 10, "balance not as expected");
        require(ch.balanceOf(testAccount1, 2) == 20, "balance not as expected");
        require(ch.balanceOf(testAccount1, 3) == 30, "balance not as expected");

    }

    function testSafeTransferToEOA() public {
        ch.mint(testAccount1, 1, 20);
        vm.prank(testAccount1);
        ch.safeTransferFrom(testAccount1, testAccount2, 1, 10, "");
        require(ch.balanceOf(testAccount2, 1) == 10, "balance not as expected");
    }

    function testSafeTransferToContract() public {
        ch.mint(testAccount1, 1, 20);
        vm.prank(testAccount1);
        ch.safeTransferFrom(testAccount1, receiverContractAddress, 1, 10, "");
        require(ch.balanceOf(receiverContractAddress, 1) == 10, "balance not as expected");
    }

    function testSafeTransferBatchToEOA() public {
        ch.mint(testAccount1, 1, 20);
        ch.mint(testAccount1, 2, 40);
        ch.mint(testAccount1, 3, 60);
        ch.safeBatchTransferFrom(testAccount1, testAccount2, ids, amounts, "");
        require(ch.balanceOf(testAccount2, 1) == 10, "balance not as expected");
        require(ch.balanceOf(testAccount2, 2) == 20, "balance not as expected");
        require(ch.balanceOf(testAccount2, 3) == 30, "balance not as expected");
    }

    function testMintToContract() public {
         ch.mint(receiverContractAddress, 1, 20);
        require(ch.balanceOf(receiverContractAddress, 1) == 20, "balance not as expected");
    }

    function testSafeTransferBatchToContract() public {
        ch.mint(testAccount1, 1, 20);
        ch.mint(testAccount1, 2, 40);
        ch.mint(testAccount1, 3, 60);
        ch.safeBatchTransferFrom(testAccount1, receiverContractAddress, ids, amounts, "");
        require(ch.balanceOf(receiverContractAddress, 1) == 10, "balance not as expected");
        require(ch.balanceOf(receiverContractAddress, 2) == 20, "balance not as expected");
        require(ch.balanceOf(receiverContractAddress, 3) == 30, "balance not as expected");
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


    function testBalanceOfBatch() public {
        ch.mint(testAccount2, 1, 3);
        ch.mint(receiverContractAddress, 5, 7);
        ch.mint(testAccount1, 1000, 29);

        require(ch.balanceOf(testAccount1, 1000) == 29, "not minted correctly");

        uint256 numberOfElements = 3;
        address[] memory accounts = new address[](numberOfElements);
        accounts[0] = testAccount2;
        accounts[1] = receiverContractAddress;
        accounts[2] = testAccount1;
        uint256[] memory ids_ = new uint256[](numberOfElements);
        ids_[0] = 1;
        ids_[1] = 5;
        ids_[2] = 1000;

        uint256[] memory result = ch.balanceOfBatch(accounts, ids_);
        require(result[0] == 3, "balance not as expected");
        require(result[1] == 7, "balance not as expected");
        require(result[2] == 29, "balance not as expected");
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
