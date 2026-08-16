//
//  ArithmeticExpressionTests.swift
//  CoreModel-MongoDB
//
//  Created by Alsey Coleman Miller on 8/16/26.
//

import Foundation
import XCTest
@testable import CoreModel
@testable import MongoDBModel
import MongoSwift

/// Arithmetic expressions: `$expr` translation and the in-memory fallback.
final class ArithmeticExpressionTests: XCTestCase {

    private func arithmetic(
        _ function: FetchRequest.Predicate.ArithmeticExpression.Function,
        _ left: FetchRequest.Predicate.Expression,
        _ right: FetchRequest.Predicate.Expression
    ) -> FetchRequest.Predicate.Expression {
        .arithmetic(.init(function: function, left: left, right: right))
    }

    // MARK: - Server-side translation

    /// `age + 10 > 45` compiles to a guarded aggregation `$expr`.
    func testExprTranslation() throws {
        let comparison = FetchRequest.Predicate.Comparison(
            left: arithmetic(.add, .keyPath("age"), .attribute(.int64(10))),
            right: .attribute(.int64(45)),
            type: .greaterThan
        )
        let document = try XCTUnwrap(BSONDocument(predicate: comparison))
        let expr = try XCTUnwrap(document["$expr"]?.documentValue)
        let and = try XCTUnwrap(expr["$and"]?.arrayValue)
        XCTAssertEqual(and.count, 2)
        // guard: { $isNumber: { $add: ["$age", 10] } }
        let guardDoc = try XCTUnwrap(and[0].documentValue)
        let added = try XCTUnwrap(guardDoc["$isNumber"]?.documentValue)
        XCTAssertEqual(added["$add"], .array([.string("$age"), .int64(10)]))
        // comparison: { $gt: [ { $add: [...] }, 45 ] }
        let compare = try XCTUnwrap(and[1].documentValue)
        let operands = try XCTUnwrap(compare["$gt"]?.arrayValue)
        XCTAssertEqual(operands.count, 2)
        XCTAssertEqual(operands[1], .int64(45))
    }

    /// Nested add/multiply translates recursively.
    func testNestedExprTranslation() throws {
        let inner = arithmetic(.add, .keyPath("age"), .attribute(.int64(10)))
        let comparison = FetchRequest.Predicate.Comparison(
            left: arithmetic(.multiply, inner, .attribute(.int64(2))),
            right: .attribute(.int64(80)),
            type: .equalTo
        )
        let document = try XCTUnwrap(BSONDocument(predicate: comparison))
        let expr = try XCTUnwrap(document["$expr"]?.documentValue)
        let and = try XCTUnwrap(expr["$and"]?.arrayValue)
        let compare = try XCTUnwrap(and[1].documentValue)
        let operands = try XCTUnwrap(compare["$eq"]?.arrayValue)
        let multiply = try XCTUnwrap(operands[0].documentValue)
        let factors = try XCTUnwrap(multiply["$multiply"]?.arrayValue)
        XCTAssertEqual(factors[0].documentValue?["$add"], .array([.string("$age"), .int64(10)]))
        XCTAssertEqual(factors[1], .int64(2))
    }

    /// A dotted key path addresses a composite element inside `$expr`.
    func testCompositeElementOperand() throws {
        let comparison = FetchRequest.Predicate.Comparison(
            left: arithmetic(.multiply, .keyPath("location.latitude"), .attribute(.int64(2))),
            right: .attribute(.double(80)),
            type: .greaterThan
        )
        let document = try XCTUnwrap(BSONDocument(predicate: comparison))
        let expr = try XCTUnwrap(document["$expr"]?.documentValue)
        let and = try XCTUnwrap(expr["$and"]?.arrayValue)
        let guardDoc = try XCTUnwrap(and[0].documentValue)
        let multiply = try XCTUnwrap(guardDoc["$isNumber"]?.documentValue)
        XCTAssertEqual(multiply["$multiply"], .array([.string("$location.latitude"), .int64(2)]))
    }

    /// Division and remainder are not server-translatable; the whole request routes
    /// through in-memory evaluation instead.
    func testDivisionRoutesToMemory() {
        for function: FetchRequest.Predicate.ArithmeticExpression.Function in [.divide, .modulus] {
            let predicate = arithmetic(function, .keyPath("age"), .attribute(.int64(2)))
                .compare(.equalTo, .attribute(.int64(0)))
            let request = FetchRequest(entity: "Person", predicate: predicate)
            XCTAssertTrue(request.requiresInMemoryEvaluation, "\(function) should evaluate in memory")
            // and the stripped superset filter drops the comparison
            XCTAssertEqual(predicate.strippingFunctionComparisons(), .value(true))
            // the expression translator refuses it too
            XCTAssertNil(BSON(aggregation: arithmetic(function, .keyPath("age"), .attribute(.int64(2)))))
        }
    }

    /// A nested division anywhere in the tree routes the request to memory.
    func testNestedDivisionRoutesToMemory() {
        let inner = arithmetic(.divide, .keyPath("age"), .attribute(.int64(7)))
        let predicate = arithmetic(.add, inner, .attribute(.int64(1)))
            .compare(.equalTo, .attribute(.int64(5)))
        XCTAssertTrue(FetchRequest(entity: "Person", predicate: predicate).requiresInMemoryEvaluation)
    }

    /// Add/subtract/multiply do not require in-memory evaluation.
    func testServerSideFunctionsStayNative() {
        for function: FetchRequest.Predicate.ArithmeticExpression.Function in [.add, .subtract, .multiply] {
            let predicate = arithmetic(function, .keyPath("age"), .attribute(.int64(2)))
                .compare(.greaterThan, .attribute(.int64(0)))
            XCTAssertFalse(FetchRequest(entity: "Person", predicate: predicate).requiresInMemoryEvaluation)
        }
    }

    // MARK: - In-memory evaluation

    private static let person = ModelData(
        entity: "Person",
        id: "alice",
        attributes: ["age": .int32(30), "weight": .double(60.5), "name": .string("Alice")]
    )

    func testIntegerArithmetic() {
        // 30 + 10 > 45 is false; 30 + 20 > 45 is true
        XCTAssertFalse(
            arithmetic(.add, .keyPath("age"), .attribute(.int64(10)))
                .compare(.greaterThan, .attribute(.int64(45)))
                .evaluate(with: Self.person, functions: [:])
        )
        XCTAssertTrue(
            arithmetic(.add, .keyPath("age"), .attribute(.int64(20)))
                .compare(.greaterThan, .attribute(.int64(45)))
                .evaluate(with: Self.person, functions: [:])
        )
    }

    /// Integer division truncates (`30 / 7` is `4`), matching CoreModel's engine.
    func testIntegerDivisionTruncates() {
        XCTAssertTrue(
            arithmetic(.divide, .keyPath("age"), .attribute(.int64(7)))
                .compare(.equalTo, .attribute(.int64(4)))
                .evaluate(with: Self.person, functions: [:])
        )
    }

    func testModulus() {
        XCTAssertTrue(
            arithmetic(.modulus, .keyPath("age"), .attribute(.int64(2)))
                .compare(.equalTo, .attribute(.int64(0)))
                .evaluate(with: Self.person, functions: [:])
        )
    }

    /// Division by zero yields nil, which fails every comparison.
    func testDivisionByZero() {
        for op: FetchRequest.Predicate.Comparison.Operator in [.equalTo, .greaterThan, .lessThan] {
            XCTAssertFalse(
                arithmetic(.divide, .keyPath("age"), .attribute(.int64(0)))
                    .compare(op, .attribute(.int64(0)))
                    .evaluate(with: Self.person, functions: [:]),
                "\(op) against division by zero should be false"
            )
        }
    }

    /// Mixed operands compute in floating point.
    func testMixedOperandsPromote() {
        XCTAssertTrue(
            arithmetic(.divide, .keyPath("weight"), .attribute(.int64(2)))
                .compare(.equalTo, .attribute(.double(30.25)))
                .evaluate(with: Self.person, functions: [:])
        )
    }

    /// Remainder is integers-only; a float operand yields nil.
    func testFloatModulusIsNil() {
        XCTAssertFalse(
            arithmetic(.modulus, .keyPath("weight"), .attribute(.int64(2)))
                .compare(.equalTo, .attribute(.int64(0)))
                .evaluate(with: Self.person, functions: [:])
        )
    }

    /// Non-numeric operands yield nil.
    func testNonNumericOperands() {
        XCTAssertFalse(
            arithmetic(.add, .keyPath("name"), .attribute(.int64(1)))
                .compare(.equalTo, .attribute(.int64(1)))
                .evaluate(with: Self.person, functions: [:])
        )
    }
}
