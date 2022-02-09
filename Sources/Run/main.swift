import App
import Vapor
import DataDogLog

var env = try Environment.detect()

//if let key = Environment.get("DATADOG_API_KEY") {
//	LoggingSystem.bootstrap {
//		// initialize handler instance
//		var handler = DataDogLogHandler(label: $0, key: key, region: .EU)
//		// global metadata (optional)
//		handler.metadata = ["foo":"bar"]
//
//		return handler
//	}
//} else {
	try LoggingSystem.bootstrap(from: &env)
//}

let app = Application(env)
defer { app.shutdown() }
try configure(app)
try app.run()
