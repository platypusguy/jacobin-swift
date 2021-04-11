//
// Global variables that will be used in the JVM
//

import Foundation
//import CoreFoundation

struct Globals {
    var logLevel = Logger.Level.SEVERE
    var startTime: DispatchTime
}

class Logger {
    enum Level :  Int {
        case SEVERE = 1, WARNING, CLASS, INFO, FINE, FINEST
    }

    func log( msg: String, level: Logger.Level ) {
//        var elapsedSecs = 0.0
        
        if level.rawValue <= globals.logLevel.rawValue {
            let currTime = DispatchTime.now()
            let elapsedMillis = ( currTime.uptimeNanoseconds - globals.startTime.uptimeNanoseconds ) / 1_000_000
            let elapsedSecs = Double(elapsedMillis) / 1000.0
            logQueue.async( group: threads ) {
                print( "[\(elapsedMillis/1000).\(elapsedMillis%1000)s] \(msg)" )
            }
        }
    }


}
