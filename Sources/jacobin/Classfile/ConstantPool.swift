/*
 * jacobin - JVM written in Swift
 *
 * Copyright (c) 2021 Andrew Binstock. All rights reserved.
 * Licensed under Mozilla Public License, v. 2.0. http://mozilla.org/MPL/2.0/.
 */
import Foundation

class ConstantPool {

    // the constant pool of a class is a collection of individual entries that point to classes, methods, strings, etc.
    // This method parses through them and creates an array of parsed entries in the class being loaded. The entries in
    // the array inherit from cpEntryTemplate. Note that the first entry in all constant pools is non-existent, which I
    // believe was done to avoid off-by-one errors in lookups, but not sure. This is why the loop through entries begins
    // at 1, rather than 0.
    //
    // returns the byte number of the end of constant pool
    //
    // Refer to: https://docs.oracle.com/javase/specs/jvms/se11/html/jvms-4.html#jvms-4.4-140
    // TODO: Adding the remaining entry types for the class constant pool
    static func load( klass: LoadedClass ) -> Int {
        var byteCounter = 9 //the number of bytes we're into the class file (zero-based)
        let cpe = CpEntryTemplate()
        klass.cp.append( cpe ) // entry[0] is never used
        for _ in 1...klass.constantPoolCount - 1 {
            byteCounter += 1
            let cpeType = Int(klass.rawBytes[byteCounter])
            switch( cpeType ) {
            case 1: // UTF-8 string
                let length =
                        Utility.getInt16from2Bytes( msb: klass.rawBytes[byteCounter+1], lsb: klass.rawBytes[byteCounter+2] )
                byteCounter += 2
                var buffer = [UInt8]()
                for n in 0...Int(length-1)  {
                    buffer.append(klass.rawBytes[byteCounter+n+1])
                }
                let UTF8string = String(bytes: buffer, encoding: String.Encoding.utf8 ) ?? ""
                let UTF8entry = CpEntryUTF8( contents: UTF8string )
                klass.cp.append( UTF8entry )
                byteCounter += Int(length)
                print( "UTF-8 string: \( UTF8string ) ")

            case 3: // integer constant
                let value =
                        Utility.getIntfrom4Bytes(bytes: klass.rawBytes, index: byteCounter+1 )
                let integerConstantEntry = CpIntegerConstant( value: value )
                klass.cp.append( integerConstantEntry )
                byteCounter += 4
                print( "Integer constant: \( value )" )

            case 5: // long constant (fills two slots in the constant pool)
                let highBytes =
                        Utility.getIntfrom4Bytes(bytes: klass.rawBytes, index: byteCounter+1 )
                let lowBytes =
                        Utility.getIntfrom4Bytes(bytes: klass.rawBytes, index: byteCounter+5 )
                let longValue : Int64 = Int64(( highBytes << 32) + lowBytes)
                let longConstantEntry = CpLongConstant( value: longValue )
                klass.cp.append( longConstantEntry )
                // longs take up two slots in the constant pool, of which the second slot is
                // never accessed. So set up a dummy entry for that slot.
                klass.cp.append( CpEntryTemplate() )
                byteCounter += 8
                print( "Long constant: \( longValue )")

            case 7: // class reference
                let classNameIndex =
                        Utility.getInt16from2Bytes( msb: klass.rawBytes[byteCounter+1], lsb: klass.rawBytes[byteCounter+2] )
                let classNameRef = CpEntryClassRef( index: classNameIndex )
                klass.cp.append( classNameRef )
                byteCounter += 2
                print( "Class name reference: index: \( classNameIndex ) ")

            case 8: // string reference
                let stringIndex =
                        Utility.getInt16from2Bytes( msb: klass.rawBytes[byteCounter+1], lsb: klass.rawBytes[byteCounter+2] )
                let stringRef = CpEntryStringRef( index: stringIndex )
                klass.cp.append( stringRef )
                byteCounter += 2
                print( "String reference: string index: \(stringIndex) ")

            case  9: // field reference
                let classIndex =
                        Utility.getInt16from2Bytes( msb: klass.rawBytes[byteCounter+1], lsb: klass.rawBytes[byteCounter+2] )
                let nameAndTypeIndex =
                        Utility.getInt16from2Bytes( msb: klass.rawBytes[byteCounter+3], lsb: klass.rawBytes[byteCounter+4] )
                byteCounter += 4
                let fieldRef : CpEntryFieldRef = CpEntryFieldRef( classIndex: classIndex,
                        nameAndTypeIndex: nameAndTypeIndex );
                klass.cp.append( fieldRef )
                print( "Field reference: class index: \(classIndex) nameAndTypeIndex: \(nameAndTypeIndex)")

            case 10: // method reference
                let classIndex =
                        Utility.getInt16from2Bytes( msb: klass.rawBytes[byteCounter+1], lsb: klass.rawBytes[byteCounter+2] )
                let nameAndTypeIndex =
                        Utility.getInt16from2Bytes( msb: klass.rawBytes[byteCounter+3], lsb: klass.rawBytes[byteCounter+4] )
                byteCounter += 4
                let methodRef : CpEntryMethodRef = CpEntryMethodRef( classIndex: classIndex,
                        nameAndTypeIndex: nameAndTypeIndex );
                klass.cp.append( methodRef )
                print( "Method reference: class index: \(classIndex) nameAndTypeIndex: \(nameAndTypeIndex)")

            case 12: // name and type info
                let nameIndex =
                        Utility.getInt16from2Bytes( msb: klass.rawBytes[byteCounter+1], lsb: klass.rawBytes[byteCounter+2] )
                let descriptorIndex =
                        Utility.getInt16from2Bytes( msb: klass.rawBytes[byteCounter+3], lsb: klass.rawBytes[byteCounter+4] )
                byteCounter += 4
                let nameAndType : CpNameAndType =
                        CpNameAndType( nameIdx: Int(nameIndex), descriptorIdx: Int(descriptorIndex))
                klass.cp.append( nameAndType )
                print( "Name and type info: name index: \(nameIndex) descriptorIndex: \(descriptorIndex)")

            default:
                print( "** Unhandled constant pool entry found: \(cpeType)" )
                break
            }
        }
        return byteCounter
    }

    // make sure all the pointers point to the correct items and that values are within the right range
    static func verify( klass: LoadedClass, klassName: String ) {
        for n in 1...klass.constantPoolCount - 1 {
            switch ( klass.cp[n].type ) {
            case 1: //UTF8 string
                let currTemp: CpEntryTemplate = klass.cp[n]
                let currEntry: CpEntryUTF8 = currTemp as! CpEntryUTF8
                let UTF8string = currEntry.string
                if UTF8string.contains( Character( UnicodeScalar( 0x00 ) ) ) || //Ox00 and OxF0 through 0xFF are disallowed
                           UTF8string.contains( Character( UnicodeScalar( 0xF0 ) ) ) ||
                           UTF8string.contains( Character( UnicodeScalar( 0xF1 ) ) ) ||
                           UTF8string.contains( Character( UnicodeScalar( 0xF2 ) ) ) ||
                           UTF8string.contains( Character( UnicodeScalar( 0xF3 ) ) ) ||
                           UTF8string.contains( Character( UnicodeScalar( 0xF4 ) ) ) ||
                           UTF8string.contains( Character( UnicodeScalar( 0xF5 ) ) ) ||
                           UTF8string.contains( Character( UnicodeScalar( 0xF6 ) ) ) ||
                           UTF8string.contains( Character( UnicodeScalar( 0xF7 ) ) ) ||
                           UTF8string.contains( Character( UnicodeScalar( 0xF8 ) ) ) ||
                           UTF8string.contains( Character( UnicodeScalar( 0xF9 ) ) ) ||
                           UTF8string.contains( Character( UnicodeScalar( 0xFA ) ) ) ||
                           UTF8string.contains( Character( UnicodeScalar( 0xFB ) ) ) ||
                           UTF8string.contains( Character( UnicodeScalar( 0xFC ) ) ) ||
                           UTF8string.contains( Character( UnicodeScalar( 0xFD ) ) ) ||
                           UTF8string.contains( Character( UnicodeScalar( 0xFE ) ) ) ||
                           UTF8string.contains( Character( UnicodeScalar( 0xFF ) ) ) {
                    jacobin.log.log( msg: "Error validating constant pool in class \(klassName) Exiting.",
                            level: Logger.Level.SEVERE )
                }

            case 7: // class reference must point to UTF8 string
                let currTemp: CpEntryTemplate = klass.cp[n]
                let currEntry: CpEntryClassRef = currTemp as! CpEntryClassRef
                let index = currEntry.classNameIndex
                let pointedToEntry = klass.cp[index]
                if pointedToEntry.type != 1 {
                    jacobin.log.log( msg: "Error validating constant pool in class \(klassName) Exiting.",
                            level: Logger.Level.SEVERE )
                }

            case 8: // constant string must point to a UTF8 string
                let currTemp: CpEntryTemplate = klass.cp[n]
                let currEntry: CpEntryStringRef = currTemp as! CpEntryStringRef
                let index = currEntry.stringIndex
                let pointedToEntry = klass.cp[index]
                if pointedToEntry.type != 1 {
                    jacobin.log.log( msg: "Error validating constant pool in class \(klassName) Exiting.",
                            level: Logger.Level.SEVERE )
                }

            case 9: // field ref must point to a class and to a nameAndType
                let currTemp: CpEntryTemplate = klass.cp[n]
                let currEntry: CpEntryFieldRef = currTemp as! CpEntryFieldRef
                let classIndex = currEntry.classIndex
                let nameAndTypeIndex = currEntry.nameAndTypeIndex
                let pointedToEntry = klass.cp[classIndex]
                let pointedToField = klass.cp[nameAndTypeIndex]
                if pointedToEntry.type != 7 || pointedToField.type != 12 {
                    jacobin.log.log( msg: "Error validating constant pool in class \(klassName) Exiting.",
                            level: Logger.Level.SEVERE )
                }

            case 10: // method reference
                let currTemp: CpEntryTemplate = klass.cp[n]
                let currEntry: CpEntryMethodRef = currTemp as! CpEntryMethodRef
                let classIndex = currEntry.classIndex
                var pointedToEntry = klass.cp[classIndex]
                if pointedToEntry.type != 7 { //method ref must point to a class reference
                    jacobin.log.log( msg: "Error validating constant pool in class \(klassName) Exiting.",
                            level: Logger.Level.SEVERE )
                }
                let nameIndex = currEntry.nameAndTypeIndex
                pointedToEntry = klass.cp[nameIndex]
                if pointedToEntry.type != 12 { //method ref name index must point to a name and type entry
                    jacobin.log.log( msg: "Error validating constant pool in class \(klassName) Exiting.",
                            level: Logger.Level.SEVERE )
                } else { // make sure the name and type entry's name is pointing to a correctly named method
                    let nameAndTypEntry: CpNameAndType = pointedToEntry as! CpNameAndType
                    let namePointer = nameAndTypEntry.nameIndex
                    pointedToEntry = klass.cp[namePointer]
                    if pointedToEntry.type != 1 { //the name must be a UTF8 string
                        jacobin.log.log( msg: "Error validating constant pool in class \(klassName) Exiting.",
                                level: Logger.Level.SEVERE )
                    } else { // if the name begins with a < it must only be <init>
                        let utf8Entry: CpEntryUTF8 = pointedToEntry as! CpEntryUTF8
                        let methodName = utf8Entry.string
                        if methodName.starts( with: "<" ) && !( methodName.starts( with: "<init>" ) ) {
                            jacobin.log.log( msg: "Error validating constant pool in class \(klassName) Exiting.",
                                    level: Logger.Level.SEVERE )
                        }
                    }
                }

            case 12: // name and type info
                let currTemp: CpEntryTemplate = klass.cp[n]
                let nameAndTypEntry: CpNameAndType = currTemp as! CpNameAndType
                let namePointer = nameAndTypEntry.nameIndex
                var cpEntry = klass.cp[namePointer]
                if cpEntry.type != 1 { //the name pointer must point to a UTF8 string
                    jacobin.log.log( msg: "Error validating constant pool in class \(klassName) Exiting.",
                            level: Logger.Level.SEVERE )
                }
                let typePointer = nameAndTypEntry.descriptorIndex
                cpEntry = klass.cp[typePointer]
                if cpEntry.type != 1 { //the name pointer must point to a UTF8 string
                    jacobin.log.log( msg: "Error validating constant pool in class \(klassName) Exiting.",
                            level: Logger.Level.SEVERE )
                }

            default: continue // for the nonce, eventually should be an error.
            }
        }
    }

    // a quick statistical point if we're at the highest level of verbosity
    static func log( klass: LoadedClass ) {
        jacobin.log.log(msg: "Class: \( klass.path ) - constant pool has: \( klass.cp.count ) entries",
                        level: Logger.Level.FINEST )
    }
}
