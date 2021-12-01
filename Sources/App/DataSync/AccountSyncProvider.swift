import Vapor

protocol AccountSyncProvider {
	static func syncAccount(from integration: BankIntegration, application: Application) async throws
}
