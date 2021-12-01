import Fluent

struct CreateBankAccount: AsyncMigration {
	func revert(on database: Database) async throws {
		try await database.schema(BankAccount.schema).delete()
	}

	func prepare(on database: Database) async throws {
		try await database.schema(BankAccount.schema)
			.field("id", .string, .identifier(auto: false))
			.field("user_id", .int, .references(User.schema, "id", onDelete: .cascade))
			.field("bank", .string)
			.field("currency_code", .int)
			.field("balance", .int)
			.field("credit_limit", .int)
			.field("number", .string)
			.field("updated_at", .datetime)
			.create()
	}
}
