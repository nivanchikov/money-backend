import Vapor

enum Interval: String, Content {
	case month
	case year
}

struct Frequency: Codable {
	let value: Int
	let interval: Interval
}

struct Renewal: Content {
	let frequency: Frequency
	let date: Date
}

struct CreateSubscriptionPaymentDTO: Content {
	let amount: Int
	let renewal: Renewal
	let description: String
	let currencyCode: Int

	let accountID: BankAccount.IDValue?

	enum CodingKeys: String, CodingKey {
		case amount
		case renewal
		case description

		case currencyCode = "currency_code"

		case accountID = "account_id"
	}
}

struct CreatePartsPaymentDTO: Content {
	let amount: Int
	let renewal: Renewal
	let description: String
	let paymentsLeft: Int

	let accountID: BankAccount.IDValue

	enum CodingKeys: String, CodingKey {
		case amount
		case renewal
		case description

		case paymentsLeft = "payments_left"
		case accountID = "account_id"
	}
}
