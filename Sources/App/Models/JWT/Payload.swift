import Vapor
import JWT

struct Payload: JWTPayload, Authenticatable {
	var userID: User.IDValue
	var exp: ExpirationClaim

	func verify(using signer: JWTSigner) throws {
		try self.exp.verifyNotExpired()
	}

	init(with user: User) throws {
		self.userID = try user.requireID()
		self.exp = ExpirationClaim(value: Date().addingTimeInterval(3600))
	}
}
