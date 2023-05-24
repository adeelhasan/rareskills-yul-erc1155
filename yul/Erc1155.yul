object "ERC1155" {
    code {

        sstore(0,caller())
        datacopy(0, dataoffset("Runtime"), datasize("Runtime"))
        return(0, datasize("Runtime"))
    }
    object "Runtime" {

        //ownership check
        //name storage
        //mint across address, id
        //  emit Event
        //balance check
        //burn
        //batch operations


        code {
            // Protection against sending Ether
            require(iszero(callvalue()))

            // Dispatcher
            switch selector()
                case 0x8da5cb5b {   //owner
                    returnUint(owner())
                }
                case 0x156e29f6 {    //mint
                    mint(decodeAsAddress(0),decodeAsUint(1),decodeAsUint(2))
                }
                case 0x00fdd58e {    //balanceOf
                    returnUint(balanceOf(decodeAsAddress(0),decodeAsUint(1)))
                }
                case 0x1f7fdffa {   //mintBatch(address, uint256[] ids, uint256[] amounts, bytes)
                    mintBatch()
                }
                case 0x9b642de1 {   //setUri
                    setUri(0x24)
                }
                case 0xeac989f8 { 
                    uri()
                }
                case 0xf242432a {
                    safeTransferFrom()
                }
                case 0x2eb2c2d6 {
                    safeBatchTransferFrom()
                }
                case 0x4e1273f4 {
                    balanceOfBatch()
                }

                default {
                    //revert(0, 0)
                    revertWithReason("unimplemented selector", 22)
                }

            function setUri(lengthOffset) {
                //require(calledByOwner())

                storeStringFromCallData(slotNoForUriLength(), lengthOffset)

                //emit uri event                
            }

            function uri() {
                getStoredString(slotNoForUriLength())
            }

            function addToTokenBalance(ownerOfToken, tokenId, amount) {
                //logToConsole(0x00, "adding", 6)
                let slotForToken := balancesByTokenSlot(ownerOfToken, tokenId)
                let currentBalance :=  sload(slotForToken)
                sstore(slotForToken, safeAdd(currentBalance, amount))
            }

            function mint(to, id, amount) {
                revertIfZeroAddress(to)
                addToTokenBalance(to, id, amount)

                //check if the recipient was ok to receive
                //safeTransferCheck
                if gt(extcodesize(to), 0) {
                    //_checkIfValidReceiverForSingle(caller(), 0, to, id, amount, 0)
                }

                //emit event
                emitTransferSingle(owner(),0x00,to,id,amount)
            }

            function balanceOf(owner_, tokenId) -> b {
                //return value from the correct slot
                let slotForToken := balancesByTokenSlot(owner_, tokenId)
                b := sload(slotForToken)
            }

            function balanceOfBatch() {
                let accountsOffset := add(decodeAsUint(0), 0x04)
                let idsOffset := add(decodeAsUint(1), 0x04)

                let numberOfIds := calldataload(idsOffset)
                let numberOfAccounts := calldataload(accountsOffset)

                idsOffset := add(idsOffset, 0x20)
                accountsOffset := add(accountsOffset, 0x20)

                require(eq(numberOfIds, numberOfAccounts))
                mstore(0x00, 0x20)
                mstore(0x20, numberOfIds)
                //mstore(0x40, 0x0a)
                for { let i := 0 } lt(i, numberOfIds) { i:= add(i, 1) } {
                    let id := calldataload(add(idsOffset, mul(i, 0x20)))
                    let account := calldataload(add(accountsOffset, mul(i, 0x20)))
                    let accountAddress := decodeAsAddress(add(i,3))
                    let balanceLookedUp := 0x0a//balanceOf(accountAddress, id)
                    mstore(add(mul(i, 0x20), 0x40), balanceLookedUp)

                    //logToConsoleNumber(0x200, balanceLookedUp)
                    // logToConsoleNumber(0x200, id)
                    // logAddress(0x200, accountAddress)
                    // logToConsoleNumber(0x200, balanceLookedUp)
                }

                return (0x00, add(mul(numberOfAccounts, 0x20), 0x40))
                //return (0x00, 0x40)


                //return (0x00, 0x60)
            }

            //function mintBatch(operator, ids, amounts, batch) {
            function mintBatch() {
                let to := decodeAsAddress(0)
                let idsOffset := add(decodeAsUint(1), 0x04)
                let amountsOffset := add(decodeAsUint(2), 0x04)
                let dataOffset := add(decodeAsUint(3), 0x04)

                let numberOfIds := calldataload(idsOffset)
                let numberOfAmounts := calldataload(amountsOffset)

                require(eq(numberOfAmounts,numberOfIds))

                idsOffset := add(idsOffset, 0x20)
                amountsOffset := add(amountsOffset, 0x20)

                for { let i := 0 } lt(i, numberOfIds) { i:= add(i, 1) } {
                    let id := calldataload(add(idsOffset, mul(i, 0x20)))
                    let amount := calldataload(add(amountsOffset, mul(i, 0x20)))
                    addToTokenBalance(to, id, amount)
                }

                if gt(extcodesize(to), 0) {
                    _checkIfValidReceiverForBatch(caller(), 0x00, to, idsOffset, amountsOffset, dataOffset)
                }
            }



            function safeTransferFrom() {
                let operator := caller()
                let from := decodeAsAddress(0)
                let to := decodeAsAddress(1)
                let tokenId := decodeAsUint(2)
                let amount := decodeAsUint(3)
                let bytesOffset := decodeAsUint(4)

                let fromSlot := balancesByTokenSlot(from, tokenId)
                let fromBalance := sload(fromSlot)

                revertIfZeroAddress(to)
                require(gt(fromBalance, amount))

                let dataLength := 0//decodeAsUint(5)

                let toSlot := balancesByTokenSlot(to, tokenId)
                let toBalance := sload(toSlot)

                //update balances
                sstore(fromSlot, sub(fromBalance, amount))
                sstore(toSlot, safeAdd(toBalance, amount))

                //if to is a contract, then check if the onReceiveHook responds correctly
                if gt(extcodesize(to), 0) {
                    _checkIfValidReceiverForSingle(caller(), from, to, tokenId, amount, bytesOffset)
                }

                //transmit event
            }

            //function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
            function safeBatchTransferFrom() {
                let from := decodeAsAddress(0)
                let to := decodeAsAddress(1)

                revertIfZeroAddress(to)

                let idsOffset := add(decodeAsUint(2), 0x04)
                let amountOffset := add(decodeAsUint(3), 0x04)
                let dataOffset := add(decodeAsUint(4), 0x04)

                let numberOfIds := calldataload(idsOffset)
                let numberOfAmounts := calldataload(amountOffset)


                require(eq(numberOfAmounts,numberOfIds))

                idsOffset := add(idsOffset, 0x20)
                amountOffset := add(amountOffset, 0x20)

                for { let i := 0 } lt(i, numberOfIds) { i:= add(i, 1) } {
                    let tokenId := calldataload(add(idsOffset, mul(i, 0x20)))
                    let amount := calldataload(add(amountOffset, mul(i, 0x20)))
                    
                    let fromSlot := balancesByTokenSlot(from, tokenId)
                    let fromBalance := sload(fromSlot)
    
                    require(gt(fromBalance, amount))
    
                    let toSlot := balancesByTokenSlot(to, tokenId)
                    let toBalance := sload(toSlot)
    
                    //update balances
                    sstore(fromSlot, safeSub(fromBalance, amount))
                    sstore(toSlot, safeAdd(toBalance, amount))
    
                }

                if gt(extcodesize(to), 0) {
                    _checkIfValidReceiverForBatch(caller(), 0x00, to, idsOffset, amountOffset, dataOffset)
                }

                //emit event
            }

            function _checkIfValidReceiverForBatch(operator, from, to, idsOffset, amountsOffset, dataOffset) {
                let validatorHookInterface := 0xf23a6e61
                mstore(0x00, shl(0xe0, 0xf23a6e61))
                mstore(0x24, operator)
                mstore(0x44, from)
                mstore(0x64, 0x00)
                mstore(0x84, 0x00)
                mstore(0xa4, 0xc4)
                let payloadLength := 0xe4
                mstore(0xc4, 0x00)

                //invalid()

                let success := staticcall(gas(), to, 0x00, payloadLength, 0x00, 0x20)
                requireWithMessage(success, "call to receiver failed", 23)
                let returnedData := decodeAsSelector(mload(0x00)) //get the first 4 bytes
                requireWithMessage(eq(returnedData, validatorHookInterface), "returned selector didnt match", 29)
            }


            function _checkIfValidReceiverForSingle(operator, from, to, id, amount, bytesOffset) {
                let validatorHookInterface := 0xf23a6e61
                mstore(0x00, shl(0xe0, 0xf23a6e61))
                mstore(0x24, operator)
                mstore(0x44, from)
                mstore(0x64, id)
                mstore(0x84, amount)
                mstore(0xa4, 0xc4)
                let payloadLength := 0xe4
                // if gt(bytesOffset, 0) {
                //     let dataLength := 0
                //     if gt(dataLength,0) {
                //         //iterate to load up all the bytes from data
                //         let bytesChunk := decodeAsUint(6)
                //         mstore(0xe4, bytesChunk)
                //     }
                // }
                //TBD: if there is bytes data to forward, then this will need to change
                mstore(0xc4, 0x00)

                //invalid()

                let success := staticcall(gas(), to, 0x00, payloadLength, 0x00, 0x20)
                requireWithMessage(success, "call to receiver failed", 23)
                let returnedData := decodeAsSelector(mload(0x00)) //get the first 4 bytes
                requireWithMessage(eq(returnedData, validatorHookInterface), "returned selector didnt match", 29)
            }

            /* -------- events ---------- */
            function emitTransferSingle(operator, from, to, tokenId, amount) {
                let signatureHash := 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62
                emitEvent3(signatureHash, operator, from, to, tokenId, amount)
            }

            function emitEvent2(signatureHash, indexed1, indexed2, nonIndexed) {
                mstore(0, nonIndexed)
                log3(0, 0x20, signatureHash, indexed1, indexed2)
            }
            function emitEvent3(signatureHash, indexed1, indexed2, indexed3, nonIndexed1, nonIndexed2) {
                mstore(0, nonIndexed1)
                mstore(0x20, nonIndexed2)
                log4(0, 0x40, signatureHash, indexed1, indexed2, indexed3)
            }

            /* -------- storage layout ---------- */
            function ownerSlot() -> p { p := 0 }
            function uriSlot() -> p { p:= 1 }
            function balancesSlot() -> p { p := 2 }
            function slotNoForUriLength() -> p { p := 3 }

            function balancesByTokenSlot(ownerOfToken, tokenId) -> slot {                
                //larger than scratch space, so have to use free pointer
                let ptr := 0x00
                mstore(ptr, balancesSlot())
                mstore(add(ptr, 0x20), ownerOfToken)
                mstore(add(ptr, 0x40), tokenId)
                slot := keccak256(0, 0x60)
            }

            /* -------- storage access ---------- */
            function owner() -> o {
                o := sload(ownerSlot())
            }

            /* ---------- calldata decoding functions ----------- */
            function selector() -> s {
                s := decodeAsSelector(calldataload(0))
            }

            function decodeAsSelector(value) -> s {
                s := div(value, 0x100000000000000000000000000000000000000000000000000000000)
            }

            function decodeAsAddress(offset) -> v {
                v := decodeAsUint(offset)
                if iszero(iszero(and(v, not(0xffffffffffffffffffffffffffffffffffffffff)))) {
                    revert(0, 0)
                }
            }
            function decodeAsUint(offset) -> v {
                let pos := add(4, mul(offset, 0x20))
                if lt(calldatasize(), add(pos, 0x20)) {
                    revert(0, 0)
                }
                v := calldataload(pos)
            }

            /* ---------- calldata encoding functions ---------- */
            function returnUint(v) {
                mstore(0, v)
                return(0, 0x20)
            }
            function returnTrue() {
                returnUint(1)
            }


            /* ---------- utility functions ---------- */
            function lte(a, b) -> r {
                r := iszero(gt(a, b))
            }
            function gte(a, b) -> r {
                r := iszero(lt(a, b))
            }
            function safeAdd(a, b) -> r {
                r := add(a, b)
                if or(lt(r, a), lt(r, b)) { revert(0, 0) }
            }
            function safeSub(a, b) -> r {
                r := sub(a, b)
                if gt(r, a) { revert(0, 0) }
            }
            function calledByOwner() -> cbo {
                cbo := eq(owner(), caller())
            }
            function revertIfZeroAddress(addr) {
                require(addr)
            }
            function require(condition) {
                if iszero(condition) { revert(0, 0) }
            }

            function revertWithReason(reason, reasonLength) {
                let ptr := 0x00
                mstore(ptr, 0x08c379a000000000000000000000000000000000000000000000000000000000) // Selector for method Error(string)
                mstore(add(ptr, 0x04), 0x20) // String offset
                mstore(add(ptr, 0x24), reasonLength) // Revert reason length
                mstore(add(ptr, 0x44), reason)
                revert(ptr, 0x64)
            }

            //reason has to be at most 32 bytes
            function requireWithMessage(condition, reason, reasonLength) {
                if iszero(condition) { 
                    revertWithReason(reason, reasonLength)
                 }
            }

            //restricted to a string literal
            function logToConsole(memPtr, message, lengthOfMessage) {
                //let memPtr := 0
                let startPos := memPtr
                mstore(memPtr, shl(0xe0,0x0bb563d6))
                memPtr := add(memPtr, 0x04) //selector
                mstore(memPtr, 0x20)
                memPtr := add(memPtr, 0x20) //offset
                mstore(memPtr, lengthOfMessage)        //length
                memPtr := add(memPtr, 0x20) 
                //mstore(memPtr, 0x6865726500000000000000000000000000000000000000000000000000000000)  //data
                mstore(memPtr, message)
                //invalid()
                pop(staticcall(gas(), 0x000000000000000000636F6e736F6c652e6c6f67, startPos, 0x64, 0x00, 0x00))
                //needs a reset: memPtr := startPos
            }

            function logCallData(memPtr, offset, length) {
                let startPos := memPtr
                mstore(memPtr, shl(0xe0, 0xe17bf956))
                memPtr := add(memPtr, 0x04)     //selector
                mstore(memPtr, 0x20)
                memPtr := add(memPtr, 0x20)     //offset of logging call
                mstore(memPtr, length)    //length of data to log
                memPtr := add(memPtr, 0x20) 
                //mstore(memPtr, 0x6865726500000000000000000000000000000000000000000000000000000000)  //data
                calldatacopy(memPtr, offset, length)
                //mstore(memPtr, calldatacopy())
                //invalid()
                pop(staticcall(gas(), 0x000000000000000000636F6e736F6c652e6c6f67, startPos, add(0x44,length), 0x00, 0x00))
                //needs a reset: memPtr := startPos
            }

            function logAddress(memPtr, addressValue) {
                let startPos := memPtr
                mstore(memPtr, shl(0xe0, 0xe17bf956))
                memPtr := add(memPtr, 0x04)     //selector
                mstore(memPtr, 0x20)
                memPtr := add(memPtr, 0x20)     //offset of logging call
                mstore(memPtr, 0x20)    //length of data to log
                memPtr := add(memPtr, 0x20) 
                //mstore(memPtr, 0x6865726500000000000000000000000000000000000000000000000000000000)  //data
                mstore(memPtr, addressValue)
                //mstore(memPtr, calldatacopy())
                //invalid()
                pop(staticcall(gas(), 0x000000000000000000636F6e736F6c652e6c6f67, startPos, add(0x44,0x20), 0x00, 0x00))
                //needs a reset: memPtr := startPos
            }

            function logMemory(memPtr, startingPointInMemory, length) {
                mstore(memPtr, shl(0xe0, 0xe17bf956))
                memPtr := add(memPtr, 0x04)     //selector
                mstore(memPtr, 0x20)
                memPtr := add(memPtr, 0x20)     //offset of logging call
                mstore(memPtr, length)    //length of data to log
                memPtr := add(memPtr, 0x20) 
                pop(staticcall(gas(), 0x000000000000000000636F6e736F6c652e6c6f67, startingPointInMemory, add(0x44,length), 0x00, 0x00))
            }

            function logToConsoleNumber(memPtr, _number) {
                let startPos := memPtr
                mstore(memPtr, shl(0xe0,0x9905b744))
                memPtr := add(memPtr, 0x04) //selector
                mstore(memPtr, _number)
                pop(staticcall(gas(), 0x000000000000000000636F6e736F6c652e6c6f67, startPos, 0x24, 0x00, 0x00))
                //needs a reset: memPtr := startPos
            }


            //utility function for saving strings
            function storeStringFromCallData(slotNoForLength, callDataOffsetForLength) {
                let length := calldataload(callDataOffsetForLength)
                if eq(length, 0) {
                    revert(0x00,0x00)
                }

                sstore(slotNoForLength, length)
                let strOffset := add(callDataOffsetForLength,0x20)
                mstore(0x00, slotNoForLength)
                let slotBase := keccak256(0x00,0x20)
                let slotsNeeded := div(length, 0x20)
                if gt(mod(length,0x20),0) {
                    slotsNeeded := add(slotsNeeded, 1)
                }

                for {let slotCounter := 0} lt(slotCounter, slotsNeeded) {slotCounter := add(slotCounter, 1)}{
                    sstore(add(slotBase,slotCounter), calldataload(strOffset))
                    strOffset := add(strOffset, 0x20)
                }
            }            

            function getStoredString(slotNoForLength) {
                let length := sload(slotNoForLength)
                mstore(0x00, slotNoForLength)
                let slotBase := keccak256(0x00,0x20)

                //return in the expected format, simpler when this is the only thing going back
                mstore(0x00, 0x20)
                mstore(0x20, length)
                let strOffsetBase := 0x40
                let slotCounterBase := slotBase
                let strOffset := 0x00

                let slotsNeeded := div(length, 0x20)
                if gt(mod(length,0x20),0) {
                    slotsNeeded := add(slotsNeeded,1)
                }

                for {let slotCounter := 0} lt(slotCounter, slotsNeeded) {slotCounter := add(slotCounter, 1)}{
                    mstore(add(strOffsetBase, strOffset), sload(add(slotCounterBase, slotCounter)))
                    strOffset := add(strOffset, 0x20)
                }

                return(0x00, mul(add(slotsNeeded,2),0x20))
            }
            
        }
    }
  }

  /*

https://jeancvllr.medium.com/solidity-tutorial-all-about-bytes-9d88fdb22676

https://ethereum.stackexchange.com/questions/131283/how-do-i-decode-call-data-in-solidity
  https://github.com/goncaloMagalhaes/erc20-low-level/blob/develop/yul/ERC20Permit.yul
  https://gist.github.com/teddav/e5c77d36d76567631ba5898a64a79079

      mapping(address => mapping(address => uint256)) public approval_;

    function approve(address spender, uint256 amount) external returns (bool) {
      assembly {
        // compute keccak(owner . approval_.slot)
        mstore(0x00, caller())
        mstore(0x20, approval_.slot)
        let googHash := keccak256(0x00, 0x40) // hash msg.sender + approval slot
        
        // compute keccak(spender . googHash) -> this is the final slot
        // we can reuse the same memory
        mstore(0x00, spender)
        mstore(0x20, googHash)
        let approveSlot := keccak256(0x00, 0x40)
        
        // load approve balance
        let balanceApproved := sload(approveSlot)

        // store the new value
        sstore(approveSlot, add(balanceApproved, amount))
      }
      return true;
    }

function getString() {
    mstore(0x00, 0x20) # you need to say where in *the return data* (btw. not relative to your own memory) the string starts (aka where it's length is stored - here it's 0x20)
    mstore(0x20, 0xe) # then the length of the string, let's say it's 14 bytes
    mstore(0x40, 0x737461636B6F766572666C6F7721000000000000000000000000000000000000) # the string to return in hex
    return(0, 0x60)
}   


// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

    contract Foo { 
    
    bytes32 public constant length = keccak256("mystoragelocation");
    bytes32 public constant data = keccak256(abi.encodePacked(length));

    function storeString(string memory _string) public {
        bytes32 _length = length;
        bytes32 _data = data;

        assembly {
            let stringLength := mload(_string)

            switch gt(stringLength, 0x1F)

            // If string length <= 31 we store a short array
            // length storage variable layout : 
            // bytes 0 - 31 : string data
            // byte 32 : length * 2
            // data storage variable is UNUSED in this case
            case 0x00 {
                sstore(_length, or(mload(add(_string, 0x20)), mul(stringLength, 2)))
            }

            // If string length > 31 we store a long array
            // length storage variable layout :
            // bytes 0 - 32 : length * 2 + 1
            // data storage layout :
            // bytes 0 - 32 : string data
            // If more than 32 bytes are required for the string we write them
            // to the slot(s) following the slot of the data storage variable
            case 0x01 {
                 // Store length * 2 + 1 at slot length
                sstore(_length, add(mul(stringLength, 2), 1))

                // Then store the string content by blocks of 32 bytes
                for {let i:= 0} lt(mul(i, 0x20), stringLength) {i := add(i, 0x01)} {
                    sstore(add(_data, i), mload(add(_string, mul(add(i, 1), 0x20))))
                }
            }
        }

    }

    function readString() public view returns (string memory returnBuffer) {
        bytes32 _length = length;
        bytes32 _data = data;

        assembly {
            let stringLength := sload(_length)

            // Check if what type of array we are dealing with
            // The return array will need to be taken from STORAGE
            // respecting the STORAGE layout of string, but rebuilt
            // in MEMORY according to the MEMORY layout of string.
            switch and(stringLength, 0x01)

            // Short array
            case 0x00 {
                let decodedStringLength := div(and(stringLength, 0xFF), 2)

                // Add length in first 32 byte slot 
                mstore(returnBuffer, decodedStringLength)
                mstore(add(returnBuffer, 0x20), and(stringLength, not(0xFF)))
                mstore(0x40, add(returnBuffer, 0x40))
            }

            // Long array
            case 0x01 {
                let decodedStringLength := div(stringLength, 2)
                let i := 0

                mstore(returnBuffer, decodedStringLength)
                
                // Write to memory as many blocks of 32 bytes as necessary taken from data storage variable slot + i
                for {} lt(mul(i, 0x20), decodedStringLength) {i := add(i, 0x01)} {
                    mstore(add(add(returnBuffer, 0x20), mul(i, 0x20)), sload(add(_data, i)))
                }

                mstore(0x40, add(returnBuffer, add(0x20, mul(i, 0x20))))
            }
        }
    }
}
*/