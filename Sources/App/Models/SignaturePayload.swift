import Foundation
import Vapor

struct SignaturePayload: Content {
	let timestamp: Int
	let payload: Any
	let path: String

	init(timestamp: Int, payload: Any, path: String) {
		self.timestamp = timestamp
		self.payload = payload
		self.path = path
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
		let sPayload: String

		switch payload {
		case let p as String:
			sPayload = p
		default:
			sPayload = String(describing: payload)
		}

		try container.encode(base64Encode(sTimestamp), forKey: .timestamp)
		try container.encode(base64Encode(sPayload), forKey: .payload)
		try container.encode(base64Encode(path), forKey: .path)
	}

	private func base64Encode(_ str: String) -> String {
		let data = Data(str.utf8)
		return data.base64EncodedString()
	}
}
