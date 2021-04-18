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

    // create Classloader with name and pointing to parent. This doesn't look like idiomatic Swift. Should revisit.
    func new( name: String, parent: String ) -> Classloader {
        self.name = name
        self.parent = parent
        return( self )
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

        if cl[name] != nil { // if the class is already in the loader, return
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
                print( "class \(name) constant pool count: \(cpCount)" )
                klass.constantPoolCount = cpCount
            }

            // load the constant pool
            loadConstantPool( klass: klass )
            print( "class \(name) constant pool has: \(klass.cp.count) entries")

        } catch JVMerror.ClassFormatError( name: name ) {
            log.log( msg: "ClassFormat error in: \(name). Exiting", level: Logger.Level.SEVERE )
            shutdown( successFlag: false )
        }
        catch {
            log.log( msg: "Error reading file: \(name). Exiting", level: Logger.Level.SEVERE )
            shutdown( successFlag: false )
        }
        //Eventually: add exception for invalid version number and for error reading class file.
    }

    func loadConstantPool( klass: LoadedClass ) {
        var byteCounter = 9 //the number of bytes we're into the class file (zero-based)
        let cpe = CpEntryTemplate()
        klass.cp.append( cpe ) // entry[0] is never used
        for n in 1...klass.constantPoolCount - 1 {
            byteCounter += 1
            let cpe = CpEntry()
            cpe.type = Int(klass.rawBytes[byteCounter])
            switch( cpe.type ) {
                case 10: // method reference
                    cpe.classIndex =
                            getInt16fromBytes( msb: klass.rawBytes[byteCounter+1], lsb: klass.rawBytes[byteCounter+2] )
                    cpe.nameAndTypeIndex =
                            getInt16fromBytes( msb: klass.rawBytes[byteCounter+3], lsb: klass.rawBytes[byteCounter+4] )
                    byteCounter += 4
//                    klass.cp.append( cpe )
                    let methodRef : CpEntryMethodRef = CpEntryMethodRef( classIndex: cpe.classIndex,
                                                                         nameAndTypeIndex: cpe.nameAndTypeIndex );
                    klass.cp.append( methodRef )
                    print( "Method reference: class index: \(cpe.classIndex) nameAndTypeIndex: \(cpe.nameAndTypeIndex)")
                default: break //CURR: for testing only. should indicate a corrupted class file.
            }
        }
    }

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
}

class CpEntryTemplate {
    var type: Int = 0
}

class CpEntryMethodRef: CpEntryTemplate {
    var classIndex: Int16 = 0
    var nameAndTypeIndex: Int16 = 0
    init( classIndex : Int16, nameAndTypeIndex: Int16 ) {
        super.init()
        type = 10
        self.classIndex = classIndex
        self.nameAndTypeIndex = nameAndTypeIndex
    }
}

class CpEntry {
    var type: Int = 0
    var string: String = ""
    var int: Int32 = 0
    var float: Float = 0.0
    var long: Int64 = 0
    var double: Double = 0.0
    var classIndex: Int16 = 0
    var nameAndTypeIndex: Int16 = 0

}
