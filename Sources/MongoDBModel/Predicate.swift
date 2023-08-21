//
//  Predicate.swift
//  
//
//  Created by Alsey Coleman Miller on 8/21/23.
//

import Foundation
import CoreModel
import MongoSwift

public extension BSONDocument {
    
    init?(predicate: FetchRequest.Predicate) {
        switch predicate {
        case .comparison(let comparison):
            self.init(predicate: comparison)
        case .compound(let compound):
            self.init(predicate: compound)
        case .value:
            return nil
        }
    }
}

public extension BSONDocument {
    
    init?(predicate: FetchRequest.Predicate.Compound) {
        guard predicate.type != .not else {
            // { field: { $not: { <operator-expression> } } }
            return nil
        }
        var array = [BSONDocument]()
        array.reserveCapacity(predicate.subpredicates.count)
        for subpredicate in predicate.subpredicates {
            guard let document = BSONDocument(predicate: subpredicate) else {
                return nil
            }
            array.append(document)
        }
        // { $and: [ { <expression1> }, { <expression2> } , ... , { <expressionN> } ] }
        // { $or: [ { <expression1> }, { <expression2> }, ... , { <expressionN> } ] }
        self = [LogicalQueryOperator(predicate: predicate.type).rawValue: .array(array.map { .document($0) })]
    }
}

public extension BSONDocument {
    
    init?(predicate: Comparison) {
        // { <field>: { $eq: <value> } }
            return nil
        }
}

public extension BSON {
    
    init?(predicate: Expression) {
        return nil
    }
}
