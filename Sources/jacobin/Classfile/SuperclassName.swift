/*
 * jacobin - JVM written in Swift
 *
 * Copyright (c) 2021 Andrew Binstock. All rights reserved.
 * Licensed under Mozilla Public License, v. 2.0. http://mozilla.org/MPL/2.0/.
 */

import Foundation

/// handles extracting the short name of the superclass of this class from the constant pool.
/// This class is called from the classloader

class SuperClassName {

    // reads the entry in the class file that points to the superclass for this class
    static func readName( klass: LoadedClass, location: Int ) {
        let superClassEntry = Int(Utility.getInt16fromBytes( msb: klass.rawBytes[location+1],
                lsb: klass.rawBytes[location+2] ))
        klass.superClassRef = superClassEntry
    }

    // verifies that the entry points to the right type of record.
    static func verify( klass: LoadedClass ) {
        if( klass.cp[klass.superClassRef].type != 7 ) { // must point to a class reference
            log.log( msg: "ClassFormatError in \( klass.path ): Invalid superClassReference",
                     level: Logger.Level.SEVERE )
            shutdown( successFlag: false )
        }
    }

    // looks up the pointed-to name for the superclass and inserts it into klass.shortName; and logs it
    static func process( klass: LoadedClass ){
        let cRef : CpEntryClassRef = klass.cp[klass.superClassRef] as! CpEntryClassRef
        let pointerToName = cRef.classNameIndex
        let superNameEntry : CpEntryUTF8 = klass.cp[pointerToName] as! CpEntryUTF8
        klass.superClassName = superNameEntry.string
        log.log( msg: "Class: \( klass.path ) - superclass: \( klass.superClassName )",
                 level: Logger.Level.SEVERE )
    }
}