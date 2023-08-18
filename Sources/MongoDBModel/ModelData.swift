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
    
    init(bson: BSONDocument, model: EntityDescription) throws {
        let id = try bson.modelObjectID
        self.init(entity: model.id, id: id)
        // decode attributes
        for attribute in model.attributes {
            let value = bson[attribute.id.rawValue]
                .map { AttributeValue(bson: $0) } ?? .null
            self.attributes[attribute.id] = value
        }
        // decode relationships
        for relationship in model.relationships {
            let relationshipBSON = bson[relationship.id.rawValue] ?? .null
            guard let value = RelationshipValue(
                bson: relationshipBSON,
                type: relationship.type
            ) else {
                throw DecodingError.typeMismatch(ModelData.self, DecodingError.Context(codingPath: [], debugDescription: ""))
            }
            self.relationships[relationship.id] = value
        }
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
