import Vapor
import Fluent
import SQLKit

struct RecurringPaymentsController {
	func createPartsPayment(_ req: Request) async throws -> HTTPStatus {
		let auth = try req.auth.require(Payload.self)

		guard let _ = try await User.find(auth.userID, on: req.db) else {
			throw Abort(.unauthorized)
		}

		let dto = try req.content.decode(CreatePartsPaymentDTO.self)

		guard let account = try await BankAccount.query(on: req.db)
				.filter(\.$id == dto.accountID)
				.filter(\.$user.$id == auth.userID).first() else {
			throw Abort(.forbidden, reason: "Account not found or user is not an owner of the account")
		}

		let dbo = try PartsPayment(payment: dto, account: account)
		try await dbo.save(on: req.db)

		return .created
	}

	func getPartsPayments(_ req: Request) async throws -> [PartsPayment.Public] {
		let auth = try req.auth.require(Payload.self)

		guard let _ = try await User.find(auth.userID, on: req.db) else {
			throw Abort(.unauthorized)
		}

		let dbo = try await PartsPayment.query(on: req.db)
							.join(BankAccount.self, on: \PartsPayment.$account.$id == \BankAccount.$id)
							.filter(BankAccount.self, \.$user.$id == auth.userID)
							.sort(\.$renewalDate, .ascending)
							.with(\.$account)
							.all()

		let payments = try dbo.map {
			return try PartsPayment.Public(payment: $0)
		}

		return payments
	}

	func createSubscriptionPayment(_ req: Request) async throws -> HTTPStatus {
		let auth = try req.auth.require(Payload.self)

		guard let _ = try await User.find(auth.userID, on: req.db) else {
			throw Abort(.unauthorized)
		}

		let dto = try req.content.decode(CreateSubscriptionPaymentDTO.self)

		if let accountID = dto.accountID {
			guard let _ = try await BankAccount.query(on: req.db)
					.filter(\.$id == accountID)
					.filter(\.$user.$id == auth.userID).first() else {
				throw Abort(.forbidden, reason: "Account not found or user is not an owner of the account")
			}
		}

		let dbo = try SubscriptionPayment(payment: dto, userID: auth.userID)
		try await dbo.save(on: req.db)

		return .created
	}

	func getSubscriptionPayments(_ req: Request) async throws -> [SubscriptionPayment.Public] {
		let auth = try req.auth.require(Payload.self)

		guard let _ = try await User.find(auth.userID, on: req.db) else {
			throw Abort(.unauthorized)
		}

		let dbo = try await SubscriptionPayment.query(on: req.db)
							.filter(\.$user.$id == auth.userID)
							.sort(\.$renewalDate, .ascending)
							.all()

		let payments = try dbo.map {
			return try SubscriptionPayment.Public(payment: $0)
		}

		return payments
	}

	func getMonthlyStats(_ req: Request) async throws -> [RecurringCurrencyStatsDTO] {
		let auth = try req.auth.require(Payload.self)

		guard let _ = try await User.find(auth.userID, on: req.db) else {
			throw Abort(.unauthorized)
		}

		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.dateFormat = "yyyy-MM-dd"

		let isoFormatter = ISO8601DateFormatter()
		isoFormatter.timeZone = .autoupdatingCurrent
		isoFormatter.formatOptions = [.withFullDate]

		let rawFrom = try req.query.get(String.self, at: "date_from")
		let rawTo = try req.query.get(String.self, at: "date_to")

		guard let dateFrom = isoFormatter.date(from: rawFrom), let dateTo = isoFormatter.date(from: rawTo) else {
			throw Abort(.badRequest, reason: "Invalid date formats \(rawFrom) \(rawTo)")
		}
//
//		let isoFrom = isoFormatter.string(from: dateFrom)
//		let isoTo = isoFormatter.string(from: dateTo)

		print("\(dateFrom) \(dateTo)")

		let sql = req.db as! SQLDatabase

		let stats = try await sql.raw("""
		SELECT
		  SUM(amount) as amount,
		  currency_code,
		  MAX(updated_at) AS updated_at
		FROM (
		  SELECT
			  subscription_payment.amount,
			  subscription_payment.currency_code,
			  subscription_payment.updated_at
		  FROM
			  subscription_payment
		  WHERE
			  user_id = \(bind: auth.userID)
			  AND subscription_payment.renewal_date >= \(bind: dateFrom)
			  AND subscription_payment.renewal_date < \(bind: dateTo)
		  UNION
		  SELECT
			  parts_payment.amount,
			  parts_payment.currency_code,
			  parts_payment.updated_at
		  FROM
			  parts_payment
		  LEFT JOIN bank_accounts ON bank_accounts.id = parts_payment.account_id
		WHERE
		  bank_accounts.user_id = \(bind: auth.userID)
		  AND parts_payment.renewal_date >= \(bind: dateFrom)
		  AND parts_payment.renewal_date < \(bind: dateTo)) AS a
		GROUP BY
		  currency_code
		""").all(decoding: RecurringCurrencyStatsDTO.self).get()

		return stats
	}

	func getUpcoming(_ req: Request) async throws -> UpcomingRecurringPaymentsDTO {
		let auth = try req.auth.require(Payload.self)

		guard let _ = try await User.find(auth.userID, on: req.db) else {
			throw Abort(.unauthorized)
		}

		let calendar = Calendar(identifier: .gregorian)
		let comps = calendar.dateComponents([.year, .month], from: Date())

		let dateFrom = calendar.date(from: comps)!
		let dateTo = calendar.date(byAdding: .month, value: 2, to: dateFrom)!

		let subDbo = try await SubscriptionPayment.query(on: req.db)
						.filter(\.$user.$id == auth.userID)
						.filter(\.$renewalDate >= dateFrom)
						.filter(\.$renewalDate <= dateTo)
						.sort(\.$renewalDate, .ascending)
						.all()

		let partsDbo = try await PartsPayment.query(on: req.db)
						.join(BankAccount.self, on: \PartsPayment.$account.$id == \BankAccount.$id)
						.filter(BankAccount.self, \.$user.$id == auth.userID)
						.filter(\.$renewalDate >= dateFrom)
						.filter(\.$renewalDate <= dateTo)
						.sort(\.$renewalDate, .ascending)
						.with(\.$account)
						.all()

		let result = UpcomingRecurringPaymentsDTO(parts: try partsDbo.map(PartsPayment.Public.init),
												  subscriptions: try subDbo.map(SubscriptionPayment.Public.init))

		return result
	}
}

struct UpcomingRecurringPaymentsDTO: Content {
	let parts: [PartsPayment.Public]
	let subscriptions: [SubscriptionPayment.Public]
}

extension RecurringPaymentsController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		routes.get("parts", use: getPartsPayments)
		routes.post("parts", use: createPartsPayment)

		routes.get("subscriptions", use: getSubscriptionPayments)
		routes.post("subscriptions", use: createSubscriptionPayment)

		routes.get("stats", "monthly", use: getMonthlyStats)

		routes.get("upcoming", use: getUpcoming)
	}
}
