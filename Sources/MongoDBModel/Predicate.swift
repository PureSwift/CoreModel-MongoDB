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
        // `(a <op> b) <operator> constant` compiles to an aggregation `$expr` filter.
        if case let .arithmetic(arithmetic) = predicate.left {
            guard let document = BSONDocument(arithmetic: arithmetic, comparison: predicate) else {
                return nil
            }
            self = document
            return
        }
        // { <field>: { $eq: <value> } }
        guard case let .keyPath(keyPath) = predicate.left,
              let comparisonOperator = ComparisonQueryOperator(predicate: predicate.type),
              predicate.options.isEmpty,
              predicate.modifier == nil else {
            return nil
        }
        let valueBSON: BSON
        switch predicate.right {
        case .keyPath, .function, .arithmetic:
            // custom functions and arithmetic expressions cannot be executed by the server
            return nil
        case let .attribute(value):
            guard let bson = try? BSON(attributeValue: value) else {
                return nil
            }
            valueBSON = bson
        case let .relationship(value):
            valueBSON = BSON(relationship: value)
        }
        self = [
            keyPath.rawValue: .document([comparisonOperator.rawValue: valueBSON])]
    }
}

// MARK: - Arithmetic

internal extension BSONDocument {

    /// The `$expr` filter for an `arithmetic <operator> constant` comparison.
    ///
    /// ```
    /// { $expr: { $and: [ { $isNumber: A }, { $gt: [ A, constant ] } ] } }
    /// ```
    ///
    /// The `$isNumber` guard makes a missing or null operand fail the comparison —
    /// `$add` of a missing field yields `null`, and without the guard aggregation
    /// comparisons would rank `null` *below* every number, so `arithmetic < constant`
    /// would spuriously match. CoreModel's engine yields `nil` for such rows, which
    /// matches no comparison.
    ///
    /// Only `.add`, `.subtract` and `.multiply` are translated; `.divide` and
    /// `.modulus` are routed to in-memory evaluation before this is reached — see
    /// `FetchRequest.requiresInMemoryEvaluation`.
    init?(
        arithmetic: FetchRequest.Predicate.ArithmeticExpression,
        comparison: FetchRequest.Predicate.Comparison
    ) {
        guard comparison.options.isEmpty,
              comparison.modifier == nil,
              let comparisonOperator = ComparisonQueryOperator(predicate: comparison.type),
              // only aggregation comparison operators are valid inside `$expr`
              [.equalTo, .notEqualTo, .greaterThan, .greaterThanOrEqualTo, .lessThan, .lessThanOrEqualTo].contains(comparisonOperator),
              case let .attribute(value) = comparison.right,
              let constant = try? BSON(attributeValue: value),
              let expression = BSON(aggregation: .arithmetic(arithmetic)) else {
            return nil
        }
        self = [
            "$expr": .document([
                "$and": .array([
                    .document(["$isNumber": expression]),
                    .document([comparisonOperator.rawValue: .array([expression, constant])])
                ])
            ])
        ]
    }
}

internal extension BSON {

    /// The aggregation expression for a predicate expression, for use inside `$expr`.
    ///
    /// A key path becomes a `$`-prefixed field path — dotted paths address composite
    /// attribute elements natively. Returns `nil` for expressions the server cannot
    /// evaluate (custom functions, relationships, division and remainder).
    init?(aggregation expression: FetchRequest.Predicate.Expression) {
        switch expression {
        case let .attribute(value):
            guard let bson = try? BSON(attributeValue: value) else {
                return nil
            }
            self = bson
        case let .keyPath(keyPath):
            self = .string("$" + keyPath.rawValue)
        case let .arithmetic(arithmetic):
            let aggregationOperator: String
            switch arithmetic.function {
            case .add:      aggregationOperator = "$add"
            case .subtract: aggregationOperator = "$subtract"
            case .multiply: aggregationOperator = "$multiply"
            case .divide, .modulus:
                // `$divide` aborts the query on division by zero and has no truncating
                // integer form; `$mod` diverges on floats. Evaluated in memory instead.
                return nil
            }
            guard let left = BSON(aggregation: arithmetic.left),
                  let right = BSON(aggregation: arithmetic.right) else {
                return nil
            }
            self = .document([aggregationOperator: .array([left, right])])
        case .function, .relationship:
            return nil
        }
    }
}
