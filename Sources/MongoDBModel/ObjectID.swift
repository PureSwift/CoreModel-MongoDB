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
