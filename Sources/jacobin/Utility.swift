/*
 * jacobin - JVM written in Swift
 *
 * Copyright (c) 2021 Andrew Binstock. All rights reserved.
 * Licensed under Mozilla Public License, v. 2.0. http://mozilla.org/MPL/2.0/.
 */

import Foundation

//various utility functions

class Utility {

    // converts two successive bytes into a 16-bit integer
    static func getInt16fromBytes( msb: UInt8, lsb: UInt8 ) -> Int16 {
        return ( Int16( msb ) * 256 ) + Int16( lsb )
    }

    // returns a UTF8 string pointed to by an index into the constant pool
    static func getUTF8stringFromConstantPoolIndex( klass: LoadedClass, index: Int ) -> String {
        let cpEntry = klass.cp[index]
        if cpEntry.type != 1 {
            jacobin.log.log( msg: "Error: Class: \(klass.path) - invalid UTF8 index \(index)",
                    level: Logger.Level.FINEST )
        }
        let UTF8entry = cpEntry as! CpEntryUTF8
        return UTF8entry.string
    }
}
