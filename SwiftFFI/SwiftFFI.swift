//
//  SwiftFFI.swift
//  libffi
//
//  Created by Mike Kasianowicz on 9/29/15.
//  Copyright © 2015 Mike Kasianowicz. All rights reserved.
//

import Foundation

public class FFIFunctionInvocation {
    private typealias functionPointerType = (@convention(c) () -> Void)!
    
    private let functionPointer: functionPointerType
    private var argTypes = [FFIType]()
    private var argPointers = [UnsafeMutablePointer<Void>]()
    
    public init(address: UnsafePointer<Void>) {
        functionPointer = unsafeBitCast(address, functionPointerType.self)
    }
    
    public func addArg(value: UnsafeMutablePointer<Void>, type: FFIType) {
        argTypes.append(type)
        argPointers.append(value)
    }
    
    public func invoke(outValue: UnsafeMutablePointer<Void>, returnType: FFIType) {
        var argTypePointers = [UnsafeMutablePointer<ffi_type>]()
        for argType in argTypes {
            argTypePointers.append(argType.pointer)
        }
        
        var cif = ffi_cif()
        let status = ffi_prep_cif(&cif, FFI_DEFAULT_ABI, UInt32(argTypes.count), returnType.pointer, &argTypePointers)
        precondition(status == FFI_OK);
        
        ffi_call(&cif, self.functionPointer, outValue, &argPointers)
    }
}

private func typeAddress(type: Any.Type) -> UnsafePointer<Void> {
    return unsafeBitCast(type, UnsafePointer<Void>.self)
}

public class FFIStructBuilder {
    var fields = [FFIType]()
    public init() {
        
    }
    public func addField(type: FFIType) {
        fields.append(type)
    }
    
    public func createType(size: Int, align: Int) -> FFIType {
        return FFIStructType(size: size, align: align, fields: fields)
    }
}

public class FFIStructType : FFIType {
    let fields: [FFIType]
    
    init(size: Int, align: Int, fields: [FFIType]) {
        self.fields = fields
        super.init(UnsafeMutablePointer<ffi_type>(calloc(1, sizeof(ffi_type.self))))
        
        self.pointer.memory.size = size
        self.pointer.memory.alignment = UInt16(align)
        self.pointer.memory.type = UInt16(FFI_TYPE_STRUCT)
        
        
        self.pointer.memory.elements = UnsafeMutablePointer<UnsafeMutablePointer<ffi_type>>(calloc(fields.count + 1, sizeof(UnsafeMutablePointer<ffi_type>.self)))
        
        var i = 0
        for field in fields {
            self.pointer.memory.elements[i++] = field.pointer
        }
        self.pointer.memory.elements[i] = nil
    }
    
    deinit {
        free(self.pointer.memory.elements)
        free(self.pointer)
    }
}


public class FFIType : CustomDebugStringConvertible, Equatable {
    let pointer: UnsafeMutablePointer<ffi_type>
    
    init(_ pointer: UnsafeMutablePointer<ffi_type>) {
        self.pointer = pointer
    }
    
    public var size: Int {
        return self.pointer.memory.size
    }
    
    public var alignment: Int {
        return Int(self.pointer.memory.alignment)
    }
    
    public var typeCode: Int {
        return Int(self.pointer.memory.type)
    }
    
    public var debugDescription: String {
        return "pointer: \(self.pointer) size: \(self.size) align: \(self.alignment) type: \(self.typeCode)"
    }
    
    public static let VoidType = FFIType(&ffi_type_void)
    public static let Int8Type = FFIType(&ffi_type_sint8)
    public static let UInt8Type = FFIType(&ffi_type_uint8)
    
    public static let Int16Type = FFIType(&ffi_type_sint16)
    public static let UInt16Type = FFIType(&ffi_type_uint16)
    
    public static let Int32Type = FFIType(&ffi_type_sint32)
    public static let UInt32Type = FFIType(&ffi_type_uint32)
    
    public static let Int64Type = FFIType(&ffi_type_sint64)
    public static let UInt64Type = FFIType(&ffi_type_uint64)
    
    public static let FloatType = FFIType(&ffi_type_float)
    public static let DoubleType = FFIType(&ffi_type_double)
    
    public static let PointerType = FFIType(&ffi_type_pointer)
    
    public static let IntType = sizeof(Int.self) == 4 ? FFIType.Int32Type : FFIType.Int64Type
    public static let UIntType = sizeof(Int.self) == 4 ? FFIType.UInt32Type : FFIType.UInt64Type
}

public func ==(lhs: FFIType, rhs: FFIType) -> Bool {
    return lhs.pointer == rhs.pointer
}