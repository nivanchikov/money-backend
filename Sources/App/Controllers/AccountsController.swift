import Vapor
import Fluent

struct AccountsController {
	func getAccounts(_ req: Request) async throws -> [BankAccount.Public] {
		let auth = try req.auth.require(Payload.self)

		guard let _ = try await User.find(auth.userID, on: req.db) else {
			throw Abort(.unauthorized)
		}

		return try await accounts(for: auth.userID, database: req.db)
	}

	func refreshAccounts(_ req: Request) async throws -> [BankAccount.Public] {
		let auth = try req.auth.require(Payload.self)

		guard let _ = try await User.find(auth.userID, on: req.db) else {
			throw Abort(.unauthorized)
		}

		try await AccountSyncer.syncAccountsInfo(for: auth.userID, application: req.application)
		return try await accounts(for: auth.userID, database: req.db)
	}

	func accounts(for userID: User.IDValue, database: Database) async throws -> [BankAccount.Public] {
		let dbo = try await BankAccount.query(on: database)
						.filter(\.$user.$id == userID).all()

		let accounts = try await withThrowingTaskGroup(of: BankAccount.Public.self) { group -> [BankAccount.Public] in
			for account in dbo {
				group.addTask {
					let currency = try await CurrencyCode.find(account.currencyCode, on: database)
					let isOwner = account.$user.id == userID
					return try BankAccount.Public(account, currency: currency?.code, isOwner: isOwner)
				}
			}

			let accounts = try await group.reduce(into: [], { $0.append($1) })
			return accounts.sorted(by: { $0.id < $1.id })
		}

		return accounts
	}

	func getRequiredPayments(_ req: Request) async throws -> HTTPStatus {
		let auth = try req.auth.require(Payload.self)

		guard let _ = try await User.find(auth.userID, on: req.db) else {
			throw Abort(.unauthorized)
		}

		let dbAccounts = try await BankAccount.query(on: req.db)
								.filter(\.$user.$id == auth.userID)
								.filter(\.$creditLimit > 0).all()

//		for account
		return .ok
	}
}

extension AccountsController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		routes.get("", use: getAccounts)
		routes.get("refresh", use: refreshAccounts)
		routes.get("required_payments", use: getRequiredPayments)
	}
}
