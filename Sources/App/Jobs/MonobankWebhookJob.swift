import Vapor
import Foundation
import Queues

struct AccountSyncPayload: Codable {
	let userID: User.IDValue
}

struct AccountSyncJob: AsyncJob {
	typealias Payload = AccountSyncPayload

	func dequeue(_ context: QueueContext, _ payload: AccountSyncPayload) async throws {
		let enqueueTask: (QueueContext, AccountSyncPayload, Date) async throws -> Void

		enqueueTask = { context, payload, date in
			let queue = context.application.queues.queue
			let nextRun = date.addingTimeInterval(60.0)

			try await queue.dispatch(AccountSyncJob.self, payload, maxRetryCount: Int.max, delayUntil: nextRun)
		}

		do {
			try await AccountSyncer.syncAccountsInfo(for: payload.userID, application: context.application)
			try await enqueueTask(context, payload, Date())
		} catch {
			context.logger.report(error: error)
			try await enqueueTask(context, payload, Date())
		}
	}
}
