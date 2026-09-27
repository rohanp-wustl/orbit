import Foundation
#if canImport(Supabase)
import Supabase
#endif

/// Configures the shared Supabase client once at app launch. Both values
/// below are meant to be public — the anon key is safe to ship inside the
/// app (unlike the old Anthropic key); real access control lives in
/// Postgres Row Level Security policies, not in keeping this key secret.
/// See docs/SUPABASE_SETUP.sql for the schema + policies.
///
/// Add the package via Swift Package Manager:
/// https://github.com/supabase/supabase-swift
enum OrbitSupabase {
    // Values live in the gitignored Secrets.swift (template: Secrets.swift.example).
    static let projectURL = URL(string: Secrets.supabaseURL) ?? URL(filePath: "/")
    static let anonKey = Secrets.supabaseAnonKey

    #if canImport(Supabase)
    /// Postgres columns are snake_case (sender_id, crew_link_id, ...) while
    /// every Swift model here uses camelCase — this converts automatically
    /// in both directions so the models don't need hand-written CodingKeys
    /// for every property. VERSION NOTE: confirm this options shape against
    /// https://supabase.com/docs/reference/swift/initializing — where
    /// custom encoder/decoder configuration lives has moved before.
    static let client = SupabaseClient(
        supabaseURL: projectURL,
        supabaseKey: anonKey,
        options: .init(
            db: .init(
                encoder: { let e = JSONEncoder(); e.keyEncodingStrategy = .convertToSnakeCase; e.dateEncodingStrategy = .iso8601; return e }(),
                decoder: { let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; d.dateDecodingStrategy = .custom(decodePostgresDate); return d }()
            )
        )
    )
    #endif

    /// Postgres `timestamptz` comes back with microseconds
    /// ("2026-09-26T20:40:15.123456+00:00"), which the plain `.iso8601`
    /// strategy rejects — so try with fractional seconds first, then without.
    @Sendable nonisolated static func decodePostgresDate(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        if let date = try? Date(text, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true).timeZone(separator: .omitted)) {
            return date
        }
        if let date = try? Date(text, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: false).timeZone(separator: .omitted)) {
            return date
        }
        if let date = try? Date(text, strategy: .iso8601) {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date format: \(text)")
    }
}
