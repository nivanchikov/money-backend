import Vapor

struct RecurringCurrencyStatsDTO: Content {
	let currencyCode: Int
	let amount: Int
	let updatedAt: Date?

	enum CodingKeys: String, CodingKey {
		case amount
		case currencyCode = "currency_code"
		case updatedAt = "updated_at"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		let amount = try container.decode(String.self, forKey: .amount)
		let currencyCode = try container.decode(String.self, forKey: .currencyCode)

		self.amount = Int(amount)!
		self.currencyCode = Int(currencyCode)!
		self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
	}
}

