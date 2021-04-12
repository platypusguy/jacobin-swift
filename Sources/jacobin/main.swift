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
    processCommandLine( args: CommandLine.arguments )
    log.log ( msg: "starting Jacobin VM", level: Logger.Level.FINE )
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

func showUsage() {
    print ( """
            Usage: jacobin [arguments] class name [program parameters]

               where arguments can be:
               -h             print this information
               -version       show the jacobin version number

            """ )
}
