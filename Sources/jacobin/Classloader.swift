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
    func load( name: String ) throws {

        if cl[name] != nil { // if the class is already in the loader, return TODO: go up the chain of classloaders
            return
        }

        let klass = LoadedClass()
        let fileURL = URL( string: "file:" + name )!
        do {
            let data = try? Data( contentsOf: fileURL, options: [.uncached] )
    //            print( "class read, size: \(data?.count)" ) //TODO: test for the I/O exception here not at the bottom.

            klass.path = name
            klass.rawBytes = [UInt8]( data.unsafelyUnwrapped )

        } catch {
            log.log( msg: "Error reading file: \(name) Exiting", level: Logger.Level.SEVERE )
            shutdown( successFlag: false )
        }

        do {
            //check that the class file begins with the magic number 0xCAFEBABE
            if klass.rawBytes[0] != 0xCA || klass.rawBytes[1] != 0xFE ||
                       klass.rawBytes[2] != 0xBA || klass.rawBytes[3] != 0xBE {
                throw JVMerror.ClassFormatError( name: name )
            }

            //check that the file version is not above JDK 11 (that is, 55)
            let version = Int( Int16( klass.rawBytes[6] ) * 256 ) + Int( klass.rawBytes[7] )
            if version > 55 {
                log.log(
                        msg: "Error: this version of Jacobin supports only Java classes at or below Java 11. Exiting.",
                        level: Logger.Level.SEVERE )
                shutdown( successFlag: false )
            } else {
                klass.version = version;
                klass.status = classStatus.PRELIM_VERIFIED
            }

            // get the constant pool count
            let cpCount: Int = Int( Int16( klass.rawBytes[8] ) * 256 ) + Int( klass.rawBytes[9] )
            if cpCount < 2 {
                throw JVMerror.ClassFormatError( name: name + " constant pool count." )
            } else {
                klass.constantPoolCount = cpCount
            }

            // load and verify the constant pool
            var location: Int = ConstantPool.load( klass: klass ) //location = index of last byte examined
            print( "class \(name) constant pool has: \(klass.cp.count) entries" )
            ConstantPool.verify( klass: klass, klassName: name )

            // load and verify the class access masks
            let accessMask = AccessFlags.readAccessFlags( klass: klass, location: location )
            AccessFlags.processClassAccessMask( mask: accessMask, klass: klass )
            AccessFlags.verify( accessMask: accessMask, klass: klass )

            location += 2
            let s = String( format: "%02X", accessMask ); print( "access mask: \(s)" )

            // get the pointer to this class
            let thisClassEntry = Int(Utility.getInt16fromBytes( msb: klass.rawBytes[location+1],
                                                                lsb: klass.rawBytes[location+2] ))
            if( klass.cp[thisClassEntry].type != 7 ) { // must point to a class reference
                throw JVMerror.ClassVerificationError( name: name )
            }
            location += 2
            let t = String( format: "%02X", thisClassEntry ); print( "this class entry in cp: \(t)" )
              //CURR: work on following fields.
        }
        catch JVMerror.ClassFormatError( name: klass.path ) {
            log.log( msg: "ClassFormatError in \(name)", level: Logger.Level.SEVERE )
            shutdown( successFlag: false )
        }

        //TODO: and validate with the logic here: https://docs.oracle.com/javase/specs/jvms/se11/html/jvms-4.html#jvms-4.1
        //TODO: from 4.10:
        //Ensuring that final classes are not subclassed.
        //
        //Ensuring that final methods are not overridden (§5.4.5).
        //
        //Checking that every class (except Object) has a direct superclass.

        }
}

enum classStatus  :  Int { case NOT_VERIFIED, PRELIM_VERIFIED, VERIFIED, LINKED, PREPARED }


class LoadedClass {
    var path = ""
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

