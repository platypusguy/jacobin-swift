/*
 * jacobin - JVM written in Swift
 *
 * Copyright (c) 2021 Andrew Binstock. All rights reserved.
 * Licensed under Mozilla Public License, v. 2.0. http://mozilla.org/MPL/2.0/.
 */
import Foundation

// reads, and loads into the class, method info and verifies it
/**
method_info {
    u2             access_flags;
    u2             name_index;
    u2             descriptor_index;
    u2             attributes_count;
    attribute_info attributes[attributes_count];
}
 */
class MethodInfo {

    let methodData = MethodContents()

    func read( klass: LoadedClass, location: Int ) {
        // first get the access flags (a 2-byte field)
        methodData.accessFlags = getMethodAccessFlags( klass: klass, location: location )
        var presentLocation = location + 2

        // get name index, which should point to a UTF8 entry, then get the UTF8 name string
        let nameIndex = Int( Utility.getInt16fromBytes( msb: klass.rawBytes[presentLocation + 1],
                                                        lsb: klass.rawBytes[presentLocation + 2] ))
        var cpEntry = klass.cp[nameIndex]
        if cpEntry.type != 1 {
            jacobin.log.log( msg: "Error: Class: \(klass.path) - method name index \(nameIndex) invalid",
                    level: Logger.Level.FINEST )
        }
        var UTF8entry = cpEntry as! CpEntryUTF8
        methodData.name = UTF8entry.string
        presentLocation += 2

        // get the descriptor index, which should point to a UTF8 entry, then get the UTF8 name string
        let descIndex = Int( Utility.getInt16fromBytes( msb: klass.rawBytes[presentLocation + 1],
                                                        lsb: klass.rawBytes[presentLocation + 2] ))
        cpEntry = klass.cp[descIndex]
        if cpEntry.type != 1 {
            jacobin.log.log( msg: "Error: Class: \(klass.path) - method desc index \(descIndex) invalid",
                    level: Logger.Level.FINEST )
        }
        UTF8entry = cpEntry as! CpEntryUTF8
        methodData.descriptor = UTF8entry.string
        presentLocation += 2

        // get the count of attributes
        let attrCount = Int( Utility.getInt16fromBytes( msb: klass.rawBytes[presentLocation + 1],
                                                        lsb: klass.rawBytes[presentLocation + 2] ))
        methodData.attributeCount = attrCount
        presentLocation += 2

        // get the attributes
        for i in 0...attrCount-1 {
            var attr = Attribute()
            presentLocation = fillInAttribute( attr: attr, klass: klass, location: presentLocation )
            methodData.attributes.append( attr )
        }
    }

    private func fillInAttribute( attr: Attribute, klass: LoadedClass, location: Int ) -> Int {
        var currLocation = location
        let attrNameIdx = Int( Utility.getInt16fromBytes( msb: klass.rawBytes[location + 1],
                                                          lsb: klass.rawBytes[location + 2] ))
        attr.attrName = Utility.getUTF8stringFromConstantPoolIndex( klass: klass, index: attrNameIdx )
        print( "attribute name: \(attr.attrName)" )
        currLocation += 2;

        let first2bytesInLen  = Utility.getInt16fromBytes( msb: klass.rawBytes[currLocation + 1],
                                                           lsb: klass.rawBytes[currLocation + 2] )
        let second2bytesInLen = Utility.getInt16fromBytes( msb: klass.rawBytes[currLocation + 3],
                                                           lsb: klass.rawBytes[currLocation + 4] )
        let length : Int = (Int(first2bytesInLen) * 65535) + Int(second2bytesInLen)
        attr.attrLength = length

        print( "Code attribute length: \(length) at location \(currLocation)" )
        currLocation += 4

        //curr: continue here, loading the Code attribute
        return( currLocation )
    }

    func verify( klass: LoadedClass, index: Int ) {

    }

    func log( klass: LoadedClass, index: Int ) {
        jacobin.log.log( msg: "Class: \( klass.path ) - method name: \( methodData.name )",
                         level: Logger.Level.FINEST )
        jacobin.log.log( msg: "Class: \( klass.path ) - description: \( methodData.descriptor )",
                level: Logger.Level.FINEST )
        jacobin.log.log( msg: "Class: \( klass.path ) - # of attributes: \( methodData.attributeCount )",
                level: Logger.Level.FINEST )

    }

    // read the two-byte access flags
    private func getMethodAccessFlags( klass: LoadedClass, location: Int ) -> Int16 {
        let methodAccessFlags = Int16( Utility.getInt16fromBytes( msb: klass.rawBytes[location + 1],
                lsb: klass.rawBytes[location + 2] ) )
        return methodAccessFlags
    }
}
