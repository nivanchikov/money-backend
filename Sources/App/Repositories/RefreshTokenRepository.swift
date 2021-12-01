import Vapor
import Fluent

protocol RefreshTokenRepository: Repository {
	func create(_ token: RefreshToken) async throws
	func find(id: RefreshToken.IDValue?) async throws -> RefreshToken?
	func find(token: String) async throws -> RefreshToken?
	func delete(_ token: RefreshToken) async throws
	func delete(for userID: User.IDValue) async throws
}

struct DatabaseRefreshTokenRepository: RefreshTokenRepository, DatabaseRepository {
	let database: Database

	func create(_ token: RefreshToken) async throws {
		try await token.create(on: database)
	}

	func find(id: RefreshToken.IDValue?) async throws -> RefreshToken? {
		try await RefreshToken.find(id, on: database)
	}

	func find(token: String) async throws -> RefreshToken? {
		try await RefreshToken.query(on: database)
			.filter(\.$token == token)
			.first()
	}

	func delete(_ token: RefreshToken) async throws {
		try await token.delete(on: database)
	}

	func delete(for userID: User.IDValue) async throws {
		try await RefreshToken.query(on: database)
			.filter(\.$user.$id == userID)
			.delete()
	}
}

extension Application.Repositories {
	var refreshTokens: RefreshTokenRepository {
		guard let factory = storage.makeRefreshTokenRepository else {
			fatalError("RefreshToken repository not configured, use: app.repositories.use")
		}
		return factory(app)
	}

	func use(_ make: @escaping (Application) -> (RefreshTokenRepository)) {
		storage.makeRefreshTokenRepository = make
	}
}
