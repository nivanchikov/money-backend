import Vapor

struct AppleSignInRequest: Content {
	let token: String
}
