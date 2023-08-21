//
//  FetchRequest.swift
//  
//
//  Created by Alsey Coleman Miller on 8/17/23.
//

import Foundation
import CoreModel
import MongoSwift

public extension BSONDocument {
    
    init(sort sortDescriptors: [FetchRequest.SortDescriptor]) {
        self.init()
        for sort in sortDescriptors {
            self[sort.property.rawValue] = sort.ascending ? 1 : -1
        }
    }
}

public extension FindOptions {
    
    init(fetchRequest: FetchRequest) {
        self.init(
            limit: fetchRequest.fetchLimit,
            skip: fetchRequest.fetchOffset,
            sort: fetchRequest.sortDescriptors.isEmpty ? nil : .init(sort: fetchRequest.sortDescriptors)
        )
    }
}

public extension CountDocumentsOptions {
    
    init(fetchRequest: FetchRequest) {
        self.init(
            limit: fetchRequest.fetchLimit,
            skip: fetchRequest.fetchOffset
        )
    }
}
