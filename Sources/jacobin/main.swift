/*
 * jacobin - JVM written in Swift
 *
 * Copyright (c) 2021 Andrew Binstock. All rights reserved.
 * Licensed under Mozilla Public  License, v. 2.0. http://mozilla.org/MPL/2.0/.
 */

/// main line of jacobin

import Dispatch
import Foundation

var globals  = Globals( startTime: DispatchTime.now() )

let logQueue = DispatchQueue( label: "logQueue" )
let threads  = DispatchGroup()
let log = Logger()
main()
shutdown( successFlag: true )


func main() {

    if( CommandLine.arguments.contains( "-vverbose" )) {
        globals.logLevel = Logger.Level.FINEST;
    }
    globals.logLevel = Logger.Level.FINEST; //for the nonce -- remove eventually
    log.log ( msg: "starting Jacobin VM", level: Logger.Level.FINE )
    processCommandLine( args: CommandLine.arguments )
}

func processCommandLine( args: [String]) {
    let cp = CommandLineProcessor()
    cp.process(args: args)
    if  cp.dispatch( commandLine: globals.commandLine ) == false {
        shutdown( successFlag: true )
    }

}

/// shuts downt the JVM. If passed 'true' it's a normal shutdown, if 'false' this indicates an error was the cause
func shutdown( successFlag : Bool ) {
    threads.wait()
    exit( successFlag ? 0 : -1 )
}

func showUsage( stream:  Streams ) {
    let outStream = stream ?? Streams.serr

    let usage =
            """
            Usage: jacobin [options] <mainclass> [args...]
                      (to execute a class)
                or jacobin [options] -jar <jarfile> [args...]
                      (to execute a jar file)
            Arguments following the main class, source file, -jar <jarfile>,
            are passed as the arguments to main class.

            where options include:

                -? -h -help
                              print this help message to the error stream
                --help        print this help message to the output stream

            """
    fputs( usage + "\n", outStream == Streams.sout ? stdout : stderr )
}
