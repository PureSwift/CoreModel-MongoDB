import Foundation
import XCTest
import NIO
@testable import CoreModel
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
        
        let model = Model(entities: Person.self, Event.self, Campground.self, Campground.RentalUnit.self)
        let store = MongoModelStorage(
            database: database,
            model: model
        )
        
        var person1 = Person(
            name: "John Appleseed",
            age: 22
        )
                
        var event1 = Event(
            name: "WWDC",
            date: Date(timeIntervalSinceNow: 60 * 60 * 24 * 10)
        )
        
        // set relationship
        event1.people.append(person1.id)
        person1.events.append(event1.id)
        
        try await store.insert(event1)
        try await store.insert(person1)
        person1 = try await store.fetch(Person.self, for: person1.id)!
        XCTAssertEqual(person1.events, [event1.id])
        event1 = try await store.fetch(Event.self, for: event1.id)!
        XCTAssertEqual(event1.people, [person1.id])
        
        var campground = Campground(
            name: "Fair Play RV Park",
            address: """
            243 Fisher Cove Rd,
            Fair Play, SC
            """,
            location: .init(latitude: 34.51446212994721, longitude: -83.01371101951648),
            descriptionText: """
            At Fair Play RV Park, we are committed to providing a clean, safe and fun environment for all of our guests, including your fur-babies! We look forward to meeting you and having you stay with us!
            """,
            officeHours: Campground.Schedule(start: 60 * 8, end: 60 * 18)
        )
        
        let rentalUnit = Campground.RentalUnit(
            campground: campground.id,
            name: "A1",
            amenities: [.amp50, .water, .mail, .river, .laundry],
            checkout: campground.officeHours
        )
        
        // set relationship
        campground.units = [rentalUnit.id]
        
        var campgroundData = try campground.encode(log: { print("Encoder:", $0) })
        try await store.insert(campgroundData)
        let rentalUnitData = try rentalUnit.encode(log: { print("Encoder:", $0) })
        XCTAssertEqual(rentalUnitData.relationships[PropertyKey(Campground.RentalUnit.CodingKeys.campground)], .toOne(ObjectID(campground.id)))
        try await store.insert(rentalUnitData)
        campgroundData = try await store.fetch(Campground.entityName, for: ObjectID(campground.id))!
        campground = try .init(from: campgroundData, log: { print("Decoder:", $0) })
        XCTAssertEqual(campground.units, [rentalUnit.id])
        XCTAssertEqual(campgroundData.relationships[PropertyKey(Campground.CodingKeys.units)], .toMany([ObjectID(rentalUnit.id)]))
        let fetchedRentalUnit = try await store.fetch(Campground.RentalUnit.self, for: rentalUnit.id)
        XCTAssertEqual(fetchedRentalUnit, rentalUnit)
    }
}
