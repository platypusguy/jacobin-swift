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
        try checkConstantPoolVersion( klass: klass )

        if klass.methodCount > 0 {
            for i in 0...klass.methodCount - 1 {
                let method = klass.methodInfo[i]
                try checkMethodAccessFlags( method: method, klass: klass )
                try checkCodeAttribute( method: method, klass: klass )
            }
        }
    }

    /// checks the constant pool entries.
    static func checkConstantPoolVersion( klass: LoadedClass ) throws {
        let cp : [CpEntryTemplate] = klass.cp
        for i in 1..<klass.constantPoolCount {
            let cpe = cp[i]
            switch( cpe.type ) {
                case .methodHandle:
                    // see https://docs.oracle.com/javase/specs/jvms/se11/html/jvms-4.html#jvms-4.4.8
                    if klass.version < 51 { // methodHandle requires Java 7 at minimum
                        jacobin.log.log( msg: "Class\(klass.shortName) has invalid instruction version",
                                         level: Logger.Level.SEVERE )
                        throw JVMerror.ClassVerificationError( msg: "\(#file), func: \(#function) line: \(#line)" )
                    }

                    let cpMethHandle = cpe as! CpEntryMethodHandle
                    switch( cpMethHandle.referenceKind ) {
                    case 1, 2, 3, 4:
                        if cp[ cpMethHandle.referenceIndex ].type != .field {
                            jacobin.log.log( msg: "Class\(klass.shortName) has a method handle w/ invalid reference index " +
                                                  "for reference kind \( cpMethHandle.referenceKind)",
                                             level: Logger.Level.SEVERE )
                            throw JVMerror.ClassVerificationError( msg: "\(#file), func: \(#function) line: \(#line)" )
                        }
                    case 5, 8:
                        if cp[ cpMethHandle.referenceIndex ].type != .method {
                            jacobin.log.log( msg: "Class\(klass.shortName) has a method handle w/ invalid reference index " +
                                                  "for reference kind \(cpMethHandle.referenceKind)",
                                             level: Logger.Level.SEVERE )
                            throw JVMerror.ClassVerificationError( msg: "\(#file), func: \(#function) line: \(#line)" )
                        }
                    case 6, 7:
                        if klass.version < 52 {
                            if cp[ cpMethHandle.referenceIndex ].type != .method {
                                jacobin.log.log( msg: "Class\(klass.shortName) has a method handle w/ invalid reference index " +
                                                      "for reference kind \(cpMethHandle.referenceKind)",
                                                 level: Logger.Level.SEVERE )
                                throw JVMerror.ClassVerificationError( msg: "\(#file), func: \(#function) line: \(#line)" )
                            }
                        }
                        else {
                            if cp[ cpMethHandle.referenceIndex ].type != .method ||
                               cp[ cpMethHandle.referenceIndex ].type != .interface {
                                jacobin.log.log( msg: "Class\(klass.shortName) has a method handle w/ invalid reference index " +
                                                      "for reference kind \(cpMethHandle.referenceKind)",
                                                 level: Logger.Level.SEVERE )
                                throw JVMerror.ClassVerificationError( msg: "\(#file), func: \(#function) line: \(#line)" )
                            }
                        }
                    case 9:
                        if cp[ cpMethHandle.referenceIndex ].type != .interface {
                            jacobin.log.log( msg: "Class\(klass.shortName) has a method handle w/ invalid reference index " +
                                                  "for reference kind \(cpMethHandle.referenceKind)",
                                             level: Logger.Level.SEVERE )
                            throw JVMerror.ClassVerificationError( msg: "\(#file), func: \(#function) line: \(#line)" )
                        }
                    default:
                            jacobin.log.log( msg: "Class\(klass.shortName) has a method handle w/ invalid reference kind: " +
                                                  "\(cpMethHandle.referenceKind)",
                                             level: Logger.Level.SEVERE )
                            throw JVMerror.ClassVerificationError( msg: "\(#file), func: \(#function) line: \(#line)" )
                }

            case .methodType,
                 .invokeDynamic:
                if klass.version < 51 { //these require Java 7 at minimum
                    jacobin.log.log( msg: "Class\(klass.shortName) has invalid instruction version",
                                     level: Logger.Level.SEVERE )
                    throw JVMerror.ClassVerificationError( msg: "\(#file), func: \(#function) line: \(#line)" )
                }
            case .module,
                 .package:
                if klass.version < 53 { //these require Java 9 at minimum
                    jacobin.log.log( msg: "Class\(klass.shortName) has invalid instruction version",
                        level: Logger.Level.SEVERE )
                    throw JVMerror.ClassVerificationError( msg: "\(#file), func: \(#function) line: \(#line)" )
                }
            case .dynamic:
                if klass.version < 55 { // requires Java 11 at minimum
                    jacobin.log.log( msg: "Class\(klass.shortName) has invalid instruction version",
                        level: Logger.Level.SEVERE )
                    throw JVMerror.ClassVerificationError( msg: "i\(#file), func: \(#function) line: \(#line)" )
                }
            default:
                continue
            }
        }
    }

    /// validate the method access flag requirements per the specification in:
    /// https://docs.oracle.com/javase/specs/jvms/se11/html/jvms-4.html#jvms-4.6
    /// - Parameter klass: the parsed class containing the method entries
    static func checkMethodAccessFlags( method: Method, klass: LoadedClass ) throws {
        //check the access levels for the method
        if ( method.isPublic() && method.isPrivate() ) ||
           ( method.isPublic() && method.isProtected() ) ||
           ( method.isPrivate() && method.isProtected() ) {
            jacobin.log.log( msg: "Method \(method.name) in \(klass.shortName) has conflicting access specifiers",
                level: Logger.Level.SEVERE )
            throw JVMerror.ClassVerificationError( msg: "\(#file), func: \(#function) line: \(#line)" )
        }

        if klass.classIsInterface &&
           ( method.isProtected() || method.isFinal() ||
             method.isNative() || method.isSynchronized() ) {
            jacobin.log.log( msg: "Interface method \(method.name) in \(klass.shortName) has invalid attributes",
                level: Logger.Level.SEVERE )
            throw JVMerror.ClassVerificationError( msg: "\(#file), func: \(#function) line: \(#line)" )
        }

        if method.isAbstract() &&
           ( method.isPrivate() || method.isStatic() ||
             method.isFinal() || method.isNative() ||
             method.isStrictFP() || method.isSynchronized() ) {
            jacobin.log.log( msg: "Abstract method \(method.name) in \(klass.shortName) has invalid attributes",
                level: Logger.Level.SEVERE )
            throw JVMerror.ClassVerificationError( msg: "\(#file), func: \(#function) line: \(#line)" )
        }

        if klass.version >= 51 && method.name == "<clinit>" {
            if method.isStatic() == false {
                jacobin.log.log( msg: "<clinit> method \(method.name) in \(klass.shortName) should be static",
                    level: Logger.Level.SEVERE )
                throw JVMerror.ClassVerificationError( msg: "\(#file), func: \(#function) line: \(#line)" )
            }
        }
    }

    /// runs various checks on the code attribute of a method (if any)
    /// consult: https://docs.oracle.com/javase/specs/jvms/se11/html/jvms-4.html#jvms-4.7.3
    /// - Parameters:
    ///   - method: the method to check
    ///   - klass:  the class that contains the method
    /// - Throws: JVMerror.ClassVerificationError
    static func checkCodeAttribute( method: Method, klass: LoadedClass ) throws {
        if method.codeLength > 0 {
            if method.code.count != method.codeLength {
                jacobin.log.log( msg: "method \(method.name) in \(klass.shortName) has invalid code attribute",
                                 level: Logger.Level.SEVERE )
                throw JVMerror.ClassVerificationError( msg: "\(#file), func: \(#function) line: \(#line)" )
            }

            if method.codeLength >= 65536 {
                jacobin.log.log( msg: "method \(method.name) in \(klass.shortName) has code length > max allowed",
                                 level: Logger.Level.SEVERE )
                throw JVMerror.ClassVerificationError( msg: "\(#file), func: \(#function) line: \(#line)" )
            }
        }

        // check the exception table of the code attribute
        if method.exceptionTable.count > 0 {
            for i in 0..<method.exceptionTable.count {
                let mex = method.exceptionTable[i]
                if mex.startPc < 0 ||
                   mex.endPc > method.codeLength ||
                   mex.startPc > mex.endPc {
                    jacobin.log.log( msg: "method \(method.name) in \(klass.shortName) has invalid exception table",
                        level: Logger.Level.SEVERE )
                    throw JVMerror.ClassVerificationError( msg: "\(#file), func: \(#function) line: \(#line)" )
                }

                if mex.handlerPc < 0 || mex.handlerPc > method.codeLength-1 {
                    jacobin.log.log( msg: "method \(method.name) in \(klass.shortName) has invalid exception table",
                        level: Logger.Level.SEVERE )
                    throw JVMerror.ClassVerificationError( msg: "\(#file), func: \(#function) line: \(#line)" )
                }

                if mex.catchType > 0 {
                    if mex.catchType > klass.constantPoolCount-1 {
                        jacobin.log.log( msg: "method \(method.name) in \(klass.shortName) has invalid exception catch type",
                            level: Logger.Level.SEVERE )
                        throw JVMerror.ClassVerificationError( msg: "\(#file), func: \(#function) line: \(#line)" )
                    }

                    let cpe = klass.cp[mex.catchType]
                    if cpe.type != ConstantPool.RecType.classRef {
                        jacobin.log.log( msg: "method \(method.name) in \(klass.shortName) has invalid exception catch type",
                            level: Logger.Level.SEVERE )
                        throw JVMerror.ClassVerificationError( msg: "\(#file), func: \(#function) line: \(#line)" )
                    }
                }
            }
        }
        //TODO: add checks for code attribute's other attributes
    }
}
