import Fluent

struct CreateRefreshToken: Migration {
	func prepare(on database: Database) -> EventLoopFuture<Void> {
		return database.schema("user_refresh_tokens")
			.field("id", .int, .identifier(auto: true))
			.field("token", .string)
			.field("user_id", .int, .references("users", "id", onDelete: .cascade))
			.field("expires_at", .datetime)
			.field("issued_at", .datetime)
			.unique(on: "token")
			.unique(on: "user_id")
			.create()
	}

	func revert(on database: Database) -> EventLoopFuture<Void> {
		return database.schema("user_refresh_tokens").delete()
	}
}
