import Foundation

enum BundleConfigurationError: LocalizedError {
    case missingResource(String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let resource):
            "Missing configuration resource: \(resource).json"
        }
    }
}

enum BundleConfigurationLoader {
    static func decode<T: Decodable>(
        _ type: T.Type,
        resource: String,
        bundle: Bundle = .main
    ) throws -> T {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            throw BundleConfigurationError.missingResource(resource)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }
}
