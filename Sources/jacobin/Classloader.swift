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
            let data = try? Data(contentsOf: fileURL, options: [.uncached])
            print( "class read, size: \(data?.count)" )
        } catch {
            print( "error reading file: \(name)" )
        }
//CURR: resume here
    }
}

class LoadedClass {
    var status = 0;
    var rawBytes = [UInt8]()
}
