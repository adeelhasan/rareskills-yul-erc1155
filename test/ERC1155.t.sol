// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "src/ERC1155Wrapper.sol";
import "./lib/YulDeployer.sol";
import "./lib/ReceiverHelpers.sol";


contract ERC1155Test is Test {
    YulDeployer yulDeployer = new YulDeployer();

    IERC1155 erc1155Contract;
    ERC1155Wrapper contractWrapper;

    address testAccount1;
    address testAccount2;
    address testAccount3;

    ReceiverHelper receiverContract;
    address receiverContractAddress; 
    
    uint256[] ids = [1, 2, 3];
    uint256[] amounts = [10, 20, 30];

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event URI(string _value, uint256 indexed _id);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
    event TransferBatch(address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _values);

    function setUp() public {
        erc1155Contract = IERC1155(yulDeployer.deployContract("ERC1155"));
        contractWrapper = new ERC1155Wrapper(erc1155Contract);

        testAccount1 = vm.addr(0xABCD);
        testAccount2 = vm.addr(0xBCDA);
        testAccount3 = vm.addr(0xCDAB);

        receiverContract = new ReceiverHelper();
        receiverContractAddress = address(receiverContract);

        //make the helper contract an operator for testAccount1
        //need to call the yul contract directly, not through the wrapper
        //as there is no pass through for the immediate contract
        vm.prank(testAccount1);
        bytes memory callDataBytes = abi.encodeWithSignature("setApprovalForAll(address,bool)", address(contractWrapper), true);
        (bool success, ) = address(erc1155Contract).call{gas: 100000, value: 0}(callDataBytes);
        require(success,"approved for all failed");
    }

    function testOwnership() public {
        require(contractWrapper.owner() == address(yulDeployer), "ownership check failed");
    }

    function testMintSingle() public {
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(yulDeployer), address(0), testAccount1, 1, 20);

        contractWrapper.mint(testAccount1, 1, 20);

        uint256 balance = contractWrapper.balanceOf(testAccount1, 1);
        require(balance == 20, "balance not as expected");
    }

    function testMintBatch() public {     
        
        vm.expectEmit(true, true, true, false);
        emit TransferBatch(address(contractWrapper), address(0), testAccount1, ids, amounts);
        
        contractWrapper.mintBatch(testAccount1, ids, amounts, "");
        require(contractWrapper.balanceOf(testAccount1, 1) == 10, "balance not as expected");
        require(contractWrapper.balanceOf(testAccount1, 2) == 20, "balance not as expected");
        require(contractWrapper.balanceOf(testAccount1, 3) == 30, "balance not as expected");
    }

    function testMintBatchToContract() public {     

        vm.expectEmit(true, true, true, false);
        emit TransferBatch(address(contractWrapper), address(0), receiverContractAddress, ids, amounts);
        contractWrapper.mintBatch(receiverContractAddress, ids, amounts, "");

        require(contractWrapper.balanceOf(receiverContractAddress, 1) == 10, "balance not as expected");
        require(contractWrapper.balanceOf(receiverContractAddress, 2) == 20, "balance not as expected");
        require(contractWrapper.balanceOf(receiverContractAddress, 3) == 30, "balance not as expected");
    }

    function testFailMintBatchToNonReceiverContract() public {     
        NonReceiverHelper nonReceiver = new NonReceiverHelper();        
        contractWrapper.mintBatch(address(nonReceiver), ids, amounts, "");
    }

    function expectFailForNonOperatorTransfer() public {
        contractWrapper.mint(testAccount2, 1, 20);

        vm.expectRevert();
        contractWrapper.safeTransferFrom(testAccount2, testAccount2, 1, 10, "");
    }

    function expectFailForNonOperatorBatchTransfer() public {
        contractWrapper.mint(testAccount2, 1, 20);
        contractWrapper.mint(testAccount2, 2, 40);
        contractWrapper.mint(testAccount2, 3, 60);

        contractWrapper.safeBatchTransferFrom(testAccount2, testAccount1, ids, amounts, "");
    }    

    function testSafeTransferToEOA() public {
        contractWrapper.mint(testAccount1, 1, 20);
        contractWrapper.safeTransferFrom(testAccount1, testAccount2, 1, 10, "");
        require(contractWrapper.balanceOf(testAccount2, 1) == 10, "balance not as expected");
    }

    function testSafeTransferToContract() public {
        contractWrapper.mint(testAccount1, 1, 20);        

        vm.prank(testAccount1);
        contractWrapper.safeTransferFrom(testAccount1, receiverContractAddress, 1, 10, "");
        require(contractWrapper.balanceOf(receiverContractAddress, 1) == 10, "balance not as expected");
    }

    function testFailSafeTransferToNonReceiverContract() public {
        contractWrapper.mint(testAccount1, 1, 20);
        NonReceiverHelper nonReceiver = new NonReceiverHelper();

        vm.prank(testAccount1);
        contractWrapper.safeTransferFrom(testAccount1, address(nonReceiver), 1, 10, "");
    }

    function testSafeTransferBatchToEOA() public {
        contractWrapper.mint(testAccount1, 1, 20);
        contractWrapper.mint(testAccount1, 2, 40);
        contractWrapper.mint(testAccount1, 3, 60);

        vm.expectEmit(true, true, true, false);
        emit TransferBatch(address(contractWrapper), testAccount1, testAccount2, ids, amounts);
        contractWrapper.safeBatchTransferFrom(testAccount1, testAccount2, ids, amounts, "");
        require(contractWrapper.balanceOf(testAccount2, 1) == 10, "balance not as expected");
        require(contractWrapper.balanceOf(testAccount2, 2) == 20, "balance not as expected");
        require(contractWrapper.balanceOf(testAccount2, 3) == 30, "balance not as expected");
    }

    function testFailSafeBatchTransferToNonReceiverContract() public {
        contractWrapper.mintBatch(testAccount1, ids, amounts, "");
        NonReceiverHelper nonReceiver = new NonReceiverHelper();

        vm.prank(testAccount1);
        contractWrapper.safeBatchTransferFrom(testAccount1, address(nonReceiver), ids, amounts, "");
    }

    function testMintToContract() public {
         contractWrapper.mint(receiverContractAddress, 1, 20);
        require(contractWrapper.balanceOf(receiverContractAddress, 1) == 20, "balance not as expected");
    }

    function testSafeTransferBatchToContract() public {
        contractWrapper.mint(testAccount1, 1, 20);
        contractWrapper.mint(testAccount1, 2, 40);
        contractWrapper.mint(testAccount1, 3, 60);
        contractWrapper.safeBatchTransferFrom(testAccount1, receiverContractAddress, ids, amounts, "");
        require(contractWrapper.balanceOf(receiverContractAddress, 1) == 10, "balance not as expected");
        require(contractWrapper.balanceOf(receiverContractAddress, 2) == 20, "balance not as expected");
        require(contractWrapper.balanceOf(receiverContractAddress, 3) == 30, "balance not as expected");
    }

    function testUri() public {
        string memory uri = "http://www.merrygoaround.com";
        vm.expectEmit(true, true, false, true);
        emit URI(uri, 0);
        vm.prank(address(yulDeployer));
        bytes memory callDataBytes = abi.encodeWithSignature("setUri(string)", uri);
        (bool success, ) = address(erc1155Contract).call{gas: 100000, value: 0}(callDataBytes);
        require(success, "setUri call failed");

        string memory result = contractWrapper.uri();
        require(keccak256(abi.encodePacked(result)) == keccak256(abi.encodePacked(uri)), "string not as expected");
    }

    function testBalanceOfBatch() public {
        contractWrapper.mint(testAccount2, 1, 3);
        contractWrapper.mint(receiverContractAddress, 5, 7);
        contractWrapper.mint(testAccount1, 1000, 29);

        uint256 numberOfElements = 3;
        address[] memory accounts = new address[](numberOfElements);
        accounts[0] = testAccount2;
        accounts[1] = receiverContractAddress;
        accounts[2] = testAccount1;
        uint256[] memory ids_ = new uint256[](numberOfElements);
        ids_[0] = 1;
        ids_[1] = 5;
        ids_[2] = 1000;

        uint256[] memory result = contractWrapper.balanceOfBatch(accounts, ids_);
        require(result[0] == 3, "balance not as expected");
        require(result[1] == 7, "balance not as expected");
        require(result[2] == 29, "balance not as expected");
    }

    function testBurn() public {
        contractWrapper.mint(testAccount2, 1, 20);

        vm.prank(address(yulDeployer));
        bytes memory callDataBytes = abi.encodeWithSignature("burn(address,uint256,uint256)", testAccount2, 1, 10);
        (bool success, ) = address(erc1155Contract).call{gas: 100000, value: 0}(callDataBytes);
        require(success, "burn failed");

        require(contractWrapper.balanceOf(testAccount2, 1) == 10, "balance not as expected");
    }

    function testBurnBatch() public {
        contractWrapper.mint(testAccount1, 1, 20);
        contractWrapper.mint(testAccount1, 2, 40);
        contractWrapper.mint(testAccount1, 3, 60);

        uint256 numberOfElements = 3;
        uint256[] memory ids_ = new uint256[](numberOfElements);
        ids_[0] = 1;
        ids_[1] = 2;
        ids_[2] = 3;
        uint256[] memory amounts_ = new uint256[](numberOfElements);
        amounts_[0] = 5;
        amounts_[1] = 25;
        amounts_[2] = 33;

        vm.prank(address(yulDeployer));
        bytes memory callDataBytes = abi.encodeWithSignature("burnBatch(address,uint256[],uint256[])", testAccount1, ids_, amounts_);
        (bool success, ) = address(erc1155Contract).call{gas: 100000, value: 0}(callDataBytes);
        require(success, "burn batch failed");

        require(contractWrapper.balanceOf(testAccount1, 1) == 15, "balance not as expected");
        require(contractWrapper.balanceOf(testAccount1, 2) == 15, "balance not as expected");
        require(contractWrapper.balanceOf(testAccount1, 3) == 27, "balance not as expected");
    }

    function testSetApprovalForAll() public {
        contractWrapper.mint(testAccount2, 1, 20);

        vm.expectEmit(true, true, true, true);
        emit ApprovalForAll(testAccount2, address(contractWrapper), true);
        vm.prank(testAccount2);
        bytes memory callDataBytes = abi.encodeWithSignature("setApprovalForAll(address,bool)", address(contractWrapper), true);
        (bool success, ) = address(erc1155Contract).call{gas: 100000, value: 0}(callDataBytes);
        require(success,"approved for all failed");
    }

    function testFailIfTransferingBeyondBalance() public {
        contractWrapper.mint(testAccount1, 1, 10);
        contractWrapper.safeTransferFrom(testAccount1, testAccount2, 1, 11, "");
    }

    function testFailIfTransferingBeyondBalance2() public {
        contractWrapper.safeTransferFrom(testAccount1, testAccount2, 1, 11, "");
    }

    function testFailBatchTransferBeyondBalance() public {
        contractWrapper.mint(testAccount1, 1, 20);
        contractWrapper.mint(testAccount1, 2, 19);
        contractWrapper.mint(testAccount1, 3, 60);

        contractWrapper.safeBatchTransferFrom(testAccount1, testAccount2, ids, amounts, "");
    }

    function testFailBurnBeyondBalance() public {
        contractWrapper.mint(testAccount2, 1, 20);

        vm.prank(address(yulDeployer));
        bytes memory callDataBytes = abi.encodeWithSignature("burn(address,uint256,uint256)", testAccount2, 1, 40);
        (bool success, ) = address(erc1155Contract).call{gas: 100000, value: 0}(callDataBytes);
        require(success, "burn failed");
    }    

}

