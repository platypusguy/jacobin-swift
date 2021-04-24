/*
 * jacobin - JVM written in Swift
 *
 * Copyright (c) 2021 Andrew Binstock. All rights reserved.
 * Licensed under Mozilla Public License, v. 2.0. http://mozilla.org/MPL/2.0/.
 */
import Foundation


// a class after it's been parsed and as it's loaded in the classloader

class LoadedClass {
    var path = ""
    var status = classStatus.NOT_VERIFIED
    var rawBytes = [UInt8]()
    var version = 0
    var constantPoolCount = 0
    var assertionStatus = globals.assertionStatus
    var cp = [CpEntryTemplate]()
    var accessMask = 0
    var thisClassRef : Int = 0
    var shortName = ""
    var superClassRef = 0
    var superClassName = ""
    var interfaceCount = 0
    var fieldCount = 0
    var methodCount = 0

    var classIsPublic      = false
    var classIsFinal       = false
    var classIsSuper       = false
    var classIsInterface   = false
    var classIsAbstract    = false
    var classIsSynthetic   = false
    var classIsAnnotation  = false
    var classIsEnum        = false
    var classIsModule      = false

}

enum classStatus  :  Int { case NOT_VERIFIED, PRELIM_VERIFIED, VERIFIED, LINKED, PREPARED }