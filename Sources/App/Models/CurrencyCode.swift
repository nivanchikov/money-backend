import Vapor
import Fluent

final class CurrencyCode: Model {
	static let schema = "currency_codes"

	@ID(custom: "id", generatedBy: .user)
	var id: Int?

	@Field(key: "code")
	var code: String

	@Field(key: "name")
	var name: String

	@Field(key: "decimals")
	var decimals: Int?

	init() {}

	init(id: IDValue, code: String, name: String, decimals: Int?) {
		self.id = id
		self.code = code
		self.name = name
		self.decimals = decimals
	}
}

struct CurrencyCodeDTO: Content {
	let code: String
	let decimals: Int?
	let name: String
	let number: Int

	enum CodingKeys: String, CodingKey {
		case code
		case decimals
		case name
		case number
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		code = try container.decode(String.self, forKey: .code)
		decimals = try container.decodeIfPresent(Int.self, forKey: .decimals)
		name = try container.decode(String.self, forKey: .name)

		let rawNumber = try container.decode(String.self, forKey: .number)

		switch rawNumber.lowercased() {
		case "nil":
			number = -1
		default:
			guard let number = Int(rawNumber) else {
				throw DecodingError.typeMismatch(Int.self, .init(codingPath: [CodingKeys.number], debugDescription: "\(rawNumber) is not an Int", underlyingError: nil))
			}

			self.number = number
		}
	}
}
