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

    }
}
