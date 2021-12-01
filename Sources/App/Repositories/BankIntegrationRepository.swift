import Vapor
import Fluent

protocol BankIntegrationRepository: Repository {
	func create(_ integration: BankIntegration) async throws
//	func find(id: BankIntegration.IDValue?) async throws -> RefreshToken?
//	func find(token: String) async throws -> RefreshToken?
//	func delete(_ integration: RefreshToken) async throws
	func delete(for userID: User.IDValue, bank: Bank) async throws
	func find(for userID: User.IDValue) async throws -> [BankIntegration]
}

struct DatabaseBankIntegrationRepository: BankIntegrationRepository, DatabaseRepository {
	let database: Database

	func create(_ integration: BankIntegration) async throws {
		try await integration.create(on: database)
	}

	func delete(for userID: User.IDValue, bank: Bank) async throws {
		try await BankIntegration.query(on: database)
			.filter(\.$user.$id == userID)
			.filter(\.$bank == bank)
			.delete()
	}

	func find(for userID: User.IDValue) async throws -> [BankIntegration] {
		try await BankIntegration.query(on: database)
			.filter(\.$user.$id == userID)
			.all()
	}
}

extension Application.Repositories {
	var bankIntegrations: BankIntegrationRepository {
		guard let factory = storage.makeBankIntegrationRepository else {
			fatalError("BankIntegration repository not configured, use: app.repositories.use")
		}
		return factory(app)
	}

	func use(_ make: @escaping (Application) -> (BankIntegrationRepository)) {
		storage.makeBankIntegrationRepository = make
	}
}
