import Vapor

enum AuthError: Error {
	case refreshTokenOrUserNotFound
	case refreshTokenExpired
}

func createAuth(for user: User, req: Request) async throws -> AuthResponse {
	let token = req.random.generate(bits: 256)

	let accessToken = try req.jwt.sign(Payload(with: user))
	let refreshToken = try RefreshToken(token: SHA256.hash(data: Data(token.utf8)).hex,
										userID: user.requireID())

	try await req.refreshTokens.delete(for: user.requireID())
	try await req.refreshTokens.create(refreshToken)

	let authResponse = AuthResponse(accessToken: accessToken,
									refreshToken: token)

	return authResponse
}

struct AuthController {
	func refreshToken(_ req: Request) async throws -> AuthResponse {
		let token = try req.content.decode(RefreshTokenRequest.self)
		let hashedToken = SHA256.hash(data: Data(token.refreshToken.utf8)).hex

		guard let token = try await req.refreshTokens.find(token: hashedToken) else {
			throw AuthError.refreshTokenOrUserNotFound
		}

		try await req.refreshTokens.delete(token)

		guard token.expiresAt > Date() else {
			throw AuthError.refreshTokenExpired
		}

		guard let user = try await req.users.find(id: token.$user.id) else {
			throw AuthError.refreshTokenOrUserNotFound
		}

		return try await createAuth(for: user, req: req)
	}
}

extension AuthController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		routes.post("refresh", use: refreshToken)
	}
}
