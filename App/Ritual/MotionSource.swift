import CoreMotion

/// Fused accelerometer + gyro at 100 Hz. `userAcceleration` already has gravity removed.
final class MotionSource {
    private let manager = CMMotionManager()

    func start(_ handler: @escaping (CMDeviceMotion) -> Void) {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 100
        // ponytail: delivered on the main queue so the session needs no locking.
        // Move to a background queue if the UI ever stutters during a shuffle.
        manager.startDeviceMotionUpdates(to: .main) { motion, _ in
            if let motion { handler(motion) }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
