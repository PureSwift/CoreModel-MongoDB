import Foundation
@_exported import CoreModel
@_exported import MongoSwift

public struct MongoModelStorage: ModelStorage {
    
    public let database: MongoDatabase
    
    public let model: Model
    
    public let options: Configuration
    
    public init(
        database: MongoDatabase,
        model: Model,
        options: Configuration = Configuration()
    ) {
        self.database = database
        self.model = model
        self.options = options
    }
    
    /// Fetch managed object.
    public func fetch(_ entityName: EntityName, for id: ObjectID) async throws -> ModelData? {
        let entity = try model(for: entityName)
        let options = options.collections[entity.id]
        return try await database.fetch(entity, for: id, options: options)
    }
    
    /// Fetch managed objects.
    public func fetch(_ fetchRequest: FetchRequest) async throws -> [ModelData] {
        let entity = try model(for: fetchRequest.entity)
        let options = options.collections[entity.id]
        return try await database.fetch(fetchRequest, entity: entity, options: options)
    }
    
    /// Fetch and return result count.
    public func count(_ fetchRequest: FetchRequest) async throws -> UInt {
        let options = options.collections[fetchRequest.entity]
        return try await database.count(fetchRequest, options: options)
    }
    
    /// Create or edit a managed object.
    public func insert(_ value: ModelData) async throws {
        let options = options.collections[value.entity]
        try await database.insert(value, options: options)
    }
    
    /// Create or edit multiple managed objects.
    public func insert(_ values: [ModelData]) async throws {
        try await database.insert(values, options: options.collections)
    }
    
    /// Delete the specified managed object.
    public func delete(_ entity: EntityName, for id: ObjectID) async throws {
        let options = options.collections[entity]
        try await database.delete(entity, for: id, options: options)
    }
    
    private func model(for entityName: EntityName) throws -> EntityDescription {
        guard let entity = self.model.entities.first(where: { $0.id == entityName }) else {
            throw CoreModelError.invalidEntity(entityName)
        }
        return entity
    }
}

public extension MongoModelStorage {
    
    struct Configuration {
        
        public var collections: [EntityName: MongoCollectionOptions]
        
        public init(collections: [EntityName : MongoCollectionOptions] = [:]) {
            self.collections = collections
        }
    }
}

internal extension MongoDatabase {
    
    /// Fetch managed object.
    func fetch(
        _ entity: EntityDescription,
        for id: ObjectID,
        options: MongoCollectionOptions?
    ) async throws -> ModelData? {
        guard let document = try await find(entity.id, for: id, options: options) else {
            return nil
        }
        return try ModelData(bson: document, model: entity)
    }
    
    /// Fetch managed objects.
    func fetch(
        _ fetchRequest: FetchRequest,
        entity: EntityDescription,
        options: MongoCollectionOptions?
    ) async throws -> [ModelData] {
        try await fetchDocuments(fetchRequest, options: options)
            .map { try ModelData(bson: $0, model: entity) }
    }
    
    /// Fetch and return result count.
    func count(
        _ fetchRequest: FetchRequest,
        options: MongoCollectionOptions?
    ) async throws -> UInt {
        let entityName = fetchRequest.entity
        let collection = self.collection(entityName, options: options)
        let filter = fetchRequest.predicate.map { BSONDocument(filter: $0) } ?? [:]
        let options = CountDocumentsOptions(fetchRequest: fetchRequest)
        let count = try await collection.countDocuments(filter, options: options)
        return UInt(count)
    }
    
    /// Create or edit a managed object.
    func insert(
        _ value: ModelData,
        options: MongoCollectionOptions?
    ) async throws {
        let entityName = value.entity
        let collection = self.collection(entityName, options: options)
        let document = BSONDocument(model: value)
        try await collection.insertOne(document)
    }
    
    func insert(
        _ values: [ModelData],
        options: [EntityName: MongoCollectionOptions]
    ) async throws {
        var collections = [EntityName: [ModelData]]()
        for value in values {
            collections[value.entity, default: []].append(value)
        }
        for (entity, values) in collections {
            let collection = self.collection(entity, options: options[entity])
            let documents = values.map { BSONDocument(model: $0) }
            try await collection.insertMany(documents)
        }
    }
    
    /// Delete the specified managed object.
    func delete(
        _ entity: EntityName,
        for id: ObjectID,
        options: MongoCollectionOptions?
    ) async throws {
        let collection = self.collection(entity, options: options)
        let options: DeleteOptions? = nil
        let filter: BSONDocument = [
            BSONDocument.BuiltInProperty.id.rawValue: .string(id.rawValue)
        ]
        try await collection.deleteOne(filter, options: options)
    }
        
    func find(
        _ entityName: EntityName,
        for id: ObjectID,
        options: MongoCollectionOptions?
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
        options: MongoCollectionOptions?
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
        options: MongoCollectionOptions?
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

private extension MongoDatabase {
    
    func collection(
        _ name: EntityName,
        options: MongoCollectionOptions?
    ) -> MongoCollection<BSONDocument> {
        let tableName = name.rawValue.lowercased() + "s"
        return collection(tableName, options: options)
    }
}
