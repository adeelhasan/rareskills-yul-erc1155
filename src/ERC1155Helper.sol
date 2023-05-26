pragma solidity 0.8.15;

interface IERC1155 {
    function owner() external returns (address);
    function setUri(string memory value) external;
    function uri() external returns (string memory result);

    function balanceOf(address account, uint256 id) external returns (uint256);
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids) external returns (uint256[] memory);

    function mint(address to, uint256 id, uint256 amount) external;
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external;

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external;
    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external;

    function isApprovedForAll(address account, address operator) external returns (bool);
    function setApprovalForAll(address operator, bool approved) external;

    function burn(address from, uint256 id, uint256 amount) external;
    function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) external;
}

contract ERC1155Helper {
    IERC1155 public target;
    constructor(IERC1155 _target) {
        target = _target;
        
    }
    function owner() external returns (address) {
        return target.owner();
    }

    function balanceOf(address owner_, uint256 id) external returns (uint256) {
        return target.balanceOf(owner_, id);
    }

    function mint(address to, uint256 id, uint256 amount) external {
        target.mint(to, id, amount);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external {
        target.mintBatch(to, ids, amounts, data);
    }

    function setUri(string memory value) external {
        target.setUri(value);
    }

    function uri() external returns (string memory result) {
        result = target.uri();
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) public {
        target.safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public{
        target.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function setApprovalForAll(address operator, bool approved) external {
        target.setApprovalForAll(operator, approved);
    }

    function isApprovedForAll(address account, address operator) external returns (bool) {
        return target.isApprovedForAll(account, operator);
    }

    function balanceOfBatch(address[] memory accounts, uint256[] memory ids) external returns (uint256[] memory) {
        return target.balanceOfBatch(accounts, ids);
    }

    function burn(address from, uint256 id, uint256 amount) external {
        target.burn(from, id, amount);
    }

    function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) external {
        target.burnBatch(from, ids, amounts);
    }

}

