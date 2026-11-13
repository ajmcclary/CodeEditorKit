import Darwin
import Foundation

/// CPU time for cost bounds in tests.
///
/// A wall-clock bound fails on a slow or loaded machine (a CI runner, the
/// rest of the suite running in parallel) although nothing got slower: wall
/// time also counts time spent waiting for a core. CPU time counts only the
/// work done, so a bound on it still catches an algorithmic regression (a
/// quadratic pass costs seconds of CPU) without depending on load.
enum CPUTime {
    /// CPU seconds used so far by the calling thread.
    static func thread() -> TimeInterval {
        seconds(of: CLOCK_THREAD_CPUTIME_ID)
    }

    /// CPU seconds used so far by the whole process (every thread). For work
    /// that hops threads (async code). Under `swift test --parallel` each
    /// test runs in a process of its own; run alone, earlier tests'
    /// leftover background work can add to it, so bounds keep headroom.
    static func process() -> TimeInterval {
        seconds(of: CLOCK_PROCESS_CPUTIME_ID)
    }

    /// The calling thread's CPU seconds spent in `body`, for synchronous work.
    static func onThread<T>(_ body: () throws -> T) rethrows -> (value: T, seconds: TimeInterval) {
        let start = thread()
        let value = try body()
        return (value, thread() - start)
    }

    /// The process's CPU seconds spent while `body` runs, for async work.
    static func inProcess<T>(
        isolation _: isolated (any Actor)? = #isolation,
        _ body: () async throws -> T
    ) async rethrows -> (value: T, seconds: TimeInterval) {
        let start = process()
        let value = try await body()
        return (value, process() - start)
    }

    private static func seconds(of clock: clockid_t) -> TimeInterval {
        var time = timespec()
        clock_gettime(clock, &time)
        return TimeInterval(time.tv_sec) + TimeInterval(time.tv_nsec) / 1_000_000_000
    }
}

/// How long to wait for something whose arrival, not its speed, is under
/// test. Expiry means it never came; cost bounds are asserted separately, in
/// CPU time.
var arrivalTimeout: TimeInterval { 30 }

/// Waits, without blocking the actor, until `condition` holds or `timeout`
/// passes. For a state that an asynchronous step reaches: a fixed sleep
/// before the assertion fails on a slow machine. Expiry only means the
/// state never arrived; the assertion after it reports what was reached.
func waitUntil(
    timeout: TimeInterval = arrivalTimeout,
    isolation _: isolated (any Actor)? = #isolation,
    _ condition: () async -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while await !condition(), Date() < deadline {
        try? await Task.sleep(for: .milliseconds(10))
    }
}

/// Runs the current run loop until `condition` holds or `timeout` passes.
/// The synchronous form of `waitUntil`, for tests that drive AppKit.
func spinUntil(timeout: TimeInterval = arrivalTimeout, _ condition: () -> Bool) {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition(), Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
    }
}

/// Returns once every block already on the main queue has run: for work the
/// code under test deferred with `DispatchQueue.main.async`, in place of a
/// short sleep that only usually covers it.
func drainMainQueue() async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        DispatchQueue.main.async { continuation.resume() }
    }
}
