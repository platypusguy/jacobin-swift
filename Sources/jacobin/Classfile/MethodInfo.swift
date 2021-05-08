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

    var methodData = Method()

    func read( klass: LoadedClass, location: Int ) -> Int {
        // first get the access flags (a 2-byte field)
        methodData.accessFlags = getMethodAccessFlags( klass: klass, location: location )
        var presentLocation = location + 2

        // get name index, which should point to a UTF8 entry, then get the UTF8 name string
        let nameIndex = Int( Utility.getInt16from2Bytes( msb: klass.rawBytes[presentLocation + 1],
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
        let descIndex = Int( Utility.getInt16from2Bytes( msb: klass.rawBytes[presentLocation + 1],
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
        let attrCount = Utility.getIntFrom2Bytes( bytes: klass.rawBytes, index: presentLocation+1 )
        presentLocation += 2

        // get the attributes
        if attrCount > 0 {
            for _ in 0...attrCount - 1 {
                presentLocation = fillInAttribute( klass: klass, location: presentLocation )
            }
        }
        return presentLocation
    }

    // gets the attribute data and puts it into the methodData structure
    private func fillInAttribute( klass: LoadedClass, location: Int ) -> Int {
        var currLocation = location
        let attrNameIdx = Utility.getIntFrom2Bytes( bytes: klass.rawBytes, index: location + 1 )
        let attrName = Utility.getUTF8stringFromConstantPoolIndex( klass: klass, index: attrNameIdx )
        currLocation += 2;

        let length = Utility.getIntfrom4Bytes( bytes: klass.rawBytes, index: currLocation+1 )
        let attrLength = Int(length)

        print( "\(attrName) attribute -> length: \(length) at location \(currLocation)" )
        currLocation += 4

        switch( attrName ) { // listed alphabetically
        case "Code":
            let codeAttr = CodeAttribute( name: attrName, length: attrLength)
            currLocation =
                    codeAttr.load( klass, location: currLocation, methodData: methodData )

        case "Deprecated": // if present, this method is deprecated
            methodData.deprecated = true
            jacobin.log.log( msg: "Class: \(klass.shortName), method name \(methodData.name) is deprecated",
                             level: Logger.Level.FINEST )

        case "Exceptions": // record the # of exceptions, but don't add to method yet
            let exceptionsAttr = ExceptionsAttribute( name: attrName, length: attrLength )
            exceptionsAttr.load( klass: klass, loc: currLocation )
            exceptionsAttr.log( klass: klass, method: methodData )
            currLocation += attrLength

        case "MethodParameters":
            let methodParmsAttr = MethodParmsAttribute( name: attrName, length: attrLength )
            methodParmsAttr.load( klass: klass, loc: currLocation )
            methodData.parameters = methodParmsAttr.parms
            methodParmsAttr.log( klass: klass, method: methodData )
            currLocation += attrLength

        case "Signature":  // not enforced by the JVM, so skipped here
            currLocation += 2

        default:
            print( "Attribute \(attrName) not handled in MethodInfo.swift" )
        }

        return( currLocation )
    }

    func log( klass: LoadedClass, index: Int ) {
        jacobin.log.log( msg: "Class: \( klass.path ) - method name: \( methodData.name )",
                         level: Logger.Level.FINEST )
        jacobin.log.log( msg: "Class: \( klass.path ) - description: \( methodData.descriptor )",
                level: Logger.Level.FINEST )
        jacobin.log.log( msg: "Method: \(methodData.name) bytecode length: \(methodData.code.count)",
                         level: Logger.Level.FINEST )
//        jacobin.log.log( msg: "Class: \( klass.path ) - # of attributes: \( methodData.attributeCount )",
//                level: Logger.Level.FINEST )

    }

    // read the two-byte access flags
    private func getMethodAccessFlags( klass: LoadedClass, location: Int ) -> Int16 {
        let methodAccessFlags = Int16( Utility.getInt16from2Bytes( msb: klass.rawBytes[location + 1],
                                                                   lsb: klass.rawBytes[location + 2] ) )
        return methodAccessFlags
    }
}
