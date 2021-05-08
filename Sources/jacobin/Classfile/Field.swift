/*
 * jacobin - JVM written in Swift
 *
 * Copyright (c) 2021 Andrew Binstock. All rights reserved.
 * Licensed under Mozilla Public License, v. 2.0. http://mozilla.org/MPL/2.0/.
 */

import Foundation

/// the data structure for holding a field's field_info from the class file.
/// the fields are explained in the JVM spec at:
/// https://docs.oracle.com/javase/specs/jvms/se11/html/jvms-4.html#jvms-4.5
///
// Layout:
// field_info {
//    u2             access_flags;
//    u2             name_index;
//    u2             descriptor_index;
//    u2             attributes_count;
//    attribute_info attributes[attributes_count];
//  }
class Field {
    var accessFlags : Int16 = 0x00
    var name = ""
    var description = ""
    var attributes : [Attribute] = []
}
