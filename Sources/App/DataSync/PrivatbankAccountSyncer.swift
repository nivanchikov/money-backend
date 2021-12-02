import Vapor
import Fluent
import AEXML

struct PrivatbankAccountSyncer: AccountSyncProvider {
	static func syncAccount(from integration: BankIntegration, application: Application) async throws {
		let rawCredential = integration.credential
		let box = try AES.GCM.SealedBox(combined: rawCredential)

		guard let rawKey = Environment.get("ENCRYPTION_KEY") else {
			throw Abort(.internalServerError, reason: "Encryption key is missing")
		}

		let hash = SHA256.hash(data: Data(rawKey.utf8))
		let key = SymmetricKey(data: hash)
		let unsealed = try AES.GCM.open(box, using: key)

		let credentials = try JSONDecoder().decode(PrivatbankMerchantCredentials.self, from: unsealed)

		try await syncAccounts(userID: integration.$user.id, credential: credentials, application: application)
	}

	private static func syncAccounts(userID: User.IDValue, credential: PrivatbankMerchantCredentials,
									 application: Application) async throws {
		let cardProp = ["name": "cardnum",
						"value": credential.accountNumber]

		let countryProp = ["name": "country",
						   "value": "UA"]

		let body = request(with: [cardProp, countryProp], credential: credential)
		let response = try await request(path: "/balance", body: body, application: application)

		let balanceInfo = response.root["data"]["info"]["cardbalance"]
		let cardInfo = balanceInfo["card"]

		guard let accountID = cardInfo["account"].value else {
			throw Abort(.internalServerError) // throw a better error
		}

		guard let rawCurrency = cardInfo["currency"].value else {
			throw Abort(.internalServerError) // throw a better error
		}

		let currencyISOCode = try await currencyCodeLookup(rawCurrency, application: application)

		guard let rawBalance = balanceInfo["av_balance"].value,
			  let dblBalance = Double(rawBalance) else {
				  throw Abort(.internalServerError) // throw a better error
			  }

		let balance = Int(dblBalance * 100.0)

		var creditLimit = 0

		if let rawLimit = balanceInfo["fin_limit"].value,
		   let dblLimit = Double(rawLimit) {
			creditLimit = Int(dblLimit * 100.0)
		}

		let account = BankAccount(id: accountID,
								  userID: userID,
								  bank: .privatbank,
								  currencyCode: currencyISOCode,
								  balance: balance,
								  creditLimit: creditLimit,
								  number: credential.accountNumber)

		if let _ = try await BankAccount.find(account.requireID(), on: application.db) {
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

	private static func fetchTransactions(account: BankAccount,
										  from: Date? = nil,
										  to: Date = .init(),
										  credential: PrivatbankMerchantCredentials,
										  application: Application) async throws {
		let fromFinal: Date

		switch from {
		case let .some(date):
			fromFinal = date
		case .none:
			let calendar = Calendar(identifier: .gregorian)
			fromFinal = calendar.date(byAdding: .day, value: -30, to: to)!
		}

		let formatter = DateFormatter()
		formatter.dateFormat = "dd.MM.yyyy"

		let accountID = try account.requireID()

		let cardProp = ["name": "card",
						"value": credential.accountNumber]

		let startDate = ["name": "sd",
						 "value": formatter.string(from: fromFinal)]

		let endDate = ["name": "ed",
					   "value": formatter.string(from: to)]

		let body = request(with: [cardProp, startDate, endDate], credential: credential)
		let response = try await request(path: "/rest_fiz", body: body, application: application)

		let statements = response.root["data"]["info"]["statements"]

		application.logger.info("Fetched \(statements.children.count) transactions for \(accountID)")

		guard let statementElements = statements["statement"].all, !statementElements.isEmpty else {
			return
		}

		let tranDateFormatter = ISO8601DateFormatter()
		tranDateFormatter.formatOptions = [.withFullDate]

		let tranTimeFormatter = ISO8601DateFormatter()
		tranTimeFormatter.formatOptions = [.withTime, .withColonSeparatorInTime]

		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = tranDateFormatter.timeZone

		for statementElement in statementElements {
			let description = statementElement.attributes["description"]
			let id = try statementElement.attributes.throwingValue(for: "appcode")

			let rawTime = try statementElement.attributes.throwingValue(for: "trantime")
			let rawDate = try statementElement.attributes.throwingValue(for: "trandate")

			guard let rDate = tranDateFormatter.date(from: rawDate),
					let rTime = tranTimeFormatter.date(from: rawTime) else {
				application.logger.error("Failed to decode date and time \(rawDate) \(rawTime)")
				throw Abort(.internalServerError)
			}

			let timeInterval = rTime.timeIntervalSince(calendar.startOfDay(for: rTime))

			let transactionDate = rDate.addingTimeInterval(timeInterval)

			let rawAmount = try statementElement.attributes.throwingValue(for: "amount")
			let amountComponents = rawAmount.components(separatedBy: .whitespaces)

			guard let value = amountComponents.first, let amount = Double(value) else {
				application.logger.error("Failed to decode amount \(rawAmount)")
				throw Abort(.internalServerError)
			}

			let rawOpAmount = try statementElement.attributes.throwingValue(for: "cardamount")
			let rawOpAmountComponents = rawOpAmount.components(separatedBy: .whitespaces)

			guard let value = rawOpAmountComponents.first, let operationAmount = Double(value) else {
				application.logger.error("Failed to decode operation amount \(rawOpAmount)")
				throw Abort(.internalServerError)
			}

			let rawBalanceAmount = try statementElement.attributes.throwingValue(for: "rest")
			let rawBalanceComponents = rawBalanceAmount.components(separatedBy: .whitespaces)

			guard let value = rawBalanceComponents.first, let balance = Double(value) else {
				application.logger.error("Failed to decode operation amount \(rawBalanceAmount)")
				throw Abort(.internalServerError)
			}

			var intAmount = Int(amount * 100.0)
			let intOpAmount = Int(operationAmount * 100.0)
			let intBalance = Int(balance * 100.0)

			if intOpAmount < 0 {
				intAmount *= -1
			}

			let comissionRate = abs(intOpAmount) - abs(intAmount)

			let currencyCode = try await currencyCodeLookup(rawOpAmountComponents.last!, application: application)

			let dbo = BankTransaction(id: id, accountID: accountID,
									  timestamp: transactionDate,
									  description: description,
									  mcc: nil, originalMCC: nil,
									  amount: intAmount, operationAmount: intOpAmount,
									  currencyCode: currencyCode, comissionRate: comissionRate,
									  balanceRest: intBalance)

			do {
				try await dbo.create(on: application.db)
			} catch {
				dbo.$id.exists = true
				try await dbo.update(on: application.db)
			}
		}
	}

//	<data><oper>cmt</oper><wait>0</wait><test>0</test><payment id=""><prop name="sd" value="01.11.2021" /><prop name="ed" value="30.11.2021" /><prop name="card" value="5363542308814897" /></payment></data>
// </request>

	private static func request(with props: [[String: String]], credential: PrivatbankMerchantCredentials) -> String {
		let data = AEXMLElement(name: "data")
		data.addChild(name: "oper", value: "cmt")
		data.addChild(name: "wait", value: "0")
		data.addChild(name: "test", value: "0")

		let payment = data.addChild(name: "payment", attributes: ["id": ""])

		for prop in props {
			payment.addChild(name: "prop", attributes: prop)
		}

		let dataContents = data.children.map { $0.xmlCompact }.joined()
		let rawSignature = dataContents + credential.password

		let md5Signature = Insecure.MD5.hash(data: Data(rawSignature.utf8)).hex
		let sha1Signature = Insecure.SHA1.hash(data: Data(md5Signature.utf8)).hex

		let merchant = AEXMLElement(name: "merchant")
		merchant.addChild(name: "id", value: String(describing: credential.merchantID))
		merchant.addChild(name: "signature", value: sha1Signature)

		let wrapper = AEXMLDocument()
		let request = wrapper.addChild(name: "request", attributes: ["version": "1.0"])
		request.addChild(merchant)
		request.addChild(data)

		return wrapper.xmlCompact
	}

	private static func request(path: String, body: String, application: Application) async throws -> AEXMLDocument {
		let uri = URI(string: "https://api.privatbank.ua/p24api" + path)

		var headers = HTTPHeaders()
		headers.add(name: "Content-Type", value: "application/xml")

		let response = try await application.client.post(uri, headers: headers, beforeSend: { req in
			req.body = ByteBuffer(data: Data(body.utf8))
		})

		guard let body = response.body else {
			throw Abort(.internalServerError)
		}

		let document = try AEXMLDocument(xml: Data(buffer: body))
		return document
	}
}

func currencyCodeLookup(_ code: String, application: Application) async throws -> Int {
	let request = CurrencyCode.query(on: application.db).filter(\.$code == code.lowercased())

	if let dbCode = try await request.first() {
		return try dbCode.requireID()
	}

	let codeCount = try await CurrencyCode.query(on: application.db).count()

	if codeCount > 0 {
		throw Abort(.noContent)
	}

	var headers = HTTPHeaders()
	headers.add(name: .accept, value: "application/json")

	let codesResponse = try await application.client.get("https://raw.githubusercontent.com/nivanchikov/ISO-Country-Data/master/currencies.min.json", headers: headers)

	let codes = try codesResponse.content.decode([CurrencyCodeDTO].self, using: JSONDecoder())

	guard !codes.isEmpty else {
		throw Abort(.noContent)
	}

	for code in codes {
		let dbo = CurrencyCode(id: code.number, code: code.code.lowercased(), name: code.name, decimals: code.decimals)

		if let _ = try await CurrencyCode.find(code.number, on: application.db) {
			dbo.$id.exists = true
			try await dbo.update(on: application.db)
		} else {
			try await dbo.create(on: application.db)
		}
	}

	return try await currencyCodeLookup(code, application: application)
}

extension Dictionary {
	enum DictionaryError: Error {
		case missingValue(key: AnyHashable)
	}

	func throwingValue(for key: Key) throws -> Value {
		guard let value = self[key] else {
			throw DictionaryError.missingValue(key: key)
		}
		return value
	}
}
