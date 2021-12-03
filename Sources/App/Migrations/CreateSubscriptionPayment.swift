import Fluent

struct CreateSubscriptionPayment: AsyncMigration {
	func revert(on database: Database) async throws {
		try await database.schema(SubscriptionPayment.schema).delete()
	}

	func prepare(on database: Database) async throws {
		try await database.schema(SubscriptionPayment.schema)
			.field("id", .int, .identifier(auto: true))
			.field("user_id", .int, .required, .references(User.schema, "id", onDelete: .cascade))
			.field("account_id", .string, .references(BankAccount.schema, "id", onDelete: .cascade))
			.field("amount", .int, .required)
			.field("currency_code", .int, .required)
			.field("renewal_interval", .string, .required)
			.field("interval_length", .int, .required)
			.field("renewal_date", .date, .required)
			.field("description", .string, .required)
			.field("active", .bool, .required)
			.field("updated_at", .datetime)
			.create()
	}
}
