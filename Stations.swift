import Foundation

struct Station: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let url: URL
}

struct StationConfigurationError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum StationConfiguration {
    static var userFile: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MacMenuRadio/stations.json")
    }

    static func load(bundle: Bundle = .main, userFile: URL = userFile) throws -> [Station] {
        let file: URL
        if FileManager.default.fileExists(atPath: userFile.path) {
            file = userFile
        } else if let bundledFile = bundle.url(forResource: "stations", withExtension: "json") {
            file = bundledFile
        } else {
            throw StationConfigurationError(message: "The bundled stations.json is missing. Rebuild the app.")
        }
        do {
            return try decode(Data(contentsOf: file))
        } catch {
            throw StationConfigurationError(message: "Could not load \(file.path). \(error.localizedDescription)")
        }
    }

    static func decode(_ data: Data) throws -> [Station] {
        let stations = try JSONDecoder().decode([Station].self, from: data)
        guard !stations.isEmpty else {
            throw StationConfigurationError(message: "Add at least one station.")
        }
        guard Set(stations.map(\.id)).count == stations.count else {
            throw StationConfigurationError(message: "Each station must have a unique id.")
        }
        for station in stations {
            guard !station.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !station.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw StationConfigurationError(message: "Every station needs a nonempty id and name.")
            }
            guard station.url.scheme?.lowercased() == "https",
                  let host = station.url.host, !host.isEmpty else {
                throw StationConfigurationError(message: "Station '\(station.name)' needs an absolute HTTPS stream URL.")
            }
        }
        return stations
    }
}
