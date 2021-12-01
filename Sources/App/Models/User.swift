import Vapor
import Fluent
import JWT

final class User: Model, Content {
	static let schema: String = "users"

	@ID(custom: "id")
	var id: Int?

	@Field(key: "email")
	var email: String?

	@Field(key: "apple_identity_token")
	var appleIdentityToken: String?

	init() {}

	init(id: IDValue? = nil, email: String, appleIdentityToken: String?) {
		self.id = id
		self.email = email
		self.appleIdentityToken = appleIdentityToken
	}
}
