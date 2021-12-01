import Vapor

struct PrivatbankMerchantCredentials: Content {
	let merchantID: Int
	let password: String
	let accountNumber: String

	enum CodingKeys: String, CodingKey {
		case merchantID = "merchant_id"
		case password
		case accountNumber = "account_number"
	}
}
