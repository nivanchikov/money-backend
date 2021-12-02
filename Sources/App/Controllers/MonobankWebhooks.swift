import APNS

struct MonobankLinkedNotification: APNSwiftNotification {
	let aps: APNSwiftPayload
	let userID: Int

	init(userID: User.IDValue) {
		let alert = APNSwiftAlert(titleLocKey: "monobank_linked_notification_title",
								  locKey: "monobank_linked_notification_body")

		aps = APNSwiftPayload(alert: alert)
		self.userID = userID
	}
}
