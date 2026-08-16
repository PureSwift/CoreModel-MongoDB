//
//  CompositeAttribute.swift
//  CoreModel-MongoDB
//
//  Created by Alsey Coleman Miller on 8/16/26.
//

import Foundation
import CoreModel
import MongoSwift

// MARK: - BSON Conversion

public extension BSONDocument {

    /// The BSON subdocument for a composite attribute value.
    ///
    /// A composite maps directly onto an embedded document, which is MongoDB's native
    /// shape for structured values — no flattening or serialization is needed, and
    /// element key paths (`location.latitude`) are the dotted paths the server already
    /// understands for queries, projections and sorts.
    init(compositeValue: [PropertyKey: AttributeValue]) throws {
        self.init()
        for (key, value) in compositeValue {
            self[key.rawValue] = try BSON(attributeValue: value)
        }
    }
}

internal extension AttributeValue {

    /// Decode a composite attribute value from an embedded BSON document.
    ///
    /// Iterates the declared elements rather than the stored document, so a stale or
    /// unknown field is ignored rather than mis-typed, and an element missing from the
    /// document decodes as `.null` so the shape always matches the schema.
    static func composite(
        from document: BSONDocument,
        elements: [Attribute]
    ) -> AttributeValue? {
        var values = [PropertyKey: AttributeValue](minimumCapacity: elements.count)
        for element in elements {
            guard let bson = document[element.id.rawValue] else {
                values[element.id] = .null
                continue
            }
            guard let value = AttributeValue(bson: bson, type: element.type) else {
                return nil
            }
            values[element.id] = value
        }
        return .composite(values)
    }
}

// MARK: - Key Path Resolution

internal extension ModelData {

    /// The attribute value a key path addresses, descending through composite elements.
    ///
    /// Used by the in-memory evaluation fallback for predicates the server can't run.
    /// A property whose name literally contains a dot resolves directly, so models that
    /// predate composite attributes are unaffected.
    func attributeValue(forKeyPath keyPath: PredicateKeyPath) -> AttributeValue? {
        // - Note: The emptiness check comes first: `PropertyKey` asserts on an empty raw
        //   value, and the root variable of a `Foundation.Predicate` converts to an empty
        //   key path.
        guard case let .property(name)? = keyPath.keys.first else {
            return nil
        }
        if let value = attributes[PropertyKey(rawValue: keyPath.rawValue)] {
            return value
        }
        guard var current = attributes[PropertyKey(rawValue: name)] else {
            return nil
        }
        for key in keyPath.keys.dropFirst() {
            guard case let .property(name) = key,
                case let .composite(elements) = current,
                let next = elements[PropertyKey(rawValue: name)] else {
                return nil
            }
            current = next
        }
        return current
    }
}
