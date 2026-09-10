import Foundation
import SwiftData

@Model
final class LocalRecord {
    @Attribute(.unique) var key: String
    var payload: Data
    var updatedAt: Date
    init(key: String, payload: Data) {
        self.key = key; self.payload = payload; self.updatedAt = .now
    }
}

@MainActor
final class LocalRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }
    func load<T: Decodable>(_ type: T.Type, key: String) throws -> T? {
        let records = try context.fetch(FetchDescriptor<LocalRecord>(predicate: #Predicate { $0.key == key }))
        guard let record = records.first else { return nil }
        return try JSONDecoder().decode(type, from: record.payload)
    }
    func save<T: Encodable>(_ value: T, key: String) throws {
        let payload = try JSONEncoder().encode(value)
        let records = try context.fetch(FetchDescriptor<LocalRecord>(predicate: #Predicate { $0.key == key }))
        if let record = records.first { record.payload = payload; record.updatedAt = .now }
        else { context.insert(LocalRecord(key: key, payload: payload)) }
        try context.save()
    }
    func deleteAll() throws {
        try context.delete(model: LocalRecord.self)
        try context.save()
    }
}
