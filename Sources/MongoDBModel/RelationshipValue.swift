//
//  RelationshipValue.swift
//  
//
//  Created by Alsey Coleman Miller on 8/17/23.
//

import Foundation
import CoreModel
import MongoSwift

public extension RelationshipValue {
    
    init?(bson: BSON, type: RelationshipType) {
        guard bson != .null else {
            self = .null
            return
        }
        switch type {
        case .toOne:
            guard let objectID = ObjectID(bson: bson) else {
                return nil
            }
            self = .toOne(objectID)
        case .toMany:
            guard case let .array(array) = bson else {
                return nil
            }
            var objectIDs = [ObjectID]()
            objectIDs.reserveCapacity(array.count)
            for item in array {
                guard let objectID = ObjectID(bson: item) else {
                    return nil
                }
                objectIDs.append(objectID)
            }
            self = .toMany(objectIDs)
        }
    }
}

public extension BSON {
    
    init(relationship: RelationshipValue) {
        switch relationship {
        case .null:
            self = .null
        case .toOne(let objectID):
            self = .string(objectID.rawValue)
        case .toMany(let array):
            self = .array(array.map { .string($0.rawValue) })
        }
    }
}
