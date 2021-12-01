import Vapor
import Fluent

struct AccountSyncer {

	static func syncAccountsInfo(for userID: User.IDValue, application: Application) async throws {
		let repos = application.repositories

		let integrations = try await repos.bankIntegrations.find(for: userID)

		guard !integrations.isEmpty else {
			return
		}

		for integration in integrations {
			switch integration.bank {
			case .monobank:
				try await MonobankAccountSyncer.syncAccount(from: integration, application: application)
			case .privatbank:
				try await PrivatbankAccountSyncer.syncAccount(from: integration, application: application)
			}
		}
	}

	
}
