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

    /// create Classloader with name and pointing to parent.
    init( name: String, parent: String ) {
        self.name = name
        self.parent = parent
    }

    /// inserts a parsed class into the classloader, if it's not already there
    /// - Parameters:
    ///   - name: the name of the class
    ///   - klass: the Swift object containing all the needed parsed data
    private func insert( name: String, klass: LoadedClass ) {
        if( cl[name] == nil ) {
            cl[name] = klass;
        }
    }

    /// add a class for which we have only the name, provided that it's not already
    /// in this classloader
    /// - Parameter name: the name of the class
    func add( name: String ) {
        if cl[name] != nil { return } // do nothing if the class is already loaded
                                      // TODO: go up the chain of classloaders
        var klass = LoadedClass()
        do {
            try ClassParser.parseClassfile(name: name, klass: klass )
            if name != "bootstrap" { //bootstrap-loaded classes don't require an integrity check
                try ClassIntegrity.check( klass: klass )
            }
            insert( name: name, klass: klass )
        }
        catch JVMerror.ClassFormatError {
            shutdown( successFlag: false ) // error msg has already been shown to user
        }
        catch { // any other errors are unexpected, we should tell the user
            log.log( msg: "Unexpected error loading class \(name)",
                     level: Logger.Level.SEVERE)
        }
    }
}

