import Vapor
import Fluent

protocol UsersRepository: Repository {
	@discardableResult
	func save(user: User) async throws -> User

	func find(appleIdentityToken: String) async throws -> User?
	func find(email: String) async throws -> User?
	func find(id: User.IDValue) async throws -> User?
}

struct DatabaseUsersRepository: UsersRepository, DatabaseRepository {
	let database: Database

	func find(appleIdentityToken: String) async throws -> User? {
		try await User.query(on: database)
			.filter(\.$appleIdentityToken == appleIdentityToken)
			.first()
	}

	func find(email: String) async throws -> User? {
		try await User.query(on: database)
			.filter(\.$email == email)
			.first()
	}

	func find(id: User.IDValue) async throws -> User? {
		try await User.find(id, on: database)
	}

	@discardableResult
	func save(user: User) async throws -> User {
		try await user.save(on: database)
		return user
	}
}

extension Application.Repositories {
	var users: UsersRepository {
		guard let factory = storage.makeUsersRepository else {
			fatalError("RefreshToken repository not configured, use: app.repositories.use")
		}
		return factory(app)
	}

	func use(_ make: @escaping (Application) -> (UsersRepository)) {
		storage.makeUsersRepository = make
	}
}
