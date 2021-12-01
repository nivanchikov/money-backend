import Vapor
import Fluent
import SQLKit

struct CurrencyStats: Content {
	init(realBalance: Int, balance: Int, currencyCode: Int, currency: String) {
		self.realBalance = realBalance
		self.balance = balance
		self.currencyCode = currencyCode
		self.currency = currency
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
	}

	let realBalance: Int
	let balance: Int
	let currencyCode: Int
	let currency: String

	enum CodingKeys: String, CodingKey {
		case realBalance = "real_balance"
		case balance = "available_balance"
		case currencyCode = "currency_code"
		case currency
	}
}

struct StatsController {
	func getStats(_ req: Request) async throws -> [CurrencyStats] {
		let auth = try req.auth.require(Payload.self)

		guard let _ = try await User.find(auth.userID, on: req.db) else {
			throw Abort(.unauthorized)
		}

		let sql = req.db as! SQLDatabase

		let stats = try await sql.raw("""
			SELECT
			   SUM(bank_accounts.balance - bank_accounts.credit_limit) AS real_balance,
			   SUM(bank_accounts.balance) AS available_balance,
			   bank_accounts.currency_code,
			   currency_codes.code as currency
			FROM
			   bank_accounts
			LEFT JOIN currency_codes ON bank_accounts.currency_code = currency_codes.id
			WHERE bank_accounts.user_id = \(bind: auth.userID)
			GROUP BY
			   bank_accounts.currency_code,
			   currency_codes.code
			ORDER BY
			   currency
			""").all(decoding: CurrencyStats.self).get()

		return stats
	}
}

extension StatsController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		routes.get("", use: getStats)
	}
}
