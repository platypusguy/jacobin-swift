/*
 * jacobin - JVM written in Swift
 *
 * Copyright (c) 2021 Andrew Binstock. All rights reserved.
 * Licensed under Mozilla Public  License, v. 2.0. http://mozilla.org/MPL/2.0/.
 */

// the logger, which operates in its own thread

import Foundation

class Logger {
        enum Level :  Int {
            case SEVERE = 1, WARNING, CLASS, INFO, FINE, FINEST
        }

        func log( msg: String, level: Logger.Level ) {
            if level.rawValue <= globals.logLevel.rawValue {
                logQueue.async( group: threads ) {
                    let currTime = DispatchTime.now()
                    let elapsedMillis = ( currTime.uptimeNanoseconds - globals.startTime.uptimeNanoseconds ) / 1_000_000
                    let s = String( format: "%0.03f", elapsedMillis/1000 )
                    fputs( "[\(s)s] \(msg)\n", stderr )
//                    print( "[\(elapsedMillis/1000).\(elapsedMillis%1000)s] \(msg)" )
                }
            }
        }
}
