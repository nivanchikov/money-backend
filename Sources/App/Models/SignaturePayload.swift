import Foundation
import Vapor

struct SignaturePayload: Content {
	let timestamp: Int
	let payload: String
	let path: String

	init(timestamp: Int, payload: Any, path: String) {
		self.timestamp = timestamp
		self.path = path

		switch payload {
		case let p as String:
			self.payload = p
		default:
			self.payload = String(describing: payload)
		}
	}

	enum CodingKeys: String, CodingKey {
		case timestamp = "p1"
		case payload = "p2"
		case path = "p3"
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		timestamp = try container.decode(Int.self, forKey: .timestamp)
		payload = try container.decode(String.self, forKey: .payload)
		path = try container.decode(String.self, forKey: .path)
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		let sTimestamp = String(timestamp)

		try container.encode(base64Encode(sTimestamp), forKey: .timestamp)
		try container.encode(base64Encode(payload), forKey: .payload)
		try container.encode(base64Encode(path), forKey: .path)
	}

	private func base64Encode(_ str: String) -> String {
		let data = Data(str.utf8)
		return data.base64EncodedString()
	}
}
