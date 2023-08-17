//
//  AttributeValue.swift
//  
//
//  Created by Alsey Coleman Miller on 8/17/23.
//

import Foundation
import CoreModel
import MongoSwift

public extension AttributeValue {
    
    init?(bson: BSON) {
        switch bson {
        case .document:
            return nil
        case .int32(let value):
            self = .int32(value)
        case .int64(let value):
            self = .int64(value)
        case .decimal128:
            return nil
        case .array:
            return nil
        case .bool(let value):
            self = .bool(value)
        case .datetime(let date):
            self = .date(date)
        case .double(let double):
            self = .double(double)
        case .string(let string):
            self = .string(string)
        case .symbol:
            return nil
        case .timestamp:
            return nil
        case .binary(let binary):
            switch binary.subtype {
            case .generic:
                let data = binary.data.withUnsafeReadableBytes { buffer in
                    Data(buffer)
                }
                self = .data(data)
            case .uuid:
                guard let uuid = try? binary.toUUID() else {
                    return nil
                }
                self = .uuid(uuid)
            default:
                return nil
            }
        case .regex:
            return nil
        case .objectID:
            return nil
        case .dbPointer:
            return nil
        case .code:
            return nil
        case .codeWithScope:
            return nil
        case .null:
            self = .null
        case .undefined:
            return nil
        case .minKey:
            return nil
        case .maxKey:
            return nil
        }
    }
}

public extension BSON {
    
    init(attributeValue: AttributeValue) {
        switch attributeValue {
        case .null:
            self = .null
        case .string(let string):
            self = .string(string)
        case .uuid(let uuid):
            self = .binary(try! BSONBinary(from: uuid))
        case .url(let url):
            self = .string(url.absoluteString)
        case .data(let data):
            self = .binary(try! .init(data: data, subtype: .generic))
        case .date(let date):
            self = .datetime(date)
        case .bool(let value):
            self = .bool(value)
        case .int16(let value):
            self = .int32(numericCast(value))
        case .int32(let value):
            self = .int32(value)
        case .int64(let value):
            self = .int64(value)
        case .float(let float):
            self = .double(Double(float))
        case .double(let double):
            self = .double(double)
        }
    }
}
