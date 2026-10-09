import Foundation

enum BackgroundWork {
    static func run<Value>(_ operation:@escaping()throws->Value) async throws->Value {
        let worker=Task.detached(priority:.userInitiated,operation:operation)
        return try await withTaskCancellationHandler(operation:{try await worker.value},onCancel:{worker.cancel()})
    }
}
