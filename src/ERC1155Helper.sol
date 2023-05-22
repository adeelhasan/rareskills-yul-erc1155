pragma solidity 0.8.15;

interface IERC1155 {
    function owner() external returns (address);
    function setUri(string memory value) external;
    function uri() external returns (string memory result);

    function balanceOf(address tokenOwner, uint256 tokenId) external returns (uint256);
    function balanceOfBatch(address[] memory account, uint256[] memory ids) external returns (uint256[] memory);

    function mint(address to, uint256 tokenId, uint256 amount) external;
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external;

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external;
    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external;

}

contract ERC1155Helper {
    IERC1155 public target;
    constructor(IERC1155 _target) {
        target = _target;
        
    }
    function owner() external returns (address) {
        return target.owner();
    }

    function balanceOf(address tokenOwner, uint256 tokenId) external returns (uint256) {
        return target.balanceOf(tokenOwner, tokenId);
    }

    function mint(address to, uint256 tokenId, uint256 amount) external {
        target.mint(to, tokenId, amount);
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
}

