/*
 * jacobin - JVM written in Swift
 *
 * Copyright (c) 2021 Andrew Binstock. All rights reserved.
 * Licensed under Mozilla Public License, v. 2.0. http://mozilla.org/MPL/2.0/.
 */

import Foundation

class CodeAttribute: Attribute {
    /**
    u2 max_stack;
    u2 max_locals;
    u4 code_length;
    u1 code[code_length];
    u2 exception_table_length;
    {   u2 start_pc;
        u2 end_pc;
        u2 handler_pc;
        u2 catch_type;
    } exception_table[exception_table_length];
    u2 attributes_count;
    attribute_info attributes[attributes_count];
     */
    var maxStack = 0
    var maxLocals = 0
    var codeLength = 0
    var code : [UInt8] = []
    var exceptionTableLength = 0
    struct ExceptionEntry {
        var startPc = 0
        var handlerPc = 0
        var catchType = 0
    }
    var exceptionTable : [ExceptionEntry] = []
    var lineNumTable : [LineNumberTable] = []


    /// read the code attribute and load the items into the class fields
    /// - returns the location of the last read byte
    func load(_ klass: LoadedClass, location: Int) -> Int {
        // get the maximum stack
        var currLoc = location
        let maxStack = Int( Utility.getInt16from2Bytes( msb: klass.rawBytes[currLoc + 1],
                                                        lsb: klass.rawBytes[currLoc + 2] ))
        currLoc += 2

        // get the maximum # of locals
        let maxLocals = Int( Utility.getInt16from2Bytes( msb: klass.rawBytes[currLoc + 1],
                                                         lsb: klass.rawBytes[currLoc + 2] ))
        currLoc += 2

        // get the length of the codebyte array
        let codeLength = Utility.getIntfrom4Bytes( bytes: klass.rawBytes, index: currLoc+1 )
        print( "Class \(klass.path) size of bytecode: \(codeLength)")
        currLoc += 4

        // load the bytecode into code array
        for i in 1...codeLength {
            code.append( klass.rawBytes[currLoc+i])
        }
        currLoc += codeLength
        print( "location: \(currLoc)")

        // get exception table length (= number of entries, rather than length in bytes)
        exceptionTableLength =
                Int( Utility.getInt16from2Bytes( msb: klass.rawBytes[currLoc + 1],
                                                 lsb: klass.rawBytes[currLoc + 2] ))
        currLoc += 2
        print( "Class \(klass.path) exception table length: \(exceptionTableLength)" )

        //TODO: add handling of exception table when there is one

        // get the code attribute count
        let codeAttrCount =
                Utility.getIntFrom2Bytes( bytes: klass.rawBytes, index: currLoc + 1 )
        currLoc += 2
        print( "Class\(klass.path) code attribute count: \(codeAttrCount)" )

        for _ in 1...codeAttrCount {
            // handle the code attributes
            let codeAttrNamePointer =
                    Utility.getIntFrom2Bytes( bytes: klass.rawBytes, index: currLoc + 1 )
            currLoc += 2

            let codeAttrName =
                    Utility.getUTF8stringFromConstantPoolIndex( klass:klass, index: codeAttrNamePointer )
            print( "Class\(klass.path), code attribute: \(codeAttrName)" )

            if codeAttrName == "LineNumberTable" {
                let lnt = LineNumberTable()
                currLoc = lnt.load( klass: klass.rawBytes, loc: currLoc )
                lineNumTable.append( lnt )
            }
        }
        return currLoc
    }
}
