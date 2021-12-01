import Vapor
import Fluent

struct PaginatedResponse<T: Content>: Content {
	let pagination: PageMetadata
	let data: T
}

struct TransactionsController {
	func getAllTransactions(_ req: Request) async throws -> PaginatedResponse<[BankTransaction.Public]> {
		let auth = try req.auth.require(Payload.self)

		guard let _ = try await User.find(auth.userID, on: req.db) else {
			throw Abort(.unauthorized)
		}

		let dbo = try await BankTransaction.query(on: req.db)
			.sort(\.$timestamp, .descending)
			.sort(\.$id, .descending)
			.with(\.$account)
			.paginate(for: req)

		let transactions = try dbo.items.map { transaction in
			return try BankTransaction.Public(transaction)
		}

		return PaginatedResponse(pagination: dbo.metadata, data: transactions)
	}

	func getAccountTransactions(_ req: Request) async throws -> PaginatedResponse<[BankTransaction.Public]> {
		let auth = try req.auth.require(Payload.self)

		guard let _ = try await User.find(auth.userID, on: req.db) else {
			throw Abort(.unauthorized)
		}

		guard let accountID = req.parameters.get("account_id") else {
			throw Abort(.badRequest)
		}

		guard let _ = try await BankAccount.find(accountID, on: req.db) else {
			throw Abort(.notFound)
		}

		let dbo = try await BankTransaction.query(on: req.db)
			.filter(\.$account.$id == accountID)
			.sort(\.$timestamp, .descending)
			.sort(\.$id, .descending)
			.with(\.$account)
			.paginate(for: req)

		let transactions = try dbo.items.map { transaction in
			return try BankTransaction.Public(transaction)
		}

		return PaginatedResponse(pagination: dbo.metadata, data: transactions)
	}
}

extension TransactionsController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		routes.get("", use: getAllTransactions)
		routes.get(":account_id", use: getAccountTransactions)
	}
}
