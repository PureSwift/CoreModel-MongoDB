//
//  ObjectID.swift
//  
//
//  Created by Alsey Coleman Miller on 8/17/23.
//

import Foundation
import CoreModel
import MongoSwift

extension BSONObjectID: ObjectIDConvertible {
    
    public init?(objectID: ObjectID) {
        try? self.init(objectID.rawValue)
    }
}

internal extension BSONDocument {
    
    var modelObjectID: ObjectID {
        get throws {
            guard let id = self[BSONDocument.BuiltInProperty.id.rawValue]?.stringValue else {
                throw CocoaError(.coderValueNotFound)
            }
            return ObjectID(rawValue: id)
        }
    }
}

public extension ObjectID {
    
    init?(bson: BSON) {
        switch bson {
        case let .string(string):
            self.init(rawValue: string)
        case let .objectID(objectID):
            self.init(rawValue: objectID.description)
        default:
            return nil
        }
    }
}
