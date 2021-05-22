/*
 * jacobin - JVM written in Swift
 *
 * Copyright (c) 2021 Andrew Binstock. All rights reserved.
 * Licensed under Mozilla Public License, v. 2.0. http://mozilla.org/MPL/2.0/.
 */

// Exceptions and error handlers

import Foundation

enum JVMerror : Error {
    case ClassFormatError( name: String )
    case ClassVerificationError( name: String )
    case InvalidParameterError( msg: String )
    case UnreachableError( msg: String )
}
