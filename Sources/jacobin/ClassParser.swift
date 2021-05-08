/*
 * jacobin - JVM written in Swift
 *
 * Copyright (c) 2021 Andrew Binstock. All rights reserved.
 * Licensed under Mozilla Public License, v. 2.0. http://mozilla.org/MPL/2.0/.
 */

import Foundation

class ClassParser {

    /// reads in a class file, parses it, and puts the values into the fields of the
    /// class that will be loaded into the classloader. Some verification performed
    /// - Parameters:
    ///   - name: name of the class to read in and parse
    ///   - klass: the Swift object that will hold the data extracted from the parsing
    /// - Throws:
    ///   - JVMerror.ClassFormatError - if the parser finds anything unexpected
    static func parseClassfile( name: String, klass: LoadedClass ) throws {

        klass.path = name
        let fileURL = URL( string: "file:" + name )!
        do {
            let data = try Data( contentsOf: fileURL, options: [.uncached] )
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
            let version = Utility.getIntFrom2Bytes( bytes: klass.rawBytes, index: 6 )
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
            let cpCount = Utility.getIntFrom2Bytes( bytes: klass.rawBytes, index: 8 )
            if cpCount < 2 {
                throw JVMerror.ClassFormatError( name: name + " constant pool count." )
            } else {
                klass.constantPoolCount = cpCount
                log.log( msg: "Class \(name) constant pool should have \(cpCount) entries",
                         level: Logger.Level.FINEST )
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

            // get the pointer to this class name and extract the name
            ThisClassName.readName( klass: klass, location: location )
            ThisClassName.verify( klass: klass )
            ThisClassName.process( klass: klass )
            ThisClassName.log( klass: klass )
            location += 2

            // get the pointer to the superclass for this class and extract the name
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
                mi.log( klass: klass, index: i )
                klass.methodInfo.append( mi.methodData )
            }
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