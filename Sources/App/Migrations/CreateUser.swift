import Vapor
import Fluent

struct CreateUser: AsyncMigration {
	func prepare(on database: Database) async throws {
		try await database.schema("users")
					.field("id", .int, .identifier(auto: true))
					.field("email", .string, .required)
					.field("apple_identity_token", .string)
					.unique(on: "email")
					.unique(on: "apple_identity_token")
					.create()
	}

	func revert(on database: Database) async throws {
		try await database.schema("users").delete()
	}
}
