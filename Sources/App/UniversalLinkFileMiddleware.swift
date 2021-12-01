import Vapor

public final class UniversalLinkFileMiddleware: Middleware {
	/// The public directory.
	/// - note: Must end with a slash.
	private let publicDirectory: String

	/// Creates a new `FileMiddleware`.
	public init(publicDirectory: String) {
		self.publicDirectory = publicDirectory.hasSuffix("/") ? publicDirectory : publicDirectory + "/"
	}

	public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
		// make a copy of the percent-decoded path
		guard var path = request.url.path.removingPercentEncoding else {
			return request.eventLoop.makeFailedFuture(Abort(.badRequest))
		}

		// path must be relative.
		while path.hasPrefix("/") {
			path = String(path.dropFirst())
		}

		// protect against relative paths
		guard !path.contains("../") else {
			return request.eventLoop.makeFailedFuture(Abort(.forbidden))
		}

		// create absolute file path
		let filePath = self.publicDirectory + path

		// check if file exists and is not a directory
		var isDir: ObjCBool = false
		guard FileManager.default.fileExists(atPath: filePath, isDirectory: &isDir), !isDir.boolValue else {
			return next.respond(to: request)
		}

		let response: Response

		let url = URL(fileURLWithPath: filePath)
		switch url.lastPathComponent {
		case "apple-app-site-association":
			response = request.fileio.streamFile(at: filePath, mediaType: .json)
		default:
			response = request.fileio.streamFile(at: filePath)
		}

		return request.eventLoop.makeSucceededFuture(response)
	}
}
