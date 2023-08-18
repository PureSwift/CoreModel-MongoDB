import Foundation
@_exported import CoreModel
@_exported import MongoSwift

public actor MongoModelStorage: ModelStorage {
    
    public let database: MongoDatabase
    
    public let model: Model
    
    public init(database: MongoDatabase, model: Model) {
        self.database = database
        self.model = model
    }
    
    /// Fetch managed object.
    public func fetch(_ entityName: EntityName, for id: ObjectID) async throws -> ModelData? {
        let entity = try model(for: entityName)
        return try await database.fetch(entity, for: id)
    }
    
    /// Fetch managed objects.
    public func fetch(_ fetchRequest: FetchRequest) async throws -> [ModelData] {
        let entity = try model(for: fetchRequest.entity)
        return try await database.fetch(fetchRequest, entity: entity)
    }
    
    /// Fetch and return result count.
    public func count(_ fetchRequest: FetchRequest) async throws -> UInt {
        try await database.count(fetchRequest)
    }
    
    /// Create or edit a managed object.
    public func insert(_ value: ModelData) async throws {
        try await database.insert(value)
    }
    
    /// Create or edit multiple managed objects.
    public func insert(_ values: [ModelData]) async throws {
        try await database.insert(values)
    }
    
    /// Delete the specified managed object.
    public func delete(_ entity: EntityName, for id: ObjectID) async throws {
        try await database.delete(entity, for: id)
    }
    
    private func model(for entityName: EntityName) throws -> EntityDescription {
        guard let entity = self.model.entities.first(where: { $0.id == entityName }) else {
            throw CoreModelError.invalidEntity(entityName)
        }
        return entity
    }
}

public extension MongoDatabase {
    
    /// Fetch managed object.
    func fetch(
        _ entity: EntityDescription,
        for id: ObjectID
    ) async throws -> ModelData? {
        guard let document = try await find(entity.id, for: id) else {
            return nil
        }
        return try ModelData(bson: document, model: entity)
    }
    
    /// Fetch managed objects.
    func fetch(
        _ fetchRequest: FetchRequest,
        entity: EntityDescription
    ) async throws -> [ModelData] {
        try await fetchDocuments(fetchRequest)
            .map { try ModelData(bson: $0, model: entity) }
    }
    
    /// Fetch and return result count.
    func count(_ fetchRequest: FetchRequest) async throws -> UInt {
        let entityName = fetchRequest.entity
        let collection = self.collection(entityName)
        let filter = fetchRequest.predicate.map { BSONDocument(filter: $0) } ?? [:]
        let options = CountDocumentsOptions(fetchRequest: fetchRequest)
        let count = try await collection.countDocuments(filter, options: options)
        return UInt(count)
    }
    
    /// Create or edit a managed object.
    func insert(_ value: ModelData) async throws {
        let entityName = value.entity
        let collection = self.collection(entityName)
        let document = BSONDocument(model: value)
        try await collection.insertOne(document)
    }
    
    func insert(_ values: [ModelData]) async throws {
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
    func delete(
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
