/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTMarket {
    /// an NFT selling order
    struct Order {
        // a token to pay for the NFT
        IERC20 paymentToken;
        // how much to pay in exchange for NFT
        uint256 value;
        // ERC721 tokenId (collection is fixed in the contract)
        uint256 nftId;
        // random word
        uint256 nonce;
        // always true
        bool sellNFT;
        // signer.signMessage(toEthSignedMessageHash(hash(paymentToken, value, nftId, nonce, sellNFT)))
        bytes signature;
    }
    /// ERC721 NFT collection
    IERC721 public collection;

    /// active NFT selling orders
    Order[] public orders;

    /// replay attacks are forbidden!
    mapping(bytes => bool) public usedSignatures;

    constructor(IERC721 _collection) {
        collection = _collection;
    }

    /**
     * Add a new NFT selling order
     *
     * This method is intended for off-chain signatures.
     * You don't need to spend gas. You can prepare an order,
     * sign it, and send this data for free to our site,
     * and we will add this data to the blockchain for you.
     *
     * NOTE: signature uses "...Ethereum signed..." prefix and follows the format:
     * sign(toEthSignedMessageHash(hash(paymentToken, value, nftId, nonce, sellNFT)))
     *
     * NOTE: web3.js and ethers.js are using the prefix by default, so you don't need to add it.
     *
     * WARNING: do not forget to `approve()`
     */
    function sell(Order calldata order) external {
        require(collection.getApproved(order.nftId) == address(this), "NFT_IS_NOT_APPROVED_FOR_MARKET");
        require(ownerOf(order) != address(0), "INCORRECT_SIGNATURE");
        require(ownerOf(order) == collection.ownerOf(order.nftId), "ADD_INCORRECT_NFT_OWNER");
        require(!usedSignatures[order.signature], "USED_SIGNATURE");
        usedSignatures[order.signature] = true;
        orders.push(order);
    }

    /**
     * Buy NFT from a selling order.
     *
     * WARNING: do not forget to `approve()`
     */
    function buy(uint256 orderIndex) external {
        Order storage order = orders[orderIndex];
        require(ownerOf(order) == collection.ownerOf(order.nftId), "EXECUTE_INCORRECT_NFT_OWNER");
        order.paymentToken.transferFrom(msg.sender, ownerOf(order), order.value);
        collection.transferFrom(ownerOf(order), msg.sender, order.nftId);
        _remove(orderIndex);
    }

    /// Remove the order from queue
    function cancel(uint256 orderIndex) external {
        require(msg.sender == ownerOf(orderIndex) || tx.origin == ownerOf(orderIndex), "ONLY_SIGNER_ALLOWED");
        _remove(orderIndex);
    }

    /// Count number of active orders
    function count() external view returns (uint256) {
        return orders.length;
    }

    /// Get the signer address of the order
    function ownerOf(uint256 orderIndex) public view returns (address) {
        return ownerOf(orders[orderIndex]);
    }

    /**
     * Extract public address from the order signature.
     *
     * Note: the order can be added by any address, not only the signer.
     */
    function ownerOf(Order memory order) public pure returns (address) {
        return recover(toEthSignedMessageHash(hash(order)), order.signature);
    }

    /**
     * Hash the order before getting its signature.
     *
     * Warning: this hash doesn't contain "...Ethereum Signed..." prefix!
     */
    function hash(Order memory order) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    address(order.paymentToken),
                    order.value,
                    order.nftId,
                    order.nonce,
                    order.sellNFT
                    //
                )
            );
    }

    function recover(bytes32 hash_, bytes memory signature) public pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        return ecrecover(hash_, v, r, s);
    }

    function toEthSignedMessageHash(bytes32 hash_) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash_));
    }

    function _remove(uint256 orderIndex) private {
        orders[orderIndex] = orders[orders.length - 1];
        orders.pop();
    }
}