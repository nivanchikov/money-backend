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
	 app.middleware.use(UniversalLinkFileMiddleware(publicDirectory: app.directory.publicDirectory))

	app.views.use(.leaf)

	let jwksFilePath = app.directory.workingDirectory + "" + (Environment.get("JWKS_KEYPAIR_FILE") ?? "keypair.jwks")
	guard
		let jwks = FileManager.default.contents(atPath: jwksFilePath),
		let jwksString = String(data: jwks, encoding: .utf8)
	else {
		fatalError("Failed to load JWKS Keypair file at: \(jwksFilePath)")
	}

	do {
		let apnsFilePath = app.directory.workingDirectory + (Environment.get("APNS_KEYPAIR_FILE") ?? "apns.p8")
		let key = try ECDSAKey.private(filePath: apnsFilePath)

		app.apns.configuration = .init(authenticationMethod: .jwt(key: key,
																  keyIdentifier: JWKIdentifier(string: Environment.get("APNS_KEY_ID")!),
																  teamIdentifier: Environment.get("APPLE_TEAM_ID")!),
									   topic: "",
									   environment: .production)
	} catch {
		fatalError()
	}

	try app.jwt.signers.use(jwksJSON: jwksString)

	app.jwt.apple.applicationIdentifier = Environment.get("APPLE_APPLICATION_IDENTIFIER")

	app.databases.use(.postgres(
		hostname: Environment.get("DATABASE_HOST") ?? "localhost",
		port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
		username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
		password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
		database: Environment.get("DATABASE_NAME") ?? "vapor_database"
	), as: .psql)

	app.migrations.add(CreateUser())
	app.migrations.add(CreateRefreshToken())
	app.migrations.add(CreateBankIntegration())
	app.migrations.add(JobModelMigrate())
	app.migrations.add(CreateBankAccount())
	app.migrations.add(CreateCurrencyCode())
	app.migrations.add(CreateBankTransaction())

	// register routes
	try routes(app)

	app.repositories.use(.database)
	app.randomGenerators.use(.random)
	app.queues.use(.fluent(useSoftDeletes: false))

	app.queues.add(AccountSyncJob())

	if app.environment == .development {
		try app.autoMigrate().wait()
		try app.queues.startInProcessJobs(on: .default)

		let payload = AccountSyncPayload(userID: 1)
		try app.queues.queue.dispatch(AccountSyncJob.self, payload).wait()
	}
}
