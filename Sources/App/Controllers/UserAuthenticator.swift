import JWT
import Vapor

struct UserAuthenticator: AsyncJWTAuthenticator {
	typealias Payload = App.Payload

	func authenticate(jwt: Payload, for request: Request) async throws {
		request.auth.login(jwt)
	}
}
