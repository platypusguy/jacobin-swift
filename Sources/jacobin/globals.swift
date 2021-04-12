/*
 * jacobin - JVM written in Swift
 *
 * Copyright (c) 2021 Andrew Binstock. All rights reserved.
 * Licensed under Mozilla Public  License, v. 2.0. http://mozilla.org/MPL/2.0/.
 */

// Global variables that will be used in the JVM

import Foundation

struct Globals {
    var logLevel = Logger.Level.SEVERE
    var startTime: DispatchTime
    var commandLine: String = ""
}

