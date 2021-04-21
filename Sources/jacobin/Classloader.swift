/*
 * jacobin - JVM written in Swift
 *
 * Copyright (c) 2021 Andrew Binstock. All rights reserved.
 * Licensed under Mozilla Public License, v. 2.0. http://mozilla.org/MPL/2.0/.
 */

/// handles the loading of classes

import Foundation

class Classloader {
    var name = ""
    var parent = ""
    var cl : [String: LoadedClass] = [:]

    // create Classloader with name and pointing to parent.
    init( name: String, parent: String ) {
        self.name = name
        self.parent = parent
    }

    // load a class into the classloader, if it's not already there
    func add( name: String, klass: LoadedClass ) {
        if( cl[name] == nil ) {
            cl[name] = klass;
        }
    }

    // reads in a class, parses it, creates a loadable class and loads it, provided the class is not
    // already in the classloader
    func load( name: String ) {

        if cl[name] != nil { // if the class is already in the loader, return TODO: go up the chain of classloaders
            return
        }

        let fileURL = URL( string: "file:" + name )!
        do {
            let data = try? Data( contentsOf: fileURL, options: [.uncached] )
//            print( "class read, size: \(data?.count)" )
            let klass = LoadedClass()
            klass.rawBytes = [UInt8]( data.unsafelyUnwrapped )

            //check that the class file begins with the magic number 0xCAFEBABE
            if klass.rawBytes[0] != 0xCA || klass.rawBytes[1] != 0xFE ||
               klass.rawBytes[2] != 0xBA || klass.rawBytes[3] != 0xBE {
                    throw JVMerror.ClassFormatError( name: name )
            }

            //check that the file version is not above JDK 11 (that is, 55)
            let version = Int( Int16( klass.rawBytes[6]) * 256 ) + Int(klass.rawBytes[7] )
            if version > 55 {
                log.log(
                    msg: "Error: this version of Jacobin supports only Java classes at or below Java 11. Exiting.",
                    level: Logger.Level.SEVERE )
                shutdown(successFlag: false)
            }
            else {
                klass.version = version;
                klass.status = classStatus.PRELIM_VERIFIED
            }

            // get the constant pool count
            let cpCount : Int = Int( Int16( klass.rawBytes[8]) * 256 ) + Int(klass.rawBytes[9] )
            if cpCount < 2  {
                throw JVMerror.ClassFormatError(name: name + " constant pool count." )
            }
            else {
            //    print( "class \(name) constant pool count: \(cpCount)" )
                klass.constantPoolCount = cpCount
            }

            // load the constant pool
            var location: Int = loadConstantPool( klass: klass ) //location = index of last byte examined
            print( "class \(name) constant pool has: \(klass.cp.count) entries")

            // validate the constant pool
            validateConstantPool( klass: klass, klassName: name )

            // load the access masks
            let accessMask = getInt16fromBytes( msb: klass.rawBytes[location+1], lsb: klass.rawBytes[location+2] )
            location += 2
            let s = String( format: "%02X", accessMask )
            print( "access mask: \(s)" )
            processClassAccessMask( mask: accessMask, klass: klass )
            do {
                try verifyClassAccessMasks( klass: klass )
            }
            catch is JVMerror {
                log.log( msg: "Class verification error in access masks of class \(name)",
                         level: Logger.Level.SEVERE )
                shutdown( successFlag: false )
            }
            print( "class is super: \(klass.classIsSuper) " )

            //TODO: and validate with the logic here: https://docs.oracle.com/javase/specs/jvms/se11/html/jvms-4.html#jvms-4.1

        } catch JVMerror.ClassFormatError( name: name ) {
            log.log( msg: "ClassFormat error in: \(name). Exiting", level: Logger.Level.SEVERE )
            shutdown( successFlag: false )
        }
        catch {
            log.log( msg: "Error reading file: \(name) Exiting", level: Logger.Level.SEVERE )
            shutdown( successFlag: false )
        }

    }

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
    func loadConstantPool( klass: LoadedClass ) -> Int {
        var byteCounter = 9 //the number of bytes we're into the class file (zero-based)
        let cpe = CpEntryTemplate()
        klass.cp.append( cpe ) // entry[0] is never used
        for _ in 1...klass.constantPoolCount - 1 {
            byteCounter += 1
            let cpeType = Int(klass.rawBytes[byteCounter])
            switch( cpeType ) {
                case  1: // UTF-8 string
                    let length =
                            getInt16fromBytes( msb: klass.rawBytes[byteCounter+1], lsb: klass.rawBytes[byteCounter+2] )
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

                case  7: // class reference
                    let classNameIndex =
                            getInt16fromBytes( msb: klass.rawBytes[byteCounter+1], lsb: klass.rawBytes[byteCounter+2] )
                    let classNameRef = CpEntryClassRef( index: classNameIndex )
                    klass.cp.append( classNameRef )
                    byteCounter += 2
                    print( "Class name reference: index: \( classNameIndex ) ")

                case  8: // string reference
                    let stringIndex =
                            getInt16fromBytes( msb: klass.rawBytes[byteCounter+1], lsb: klass.rawBytes[byteCounter+2] )
                    let stringRef = CpEntryStringRef( index: stringIndex )
                    klass.cp.append( stringRef )
                    byteCounter += 2
                    print( "String reference: string index: \(stringIndex) ")

                case  9: // field reference
                    let classIndex =
                            getInt16fromBytes( msb: klass.rawBytes[byteCounter+1], lsb: klass.rawBytes[byteCounter+2] )
                    let nameAndTypeIndex =
                            getInt16fromBytes( msb: klass.rawBytes[byteCounter+3], lsb: klass.rawBytes[byteCounter+4] )
                    byteCounter += 4
                    let fieldRef : CpEntryFieldRef = CpEntryFieldRef( classIndex: classIndex,
                            nameAndTypeIndex: nameAndTypeIndex );
                    klass.cp.append( fieldRef )
                    print( "Field reference: class index: \(classIndex) nameAndTypeIndex: \(nameAndTypeIndex)")

                case 10: // method reference
                    let classIndex =
                            getInt16fromBytes( msb: klass.rawBytes[byteCounter+1], lsb: klass.rawBytes[byteCounter+2] )
                    let nameAndTypeIndex =
                            getInt16fromBytes( msb: klass.rawBytes[byteCounter+3], lsb: klass.rawBytes[byteCounter+4] )
                    byteCounter += 4
                    let methodRef : CpEntryMethodRef = CpEntryMethodRef( classIndex: classIndex,
                                                                         nameAndTypeIndex: nameAndTypeIndex );
                    klass.cp.append( methodRef )
                    print( "Method reference: class index: \(classIndex) nameAndTypeIndex: \(nameAndTypeIndex)")

                case 12: // name and type info
                    let nameIndex =
                            getInt16fromBytes( msb: klass.rawBytes[byteCounter+1], lsb: klass.rawBytes[byteCounter+2] )
                    let descriptorIndex =
                            getInt16fromBytes( msb: klass.rawBytes[byteCounter+3], lsb: klass.rawBytes[byteCounter+4] )
                    byteCounter += 4
                    let nameAndType : CpNameAndType =
                            CpNameAndType( nameIdx: Int(nameIndex), descriptorIdx: Int(descriptorIndex))
                    klass.cp.append( nameAndType )
                    print( "Name and type info: name index: \(nameIndex) descriptorIndex: \(descriptorIndex)")

                default: break
            }
        }
        return byteCounter
    }

    // make sure all the pointers point to the correct items and that values are within the right range
    func validateConstantPool( klass: LoadedClass, klassName: String ) {
        for n in 1...klass.constantPoolCount-1 {
            switch( klass.cp[n].type ) {
            case 1: //UTF8 string
                let currTemp: CpEntryTemplate = klass.cp[n]
                let currEntry: CpEntryUTF8 = currTemp as! CpEntryUTF8
                let UTF8string = currEntry.string
                if UTF8string.contains( Character(UnicodeScalar(0x00))) || //Ox00 and OxF0 through 0xFF are disallowed
                   UTF8string.contains( Character(UnicodeScalar(0xF0))) ||
                   UTF8string.contains( Character(UnicodeScalar(0xF1))) ||
                   UTF8string.contains( Character(UnicodeScalar(0xF2))) ||
                   UTF8string.contains( Character(UnicodeScalar(0xF3))) ||
                   UTF8string.contains( Character(UnicodeScalar(0xF4))) ||
                   UTF8string.contains( Character(UnicodeScalar(0xF5))) ||
                   UTF8string.contains( Character(UnicodeScalar(0xF6))) ||
                   UTF8string.contains( Character(UnicodeScalar(0xF7))) ||
                   UTF8string.contains( Character(UnicodeScalar(0xF8))) ||
                   UTF8string.contains( Character(UnicodeScalar(0xF9))) ||
                   UTF8string.contains( Character(UnicodeScalar(0xFA))) ||
                   UTF8string.contains( Character(UnicodeScalar(0xFB))) ||
                   UTF8string.contains( Character(UnicodeScalar(0xFC))) ||
                   UTF8string.contains( Character(UnicodeScalar(0xFD))) ||
                   UTF8string.contains( Character(UnicodeScalar(0xFE))) ||
                   UTF8string.contains( Character(UnicodeScalar(0xFF))) {
                    log.log( msg: "Error validating constant pool in class \(klassName ) Exiting.",
                             level: Logger.Level.SEVERE )
                }

            case 7: // class reference must point to UTF8 string
                let currTemp: CpEntryTemplate = klass.cp[n]
                let currEntry: CpEntryClassRef = currTemp as! CpEntryClassRef
                let index = currEntry.classNameIndex
                let pointedToEntry = klass.cp[index]
                if pointedToEntry.type != 1 {
                    log.log( msg: "Error validating constant pool in class \(klassName) Exiting.",
                            level: Logger.Level.SEVERE )
                }

            case 8: // constant string must point to a UTF8 string
                let currTemp: CpEntryTemplate = klass.cp[n]
                let currEntry: CpEntryStringRef = currTemp as! CpEntryStringRef
                let index = currEntry.stringIndex
                let pointedToEntry = klass.cp[index]
                if pointedToEntry.type != 1 {
                    log.log( msg: "Error validating constant pool in class \(klassName ) Exiting.",
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
                    log.log( msg: "Error validating constant pool in class \(klassName) Exiting.",
                            level: Logger.Level.SEVERE )
                }

            case 10: // method reference
                let currTemp: CpEntryTemplate = klass.cp[n]
                let currEntry: CpEntryMethodRef = currTemp as! CpEntryMethodRef
                let classIndex = currEntry.classIndex
                var pointedToEntry = klass.cp[classIndex]
                if pointedToEntry.type != 7 { //method ref must point to a class reference
                    log.log( msg: "Error validating constant pool in class \(klassName) Exiting.",
                            level: Logger.Level.SEVERE )
                }
                let nameIndex = currEntry.nameAndTypeIndex
                pointedToEntry = klass.cp[nameIndex]
                if pointedToEntry.type != 12 { //method ref name index must point to a name and type entry
                    log.log( msg: "Error validating constant pool in class \(klassName) Exiting.",
                            level: Logger.Level.SEVERE )
                }
                else { // make sure the name and type entry's name is pointing to a correctly named method
                    let nameAndTypEntry : CpNameAndType = pointedToEntry as! CpNameAndType
                    let namePointer = nameAndTypEntry.nameIndex
                    pointedToEntry = klass.cp[namePointer]
                    if pointedToEntry.type != 1 { //the name must be a UTF8 string
                        log.log( msg: "Error validating constant pool in class \(klassName) Exiting.",
                                level: Logger.Level.SEVERE )
                    }
                    else { // if the name begins with a < it must only be <init>
                        let utf8Entry : CpEntryUTF8 = pointedToEntry as! CpEntryUTF8
                        let methodName = utf8Entry.string
                        if methodName.starts(with: "<") && !( methodName.starts(with: "<init>")) {
                            log.log( msg: "Error validating constant pool in class \(klassName) Exiting.",
                                    level: Logger.Level.SEVERE )
                        }
                    }
                }

            case 12: // name and type info
                let currTemp: CpEntryTemplate = klass.cp[n]
                let nameAndTypEntry : CpNameAndType = currTemp as! CpNameAndType
                let namePointer = nameAndTypEntry.nameIndex
                var cpEntry = klass.cp[namePointer]
                if cpEntry.type != 1 { //the name pointer must point to a UTF8 string
                    log.log( msg: "Error validating constant pool in class \(klassName) Exiting.",
                            level: Logger.Level.SEVERE )
                }
                let typePointer = nameAndTypEntry.descriptorIndex
                cpEntry = klass.cp[typePointer]
                if cpEntry.type != 1 { //the name pointer must point to a UTF8 string
                    log.log( msg: "Error validating constant pool in class \(klassName) Exiting.",
                            level: Logger.Level.SEVERE )
                }

            default: continue // for the nonce, eventually should be an error.
            }
        }
    }

    // decode the meaning of the class access flags.
    // FromTable 4.1-B in the spec: https://docs.oracle.com/javase/specs/jvms/se11/html/jvms-4.html#jvms-4.1-200-E.1
    func processClassAccessMask( mask: Int16, klass: LoadedClass ) {

        if ( mask & 0x0001 ) > 0 { klass.classIsPublic =     true }
        if ( mask & 0x0010 ) > 0 { klass.classIsFinal      = true }
        if ( mask & 0x0020 ) > 0 { klass.classIsSuper      = true }
        if ( mask & 0x0200 ) > 0 { klass.classIsInterface  = true }
        if ( mask & 0x0400 ) > 0 { klass.classIsAbstract   = true }
        if ( mask & 0x1000 ) > 0 { klass.classIsSynthetic  = true } // is generated by the JVM, is not in the program
        if ( mask & 0x2000 ) > 0 { klass.classIsAnnotation = true }
        if ( mask & 0x4000 ) > 0 { klass.classIsEnum       = true }
        if ( Int(mask) & 0x8000)  > 0 {klass.classIsModule = true }
        //TODO: implement the Prolog predicates this allows for klass. See section 4.10.1.1
    }

    // verify the settings according to the requirements specified in the spec:
    // https://docs.oracle.com/javase/specs/jvms/se11/html/jvms-4.html#jvms-4.1
    func verifyClassAccessMasks( klass: LoadedClass ) throws {
        if klass.classIsInterface {
            if klass.classIsAbstract == false ||
               klass.classIsSuper == true ||
               klass.classIsFinal == true ||
               klass.classIsEnum == true  ||
               klass.classIsModule == true {
                   throw JVMerror.ClassVerificationError(name: "verifying access flags")
            }
        }
        //CURR: resume here with remaining validation.

    }

    // syntactic sugar for converting two succeeding bytes into an integer
    func getInt16fromBytes( msb: UInt8, lsb: UInt8 ) -> Int16 {
        return( Int16(msb) * 256 ) + Int16( lsb )
    }
}

enum classStatus  :  Int { case NOT_VERIFIED, PRELIM_VERIFIED, VERIFIED, LINKED, PREPARED }


class LoadedClass {
    var status = classStatus.NOT_VERIFIED
    var rawBytes = [UInt8]()
    var version = 0
    var constantPoolCount = 0
    var assertionStatus = globals.assertionStatus
    var cp = [CpEntryTemplate]()
    
    var  classIsPublic      = false
    var  classIsFinal       = false
    var  classIsSuper       = false
    var  classIsInterface   = false
    var  classIsAbstract    = false
    var  classIsSynthetic   = false
    var  classIsAnnotation  = false
    var  classIsEnum        = false
    var  classIsModule      = false
    
}



// ==== the classes for each type of entry in the constant pool ====
class CpEntryTemplate {
    var type: Int = 0

    init() {
        type = 0
    }

    init( type: Int ) {
        self.type = type
    }
}

class CpEntryMethodRef: CpEntryTemplate {
    var classIndex = 0
    var nameAndTypeIndex = 0

    init( classIndex : Int16, nameAndTypeIndex: Int16 ) {
        super.init( type: 10 )
        self.classIndex = Int(classIndex)
        self.nameAndTypeIndex = Int(nameAndTypeIndex)
    }

    override init( type: Int ) {
        super.init( type: type )
    }
}

// Field References store the same data as Method References,
//  hence this class derives from CpEntryMethodRef
class CpEntryFieldRef: CpEntryMethodRef {
    override init( classIndex : Int16, nameAndTypeIndex: Int16 ) {
        super.init( type: 9 )
        self.classIndex = Int(classIndex)
        self.nameAndTypeIndex = Int(nameAndTypeIndex)
    }
}

class CpEntryStringRef: CpEntryTemplate {
    var stringIndex = 0

    init( index: Int16 ) {
        super.init( type: 8 )
        stringIndex = Int( index )
    }
}

class CpEntryClassRef: CpEntryTemplate {
    var classNameIndex = 0

    init( index: Int16 ) {
        super.init( type: 7 )
        classNameIndex = Int(index)
    }
}

class CpEntryUTF8: CpEntryTemplate {
    var length = 0
    var string = ""

    init( contents: String ) {
        super.init( type: 1 )
        string = contents
        length = contents.count
    }
}

class CpNameAndType: CpEntryTemplate {
    var nameIndex = 0
    var descriptorIndex = 0

    init( nameIdx: Int, descriptorIdx: Int ) {
        super.init( type: 12 )
        nameIndex = nameIdx
        descriptorIndex = descriptorIdx
    }
}

