/*
 * jacobin - JVM written in Swift
 *
 * Copyright (c) 2021 Andrew Binstock. All rights reserved.
 * Licensed under Mozilla Public License, v. 2.0. http://mozilla.org/MPL/2.0/.
 */

import Foundation

/// handles extracting the class access flags from the class bytecode, processing it, and verifying it.
/// This class is called from the classloader

class AccessFlags {

    // read the class access flags from the raw bytes of the class, here name klass
    // returns the access flags as a 16-bit integer
    static func readAccessFlags( klass: LoadedClass, location: Int ) {
        let accessFlags = Utility.getInt16fromBytes( msb: klass.rawBytes[location+1],
                                                                  lsb: klass.rawBytes[location+2] )
        klass.accessMask = Int( accessFlags )
    }

    // decode the meaning of the class access flags and set the various getters in the class
    // FromTable 4.1-B in the spec: https://docs.oracle.com/javase/specs/jvms/se11/html/jvms-4.html#jvms-4.1-200-E.1
    static func processClassAccessMask( klass: LoadedClass ) {
        let mask = klass.accessMask

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
    static func verify( klass: LoadedClass ) {
        do {
            if klass.classIsInterface {
                if klass.classIsAbstract == false ||
                   klass.classIsSuper    == true  ||
                   klass.classIsFinal    == true  ||
                   klass.classIsEnum     == true  ||
                   klass.classIsModule   == true {
                       throw JVMerror.ClassVerificationError( name: klass.path )
                }
            }

            if klass.classIsInterface == false {
                if klass.classIsAnnotation == true ||
                   klass.classIsModule     == true {
                       throw JVMerror.ClassVerificationError( name: klass.path )
                }
                else
                if klass.classIsFinal    == true &&
                   klass.classIsAbstract == true {
                       throw JVMerror.ClassVerificationError( name: klass.path )
                }
            }

            if klass.classIsAnnotation == true &&
               klass.classIsInterface  == false {
                       throw JVMerror.ClassVerificationError( name: klass.path )
            }

            if klass.accessMask == 0 {
                       throw JVMerror.ClassVerificationError( name: klass.path )
            }

        }
        catch  {
            jacobin.log.log( msg: "Class verification error in access masks of class \(klass.path)",
                     level: Logger.Level.SEVERE )
            shutdown( successFlag: false )
        }
    }

    // log this if we're set at the most verbose level of detail
    static func log( klass: LoadedClass ) {
        let s = String( format: "%02X", klass.accessMask )
        jacobin.log.log(msg: "Class: \(klass.path) - access mask: \(s)", level: Logger.Level.FINEST )
    }
}