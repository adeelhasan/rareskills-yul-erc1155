object "WhereIsZero" {
    
        code {
            function require(condition) {
                if iszero(condition) { revert(0, 0) }
            } 

/*          this works:
             function require2(condition) {
                if eq(condition,0) { revert(0, 0) }
            }            
 */

    }
  }
