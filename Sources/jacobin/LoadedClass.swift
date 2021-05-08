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
    var cp = [CpEntryTemplate]()  // cp = constant pool
    var accessMask = 0
    var shortName = ""
    var superClassName = ""
    var interfaceCount = 0
    var fieldCount = 0
    var fieldInfo: [Field] = []
    var methodCount = 0
    var methodInfo : [Method] = []

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


// ==== the classes for each type of entry in the constant pool and in the rest of the class ====

class CpEntryTemplate {
    var type: Int = 0

    init() {
        type = 0
    }

    init( type: Int ) {
        self.type = type
    }
}

class CpEntryMethodRef: CpEntryTemplate {  // method reference (10)
    var classIndex = 0
    var nameAndTypeIndex = 0

    init( classIndex : Int16, nameAndTypeIndex: Int16 ) {
        super.init( type: 10 )
        self.classIndex = Int(classIndex)
        self.nameAndTypeIndex = Int(nameAndTypeIndex)
    }

    override init( type: Int ) {
        super.init( type: type )
    }
}

// Field References store the same data as Method References,
//  hence this class derives from CpEntryMethodRef
class CpEntryFieldRef: CpEntryMethodRef {
    override init( classIndex : Int16, nameAndTypeIndex: Int16 ) {
        super.init( type: 9 )
        self.classIndex = Int(classIndex)
        self.nameAndTypeIndex = Int(nameAndTypeIndex)
    }
}

// Interface Method Reference has the same layout as a Method Reference
class CpEntryInterfaceMethodRef: CpEntryMethodRef {
    override init( classIndex : Int16, nameAndTypeIndex: Int16 ) {
        super.init( type: 11 )
        self.classIndex = Int(classIndex)
        self.nameAndTypeIndex = Int(nameAndTypeIndex)
    }
}
class CpEntryStringRef: CpEntryTemplate {  // string reference (8)
    var stringIndex = 0

    init( index: Int16 ) {
        super.init( type: 8 )
        stringIndex = Int( index )
    }
}

class CpIntegerConstant: CpEntryTemplate {  // Constant Integer (3)
    var int = 0

    init( value: Int ) {
        super.init( type: 3 )
        int = value
    }
}

class CpLongConstant : CpEntryTemplate {  // Constant long (5)
    var long: Int64 = 0

    init( value: Int64 ) {
        super.init( type: 5 )
        long = value
    }
}

class CpEntryClassRef: CpEntryTemplate {  // Class ref (7)
    var classNameIndex = 0

    init( index: Int16 ) {
        super.init( type: 7 )
        classNameIndex = Int(index)
    }
}

class CpEntryMethodHandle: CpEntryTemplate { // method reference (15)
    var referenceKind = 0
    var referenceIndex = 0

    init( kind: UInt8, index: Int16 ) {
        super.init( type: 15 )
        referenceKind  = Int( kind )
        referenceIndex = Int( index )
    }
}

class CpMethodType: CpEntryTemplate { // constant method type (16)
    var constantMethodIndex = 0

    init( index: Int16 ) {
        super.init( type: 16 )
        constantMethodIndex = Int(index)
    }
}

class CpInvokedynamic: CpEntryTemplate { // invokedynamic (18)
    var bootstrapIndex = 0
    var nameAndTypeIndex = 0

    init( bootstrap: Int16, nameAndType: Int16 ) {
        super.init( type: 18 )
        bootstrapIndex = Int(bootstrap)
        nameAndTypeIndex = Int(nameAndType)
    }
}

class CpEntryUTF8: CpEntryTemplate {
    var length = 0
    var string = ""

    init( contents: String ) {
        super.init( type: 1 )
        string = contents
        length = contents.count
    }
}

class CpNameAndType: CpEntryTemplate {
    var nameIndex = 0
    var descriptorIndex = 0

    init( nameIdx: Int, descriptorIdx: Int ) {
        super.init( type: 12 )
        nameIndex = nameIdx
        descriptorIndex = descriptorIdx
    }
}


