/*
QUESTION: uri in the constructor ?
*/

object "ERC1155" {
    code {

        sstore(0,caller())
        datacopy(0, dataoffset("Runtime"), datasize("Runtime"))
        return(0, datasize("Runtime"))
    }
    object "Runtime" {

        code {
            // ether is not accepted
            require(iszero(callvalue()))

            // Dispatcher
            switch selector()
                case 0x8da5cb5b {   //owner
                    returnUint(owner())
                }
                case 0x156e29f6 {    //mint
                    mint(decodeAsAddress(0),decodeAsUint(1),decodeAsUint(2))
                }
                case 0x1f7fdffa {   //mintBatch(address, uint256[] ids, uint256[] amounts, bytes)
                    mintBatch()
                }
                case 0x9b642de1 {   //setUri(string memory)
                    setUri()
                }
                case 0xeac989f8 {   //uri() returns(string memory)
                    uri()
                }
                case 0xf242432a {   //safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes calldata _data)
                    safeTransferFrom()
                }
                case 0x2eb2c2d6 {   //safeBatchTransferFrom(address _from, address _to, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data)
                    safeBatchTransferFrom()
                }
                case 0x00fdd58e {    //balanceOf(address _owner, uint256 _id) external view returns (uint256)
                    returnUint(balanceOf(decodeAsAddress(0),decodeAsUint(1)))
                }
                case 0x4e1273f4 {    //balanceOfBatch(address[] calldata _owners, uint256[] calldata _ids) external view returns (uint256[] memory)
                    balanceOfBatch()
                }
                case 0xe985e9c5 {   //isApprovedForAll(address _owner, address _operator) external view returns (bool)
                    returnUint(isApprovedForAll(decodeAsAddress(0), decodeAsAddress(1)))
                }
                case 0xa22cb465 {   //setApprovalForAll(address _operator, bool _approved);
                    setApprovalForAll(decodeAsAddress(0), decodeAsUint(1))
                }
                case 0xf5298aca {
                    burn()
                }
                case 0x6b20c454 /* burnBatch(address from, uint256[] ids, uint256[] amounts) */ {
                    burnBatch()
                }
                case 0xce8cc46a {
                    logToConsoleTests()
                }
                case 0xec0f2d9c {
                    logToConsoleTests()
                }
                default {
                    //revert(0, 0)
                    revertWithReason("unimplemented selector", 22)
                }

            function ownerOnlyCheck() {
                requireWithMessage(eq(caller(), owner()), "only owner can call", 19)
            }

            // TODO: clear out existing slots, if that is going to be necessary
            function setUri() {
                ownerOnlyCheck()

                storeStringFromCallData(slotNoForUriLength(), 0x24)

                //emit uri event
                let signatureHash := 0x6bb7ff708619ba0610cba295a58592e0451dee2622938c8755667688daf3529b
                let stringLength := calldataload(0x24)
                let lengthOfData := add(mul(roundToWord(stringLength), 0x20), 0x40)
                calldatacopy(0x00, 0x04, lengthOfData)
                log2(0x00, lengthOfData, signatureHash, 0)
            }

            function uri() {
                getStoredString(slotNoForUriLength())
            }

            function mint(to, id, amount) {
                revertIfZeroAddress(to)
                _adjustTokenBalance(to, id, amount, true)

                if gt(extcodesize(to), 0) {
                    _checkIfValidReceiverForSingle(caller(), 0, to, id, amount, 0)
                }

                emitTransferSingle(owner(),0x00,to,id,amount)
            }

            function balanceOf(owner_, id) -> b {
                let slotForToken := balancesByTokenSlot(owner_, id)
                b := sload(slotForToken)
            }

            function balanceOfBatch() {
                let accountsOffset := add(decodeAsUint(0), 0x04)
                let idsOffset := add(decodeAsUint(1), 0x04)

                let numberOfIds := calldataload(idsOffset)
                let numberOfAccounts := calldataload(accountsOffset)

                idsOffset := add(idsOffset, 0x20)
                accountsOffset := add(accountsOffset, 0x20)
                
                let returnOffset := 0x80
                mstore(returnOffset, 0x20)
                mstore(add(returnOffset, 0x20), numberOfIds)

                require(eq(numberOfIds, numberOfAccounts))
                for { let i := 0 } lt(i, numberOfIds) { i:= add(i, 1) } {
                    let id := calldataload(add(idsOffset, mul(i, 0x20)))
                    let account := calldataload(add(accountsOffset, mul(i, 0x20)))
                    let accountAddress := decodeAsAddress(add(i,3))
                    let balanceLookedUp := balanceOf(accountAddress, id)
                    mstore(add(mul(i, 0x20), add(returnOffset,0x40)), balanceLookedUp)
                }

                return (returnOffset, add(mul(numberOfAccounts, 0x20), 0x40))
            }

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
                    _adjustTokenBalance(to, id, amount, true)
                }

                if gt(extcodesize(to), 0) {
                    _checkIfValidReceiverForBatch(caller(), 0x00, to, idsOffset, amountsOffset, dataOffset)
                }

                emitTransferBatch(caller(), 0, to, numberOfIds, idsOffset, amountsOffset)
            }

            function safeTransferFrom() {
                let operator := caller()
                let from := decodeAsAddress(0)
                let to := decodeAsAddress(1)
                let id := decodeAsUint(2)
                let amount := decodeAsUint(3)
                let bytesOffset := decodeAsUint(4)

                let fromSlot := balancesByTokenSlot(from, id)
                let fromBalance := sload(fromSlot)

                revertIfZeroAddress(to)
                require(gt(fromBalance, amount))

                requireWithMessage(or(eq(caller(), from), isApprovedForAll(from, caller())), "neither approved nor owner", 26)

                let dataLength := 0//decodeAsUint(5)

                //update balances
                sstore(fromSlot, sub(fromBalance, amount))

                let toSlot := balancesByTokenSlot(to, id)
                let toBalance := sload(toSlot)
                sstore(toSlot, safeAdd(toBalance, amount))

                //if to is a contract, then check if the onReceiveHook responds correctly
                if gt(extcodesize(to), 0) {
                    _checkIfValidReceiverForSingle(caller(), from, to, id, amount, bytesOffset)
                }

                emitTransferSingle(caller(), from, to, id, amount)
            }

            function safeBatchTransferFrom() {
                let from := decodeAsAddress(0)
                let to := decodeAsAddress(1)

                revertIfZeroAddress(to)
                requireWithMessage(or(eq(caller(), from), isApprovedForAll(from, caller())), "neither approved nor owner", 26)

                let idsOffset := add(decodeAsUint(2), 0x04)
                let amountOffset := add(decodeAsUint(3), 0x04)
                let dataOffset := add(decodeAsUint(4), 0x04)

                let numberOfIds := calldataload(idsOffset)
                let numberOfAmounts := calldataload(amountOffset)

                require(eq(numberOfAmounts,numberOfIds))

                idsOffset := add(idsOffset, 0x20)
                amountOffset := add(amountOffset, 0x20)

                for { let i := 0 } lt(i, numberOfIds) { i:= add(i, 1) } {
                    let id := calldataload(add(idsOffset, mul(i, 0x20)))
                    let amount := calldataload(add(amountOffset, mul(i, 0x20)))
                    
                    let fromSlot := balancesByTokenSlot(from, id)
                    let fromBalance := sload(fromSlot)
    
                    requireWithMessage(gt(fromBalance, amount), "insufficient balance", 20)
        
                    sstore(fromSlot, safeSub(fromBalance, amount))
                    let toSlot := balancesByTokenSlot(to, id)
                    let toBalance := sload(toSlot)
                    sstore(toSlot, safeAdd(toBalance, amount))
                }

                if gt(extcodesize(to), 0) {
                    _checkIfValidReceiverForBatch(caller(), 0x00, to, idsOffset, amountOffset, dataOffset)
                }

                emitTransferBatch(caller(), from, to, numberOfIds, idsOffset, amountOffset)
            }

            function burn() {
                ownerOnlyCheck()
    
                let from := decodeAsAddress(0)
                let id := decodeAsUint(1)
                let amount := decodeAsUint(2)

                let fromSlot := balancesByTokenSlot(from, id)
                let fromBalance := sload(fromSlot)

                require(gt(fromBalance, amount))

                sstore(fromSlot, safeSub(fromBalance, amount))

                emitTransferSingle(caller(), from, 0, id, amount)
            }

            function burnBatch() {
                ownerOnlyCheck()
    
                let from := decodeAsAddress(0)
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

                    _adjustTokenBalance(from, id, amount, false)
                }

                emitTransferBatch(caller(), from, 0, numberOfIds, idsOffset, amountsOffset)
            }

            function setApprovalForAll(operator, approved) {
                revertIfZeroAddress(operator)
                sstore(calculateApprovedForAllSlot(caller(), operator), approved)

                emitApprovalForAll(caller(), operator, approved)
            }

            function isApprovedForAll(owner_, operator) -> b {
                revertIfZeroAddress(owner_)
                revertIfZeroAddress(operator)
                b := sload(calculateApprovedForAllSlot(owner_, operator))
                //return (0x00,0x20)
            }

            /* ---------- internal functions --------- */

            function _adjustTokenBalance(ownerOfToken, id, amount, increaseBalance) {
                let slotForToken := balancesByTokenSlot(ownerOfToken, id)
                let currentBalance :=  sload(slotForToken)
                let newBalance := 0
                if increaseBalance {
                    newBalance := safeAdd(currentBalance, amount)
                }
                if eq(increaseBalance, false) {                    
                    newBalance := safeSub(currentBalance, amount)
                }
                sstore(slotForToken, newBalance)
            }

            //TODO: the ids and amounts have to be copied over to data fields
            function _checkIfValidReceiverForBatch(operator, from, to, idsOffset, amountsOffset, dataOffset) {
                let validatorHookInterface := 0xf23a6e61
                mstore(0x00, shl(0xe0, 0xf23a6e61))
                mstore(0x24, operator)
                mstore(0x44, from)
                mstore(0x64, 0x00)  //ids
                mstore(0x84, 0x00)  //amounts
                mstore(0xa4, 0xc4)
                let payloadLength := mul(0x20,7) //when calling solidity, have to be an even number of words

                mstore(0xc4, 0x00)

                let success := staticcall(gas(), to, 0x00, payloadLength, 0x00, 0x20)
                requireWithMessage(success, "call to receiver failed", 23)
                let returnedData := decodeAsSelector(mload(0x00))
                requireWithMessage(eq(returnedData, validatorHookInterface), "returned selector didnt match", 29)
            }

            function _checkIfValidReceiverForSingle(operator, from, to, id, amount, bytesOffset) {
                let validatorHookInterface := 0xf23a6e61
                let requestOffset := 0x00
                mstore(requestOffset, shl(0xe0, 0xf23a6e61))
                mstore(add(requestOffset, 0x04), operator)
                mstore(add(requestOffset, 0x24), from)
                mstore(add(requestOffset, 0x44), id)
                mstore(add(requestOffset, 0x64), amount)
                mstore(add(requestOffset, 0x84), 0xa4)
                let payloadLength := add(mul(0x20,7), 0)
                // if gt(bytesOffset, 0) {
                //     let dataLength := 0
                //     if gt(dataLength,0) {
                //         //iterate to load up all the bytes from data
                //         let bytesChunk := decodeAsUint(6)
                //         mstore(0xe4, bytesChunk)
                //     }
                // }
                //TBD: if there is bytes data to forward, then this will need to change
                mstore(add(requestOffset, 0xa4), 0x00)

                //invalid()

                let success := staticcall(gas(), to, requestOffset, payloadLength, 0x00, 0x20)
                requireWithMessage(success, "call to receiver failed", 23)
                let returnedData := decodeAsSelector(mload(0x00)) //get the first 4 bytes
                requireWithMessage(eq(returnedData, validatorHookInterface), "returned selector didnt match", 29)
            }            

            /* -------- events ---------- */
            function emitTransferSingle(operator, from, to, id, amount) {
                let signatureHash := 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62
                mstore(0x00, id)
                mstore(0x20, amount)
                log4(0, 0x40, signatureHash, operator, from, to)
            }
    
            function emitApprovalForAll(owner_, operator, approved) {
                let signatureHash := 0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31
                mstore(0x00, approved)
                log3(0x00, 0x20, signatureHash, owner_, operator)
            }

            //event TransferBatch(address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _values);
            function emitTransferBatch(operator, from, to, numberOfIds, idsOffset, amountOffset) {
                let signatureHash := 0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb
                let idsOffsetInEvent := 0x40
                let amountsOffsetInEvent := add(mul(numberOfIds, 0x20), 0x60)
                mstore(0x00, 0x40)
                mstore(idsOffsetInEvent, numberOfIds) //length of array
                mstore(0x20, amountsOffsetInEvent)
                mstore(amountsOffsetInEvent, numberOfIds)

                idsOffsetInEvent := add(idsOffsetInEvent, 0x20)
                amountsOffsetInEvent := add(amountsOffsetInEvent, 0x20)

                for { let j := 0 } lt(j, numberOfIds) { j:= add(j, 1) } {
                    let id := calldataload(add(idsOffset, mul(j, 0x20)))
                    let amount := calldataload(add(amountOffset, mul(j, 0x20)))
                    mstore(add(idsOffsetInEvent, mul(j, 0x20)), id)
                    mstore(add(amountsOffsetInEvent, mul(j, 0x20)), amount)
                }

                let dataLength := mul(add(mul(numberOfIds, 0x20),0x40),2)

                log4(0x00, dataLength, signatureHash, caller(), from, to)
            }

            /* -------- storage layout ---------- */
            function ownerSlot() -> p { p := 0 }
            function uriSlot() -> p { p:= 1 }
            function balancesSlot() -> p { p := 2 }
            function slotNoForUriLength() -> p { p := 3 }
            function approvedForAllSlot() -> p { p:= 4 }

            function balancesByTokenSlot(ownerOfToken, id) -> slot {                
                mstore(0x00, balancesSlot())
                mstore(0x20, ownerOfToken)
                mstore(0x40, id)
                slot := keccak256(0, 0x60)
            }

            function calculateApprovedForAllSlot(owner_, operator) -> slot {
                mstore(0x00, approvedForAllSlot())
                mstore(0x20, owner_)
                mstore(0x40, operator)
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

            function roundToWord(length) -> numberOfWords {
                numberOfWords := div(length, 0x20)
                if gt(mod(length,0x20),0) {
                    numberOfWords := add(numberOfWords, 1)
                }
            }

            function revertWithReason(reason, reasonLength) {
                let ptr := 0x00 //since we are going to abort, can use memory at 0x00
                mstore(ptr, shl(0xe0,0x08c379a)) // Selector for method Error(string)
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

            /* ------------ log to console ----------- */

            function logToConsoleTests() {
                // logToConsole(0x00, "This is the first message", 25)
                // logToConsoleNumber(0x00, calldatasize())
                // logAddress(0xe0, caller())
                logCalldataWrapped(0x00, 0x00, calldatasize())
            }

            //restricted to a string literal
            function logString(memPtr, message, lengthOfMessage) {
                mstore(memPtr, shl(0xe0,0x0bb563d6))        //selector
                mstore(add(memPtr, 0x04), 0x20)             //offset
                mstore(add(memPtr, 0x24), lengthOfMessage)  //length
                mstore(add(memPtr, 0x44), message)          //data
                pop(staticcall(gas(), 0x000000000000000000636F6e736F6c652e6c6f67, memPtr, 0x64, 0x00, 0x00))
            }

            function logCalldata(memPtr, offset, length) {
                mstore(memPtr, shl(0xe0, 0xe17bf956))
                mstore(add(memPtr, 0x04), 0x20)
                mstore(add(memPtr, 0x24), length)
                calldatacopy(add(memPtr, 0x44), offset, length)
                let dataLengthRoundedToWord := roundToWord(length)
                
                pop(staticcall(gas(), 0x000000000000000000636F6e736F6c652e6c6f67, memPtr, mul(0x20,add(dataLengthRoundedToWord, 2)), 0x00, 0x00))
            }

            function logCalldataWrapped(memPtr, offset, length) {
                //the "request header" remains the same, we keep
                //sending 32 bytes to the console contract
                mstore(memPtr, shl(0xe0, 0xe17bf956))
                mstore(add(memPtr, 0x04), 0x20)
                mstore(add(memPtr, 0x24), 0x20)

                let dataLengthRoundedToWord := roundToWord(calldatasize())                
                let calldataOffset := 0x00
                
                for { let i := 0 } lt(i, dataLengthRoundedToWord) { i:= add(i, 1) } {
                    calldataOffset := mul(i, 0x20)
                    calldatacopy(add(memPtr, 0x44), calldataOffset, 0x20)
                    pop(staticcall(gas(), 0x000000000000000000636F6e736F6c652e6c6f67, memPtr, 0x64, 0x00, 0x00))
                }
            }


            function logAddress(memPtr, addressValue) {
                mstore(memPtr, shl(0xe0, 0xe17bf956))
                mstore(add(memPtr, 0x04), 0x20)
                mstore(add(memPtr, 0x24), 0x20)
                mstore(add(memPtr, 0x44), addressValue)
                pop(staticcall(gas(), 0x000000000000000000636F6e736F6c652e6c6f67, memPtr, 0x64, 0x00, 0x00))
            }

            function logMemory(memPtr, startingPointInMemory, length) {
                mstore(memPtr, shl(0xe0, 0xe17bf956))
                mstore(add(memPtr, 0x04), 0x20)
                mstore(add(memPtr, 0x24), length)
                let dataLengthRoundedToWord := roundToWord(length)
                pop(staticcall(gas(), 0x000000000000000000636F6e736F6c652e6c6f67, startingPointInMemory, add(0x44, dataLengthRoundedToWord), 0x00, 0x00))
            }
            
            function logNumber(memPtr, _number) {
                mstore(memPtr, shl(0xe0,0x9905b744))
                mstore(add(memPtr, 0x04), _number)
                pop(staticcall(gas(), 0x000000000000000000636F6e736F6c652e6c6f67, memPtr, 0x24, 0x00, 0x00))
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
            function internalTransfer(from, to, idsOffset, amountsOffset, singleton) {
                let decrementFromBalance := true
                if eq(from, 0) { decrementFromBalance := false }
                
                let numberOfIds := calldataload(idsOffset)
                let numberOfAmounts := calldataload(amountsOffset)
                if singleton { 
                    numberOfIds := 1
                    numberOfAmounts := 1
                 }

                 requireWithMessage(eq(numberOfAmounts, numberOfIds), "mismatched array counts", 23)

                 idsOffset := add(idsOffset, 0x20)
                 amountsOffset := add(amountsOffset, 0x20)

                 for { let i := 0 } lt(i, numberOfIds) { i:= add(i, 1) } {
                    let id := calldataload(add(idsOffset, mul(i, 0x20)))
                    let amount := calldataload(add(amountsOffset, mul(i, 0x20)))
                    
                    let fromSlot := balancesByTokenSlot(from, id)
                    let fromBalance := sload(fromSlot)
    
                    require(gt(fromBalance, amount))
    
                    let toSlot := balancesByTokenSlot(to, id)
                    let toBalance := sload(toSlot)
    
                    //update balances
                    sstore(fromSlot, safeSub(fromBalance, amount))
                    sstore(toSlot, safeAdd(toBalance, amount))
                }
            }



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