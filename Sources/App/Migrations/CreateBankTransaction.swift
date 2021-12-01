import Fluent

struct CreateBankTransaction: AsyncMigration {
	func revert(on database: Database) async throws {
		try await database.schema(BankTransaction.schema).delete()
	}

	func prepare(on database: Database) async throws {
		try await database.schema(BankTransaction.schema)
			.field("id", .string, .identifier(auto: false))
			.field("account_id", .string, .references(BankAccount.schema, "id", onDelete: .cascade))
			.field("timestamp", .datetime)
			.field("description", .string)
			.field("mcc", .int)
			.field("original_mcc", .int)
			.field("amount", .int)
			.field("operation_amount", .int)
			.field("currency_code", .int)
			.field("commission_rate", .int)
			.field("balance_rest", .int)
			.create()
	}
}
//
//@Parent(key: "account_id")
//var account: BankAccount
//
//@Field(key: "timestamp")
//var timestamp: Date
//
//@Field(key: "mcc")
//var mcc: Int?
//
//@Field(key: "original_mcc")
//var originalMCC: Int?
//
//@Field(key: "amount")
//var amount: Int
//
//@Field(key: "operation_amount")
//var operationAmount: Int
//
//@Field(key: "currency_code")
//var currencyCode: Int
//
//@Field(key: "commission_rate")
//var commissionRate: Int
