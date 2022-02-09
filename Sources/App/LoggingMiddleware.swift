import Vapor

struct LoggingMiddleware: AsyncMiddleware {
	func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
		let response = try await next.respond(to: request)

		request.logger.warning("Request \(request)\nResponse \(response)", metadata: nil)

		return response
	}
}
