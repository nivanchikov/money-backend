import Vapor
import Fluent
import SQLKit

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
			   currency_codes.code as currency,
				MAX(updated_at) as updated_at
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
