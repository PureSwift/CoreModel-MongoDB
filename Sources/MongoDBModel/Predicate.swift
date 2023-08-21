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
    
    init?(predicate: FetchRequest.Predicate.Comparison) {
        // { <field>: { $eq: <value> } }
        guard case let .keyPath(keyPath) = predicate.left,
              let comparisonOperator = ComparisonQueryOperator(predicate: predicate.type),
              case let .value(value) = predicate.right,
              predicate.options.isEmpty,
              predicate.modifier == nil,
              let valueBSON = try? BSON(attributeValue: value) else {
            return nil
        }
        self = [
            keyPath.rawValue: .document([comparisonOperator.rawValue: valueBSON])]
    }
}
