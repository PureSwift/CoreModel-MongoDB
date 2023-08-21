//
//  LogicalQueryOperator.swift
//  
//
//  Created by Alsey Coleman Miller on 8/21/23.
//

import Foundation

/// Logical Query Operators
///
/// Logical operators return data based on expressions that evaluate to true or false.
///
/// [Documentation](https://www.mongodb.com/docs/v7.0/reference/operator/query-comparison/)
public enum LogicalQueryOperator: String, Codable, CaseIterable {
    
    /// Joins query clauses with a logical AND returns all documents that match the conditions of both clauses.
    case and                = "$and"
    
    /// Joins query clauses with a logical OR returns all documents that match the conditions of either clause.
    case or                 = "$or"
    
    /// Inverts the effect of a query expression and returns documents that do not match the query expression.
    case not                = "$not"
    
    /// Joins query clauses with a logical NOR returns all documents that fail to match both clauses.
    case nor                = "$nor"
}

// MARK: - Predicate

public extension LogicalQueryOperator {
    
    init(predicate: FetchRequest.Predicate.Compound.Logical​Type) {
        switch predicate {
        case .and:
            self = .and
        case .or:
            self = .or
        case .not:
            self = .not
        }
    }
}
