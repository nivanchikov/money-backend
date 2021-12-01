import Vapor
import Fluent

struct MonobankAccountSyncer: AccountSyncProvider {
	static func syncAccount(from integration: BankIntegration, application: Application) async throws {
		let rawCredential = integration.credential
		let box = try AES.GCM.SealedBox(combined: rawCredential)

		guard let rawKey = Environment.get("ENCRYPTION_KEY") else {
			throw Abort(.internalServerError)
		}

		let hash = SHA256.hash(data: Data(rawKey.utf8))
		let key = SymmetricKey(data: hash)
		let unsealed = try AES.GCM.open(box, using: key)

		guard let credential = String(data: unsealed, encoding: .utf8) else {
			throw Abort(.internalServerError)
		}

		try await syncAccounts(userID: integration.$user.id, credential: credential, application: application)
	}

	private static func signature(time: Int, credential: String, path: String, application: Application) async throws -> String {
		let payload = SignaturePayload(timestamp: time, payload: credential, path: path)

		let data = try await application.client.post(URI(string: "https://oleksandryolkin.com/mb/mbs.php")) { req in
			try req.content.encode(payload)
		}

		guard let signature = data.body.flatMap({ $0.getString(at: 0, length: $0.readableBytes) }) else {
			throw Abort(.internalServerError)
		}

		return signature
	}

	private static func syncAccounts(userID: User.IDValue, credential: String, application: Application) async throws {
		let result = try await request(MonobankAccountsResponse.self,
									   path: "/personal/client-info",
									   credential: credential,
									   application: application)

		let bankAccounts = result.accounts.map { BankAccount(account: $0, userID: userID) }

		for account in bankAccounts {
			let accountID = try account.requireID()

			if let _ = try await BankAccount.find(accountID, on: application.db) {
				account.$id.exists = true
				try await account.update(on: application.db)
			} else {
				try await account.create(on: application.db)
			}

			let lastTransaction = try await BankTransaction.query(on: application.db)
												.filter(\.$account.$id == accountID)
												.sort(\.$timestamp, .descending)
												.first()

			try await fetchTransactions(account: account, from: lastTransaction?.timestamp,
										credential: credential, application: application)
		}
	}

	private static func fetchTransactions(account: BankAccount,
										  from: Date? = nil,
										  to: Date = .init(),
										  credential: String,
										  application: Application) async throws {
		let fromFinal: Date

		switch from {
		case let .some(date):
			fromFinal = date
		case .none:
			let calendar = Calendar(identifier: .gregorian)
			fromFinal = calendar.date(byAdding: .day, value: -30, to: to)!
		}

		let accountID = try account.requireID()

		let path = [
			"/personal/statement",
			accountID,
			String(describing: Int(fromFinal.timeIntervalSince1970)),
			String(describing: Int(to.timeIntervalSince1970))
		].joined(separator: "/")

		let transactions = try await request([MonobankTransactionDTO].self, path: path, credential: credential, application: application)

		application.logger.info("Fetched \(transactions.count) transactions for \(accountID)")

		for transaction in transactions {
			let dbo = BankTransaction(id: transaction.id, accountID: accountID,
									  timestamp: transaction.time, description: transaction.description,
									  mcc: transaction.mcc,
									  originalMCC: transaction.originalMcc, amount: transaction.amount,
									  operationAmount: transaction.operationAmount,
									  currencyCode: transaction.currencyCode,
									  comissionRate: transaction.commissionRate,
									  balanceRest: transaction.balance)

			do {
				try await dbo.create(on: application.db)
			} catch {
				dbo.$id.exists = true
				try await dbo.update(on: application.db)
			}
		}
	}

	private static func request<Payload: Decodable>(_: Payload.Type, path: String, credential: String, application: Application) async throws -> Payload {
		let time = Int(Date().timeIntervalSince1970)

		let signature = try await signature(time: time, credential: credential, path: path, application: application)

		let uri = URI(string: "https://api.monobank.ua" + path)

		var headers = HTTPHeaders()
		headers.add(name: "X-Key-Id", value: Environment.get("MONOBANK_API_KEY")!)
		headers.add(name: "X-Time", value: String(describing: time))
		headers.add(name: "X-Request-Id", value: credential)
		headers.add(name: "X-Sign", value: signature)

		let response = try await application.client.get(uri, headers: headers)

//		application.logger.info("\(response)")

		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .secondsSince1970

		let decoded = try response.content.decode(Payload.self, using: decoder)
		return decoded
	}
}
