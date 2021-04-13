/*
 * jacobin - JVM written in Swift
 *
 * Copyright (c) 2021 Andrew Binstock. All rights reserved.
 * Licensed under Mozilla Public  License, v. 2.0. http://mozilla.org/MPL/2.0/.
 */

/// handles all command-line parsing and function dispatch

import Foundation

class CommandLineProcessor {
    func process( args: [String] ) {
        //in Swift, arg[0] is the name of the program (i.e., jacobin). we capture this.
        var commandLine: String = args[0] + " "

        let environment: [String: String] = ProcessInfo.processInfo.environment

        // get the command-line args that might be hidden in the environment variables
        // the order of the fetches is significant and specified in the JVM spec

        if let javaToolOptions = environment["JAVA_TOOL_OPTIONS"] {
            commandLine += javaToolOptions + " "
        }

        if let javaOptions = environment["_JAVA_OPTIONS"] {
            commandLine += javaOptions + " "
        }

        if let jdkOptions = environment["JDK_JAVA_OPTIONS"] {
            commandLine += jdkOptions + " "
        }

        // after adding all the options specified in the environment variables, we add the user-specified parameters
        if args.count > 1 {
            for index in 1...args.count - 1 {
                commandLine += args[index] + " "
            }
        }

        let fullCommandLine = commandLine.trimmingCharacters( in: .whitespacesAndNewlines )
        globals.commandLine = fullCommandLine
        log.log ( msg: "command line: " + fullCommandLine, level: Logger.Level.FINE )
    }

    // parses the full command line into a table; dispatches basic commands (-help, -version, etc.)
    // returns true = continue processing, false = should exit (such as after showing -help or -version info)
    func dispatch( commandLine: String )-> Bool {
        let allArgs = commandLine.components(separatedBy: " ")

        if allArgs.count < 2        ||
           allArgs.contains( "?" )  ||
           allArgs.contains( "=h" ) ||
           allArgs.contains( "-help" )  {
                showUsage( stream: Streams.serr );
                return false
        }
        else
        if allArgs.contains( "--help") {
            showUsage( stream: Streams.sout )
            return false
        }

        return( true ) // for the nonce TODO: resume here with version number and copyright (stored in globals)

    }
}
