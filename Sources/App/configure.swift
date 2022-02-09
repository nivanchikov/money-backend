import Fluent
import FluentPostgresDriver
import Vapor
import Leaf
import APNS
import JWT
import QueuesFluentDriver
import QueuesRedisDriver

// configures your application
public func configure(_ app: Application) throws {
	// uncomment to serve files from /Public folder
	app.middleware.use(LoggingMiddleware())
	app.middleware.use(UniversalLinkFileMiddleware(publicDirectory: app.directory.publicDirectory))

	app.views.use(.leaf)

	guard let ecdsaPublicKey = Environment.get("JWT_SIGNING_KEY") else {
		fatalError()
	}

	let jwtKey = try RSAKey.private(pem: ecdsaPublicKey)
	app.jwt.signers.use(.rs512(key: jwtKey))

	guard let apnsKeyString = Environment.get("ANPS_KEYPAIR_STRING") else {
		fatalError()
	}

	let apnsKey = try ECDSAKey.private(pem: apnsKeyString)

	app.apns.configuration = .init(authenticationMethod: .jwt(key: apnsKey,
															  keyIdentifier: JWKIdentifier(string: Environment.get("APNS_KEY_ID")!),
															  teamIdentifier: Environment.get("APPLE_TEAM_ID")!),
								   topic: "",
								   environment: .production)

	app.jwt.apple.applicationIdentifier = Environment.get("APPLE_APPLICATION_IDENTIFIER")

	if let url = Environment.get("DATABASE_URL").flatMap(URL.init) {
		app.databases.use(try .postgres(url: url), as: .psql)
	} else {
		app.databases.use(.postgres(
			hostname: Environment.get("DATABASE_HOST") ?? "localhost",
			port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
			username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
			password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
			database: Environment.get("DATABASE_NAME") ?? "vapor_database"
		), as: .psql)
	}

	app.migrations.add(CreateUser())
	app.migrations.add(CreateRefreshToken())
	app.migrations.add(CreateBankIntegration())
	app.migrations.add(JobModelMigrate())
	app.migrations.add(CreateBankAccount())
	app.migrations.add(CreateCurrencyCode())
	app.migrations.add(CreateBankTransaction())
	app.migrations.add(CreatePartsPayment())
	app.migrations.add(CreateSubscriptionPayment())

	// register routes
	try routes(app)

	app.repositories.use(.database)
	app.randomGenerators.use(.random)
	app.queues.use(.fluent(useSoftDeletes: false))
	
	app.queues.add(AccountSyncJob())

	if app.environment == .development {
		try app.autoMigrate().wait()

		try JobModel.query(on: app.db).delete().wait()

		let payload = AccountSyncPayload(userID: 1)
		try app.queues.queue.dispatch(AccountSyncJob.self, payload).wait()

		try app.queues.startInProcessJobs(on: .default)
	}
}

class JobModel: Model {
	@ID(key: .id)
	var id: UUID?

	public required init() {}

	public static var schema = "_jobs"
}
