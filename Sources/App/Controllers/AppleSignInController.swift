import Fluent
import JWT
import Vapor

struct AppleSignInController {
	func authHandler(req: Request) async throws -> AuthResponse {
		let userBody = try req.content.decode(AppleSignInRequest.self)

		let token = try await req.jwt.apple.verify(userBody.token)

		let user = try await req.users.find(appleIdentityToken: token.subject.value)

		switch user {
		case let .some(user):
			return try await createAuth(for: user, req: req)
		case .none:
			let user = try await createUser(token: token, req: req)
			return try await createAuth(for: user, req: req)
		}
	}

	func createUser(token: AppleIdentityToken, req: Request) async throws -> User {
		guard let email = token.email else {
			throw Abort(.badRequest)
		}

		let existing = try await req.users.find(email: email)

		switch existing {
		case .none:
			let user = User(email: email, appleIdentityToken: token.subject.value)
			return try await req.users.save(user: user)
		case let .some(user):
			user.appleIdentityToken = token.subject.value
			return try await req.users.save(user: user)
		}
	}
}

// MARK: - RouteCollection
extension AppleSignInController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		routes.post(use: authHandler)
	}
}
