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

    /// inserts a parsed class into the classloader, if it's not already there
    /// - Parameters:
    ///   - name: the name of the class
    ///   - klass: the Swift class containing all the needed parsed data
    private func insert( name: String, klass: LoadedClass ) {
        if( cl[name] == nil ) {
            cl[name] = klass;
        }
    }

    /// add a class for which we have only the name, provided that it's not already
    /// in this classloader
    /// - Parameter name: the name of the class
    func add( name: String ) {
        if cl[name] != nil { return } // do nothing if the class is already loaded

        var klass = LoadedClass()
        do {
            try load( name: name, klass: klass )
            insert( name: name, klass: klass )
        }
        catch JVMerror.ClassFormatError {
            shutdown( successFlag: false ) // error msg has already been shown to user
        }
        catch { // any other errors are unexpected, we should tell the user
            log.log( msg: "Unexpected error loading class \(name)",
                    level: Logger.Level.SEVERE)
        }
    }

    // CURR >>>> move load to its own class. Maybe ClassParser.swift or the like
    // CURR >>>> possibly keep the read function here and export just the parsing
    // reads in a class, parses it, creates a loadable class and loads it
    // then adds it to the class loader
    func load( name: String, klass: LoadedClass  ) throws {

        if cl[name] != nil { // if the class is already in the loader, return TODO: go up the chain of classloaders
            return
        }

        let fileURL = URL( string: "file:" + name )!
        do {
            let data = try Data( contentsOf: fileURL, options: [.uncached] )
    //            print( "class read, size: \(data?.count)" ) //TODO: test for the I/O exception here not at the bottom.
            klass.path = name
            klass.rawBytes = [UInt8]( data )

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

            for i in 0...( klass.methodCount - 1 ) {
                let mi = MethodInfo()
                location = mi.read( klass: klass, location: location )
//                mi.verify( klass: klass, index: i )
                mi.log( klass: klass, index: i )
            }

              //CURR: work on getting method info...
        }
        catch JVMerror.ClassFormatError( name: klass.path ) {
            log.log( msg: "ClassFormatError in \(name)", level: Logger.Level.SEVERE )
            throw JVMerror.ClassFormatError( name: "" )
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

