import Vapor
import Fluent

final class PartsPayment: Model {
	static let schema: String = "parts_payment"

	@ID(custom: "id")
	var id: Int?

	@Parent(key: "account_id")
	var account: BankAccount

	@Field(key: "amount")
	var amount: Int

	@Field(key: "description")
	var description: String

	@Field(key: "currency_code")
	var currencyCode: Int

	@Field(key: "payments_left")
	var paymentsLeft: Int

	@Field(key: "renewal_interval")
	var renewalInterval: Interval

	@Field(key: "interval_length")
	var renewalIntervalLength: Int

	@Field(key: "renewal_date")
	var renewalDate: Date

	@Field(key: "active")
	var active: Bool

	@Timestamp(key: "updated_at", on: .update)
	var updatedAt: Date?

	init() {}

	init(payment: CreatePartsPaymentDTO, account: BankAccount) throws {
		$account.id = try account.requireID()
		amount = payment.amount
		description = payment.description
		currencyCode = account.currencyCode
		paymentsLeft = payment.paymentsLeft
		renewalInterval = payment.renewal.frequency.interval
		renewalIntervalLength = payment.renewal.frequency.value
		renewalDate = payment.renewal.date
		active = true
	}
}

extension PartsPayment {
	struct Public: Content {
		let id: Int
		let accountID: BankAccount.IDValue
		let amount: Int
		let currencyCode: Int
		let renewal: Renewal
		let paymentsLeft: Int
		let active: Bool
		let description: String
		let updatedAt: Date?

		init(payment: PartsPayment) throws {
			id = try payment.requireID()
			accountID = try payment.account.requireID()
			amount = payment.amount
			currencyCode = payment.currencyCode
			paymentsLeft = payment.paymentsLeft
			active = payment.active
			description = payment.description
			updatedAt = payment.updatedAt

			renewal = Renewal(frequency: Frequency(value: payment.renewalIntervalLength,
												   interval: payment.renewalInterval),
							  date: payment.renewalDate)

		}

		enum CodingKeys: String, CodingKey {
			case id
			case accountID = "account_id"
			case amount
			case currencyCode = "currency_code"
			case renewal
			case paymentsLeft = "payments_left"
			case active
			case description
			case updatedAt = "updated_at"
		}
	}
}
