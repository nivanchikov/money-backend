import Fluent

struct CreateBankIntegration: Migration {
	func prepare(on database: Database) -> EventLoopFuture<Void> {
		return database.schema("bank_integrations")
			.field("id", .int, .identifier(auto: true))
			.field("bank", .string)
			.field("credential", .data)
			.field("webhook_installed", .bool)
			.field("user_id", .int, .references("users", "id", onDelete: .cascade))
			.unique(on: "bank")
			.create()
	}

	func revert(on database: Database) -> EventLoopFuture<Void> {
		return database.schema("bank_integrations").delete()
	}
}


//@ID(custom: "id")
//   var id: Int?
//
//   @Field(key: "bank")
//   var bank: Bank
//
//   @Field(key: "credential")
//   var credential: Data
//
//   @Field(key: "webhook_installed")
//   var webhookInstalled: Bool
//
//   @Parent(key: "user_id")
//   var user: User
