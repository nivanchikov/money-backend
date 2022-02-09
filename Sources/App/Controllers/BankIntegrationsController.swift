import Vapor
import Fluent

struct BankIntegrationsController {
	func getIntegrations(_ req: Request) async throws -> [BankIntegration.Public] {
		let auth = try req.auth.require(Payload.self)

		guard let _ = try await User.find(auth.userID, on: req.db) else {
			throw Abort(.unauthorized)
		}

		let integrations = try await req.bankIntegrations.find(for: auth.userID)
		return try integrations.map(BankIntegration.Public.init)
	}

	func createPrivatIntegration(_ req: Request) async throws -> BankIntegration.Public {
		let auth = try req.auth.require(Payload.self)

		guard let _ = try await User.find(auth.userID, on: req.db) else {
			throw Abort(.unauthorized)
		}

		let rawCredentials = try req.content.decode(PrivatbankMerchantCredentials.self)
		let credentials = try JSONEncoder().encode(rawCredentials)

		guard let rawKey = Environment.get("ENCRYPTION_KEY") else {
			throw Abort(.internalServerError)
		}

		let hash = SHA256.hash(data: Data(rawKey.utf8))
		let key = SymmetricKey(data: hash)

		guard let sealed = try AES.GCM.seal(credentials, using: key).combined else {
			throw Abort(.internalServerError)
		}

		let integration = BankIntegration(bank: .privatbank,
										  credential: sealed,
										  webhookInstalled: false,
										  userID: auth.userID)

		try await integration.save(on: req.db)

		return try BankIntegration.Public(integration)
	}

	func createMonobankIntegration(_ req: Request) async throws -> HTTPStatus {
		guard let userID = req.parameters.get("userID", as: Int.self) else {
			throw Abort(.badRequest)
		}

		guard let requestID = req.headers.first(name: "X-Request-Id") else {
			throw Abort(.badRequest)
		}

		guard let _ = try await req.users.find(id: userID) else {
			throw Abort(.badRequest)
		}

		guard let rawKey = Environment.get("ENCRYPTION_KEY") else {
			throw Abort(.internalServerError)
		}

		let hash = SHA256.hash(data: Data(rawKey.utf8))

		let key = SymmetricKey(data: hash)

		guard let sealed = try AES.GCM.seal(Data(requestID.utf8), using: key).combined else {
			throw Abort(.internalServerError)
		}

		let integration = BankIntegration(bank: .monobank, credential: sealed, webhookInstalled: false, userID: userID)

		try await req.bankIntegrations.delete(for: userID, bank: .monobank)
		try await req.bankIntegrations.create(integration)

		return .ok
	}

	func bindMonobankApp(_ req: Request) async throws -> MonobankAuthResponse {
		let auth = try req.auth.require(Payload.self)

		guard let _ = try await User.find(auth.userID, on: req.db) else {
			throw Abort(.unauthorized)
		}

		let uri = URI(scheme: .https, host: Environment.get("SERVER_NAME"), path: "api/integrations/monobank/connect/\(auth.userID)")

		req.logger.notice("Binding to \(uri)", metadata: nil)

		let permissionsHeader: (String, String) = ("X-Permissions", "s")
		let headers: HTTPHeaders = ["X-Callback" : uri.string]

		let response = try await monobankPostRequest(MonobankAuthResponse.self,
													 path: "/personal/auth/request",
													 payloadHeader: permissionsHeader,
													 additionalHeaders: headers,
													 application: req.application)
		return response
	}
}

extension BankIntegrationsController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		routes.get("", use: getIntegrations)

		routes.post("privatbank", use: createPrivatIntegration)

		routes.get("monobank", "connect", ":userID", use: createMonobankIntegration)
		routes.get("monobank", "authorize", use: bindMonobankApp)
	}
}
