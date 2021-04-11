/// main line of jacobin
///
import Dispatch

var globals  = Globals( startTime: DispatchTime.now() )
//globals.startTime = DispatchTime.now()

let logQueue = DispatchQueue( label: "logQueue" )
let threads  = DispatchGroup()
main()
threads.wait()


func main() {
    processCommandLine( args: CommandLine.arguments )
    let log = Logger()
    if( CommandLine.arguments.contains( "-vverbose" )) {
        globals.logLevel = Logger.Level.FINEST;
    }
    globals.logLevel = Logger.Level.FINEST; //for the nonce
    log.log ( msg: "Starting Jacobin VM", level: Logger.Level.FINE )
}

func processCommandLine( args: [String]) {
    if( args.count != 2 ) {
        showUsage()
    } else {
        let name = CommandLine.arguments[1]
        print( "hello \(name)" )
    }
}

func showUsage() {
    print ( """
            Usage: jacobin [arguments] class name [program parameters]

               where arguments can be:
               -h             print this information
               -version       show the jacobin version number

            """ )
}
