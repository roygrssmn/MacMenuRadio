import AVFoundation
import Foundation

@main
struct PlayerRecoveryCheck {
    @MainActor
    static func main() async throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let file = temporary.appendingPathComponent("stations.json")
        try Data("""
        [{"id":"test","name":"Test","url":"https://127.0.0.1:9/unavailable"}]
        """.utf8).write(to: file)
        let radio = RadioPlayer(userFile: file)
        radio.volume = 0
        radio.play()
        let original = radio.player
        guard radio.wantsPlayback, let item = original.currentItem else {
            throw StationConfigurationError(message: "Play did not prepare a stream.")
        }

        NotificationCenter.default.post(name: AVPlayerItem.failedToPlayToEndTimeNotification, object: item)
        try await Task.sleep(for: .milliseconds(100))
        guard !radio.wantsPlayback, radio.errorMessage != nil, radio.player !== original else {
            throw StationConfigurationError(message: "Stream failure did not retire the old player.")
        }

        let stopped = radio.player
        radio.play()
        guard radio.wantsPlayback, radio.player !== original, radio.player !== stopped,
              radio.player.currentItem != nil, radio.player.volume == 0 else {
            throw StationConfigurationError(message: "Retry must use a fresh player and preserve volume.")
        }

        let retried = radio.player
        radio.stop()
        guard !radio.wantsPlayback, radio.player !== retried, radio.player.currentItem == nil else {
            throw StationConfigurationError(message: "Stop did not release the old player.")
        }
        print("PASS failed stream cleanup, fresh-player retry, preserved volume, and stop")
    }
}
