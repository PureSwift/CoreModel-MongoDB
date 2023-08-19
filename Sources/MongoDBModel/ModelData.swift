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
            let attributeBSON = (bson[attribute.id.rawValue] ?? .null)
            guard let value = AttributeValue(bson: attributeBSON, type: attribute.type) else {
                throw DecodingError.typeMismatch(ModelData.self, DecodingError.Context(codingPath: [], debugDescription: "Unable to decode \(attribute.type) attribute \"\(attribute.id)\" from \(attributeBSON)"))
            }
            self.attributes[attribute.id] = value
        }
        // decode relationships
        for relationship in model.relationships {
            let relationshipBSON = bson[relationship.id.rawValue] ?? .null
            guard let value = RelationshipValue(bson: relationshipBSON, type: relationship.type) else {
                throw DecodingError.typeMismatch(ModelData.self, DecodingError.Context(codingPath: [], debugDescription: "Unable to decode \(relationship.type) relationship \"\(relationship.id)\" from \(relationshipBSON)"))
            }
            self.relationships[relationship.id] = value
        }
    }
}

public extension BSONDocument {
    
    init(model: ModelData) throws {
        self.init()
        // set id
        self[BSONDocument.BuiltInProperty.id.rawValue] = .string(model.id.rawValue)
        // set attributes
        for (key, attribute) in model.attributes {
            let attributeBSON: BSON
            do {
                attributeBSON = try BSON(attributeValue: attribute)
            } catch {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Unable to decode \(attribute) for \(key)", underlyingError: error))
            }
            self[key.rawValue] = attributeBSON
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
