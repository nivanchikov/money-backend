import Vapor
import Fluent

enum Constants {
	static let refreshTokenLifetime: TimeInterval = 3600 * 24 * 30
}

final class RefreshToken: Model {
	static let schema = "user_refresh_tokens"

	@ID(custom: "id")
	var id: Int?

	@Field(key: "token")
	var token: String

	@Parent(key: "user_id")
	var user: User

	@Field(key: "expires_at")
	var expiresAt: Date

	@Field(key: "issued_at")
	var issuedAt: Date

	init() {}

	init(id: IDValue? = nil, token: String, userID: User.IDValue,
		 expiresAt: Date = Date().addingTimeInterval(Constants.refreshTokenLifetime),
		 issuedAt: Date = Date()) {
		self.id = id
		self.token = token
		self.$user.id = userID
		self.expiresAt = expiresAt
		self.issuedAt = issuedAt
	}
}
