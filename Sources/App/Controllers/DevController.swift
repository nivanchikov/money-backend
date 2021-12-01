import Vapor


struct DevController {
	func generateAuth(_ req: Request) async throws -> AuthResponse {
		guard let userID = req.parameters.get("user_id", as: Int.self) else {
			throw Abort(.badRequest)
		}

		guard let user = try await User.find(userID, on: req.db) else {
			throw Abort(.unauthorized)
		}

		return try await createAuth(for: user, req: req)
	}
}

extension DevController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		routes.get("auth", ":user_id", use: generateAuth)
	}
}
