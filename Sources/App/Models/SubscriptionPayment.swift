import Vapor
import Fluent

final class SubscriptionPayment: Model {
	static let schema: String = "subscription_payment"

	@ID(custom: "id")
	var id: Int?

	@Parent(key: "user_id")
	var user: User

	@OptionalField(key: "account_id")
	var accountID: BankAccount.IDValue?

	@Field(key: "amount")
	var amount: Int

	@Field(key: "description")
	var description: String

	@Field(key: "currency_code")
	var currencyCode: Int

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

	init(payment: CreateSubscriptionPaymentDTO, userID: User.IDValue) throws {
		$user.id = userID
		accountID = payment.accountID
		amount = payment.amount
		description = payment.description
		currencyCode = payment.currencyCode
		renewalInterval = payment.renewal.frequency.interval
		renewalIntervalLength = payment.renewal.frequency.value
		renewalDate = payment.renewal.date
		active = true
	}
}

extension SubscriptionPayment {
	struct Public: Content {
		let id: Int
		let accountID: BankAccount.IDValue?
		let amount: Int
		let currencyCode: Int
		let renewal: Renewal
		let active: Bool
		let description: String
		let updatedAt: Date?

		init(payment: SubscriptionPayment) throws {
			id = try payment.requireID()
			accountID = payment.accountID
			amount = payment.amount
			currencyCode = payment.currencyCode
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
			case active
			case description
			case updatedAt = "updated_at"
		}
	}
}
