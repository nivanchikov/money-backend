import Fluent

struct CreateCurrencyCode: AsyncMigration {
	func revert(on database: Database) async throws {
		try await database.schema(CurrencyCode.schema).delete()
	}

	func prepare(on database: Database) async throws {
		try await database.schema(CurrencyCode.schema)
			.field("id", .int, .identifier(auto: false))
			.field("code", .string)
			.field("name", .string)
			.field("decimals", .int)
			.create()
	}
}
