//
//  CompositeAttributeTests.swift
//  CoreModel-MongoDB
//
//  Created by Alsey Coleman Miller on 8/16/26.
//

import Foundation
import XCTest
@testable import CoreModel
@testable import MongoDBModel
import MongoSwift

/// Composite attribute conversion, which needs no running server.
final class CompositeAttributeTests: XCTestCase {

    static let locationElements: [Attribute] = [
        Attribute(id: "latitude", type: .double),
        Attribute(id: "longitude", type: .double)
    ]

    static let addressElements: [Attribute] = [
        Attribute(id: "street", type: .string),
        Attribute(id: "location", type: .composite(locationElements))
    ]

    static var location: AttributeValue {
        .composite(["latitude": .double(40.7), "longitude": .double(-74.0)])
    }

    static var address: AttributeValue {
        .composite(["street": .string("1 Main"), "location": location])
    }

    /// A composite becomes an embedded document, not a string or binary blob.
    func testEncodeComposite() throws {
        let bson = try BSON(attributeValue: Self.location)
        guard case let .document(document) = bson else {
            return XCTFail("expected an embedded document, got \(bson)")
        }
        XCTAssertEqual(document["latitude"], .double(40.7))
        XCTAssertEqual(document["longitude"], .double(-74.0))
        XCTAssertEqual(document.keys.sorted(), ["latitude", "longitude"])
    }

    func testEncodeNestedComposite() throws {
        let bson = try BSON(attributeValue: Self.address)
        guard case let .document(document) = bson,
              case let .document(inner)? = document["location"] else {
            return XCTFail("expected a nested embedded document, got \(bson)")
        }
        XCTAssertEqual(document["street"], .string("1 Main"))
        XCTAssertEqual(inner["latitude"], .double(40.7))
    }

    func testDecodeComposite() throws {
        let bson = try BSON(attributeValue: Self.location)
        let decoded = AttributeValue(bson: bson, type: .composite(Self.locationElements))
        XCTAssertEqual(decoded, Self.location)
    }

    func testDecodeNestedComposite() throws {
        let bson = try BSON(attributeValue: Self.address)
        let decoded = AttributeValue(bson: bson, type: .composite(Self.addressElements))
        XCTAssertEqual(decoded, Self.address)
    }

    /// An element absent from the stored document decodes as null, so the decoded shape
    /// always matches the schema.
    func testDecodeMissingElement() throws {
        let document: BSONDocument = ["latitude": .double(40.7)]
        let decoded = AttributeValue(bson: .document(document), type: .composite(Self.locationElements))
        XCTAssertEqual(decoded, .composite(["latitude": .double(40.7), "longitude": .null]))
    }

    /// A stale field the schema no longer declares is ignored rather than mis-typed.
    func testDecodeIgnoresUnknownField() throws {
        let document: BSONDocument = [
            "latitude": .double(40.7),
            "longitude": .double(-74.0),
            "altitude": .double(3.0)
        ]
        let decoded = AttributeValue(bson: .document(document), type: .composite(Self.locationElements))
        XCTAssertEqual(decoded, Self.location)
    }

    func testDecodeWrongElementType() throws {
        let document: BSONDocument = ["latitude": .string("nope"), "longitude": .double(-74.0)]
        XCTAssertNil(AttributeValue(bson: .document(document), type: .composite(Self.locationElements)))
    }

    func testDecodeNull() throws {
        XCTAssertEqual(AttributeValue(bson: .null, type: .composite(Self.locationElements)), .null)
    }

    // MARK: - Key path resolution

    func testKeyPathResolution() {
        let data = ModelData(
            entity: "Facility",
            id: "north",
            attributes: ["name": .string("North"), "location": Self.location, "address": Self.address]
        )
        XCTAssertEqual(data.attributeValue(forKeyPath: "name"), .string("North"))
        XCTAssertEqual(data.attributeValue(forKeyPath: "location"), Self.location)
        XCTAssertEqual(data.attributeValue(forKeyPath: "location.latitude"), .double(40.7))
        XCTAssertEqual(data.attributeValue(forKeyPath: "address.location.longitude"), .double(-74.0))
        XCTAssertNil(data.attributeValue(forKeyPath: "location.altitude"))
        XCTAssertNil(data.attributeValue(forKeyPath: "name.length"))
        XCTAssertNil(data.attributeValue(forKeyPath: PredicateKeyPath(keys: [])))
    }

    /// A property whose name literally contains a dot still resolves directly.
    func testLiteralDottedNameWins() {
        let data = ModelData(
            entity: "Facility",
            id: "north",
            attributes: [
                "location.latitude": .double(1),
                "location": .composite(["latitude": .double(2)])
            ]
        )
        XCTAssertEqual(data.attributeValue(forKeyPath: "location.latitude"), .double(1))
    }

    /// The server query for an element key path uses MongoDB's native dotted field path.
    func testElementPredicateQuery() throws {
        let comparison = FetchRequest.Predicate.Comparison(
            left: .keyPath("location.latitude"),
            right: .attribute(.double(30)),
            type: .greaterThan
        )
        let document = try XCTUnwrap(BSONDocument(predicate: comparison))
        XCTAssertEqual(document.keys, ["location.latitude"])
        XCTAssertEqual(document["location.latitude"], .document(["$gt": .double(30)]))
    }

    func testNestedElementPredicateQuery() throws {
        let comparison = FetchRequest.Predicate.Comparison(
            left: .keyPath("address.location.latitude"),
            right: .attribute(.double(30)),
            type: .lessThan
        )
        let document = try XCTUnwrap(BSONDocument(predicate: comparison))
        XCTAssertEqual(document.keys, ["address.location.latitude"])
    }
}
