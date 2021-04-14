/*
 * jacobin - JVM written in Swift
 *
 * Copyright (c) 2021 Andrew Binstock. All rights reserved.
 * Licensed under Mozilla Public  License, v. 2.0. http://mozilla.org/MPL/2.0/.
 */

/// handles all command-line parsing and function dispatch

import Foundation

let execStop = false
let execContinue = true

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
        var allArgs = commandLine.components( separatedBy: " " )

        //start by handling all the params that just show the user info and exit: -version, -help, errors, etc.
        let result : Bool? = handleUserMessages( allArgs: allArgs )
        if result != nil {
            return result.unsafelyUnwrapped
        }

        _ = allArgs.removeFirst() // get rid of the call to jacobin
        //next get all the switches/params intended for the JVM, rather than the app
        let startingClass = dispatchJVMParams( args: allArgs )
        if( startingClass.isEmpty ) {
            return execStop // if startingClass is empty, an error occurred and the error msg has already been shown
        }
        else {
            log.log( msg: "starting class: \(startingClass)", level: Logger.Level.FINE )
        }

        return execContinue
    }

    //goes through the command-line switches and parameters that precede the name of the class/jar to execute
    //he settings they specify. Returns the name of the class/jar to execute.
    func dispatchJVMParams( args: [String] ) -> String {
        let startingClass = ""
        for arg in args {

            if !( arg.starts(with: "-") ) { //first arg without a leading hyphen should be the class/jar to execute
                if arg.hasSuffix( ".class") || arg.hasSuffix( ".jar" ) {
                   return( arg )
                }
                else {
                    unrecognizedOptionMsg( option: arg )
                    return ""
                }
            }

            //handle all args/params that start with one or more hyphens
            switch arg {
            case "-h", "-help", "--help", "-showversion", "-version", "--version":
                // these were previously processed, so skip over them
                continue;
            default:
                fputs( "Parameter \(arg) not supported. Ignored.\n", stderr )
            }
        }

        if startingClass.isEmpty {
            UserMsgs.showUsage( stream: Streams.serr );
        }
        return( startingClass )
    }

    // there are a multitude of JVM switches that just print some information (version number, help instructions, etc.)
    // for the user on the console. If they appear on the command line, they are executed (below) and in most cases,
    // all other items are ignored and the program then exits. Where the other switches are *not* ignored, they return
    // execContine in the code below.
    func handleUserMessages( allArgs: [String] ) -> Bool? {
        if allArgs.count < 2        ||
                   allArgs.contains( "?" )  ||
                   allArgs.contains( "-h" ) ||
                   allArgs.contains( "-help" )  {
            UserMsgs.showUsage( stream: Streams.serr );
            return execStop
        }
        else
        if allArgs.contains( "--help") {
            UserMsgs.showUsage( stream: Streams.sout )
            return execStop
        }
        else
        if allArgs.contains( "-version" ) {
            UserMsgs.showVersion( stream: Streams.serr )
            return execStop
        }
        else
        if allArgs.contains( "--version" ) {
            UserMsgs.showVersion( stream: Streams.sout )
            return execStop
        }
        else
        if allArgs.contains( "-showversion" ) {
            UserMsgs.showVersion( stream: Streams.serr )
            return execContinue
        }
        else
        if allArgs.contains( "--showversion" ) {
            UserMsgs.showVersion( stream: Streams.sout )
            return execContinue
        }

        return( nil )
    }

    // shows the fatal error message arising from an invalid, that is, unrecognized, option on the command line
    private func unrecognizedOptionMsg( option: String ) {
        fputs( "Unrecognized option: \(option)\n", stderr )
        fputs( """
               Error: Could not create the Java Virtual Machine.
               Error: A fatal exception has occurred. Program will exit.
               """ + "\n", stderr )
    }
}
