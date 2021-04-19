/*
 * jacobin - JVM written in Swift
 *
 * Copyright (c) 2021 Andrew Binstock. All rights reserved.
 * Licensed under Mozilla Public License, v. 2.0. http://mozilla.org/MPL/2.0/.
 */

// Global variables that will be used in the JVM

import Foundation

struct Globals {
    // ---- logging items ----
    var logLevel = Logger.Level.WARNING
    var startTime: DispatchTime

    // ---- command-line items ----
    var commandLine: String = ""
    var startingClass = ""
    var appArgs: [String] = [""]

    // ---- classloading items ----
    var bootstrapLoader = Classloader( name: "bootstrap", parent: "" )
    var systemLoader    = Classloader( name: "system", parent: "bootstrap" )
    var assertionStatus = true //default assertion status is that assertions are executed. This is only for start-up.

    // ---- jacobin version info -----
    let version = "0.1.0"
}

