import Fluent

struct CreatePartsPayment: AsyncMigration {
	func revert(on database: Database) async throws {
		try await database.schema(PartsPayment.schema).delete()
	}

	func prepare(on database: Database) async throws {
		try await database.schema(PartsPayment.schema)
			.field("id", .int, .identifier(auto: true))
			.field("account_id", .string, .required, .references(BankAccount.schema, "id", onDelete: .cascade))
			.field("amount", .int, .required)
			.field("currency_code", .int, .required)
			.field("renewal_interval", .string, .required)
			.field("interval_length", .int, .required)
			.field("payments_left", .int)
			.field("renewal_date", .date, .required)
			.field("description", .string, .required)
			.field("active", .bool, .required)
			.field("updated_at", .datetime)
			.create()
	}
}
