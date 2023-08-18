//
//  ModelData.swift
//  
//
//  Created by Alsey Coleman Miller on 8/17/23.
//

import Foundation
import CoreModel
import MongoSwift

public extension ModelData {
    
    init(bson: BSONDocument) {
        fatalError()
    }
}

public extension BSONDocument {
    
    init(model: ModelData) {
        self.init()
        // set id
        self[BSONDocument.BuiltInProperty.id.rawValue] = .string(model.id.rawValue)
        // set attributes
        for (key, attribute) in model.attributes {
            self[key.rawValue] = BSON(attributeValue: attribute)
        }
        // set relationships
        for (key, relationship) in model.relationships {
            self[key.rawValue] = BSON(relationship: relationship)
        }
    }
}

internal extension BSONDocument {
    
    enum BuiltInProperty: String {
        
        case id = "_id"
    }
}
