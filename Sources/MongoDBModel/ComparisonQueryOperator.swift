//
//  ComparisonQueryOperator.swift
//  
//
//  Created by Alsey Coleman Miller on 8/21/23.
//

import Foundation

/// Comparison Query Operators
///
/// Comparison operators return data based on value comparisons.
///
/// [Documentation](https://www.mongodb.com/docs/v7.0/reference/operator/query-comparison/)
public enum ComparisonQueryOperator: String, Codable, CaseIterable {
    
    /// Matches values that are equal to a specified value.
    case equalTo                    = "$eq"
    
    /// Matches all values that are not equal to a specified value.
    case notEqualTo                 = "$ne"
    
    /// Matches values that are greater than a specified value.
    case greaterThan                = "$gt"
    
    /// Matches values that are greater than or equal to a specified value.
    case greaterThanOrEqualTo       = "$gte"
    
    /// Matches values that are less than a specified value.
    case lessThan                   = "$lt"
    
    /// Matches values that are less than or equal to a specified value.
    case lessThanOrEqualTo          = "$lte"
    
    /// Matches any of the values specified in an array.
    case `in`                       = "$in"
    
    /// Matches none of the values specified in an array.
    case notIn                      = "$nin"
}

// MARK: - Predicate

public extension ComparisonQueryOperator {
    
    init?(predicate: FetchRequest.Predicate.Comparison.Operator) {
        switch predicate {
        case .equalTo:
            self = .equalTo
        case .greaterThan:
            self = .greaterThan
        case .greaterThanOrEqualTo:
            self = .greaterThanOrEqualTo
        case .in:
            self = .in
        case .lessThan:
            self = .lessThan
        case .lessThanOrEqualTo:
            self = .lessThanOrEqualTo
        case .notEqualTo:
            self = .notEqualTo
        default:
            return nil
        }
    }
}
