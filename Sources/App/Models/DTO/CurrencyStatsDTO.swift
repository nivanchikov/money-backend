import Vapor

struct CurrencyStats: Content {
	init(realBalance: Int, balance: Int, currencyCode: Int, currency: String, updatedAt: Date) {
		self.realBalance = realBalance
		self.balance = balance
		self.currencyCode = currencyCode
		self.currency = currency
		self.updatedAt = updatedAt
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		let realBalance = try container.decode(String.self, forKey: .realBalance)
		let balance = try container.decode(String.self, forKey: .balance)
		let currencyCode = try container.decode(String.self, forKey: .currencyCode)

		self.realBalance = Int(realBalance)!
		self.balance = Int(balance)!
		self.currencyCode = Int(currencyCode)!
		currency = try container.decode(String.self, forKey: .currency)

		updatedAt = try container.decode(Date.self, forKey: .updatedAt)
	}

	let realBalance: Int
	let balance: Int
	let currencyCode: Int
	let currency: String
	let updatedAt: Date

	enum CodingKeys: String, CodingKey {
		case realBalance = "real_balance"
		case balance = "available_balance"
		case currencyCode = "currency_code"
		case currency
		case updatedAt = "updated_at"
	}
}
