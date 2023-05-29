object "Sandbox" {
    code {
      datacopy(0, dataoffset("Runtime"), datasize("Runtime"))
      return(0, datasize("Runtime"))
    }
    object "Runtime" {

        code {


            // Dispatcher
            switch selector()
                case 0xc04f01fc {
                    returnUint(power(decodeAsUint(0), decodeAsUint(1)))
                }
                case 0x36473ce1 {
                    getPreDefinedString()
                    //logToConsole("herehere1herehere1herehere1",28)
                }
                case 0x0323d234 {
                    revertWithString()
                }
                case 0xdcb21d12 {
                    getStoredString(0)
                }
                case 0x7fcaf666 {
                    setString(0,0x24)
                }

                default {
                    revert(0, 0)
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

            //restricted to a string literal
            function logToConsole(message, lengthOfMessage) {
                let memPtr := 0
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
                memPtr := startPos
            }

            //when storing the string, its kind of packed with
            //31 bytes of data followed by a byte for length.
            function setString(slotNoForLength, callDataOffset) {
                //get the string from calldata and store in storage slot1
                //this is the only parameter in this case
                //skip the offset (since this is the only parameter), as well as function selector
                //if something is already set, then it needs to be cleared out first too
                //which can get quite an expensive operation to do

                let length := calldataload(callDataOffset)
                if eq(length, 0) {
                    revert(0x00,0x00)
                }

                //let str := calldataload(add(callDataOffset,0x20))
                //strData := 0x20
                //31 bytes of data, followed by length -- is that particular to solidity only?
                //can only store only byte at a time

                sstore(slotNoForLength, length)
                let strOffset := add(callDataOffset,0x20)
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

                //mstore(0x00, uriSlot())
                //let actualSlot := 0//keccak256(0x00, 0x00)
                //expecting offset, length, and bytes
                //let length := calldataload(0x20)
                //mstore(0x80, length)
                //mstore(0xa0, calldataload(0x40))


            }

            // question : do we need to consider the scratch space in a pure yul contract?
            // in this case, the contract is being called from a solidity contract ... the context is different?
            // what is context
            // more about the free memory pointer
            function revertWithString() {
                let ptr := mload(0x40) // Get free memory pointer
                mstore(ptr, 0x08c379a000000000000000000000000000000000000000000000000000000000) // Selector for method Error(string)
                mstore(add(ptr, 0x04), 0x20) // String offset
                mstore(add(ptr, 0x24), 0x0f) // Revert reason length
                mstore(add(ptr, 0x44), "my error string")
                revert(ptr, 0x64)
            }

            //return a predefined string, as a test
            //the string is stored in the most significant bytes
            //thus, shorter strings ie. 31 bytes or less can be returned by having the length in the last byte
            //so the most significant byte can be tested to see if that is the case
            //when does this apply?
            function getPreDefinedString() {
                mstore(0x00, 0x20)  //offset
                mstore(0x20, 10)  //length
                //mstore(0x40, 0x6e657720737472696e6700000000000000000000000000000000000000000000) //data
                mstore(0x40, "new string") //data
                return (0x00,0x60)
            }

            function power(base, exponent) -> result {

                switch exponent
                case 0 { result := 1 }
                case 1 { result := base }
                default {
                    result := power(mul(base, base), div(exponent, 2))
                    switch mod(exponent, 2)
                        case 1 { result := mul(base, result) }
                }
            }

            /* ---------- calldata decoding functions ----------- */
            function selector() -> s {
                s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
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

            /* -------- events ---------- */
            function emitTransfer(from, to, amount) {
                let signatureHash := 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef
                emitEvent(signatureHash, from, to, amount)
            }
            function emitApproval(from, spender, amount) {
                let signatureHash := 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925
                emitEvent(signatureHash, from, spender, amount)
            }

            function emitEvent(signatureHash, indexed1, indexed2, nonIndexed) {
                mstore(0, nonIndexed)
                log3(0, 0x20, signatureHash, indexed1, indexed2)
            }

            /* -------- storage layout ---------- */
            function ownerPos() -> p { p := 0 }
            function totalSupplyPos() -> p { p := 1 }
            function accountToStorageOffset(account) -> offset {
                offset := add(0x1000, account)
            }
            function allowanceStorageOffset(account, spender) -> offset {
                offset := accountToStorageOffset(account)
                mstore(0, offset)
                mstore(0x20, spender)
                offset := keccak256(0, 0x40)
            }

            /* -------- storage access ---------- */
            function owner() -> o {
                o := sload(ownerPos())
            }
            function totalSupply() -> supply {
                supply := sload(totalSupplyPos())
            }
            function mintTokens(amount) {
                sstore(totalSupplyPos(), safeAdd(totalSupply(), amount))
            }
            function balanceOf(account) -> bal {
                bal := sload(accountToStorageOffset(account))
            }
            function addToBalance(account, amount) {
                let offset := accountToStorageOffset(account)
                sstore(offset, safeAdd(sload(offset), amount))
            }
            function deductFromBalance(account, amount) {
                let offset := accountToStorageOffset(account)
                let bal := sload(offset)
                require(lte(amount, bal))
                sstore(offset, sub(bal, amount))
            }
            function allowance(account, spender) -> amount {
                amount := sload(allowanceStorageOffset(account, spender))
            }
            function setAllowance(account, spender, amount) {
                sstore(allowanceStorageOffset(account, spender), amount)
            }
            function decreaseAllowanceBy(account, spender, amount) {
                let offset := allowanceStorageOffset(account, spender)
                let currentAllowance := sload(offset)
                require(lte(amount, currentAllowance))
                sstore(offset, sub(currentAllowance, amount))
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
            function calledByOwner() -> cbo {
                cbo := eq(owner(), caller())
            }
            function revertIfZeroAddress(addr) {
                require(addr)
            }
            function require(condition) {
                if iszero(condition) { revert(0, 0) }
            }
        }
    }
  }

  //https://github.com/andreitoma8/learn-yul
  //good article https://medium.com/@novablitz/storing-structs-is-costing-you-gas-774da988895e

                  //QUESTION: storage writes out one word at time, and you read one slot at a time too
                //for memory, you also read one word at time, but can start from any offset
                //for memory, you also write one word at a time, and start from any point?
                //calldata is the same
                //return data is a snapshot of memory, consisting of the starting offset and length
                //revert is a a return that halts execution, but takes the start and end memory offsets that go back
                //I think preparing some notes in notion, would make it more specific
                //unlike memory where you have to manually track collisions. additionally, memory is costly to expand beyond a certain level
                //you can load the memory in the first xx (3 words?) bytes cheaply, after that the cost is quadratic
                //storage slots can be anything, and collisions are less likely with hashing. but it can happen. has it happened?
                //memory is not packed, however storage is packed. storage is more expensive too


                //when writing a string -- or variable bytes -- you have a slot with length
                //