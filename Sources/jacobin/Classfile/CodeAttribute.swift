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

    /// read the code attribute and load the items into the class fields
    /// - parameter klass: the bytes we're parsing
    /// - location: where we are in the klass bytes
    /// - methodData: the Method object we're loading up with the code data
    /// - returns the location of the last read byte
    func load(_ klass: LoadedClass, location: Int, methodData: Method ) -> Int {

        var currLoc = location
        methodData.maxStack = Int( Utility.getInt16from2Bytes( msb: klass.rawBytes[currLoc + 1],
                                                               lsb: klass.rawBytes[currLoc + 2] ))

        currLoc += 2

        // get the maximum # of locals
        methodData.maxLocals = Int( Utility.getInt16from2Bytes( msb: klass.rawBytes[currLoc + 1],
                                                                lsb: klass.rawBytes[currLoc + 2] ))
        currLoc += 2

        // get the length of the codebyte array
        let codeLength = Utility.getIntfrom4Bytes( bytes: klass.rawBytes, index: currLoc+1 )
        print( "Class \(klass.shortName), Method \(methodData.name), size of bytecode: \(codeLength)" )
        currLoc += 4

        // load the bytecode into code array
        for i in 1...codeLength {
            methodData.code.append( klass.rawBytes[currLoc+i])
        }
        currLoc += codeLength
        print( "location: \(currLoc)")

        // get exception table length (= number of entries, rather than length in bytes)
        let exceptionTableLength =
                Int( Utility.getInt16from2Bytes( msb: klass.rawBytes[currLoc + 1],
                                                 lsb: klass.rawBytes[currLoc + 2] ))
        currLoc += 2
        print( "Class \(klass.shortName), Method \(methodData.name), exception table length: \(exceptionTableLength)" )

        //TODO: add handling of exception table when there is one

        // get the code attribute count
        let codeAttrCount =
                Utility.getIntFrom2Bytes( bytes: klass.rawBytes, index: currLoc + 1 )
        currLoc += 2
        print( "Class \(klass.shortName), Method \(methodData.name), code attribute count: \(codeAttrCount)" )

        let lnt = LineNumberTable()

        for _ in 1...codeAttrCount {
            // handle the code attributes
            let codeAttrNamePointer =
                    Utility.getIntFrom2Bytes( bytes: klass.rawBytes, index: currLoc + 1 )
            currLoc += 2

            let codeAttrName =
                    Utility.getUTF8stringFromConstantPoolIndex( klass:klass, index: codeAttrNamePointer )
            print( "Class \(klass.shortName), Method \(methodData.name), code attribute: \(codeAttrName)" )

            if codeAttrName == "LineNumberTable" {
                currLoc = lnt.load( klass: klass.rawBytes, loc: currLoc )
                for i in 0...lnt.entryCount-1 {
                    let pc   = lnt.entries[i].pc
                    let line = lnt.entries[i].line
                    var entry : [Int] = []; entry.append( pc ); entry.append( line )
                    methodData.lineNumTable.append( entry )
                }
            }
            else if codeAttrName == "StackMapTable" { //skip over it for the nonce
                let length = Utility.getIntfrom4Bytes( bytes: klass.rawBytes, index: currLoc + 1 )
                currLoc += 4
                currLoc += length
                print( "Class \(klass.shortName), Method \(methodData.name), stack map table length: \(length)" )
            }
        }

        for i in 0...lnt.entryCount-1 {
            print( "line # table entry: pc > \(methodData.lineNumTable[i][0]) line # > \(methodData.lineNumTable[i][1])")
        }
        return currLoc
    }
}
