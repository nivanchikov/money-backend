import Vapor
import Fluent

func monobankSignature(time: Int, payload: String, path: String, application: Application) async throws -> String {
	let payload = SignaturePayload(timestamp: time, payload: payload, path: path)

	let data = try await application.client.post(URI(string: "https://oleksandryolkin.com/mb/mbs.php")) { req in
		try req.content.encode(payload)
	}

	guard let signature = data.body.flatMap({ $0.getString(at: 0, length: $0.readableBytes) }) else {
		throw Abort(.internalServerError, reason: "Failed to decode string from signature body")
	}

	return signature.trimmingCharacters(in: .whitespacesAndNewlines)
}

func monobankGetRequest<ResponsePayload: Decodable>(_: ResponsePayload.Type,
										 path: String,
										 payloadHeader: (name: String, value: String),
										 application: Application) async throws -> ResponsePayload {
	let time = Int(Date().timeIntervalSince1970)

	let signature = try await monobankSignature(time: time, payload: payloadHeader.value, path: path, application: application)

	let uri = URI(string: "https://api.monobank.ua" + path)

	var headers = HTTPHeaders()
	headers.add(name: "X-Key-Id", value: Environment.get("MONOBANK_API_KEY")!)
	headers.add(name: "X-Time", value: String(describing: time))
	headers.add(name: "X-Sign", value: signature)
	headers.add(name: payloadHeader.name, value: payloadHeader.value)

	let response = try await application.client.get(uri, headers: headers)

	if let resp = response.body {
		let data = Data(buffer: resp)
		application.logger.error("\(uri) \(String(data: data, encoding: .utf8))", metadata: nil)
	}

	let decoder = JSONDecoder()
	decoder.dateDecodingStrategy = .secondsSince1970

	let decoded = try response.content.decode(ResponsePayload.self, using: decoder)
	return decoded
}

func monobankPostRequest<ResponsePayload>(_: ResponsePayload.Type,
										  path: String,
										  payloadHeader: (name: String, value: String),
										  additionalHeaders: HTTPHeaders? = nil,
										  beforeSend: (inout ClientRequest) throws -> () = { _ in },
										  application: Application) async throws -> ResponsePayload where ResponsePayload: Decodable
{
	let time = Int(Date().timeIntervalSince1970)

	let signature = try await monobankSignature(time: time, payload: payloadHeader.value, path: path, application: application)

	let uri = URI(string: "https://api.monobank.ua" + path)

	var headers = HTTPHeaders()
	headers.add(name: "X-Key-Id", value: Environment.get("MONOBANK_API_KEY")!)
	headers.add(name: "X-Time", value: String(describing: time))
	headers.add(name: "X-Sign", value: signature)
	headers.add(name: payloadHeader.name, value: payloadHeader.value)

	if let additionalHeaders = additionalHeaders {
		headers.add(contentsOf: additionalHeaders)
	}

	let response = try await application.client.post(uri, headers: headers, beforeSend: beforeSend)

	if let resp = response.body {
		let data = Data(buffer: resp)
		application.logger.error("\(uri) \(String(data: data, encoding: .utf8))", metadata: nil)
	}

	let decoder = JSONDecoder()
	decoder.dateDecodingStrategy = .secondsSince1970

	let decoded = try response.content.decode(ResponsePayload.self, using: decoder)
	return decoded
}

struct MonobankAccountSyncer: AccountSyncProvider {
	static func syncAccount(from integration: BankIntegration, application: Application) async throws {
		let rawCredential = integration.credential
		let box = try AES.GCM.SealedBox(combined: rawCredential)

		guard let rawKey = Environment.get("ENCRYPTION_KEY") else {
			throw Abort(.internalServerError, reason: "Encryption key is missing")
		}

		let hash = SHA256.hash(data: Data(rawKey.utf8))
		let key = SymmetricKey(data: hash)
		let unsealed = try AES.GCM.open(box, using: key)

		guard let credential = String(data: unsealed, encoding: .utf8) else {
			throw Abort(.internalServerError, reason: "Failed to decode monobank credential")
		}

		try await syncAccounts(userID: integration.$user.id, credential: credential, application: application)
	}

	private static func syncAccounts(userID: User.IDValue, credential: String, application: Application) async throws {
		let result = try await monobankGetRequest(MonobankAccountsResponse.self,
											   path: "/personal/client-info",
											   payloadHeader: ("X-Request-Id", credential),
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
		var toFinal = to
		let calendar = Calendar(identifier: .gregorian)

		switch from {
		case let .some(date):
			fromFinal = date

			let components = calendar.dateComponents([.day], from: date, to: to)

			if let days = components.day, days > 30 {
				toFinal = calendar.date(byAdding: .day, value: 30, to: date)!
			}
		case .none:
			fromFinal = calendar.date(byAdding: .day, value: -30, to: to)!
		}

		let accountID = try account.requireID()

		let path = [
			"/personal/statement",
			accountID,
			String(describing: Int(fromFinal.timeIntervalSince1970)),
			String(describing: Int(toFinal.timeIntervalSince1970))
		].joined(separator: "/")

		let transactions = try await monobankGetRequest([MonobankTransactionDTO].self,
													 path: path,
													 payloadHeader: ("X-Request-Id", credential),
													 application: application)

		for transaction in transactions {
			let dbo = BankTransaction(id: transaction.id, accountID: accountID,
									  timestamp: transaction.time, description: transaction.description,
									  mcc: transaction.mcc,
									  originalMCC: transaction.originalMcc, amount: transaction.amount,
									  operationAmount: transaction.operationAmount,
									  currencyCode: transaction.currencyCode,
									  comissionRate: transaction.commissionRate,
									  balanceRest: transaction.balance - account.creditLimit)

			do {
				try await dbo.create(on: application.db)
			} catch {
				dbo.$id.exists = true
				try await dbo.update(on: application.db)
			}
		}
	}


}
