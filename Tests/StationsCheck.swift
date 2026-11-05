import Foundation

@main
struct StationsCheck {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else {
            throw StationConfigurationError(message: message)
        }
    }

    static func main() throws {
        for path in CommandLine.arguments.dropFirst() {
            _ = try StationConfiguration.decode(Data(contentsOf: URL(fileURLWithPath: path)))
        }
        let sampleData = Data("""
        [{"id":"station-a","name":"Station A","url":"https://example.org/radio"},
         {"id":"station-b","name":"Station B","url":"https://example.org/hits"}]
        """.utf8)
        let stations = try StationConfiguration.decode(sampleData)
        try require(stations.count == 2, "Expected two fixture stations.")
        try require(stations[0].id == "station-a" && stations[1].id == "station-b", "Station IDs must be preserved when decoding.")

        let custom = Data("""
        [{"id":"custom","name":"My station","url":"https://example.org/live.m3u8"}]
        """.utf8)
        let customStations = try StationConfiguration.decode(custom)
        try require(customStations.first?.name == "My station", "Custom station was not loaded.")

        let invalidDocuments = [
            "[]",
            "not JSON",
            "[{}]",
            """
            [{"id":"same","name":"A","url":"https://example.org/a"},
             {"id":"same","name":"B","url":"https://example.org/b"}]
            """,
            """
            [{"id":" ","name":"A","url":"https://example.org/a"}]
            """,
            """
            [{"id":"a","name":" ","url":"https://example.org/a"}]
            """,
            """
            [{"id":"a","name":"A","url":"http://example.org/a"}]
            """,
            """
            [{"id":"a","name":"A","url":"/local/file"}]
            """
        ]
        for document in invalidDocuments {
            var rejected = false
            do { _ = try StationConfiguration.decode(Data(document.utf8)) }
            catch { rejected = true }
            try require(rejected, "Invalid station configuration was accepted.")
        }

        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let bundleURL = temporary.appendingPathComponent("Test.bundle")
        let resources = bundleURL.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try sampleData.write(to: resources.appendingPathComponent("stations.json"))
        try Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict><key>CFBundleIdentifier</key><string>local.radio.configcheck</string></dict></plist>
        """.utf8).write(to: bundleURL.appendingPathComponent("Contents/Info.plist"))
        guard let bundle = Bundle(url: bundleURL) else {
            throw StationConfigurationError(message: "Could not create test bundle.")
        }
        let overrideURL = temporary.appendingPathComponent("stations.json")
        let defaults = try StationConfiguration.load(bundle: bundle, userFile: overrideURL)
        try require(defaults == stations, "Missing override should use bundled defaults.")
        try custom.write(to: overrideURL)
        let overridden = try StationConfiguration.load(bundle: bundle, userFile: overrideURL)
        try require(overridden == customStations, "User configuration should replace bundled defaults.")
        try Data("invalid".utf8).write(to: overrideURL)
        var rejectedOverride = false
        do { _ = try StationConfiguration.load(bundle: bundle, userFile: overrideURL) }
        catch { rejectedOverride = true }
        try require(rejectedOverride, "Invalid override must be reported.")
        print("PASS default IDs, custom stations, invalid entries, bundled fallback, and user override behavior")
    }
}
