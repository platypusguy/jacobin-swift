/*
 * jacobin - JVM written in Swift
 *
 * Copyright (c) 2021 Andrew Binstock. All rights reserved.
 * Licensed under Mozilla Public License, v. 2.0. http://mozilla.org/MPL/2.0/.
 */

import Foundation

//various utility functions

class Utility {

    static func getInt16fromBytes( msb: UInt8, lsb: UInt8 ) -> Int16 {
        return ( Int16( msb ) * 256 ) + Int16( lsb )
    }

    static func getUTF8stringFromConstantPoolIndex( klass: LoadedClass, index: Int ) -> String {
            let cRef : CpEntryClassRef = klass.cp[index] as! CpEntryClassRef
            let pointerToName = cRef.classNameIndex
            let shortNameEntry : CpEntryUTF8 = klass.cp[pointerToName] as! CpEntryUTF8
            return shortNameEntry.string
    }
}
