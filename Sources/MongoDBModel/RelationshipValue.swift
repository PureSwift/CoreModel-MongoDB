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
    
    init?(bson: BSON) {
        fatalError()
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
