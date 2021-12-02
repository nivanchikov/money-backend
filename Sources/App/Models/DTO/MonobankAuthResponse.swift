import Vapor

struct MonobankAuthResponse: Content {
	let tokenRequestId: String
	let acceptURL: URL

	enum CodingKeys: String, CodingKey {
		case tokenRequestId
		case acceptURL = "acceptUrl"
	}
}
