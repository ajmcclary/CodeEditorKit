import Foundation

/// Configuration for LSP connection retry behavior
public struct LSPRetryConfiguration: Sendable {
    /// Maximum number of retry attempts
    public let maxRetries: Int
    
    /// Initial delay between retries (in seconds)
    public let initialDelay: TimeInterval
    
    /// Maximum delay between retries (in seconds)
    public let maxDelay: TimeInterval
    
    /// Factor by which to multiply the delay after each retry (exponential backoff)
    public let backoffFactor: Double
    
    /// Whether to add random jitter to retry delays to avoid thundering herd
    public let jitterEnabled: Bool
    
    /// Default configuration with sensible retry settings
    public static let `default` = Self(
        maxRetries: 3,
        initialDelay: 1.0,
        maxDelay: 30.0,
        backoffFactor: 2.0,
        jitterEnabled: true
    )
    
    /// Aggressive retry configuration for critical connections
    public static let aggressive = Self(
        maxRetries: 5,
        initialDelay: 0.5,
        maxDelay: 60.0,
        backoffFactor: 1.5,
        jitterEnabled: true
    )
    
    /// Conservative retry configuration to minimize resource usage
    public static let conservative = Self(
        maxRetries: 2,
        initialDelay: 2.0,
        maxDelay: 10.0,
        backoffFactor: 2.0,
        jitterEnabled: false
    )
    
    /// No retry configuration (single attempt only)
    public static let noRetry = Self(
        maxRetries: 0,
        initialDelay: 0,
        maxDelay: 0,
        backoffFactor: 0,
        jitterEnabled: false
    )
    
    public init(
        maxRetries: Int,
        initialDelay: TimeInterval,
        maxDelay: TimeInterval,
        backoffFactor: Double,
        jitterEnabled: Bool
    ) {
        self.maxRetries = maxRetries
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.backoffFactor = backoffFactor
        self.jitterEnabled = jitterEnabled
    }
    
    /// Calculate the delay for a given retry attempt
    /// - Parameter attempt: The retry attempt number (0-based)
    /// - Returns: The delay in seconds before the next retry
    public func delay(for attempt: Int) -> TimeInterval {
        guard attempt >= 0 else { return initialDelay }
        
        // Calculate exponential backoff
        let baseDelay = initialDelay * pow(backoffFactor, Double(attempt))
        let clampedDelay = min(baseDelay, maxDelay)
        
        // Add jitter if enabled
        if jitterEnabled {
            let jitter = Double.random(in: 0.8...1.2)
            return clampedDelay * jitter
        }
        
        return clampedDelay
    }
}
