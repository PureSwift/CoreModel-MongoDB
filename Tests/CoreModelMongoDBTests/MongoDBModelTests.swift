import Foundation
import XCTest
import NIO
@testable import MongoDBModel

final class MongoDBModelTests: XCTestCase {
    
    func testMongoDB() async throws {
        
        let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        let client = try MongoClient("mongodb://localhost:27017", using: elg)
        let database = client.db("test")
        
        defer {
            // clean up driver resources
            try? client.syncClose()
            cleanupMongoSwift()

            // shut down EventLoopGroup
            try? elg.syncShutdownGracefully()
        }
        
        let model = Model(entities: Person.self, Event.self)
        let store = MongoModelStorage(
            database: database,
            model: model
        )
        
        var person1 = Person(
            name: "John Appleseed",
            age: 22
        )
        
        try await store.insert(person1)
        
        var event1 = Event(
            name: "WWDC",
            date: Date(timeIntervalSinceNow: 60 * 60 * 24 * 10),
            people: [person1.id]
        )
        
        try await store.insert(event1)
        person1 = try await store.fetch(Person.self, for: person1.id)!
        XCTAssertEqual(person1.events, [event1.id])
        event1 = try await store.fetch(Event.self, for: event1.id)!
        XCTAssertEqual(event1.people, [person1.id])
    }
}
