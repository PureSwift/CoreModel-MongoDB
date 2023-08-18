import Foundation
@_exported import CoreModel
@_exported import MongoSwift

extension MongoDatabase: ModelStorage {
    
    /// Fetch managed object.
    public func fetch(
        _ entity: EntityName,
        for id: ObjectID
    ) async throws -> ModelData? {
        guard let document = try await find(entity, for: id) else {
            return nil
        }
        return ModelData(bson: document)
    }
    
    /// Fetch managed objects.
    public func fetch(_ fetchRequest: FetchRequest) async throws -> [ModelData] {
        try await fetchDocuments(fetchRequest)
            .map { ModelData(bson: $0) }
    }
    
    /// Fetch and return result count.
    public func count(_ fetchRequest: FetchRequest) async throws -> UInt {
        let entityName = fetchRequest.entity
        let collection = self.collection(entityName)
        let filter = fetchRequest.predicate.map { BSONDocument(filter: $0) } ?? [:]
        let options = CountDocumentsOptions(fetchRequest: fetchRequest)
        let count = try await collection.countDocuments(filter, options: options)
        return UInt(count)
    }
    
    /// Create or edit a managed object.
    public func insert(_ value: ModelData) async throws {
        let entityName = value.entity
        let collection = self.collection(entityName)
        let document = BSONDocument(model: value)
        try await collection.insertOne(document)
    }
    
    public func insert(_ values: [ModelData]) async throws {
        var collections = [EntityName: [ModelData]]()
        for value in values {
            collections[value.entity, default: []].append(value)
        }
        for (entity, values) in collections {
            let collection = self.collection(entity)
            let documents = values.map { BSONDocument(model: $0) }
            try await collection.insertMany(documents)
        }
    }
    
    /// Delete the specified managed object.
    public func delete(
        _ entity: EntityName,
        for id: ObjectID
    ) async throws {
        let collection = self.collection(entity)
        let options: DeleteOptions? = nil
        let filter: BSONDocument = [
            BSONDocument.BuiltInProperty.id.rawValue: .string(id.rawValue)
        ]
        try await collection.deleteOne(filter, options: options)
    }
}

public extension MongoDatabase {
    
    
}

internal extension MongoDatabase {
        
    func find(
        _ entityName: EntityName,
        for id: ObjectID,
        options: MongoCollectionOptions? = nil
    ) async throws -> BSONDocument? {
        let collection = self.collection(entityName, options: options)
        let options: FindOneOptions? = nil
        let filter: BSONDocument = [
            BSONDocument.BuiltInProperty.id.rawValue: .string(id.rawValue)
        ]
        return try await collection.findOne(filter, options: options)
    }
    
    func fetchDocuments(
        _ fetchRequest: FetchRequest,
        options: MongoCollectionOptions? = nil
    ) async throws -> [BSONDocument] {
        let entityName = fetchRequest.entity
        let collection = self.collection(entityName, options: options)
        let filter = fetchRequest.predicate.map { BSONDocument(filter: $0) } ?? [:]
        let options = FindOptions(fetchRequest: fetchRequest)
        let stream = try await collection.find(filter, options: options)
        var results = [BSONDocument]()
        for try await document in stream {
            results.append(document)
        }
        return results
    }
    
    func create(
        _ entityName: EntityName,
        for id: ObjectID,
        options: MongoCollectionOptions? = nil
    ) async throws -> BSONDocument {
        let collection = self.collection(entityName, options: options)
        let document: BSONDocument = [
            BSONDocument.BuiltInProperty.id.rawValue: .string(id.rawValue)
        ]
        let options: InsertOneOptions? = nil
        try await collection.insertOne(document, options: options)
        return document
    }
}

fileprivate extension MongoDatabase {
    
    func collection(
        _ name: EntityName,
        options: MongoCollectionOptions? = nil
    ) -> MongoCollection<BSONDocument> {
        let tableName = name.rawValue.lowercased() + "s"
        return collection(tableName, options: options)
    }
}
