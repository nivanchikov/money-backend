import Vapor

struct AuthResponse: Content {
	let accessToken: String
	let refreshToken: String

	enum CodingKeys: String, CodingKey {
		case accessToken = "access_token"
		case refreshToken = "refresh_token"
	}
}
