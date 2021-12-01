import Vapor
import Fluent

final class BankAccount: Model {
	static let schema = "bank_accounts"

	@ID(custom: "id", generatedBy: .user)
	var id: String?

	@Parent(key: "user_id")
	var user: User

	@Field(key: "bank")
	var bank: Bank

	@Field(key: "currency_code")
	var currencyCode: Int

	@Field(key: "balance")
	var balance: Int

	@Field(key: "credit_limit")
	var creditLimit: Int

	@Field(key: "number")
	var number: String

	@Timestamp(key: "updated_at", on: .update)
	var updatedAt: Date?

	init() {}

	init(id: IDValue? = nil,
		 userID: User.IDValue,
		 bank: Bank,
		 currencyCode: Int,
		 balance: Int,
		 creditLimit: Int,
		 number: String) {
		self.id = id
		self.$user.id = userID
		self.bank = bank
		self.currencyCode = currencyCode
		self.balance = balance
		self.creditLimit = creditLimit
		self.number = number
	}
}

extension BankAccount {
	convenience init(account: MonobankAccountDTO, userID: User.IDValue) {
		self.init(id: account.id, userID: userID, bank: .monobank,
				  currencyCode: account.currencyCode, balance: account.balance,
				  creditLimit: account.creditLimit, number: account.number.first!)
	}
}

extension BankAccount {
	struct Public: Content {
		let id: String
		let bank: Bank
		let currencyCode: Int
		let currency: String?
		let balance: Int
		let creditLimit: Int
		let number: String
		let updatedAt: Date?
		let isOwner: Bool

		init(_ account: BankAccount, currency: String?, isOwner: Bool) throws {
			id = try account.requireID()
			bank = account.bank
			currencyCode = account.currencyCode
			self.currency = currency
			balance = account.balance
			creditLimit = account.creditLimit
			number = account.number
			updatedAt = account.updatedAt
			self.isOwner = isOwner
		}

		enum CodingKeys: String, CodingKey {
			case id
			case bank
			case currencyCode = "currency_code"
			case balance
			case currency
			case creditLimit = "credit_limit"
			case number
			case updatedAt = "updated_at"
			case isOwner = "is_owner"
		}
	}
}
