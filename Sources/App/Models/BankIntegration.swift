import Vapor
import Fluent

enum Bank: String, Codable {
	case monobank
	case privatbank
}

final class BankIntegration: Model {
	static let schema = "bank_integrations"

	@ID(custom: "id")
	var id: Int?

	@Field(key: "bank")
	var bank: Bank

	@Field(key: "credential")
	var credential: Data

	@Field(key: "webhook_installed")
	var webhookInstalled: Bool

	@Parent(key: "user_id")
	var user: User

	init() {}

	init(id: IDValue? = nil, bank: Bank, credential: Data, webhookInstalled: Bool, userID: User.IDValue) {
		self.id = id
		self.bank = bank
		self.credential = credential
		self.webhookInstalled = webhookInstalled
		self.$user.id = userID
	}
}

extension BankIntegration {
	struct Public: Content {
		let id: Int
		let bank: Bank

		init(_ integration: BankIntegration) throws {
			id = try integration.requireID()
			bank = integration.bank
		}
	}
}
