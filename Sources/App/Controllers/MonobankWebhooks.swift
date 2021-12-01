import Vapor
import APNS
import Fluent
import Foundation
import Queues

struct MonobankWebhooks {
	func connect(_ req: Request) async throws -> HTTPStatus {
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

		// TODO: Send notification (optional)

		let payload = AccountSyncPayload(userID: userID)
		try await req.queue.dispatch(AccountSyncJob.self, payload)

		return .ok
	}
}

extension MonobankWebhooks: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		routes.get("connect", ":userID", use: connect)
	}
}

struct MonobankLinkedNotification: APNSwiftNotification {
	let aps: APNSwiftPayload
	let userID: Int

	init(userID: User.IDValue) {
		let alert = APNSwiftAlert(titleLocKey: "monobank_linked_notification_title",
								  locKey: "monobank_linked_notification_body")

		aps = APNSwiftPayload(alert: alert)
		self.userID = userID
	}
}
