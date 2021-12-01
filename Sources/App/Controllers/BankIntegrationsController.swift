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
}

extension BankIntegrationsController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		routes.get("", use: getIntegrations)

		routes.post("privatbank", use: createPrivatIntegration)
	}
}
