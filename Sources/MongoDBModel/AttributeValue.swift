//
//  AttributeValue.swift
//  
//
//  Created by Alsey Coleman Miller on 8/17/23.
//

import Foundation
import CoreModel
import MongoSwift

internal extension AttributeValue {
    
    init?(bson: BSON, type: AttributeType) {
        switch (type, bson) {
        case (.int16, .int32(let value)):
            self = .int16(numericCast(value))
        case (.int16, .int64(let value)):
            self = .int16(numericCast(value))
        case (.int32, .int32(let value)):
            self = .int32(value)
        case (.int32, .int64(let value)):
            self = .int32(numericCast(value))
        case (.int64, .int64(let value)):
            self = .int64(value)
        case (.int64, .int32(let value)):
            self = .int64(numericCast(value))
        case (.boolean, .bool(let value)):
            self = .bool(value)
        case (.date, .datetime(let date)):
            self = .date(date)
        case (.date, .timestamp(let timestamp)):
            self = .date(Date(timeIntervalSince1970: TimeInterval(timestamp.timestamp)))
        case (.double, .double(let double)):
            self = .double(double)
        case (.float, .double(let double)):
            self = .float(Float(double))
        case (.string, .string(let string)):
            self = .string(string)
        case (.data, .binary(let binary)):
            let data = binary.data.withUnsafeReadableBytes { buffer in
                Data(buffer)
            }
            self = .data(data)
        case (.uuid, .binary(let binary)):
            guard let uuid = try? binary.toUUID() else {
                return nil
            }
            self = .uuid(uuid)
        case (.uuid, .string(let string)):
            guard let uuid = UUID(uuidString: string) else {
                return nil
            }
            self = .uuid(uuid)
        case (.url, .string(let string)):
            guard let url = URL(string: string) else {
                return nil
            }
            self = .url(url)
        case (_, .null):
            self = .null
        default:
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
