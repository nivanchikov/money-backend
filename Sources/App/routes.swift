import Fluent
import Vapor

func routes(_ app: Application) throws {
	let unprotectedAPI = app.grouped("api")
	try unprotectedAPI.grouped("auth", "apple").register(collection: AppleSignInController())
	try unprotectedAPI.grouped("auth").register(collection: AuthController())

	try unprotectedAPI.grouped("webhooks", "monobank").register(collection: MonobankWebhooks())

	let protectedAPI = unprotectedAPI.grouped(UserAuthenticator())

	try protectedAPI.grouped("integrations").register(collection: BankIntegrationsController())
	try protectedAPI.grouped("accounts").register(collection: AccountsController())
	try protectedAPI.grouped("transactions").register(collection: TransactionsController())
	try protectedAPI.grouped("stats").register(collection: StatsController())

	if app.environment == .development {
		try unprotectedAPI.grouped("debug").register(collection: DevController())
	}
}
