import AVFoundation
import Combine
import SwiftUI

@MainActor
final class RadioPlayer: ObservableObject {
    let stations: [Station]
    @Published private(set) var station: Station?
    @Published private(set) var wantsPlayback = false
    @Published private(set) var status = "Stopped"
    @Published private(set) var errorMessage: String?
    @Published var volume: Double {
        didSet {
            player.volume = Float(volume)
            UserDefaults.standard.set(volume, forKey: "volume")
        }
    }

    private(set) var player = AVPlayer()
    private var playbackObservation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var endObservation: NSObjectProtocol?
    private var failureObservation: NSObjectProtocol?
    private var connectionTimeout: Task<Void, Never>?

    init(userFile: URL = StationConfiguration.userFile) {
        let defaults = UserDefaults.standard
        var configurationError: String?
        do {
            stations = try StationConfiguration.load(userFile: userFile)
        } catch {
            stations = []
            configurationError = error.localizedDescription
        }
        station = stations.first { $0.id == defaults.string(forKey: "station") } ?? stations.first
        volume = min(1, max(0, defaults.object(forKey: "volume") as? Double ?? 0.5))
        if let configurationError {
            status = "Configuration error"
            errorMessage = configurationError
        }
        player.volume = Float(volume)
    }

    func select(_ newStation: Station) {
        guard station != newStation else { return }
        station = newStation
        UserDefaults.standard.set(newStation.id, forKey: "station")
        errorMessage = nil
        if wantsPlayback { play() }
        else { status = "Stopped" }
    }

    func play() {
        guard let station else { return }
        stop()
        wantsPlayback = true
        status = "Connecting…"
        errorMessage = nil
        playbackObservation = player.observe(\.timeControlStatus) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.updateStatus() }
        }
        let item = AVPlayerItem(url: station.url)
        itemObservation = item.observe(\.status) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.updateStatus() }
        }
        failureObservation = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: item, queue: .main
        ) { [weak self, weak item] _ in
            Task { @MainActor [weak self, weak item] in
                guard let self, let item, self.player.currentItem === item else { return }
                self.fail("The stream disconnected. Press Play to reconnect.")
            }
        }
        endObservation = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item, queue: .main
        ) { [weak self, weak item] _ in
            Task { @MainActor [weak self, weak item] in
                guard let self, let item, self.player.currentItem === item else { return }
                self.fail("The stream ended. Press Play to reconnect.")
            }
        }
        player.replaceCurrentItem(with: item)
        player.play()
        updateStatus()
    }

    func stop() {
        wantsPlayback = false
        connectionTimeout?.cancel()
        connectionTimeout = nil
        itemObservation = nil
        if let endObservation { NotificationCenter.default.removeObserver(endObservation) }
        if let failureObservation { NotificationCenter.default.removeObserver(failureObservation) }
        endObservation = nil
        failureObservation = nil
        playbackObservation = nil
        if player.status != .failed { player.pause() }
        // AVPlayer cannot recover once its own status becomes failed.
        // Release the old player so the next Play always starts with a fresh instance.
        player = AVPlayer()
        player.volume = Float(volume)
        status = "Stopped"
        errorMessage = nil
    }

    private func fail(_ message: String) {
        guard wantsPlayback else { return }
        stop()
        status = "Unable to play"
        errorMessage = message
    }

    private func updateStatus() {
        guard wantsPlayback else { return }
        if player.currentItem?.status == .failed || player.status == .failed {
            fail(player.currentItem?.error?.localizedDescription
                 ?? player.error?.localizedDescription
                 ?? "Could not open the stream. Check your connection and try again.")
            return
        }
        if player.timeControlStatus == .playing {
            status = "Playing"
            connectionTimeout?.cancel()
            connectionTimeout = nil
        } else {
            status = "Connecting…"
            guard connectionTimeout == nil else { return }
            connectionTimeout = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .seconds(30)) }
                catch { return }
                self?.fail("The connection timed out. Check your network and press Play to retry.")
            }
        }
    }
}

struct RadioControls: View {
    @ObservedObject var radio: RadioPlayer

    private var stationButtons: some View {
        VStack(spacing: 8) {
            ForEach(radio.stations) { station in
                Button { radio.select(station) } label: {
                    HStack {
                        Text(station.name)
                            .lineLimit(1)
                        Spacer()
                        if station == radio.station {
                            Image(systemName: "checkmark")
                        }
                    }
                    .frame(height: 24)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(station.name)
                .accessibilityLabel(station.name)
                .accessibilityValue(station == radio.station ? "Selected" : "")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("MacMenuRadio", systemImage: "radio")
                    .font(.headline)
                Spacer()
                Text(radio.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("playbackStatus")
            }

            if radio.stations.count > 5 {
                ScrollView { stationButtons }
                    .frame(height: 180)
            } else {
                stationButtons
            }

            Button {
                if radio.wantsPlayback { radio.stop() }
                else { radio.play() }
            } label: {
                Label(radio.wantsPlayback ? "Stop" : "Play",
                      systemImage: radio.wantsPlayback ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(radio.stations.isEmpty)

            HStack {
                Image(systemName: "speaker.fill")
                Slider(value: $radio.volume, in: 0...1)
                    .accessibilityLabel("Volume")
                Text("\(Int((radio.volume * 100).rounded()))%")
                    .monospacedDigit()
                    .frame(width: 42, alignment: .trailing)
            }

            if let errorMessage = radio.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            Divider()
            HStack {
                Text("Live radio")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit") {
                    radio.stop()
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(16)
        .frame(width: 290)
    }
}

#if !RADIO_DIAGNOSTICS
@main
struct MacMenuRadioApp: App {
    @StateObject private var radio = RadioPlayer()

    var body: some Scene {
        MenuBarExtra {
            RadioControls(radio: radio)
        } label: {
            Label("MacMenuRadio", systemImage: radio.wantsPlayback ? "radio.fill" : "radio")
        }
        .menuBarExtraStyle(.window)
    }
}
#endif
