import Vapor
import Fluent

final class BankTransaction: Model {
	static let schema = "bank_transactions"

	@ID(custom: "id", generatedBy: .user)
	var id: String?

	@Parent(key: "account_id")
	var account: BankAccount

	@Field(key: "timestamp")
	var timestamp: Date

	@Field(key: "description")
	var description: String?

	@Field(key: "mcc")
	var mcc: Int?

	@Field(key: "original_mcc")
	var originalMCC: Int?

	@Field(key: "amount")
	var amount: Int

	@Field(key: "operation_amount")
	var operationAmount: Int

	@Field(key: "currency_code")
	var currencyCode: Int

	@Field(key: "commission_rate")
	var commissionRate: Int

	@Field(key: "balance_rest")
	var balanceRest: Int

	init() {}

	init(id: IDValue? = nil, accountID: BankAccount.IDValue,
		 timestamp: Date, description: String?, mcc: Int?, originalMCC: Int?, amount: Int,
		 operationAmount: Int, currencyCode: Int, comissionRate: Int,
		 balanceRest: Int)
	{
		self.id = id
		self.$account.id = accountID
		self.timestamp = timestamp
		self.description = description
		self.mcc = mcc
		self.originalMCC = originalMCC
		self.amount = amount
		self.operationAmount = operationAmount
		self.currencyCode = currencyCode
		self.commissionRate = comissionRate
		self.balanceRest = balanceRest
	}
}

extension BankTransaction {
	struct Public: Content {
		let id: BankTransaction.IDValue
		let accountID: BankAccount.IDValue
		let timestamp: Date
		let bank: Bank
		let description: String?
		let mcc: Int?
		let originalMCC: Int?
		let amount: Int
		let operationAmount: Int
		let currencyCode: Int
		let commissionRate: Int
		let balanceRest: Int

		internal init(_ transaction: BankTransaction) throws {
			self.id = try transaction.requireID()
			self.accountID = transaction.$account.id
			self.bank = transaction.account.bank
			self.timestamp = transaction.timestamp
			self.description = transaction.description
			self.mcc = transaction.mcc
			self.originalMCC = transaction.originalMCC
			self.amount = transaction.amount
			self.operationAmount = transaction.operationAmount
			self.currencyCode = transaction.currencyCode
			self.commissionRate = transaction.commissionRate
			self.balanceRest = transaction.balanceRest
		}

		enum CodingKeys: String, CodingKey {
			case id
			case bank
			case accountID = "account_id"
			case timestamp
			case description
			case mcc
			case originalMCC = "original_mcc"
			case amount
			case operationAmount = "operation_amount"
			case currencyCode = "currency_code"
			case commissionRate = "commission_rate"
			case balanceRest = "balance_rest"
		}
	}
}
