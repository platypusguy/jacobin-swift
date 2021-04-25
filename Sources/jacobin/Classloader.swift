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
            ConstantPool.verify( klass: klass, klassName: name )
            ConstantPool.log( klass: klass )

            // load and verify the class access masks
            AccessFlags.readAccessFlags( klass: klass, location: location )
            AccessFlags.processClassAccessMask( klass: klass )
            AccessFlags.verify( klass: klass )
            AccessFlags.log( klass: klass )
            location += 2

            // get the pointer to this class name
            ThisClassName.readName( klass: klass, location: location )
            ThisClassName.verify( klass: klass )
            ThisClassName.process( klass: klass )
            ThisClassName.log( klass: klass )
            location += 2

            // get the pointer to the superclass for this class
            SuperClassName.readName( klass: klass, location: location )
            SuperClassName.verify( klass: klass )
            SuperClassName.process( klass: klass )
            SuperClassName.log( klass: klass )
            location += 2

            // get the count of interfaces implemented by this class
            InterfaceCount.readInterfaceCount( klass: klass, location: location )
            InterfaceCount.log( klass: klass )
            location += 2

            //**Eventually: add handling of interfaces, when count > 0

            // get the count of fields in this class
            FieldCount.readFieldCount( klass: klass, location: location )
            FieldCount.log( klass: klass )
            location += 2

            //**Eventually: add handling of fields , when count > 0

            // get the count of methods in this class
            MethodCount.readMethodCount( klass: klass, location: location )
            MethodCount.log( klass: klass )
            location += 2

            for i in 0...(klass.methodCount - 1) {
                let mi = MethodInfo()
                mi.read( klass: klass, location: location )
//                mi.verify( klass: klass, index: i )
                mi.log( klass: klass, index: i )
            }

              //CURR: work on getting method info...
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

