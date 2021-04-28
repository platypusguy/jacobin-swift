/*
 * jacobin - JVM written in Swift
 *
 * Copyright (c) 2021 Andrew Binstock. All rights reserved.
 * Licensed under Mozilla Public License, v. 2.0. http://mozilla.org/MPL/2.0/.
 */

import Foundation


// Classes for all the attributes found in class files
class Attribute {
    var attrName = ""
    var attrLength = 0
}

class AttributeInfo: Attribute {
    var attrInfo : [UInt8] = []
}

//class CodeAttribute: Attribute {
//    /**
//      u2 max_stack;
//    u2 max_locals;
//    u4 code_length;
//    u1 code[code_length];
//    u2 exception_table_length;
//    {   u2 start_pc;
//        u2 end_pc;
//        u2 handler_pc;
//        u2 catch_type;
//    } exception_table[exception_table_length];
//    u2 attributes_count;
//    attribute_info attributes[attributes_count];
//     */
//    var maxStack = 0
//    var maxLocals = 0
//    var codeLength = 0
//    var exceptionTableLength = 0
//    struct ExceptionEntry {
//        var startPc = 0
//        var handlerPc = 0
//        var catchType = 0
//    }
//    var exceptionTable : [ExceptionEntry] = []
//    var codeAttrCount = 0
//    var codeAttrTable : [AttributeInfo] = []
//}
