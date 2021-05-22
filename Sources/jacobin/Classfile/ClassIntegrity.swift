/*
 * jacobin - JVM written in Swift
 *
 * Copyright (c) 2021 Andrew Binstock. All rights reserved.
 * Licensed under Mozilla Public License, v. 2.0. http://mozilla.org/MPL/2.0/.
 */
import Foundation

class ClassIntegrity {

    /// does a complete integrity check of the class, making sure of the requirements as
    /// stated in: https://docs.oracle.com/javase/specs/jvms/se11/html/jvms-4.html#jvms-4.8
    /// This is different than verification, which occurs later in the class loading process
    /// - Parameter klass: the class whose integrity is being checked
    /// - Throws: JVMerror.ClassFormatError (principally)
    static func check( klass: LoadedClass ) throws {
        //Notes: the integrity of superclass entries is verified when they're loaded

        if klass.methodCount > 0 {
            try verifyMethodAccessFlags( klass: klass )
            //TODO: Add integrity checks on method attributes
        }
    }

    /// validate the method access flag requirements per the specification in:
    /// https://docs.oracle.com/javase/specs/jvms/se11/html/jvms-4.html#jvms-4.6
    /// - Parameter klass: the parsed class containing the method entries
    private static func verifyMethodAccessFlags( klass: LoadedClass ) throws {
        for i in 0...klass.methodCount-1 {
            let method = klass.methodInfo[i]

            //check the access levels for the method
            if ( method.isPublic()  && method.isPrivate() )   ||
               ( method.isPublic()  && method.isProtected() ) ||
               ( method.isPrivate() && method.isProtected() ) {
                jacobin.log.log( msg: "Method \(method.name) in \(klass.shortName) has conflicting access specifiers",
                                 level: Logger.Level.SEVERE )
                throw JVMerror.ClassVerificationError( msg: "in: \(#file), func: \(#function) line: \(#line)" )
            }

            if klass.classIsInterface &&
               ( method.isProtected() || method.isFinal() ||
                 method.isNative()    || method.isSynchronized() ) {
                jacobin.log.log( msg: "Interface method \(method.name) in \(klass.shortName) has invalid attributes",
                    level: Logger.Level.SEVERE )
                throw JVMerror.ClassVerificationError( msg: "in: \(#file), func: \(#function) line: \(#line)" )
            }

            if method.isAbstract() &&
               ( method.isPrivate()  || method.isStatic() ||
                 method.isFinal()    || method.isNative() ||
                 method.isStrictFP() || method.isSynchronized() ) {
                jacobin.log.log( msg: "Abstract method \(method.name) in \(klass.shortName) has invalid attributes",
                    level: Logger.Level.SEVERE )
                throw JVMerror.ClassVerificationError( msg: "in: \(#file), func: \(#function) line: \(#line)" )
            }

            if klass.version >= 51 && method.name == "<clinit>" {
                if method.isStatic() == false {
                    jacobin.log.log( msg: "<clinit> method \(method.name) in \(klass.shortName) should be static",
                        level: Logger.Level.SEVERE )
                    throw JVMerror.ClassVerificationError( msg: "in: \(#file), func: \(#function) line: \(#line)" )
                }
            }
        }
    }
}
