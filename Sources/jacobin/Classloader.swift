/*
 * jacobin - JVM written in Swift
 *
 * Copyright (c) 2021 Andrew Binstock. All rights reserved.
 * Licensed under Mozilla Public License, v. 2.0. http://mozilla.org/MPL/2.0/.
 */

/// handles the loading of classes

import Foundation

class Classloader {
    var name = ""
    var parent = ""
    var cl : [String: LoadedClass] = [:]

    func setName( name: String ) {
        self.name = name
    }

    func add( name: String, klass: LoadedClass ) {
        cl[name] = klass;
    }

    func load( name: String ) {
        let fileURL = URL( string: "file:" + name )!
        do {
            let data = try? Data( contentsOf: fileURL, options: [.uncached] )
//            print( "class read, size: \(data?.count)" )
            let klass = LoadedClass()
            klass.rawBytes = [UInt8]( data.unsafelyUnwrapped )

            //check that the class file begins with the magic number 0xCAFEBABE
            if klass.rawBytes[0] != 0xCA || klass.rawBytes[1] != 0xFE ||
               klass.rawBytes[2] != 0xBA || klass.rawBytes[3] != 0xBE {
               log.log(msg: "Invalid class format in \(name). Exiting", level: Logger.Level.SEVERE )
               shutdown( successFlag: false )
            }

            //check that the file version is not above JDK 11
            let minorVersion = Int16( klass.rawBytes[4] )
        } catch {
            log.log(msg: "Error reading file: \(name). Exiting", level: Logger.Level.SEVERE)
            shutdown( successFlag: false )
        }
//CURR: resume here
    }
}

class LoadedClass {
    var status = 0;
    var rawBytes = [UInt8]()
}
