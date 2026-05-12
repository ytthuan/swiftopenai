import Foundation

/// Options for web search in chat completions.
///
/// Configures how the model performs web searches to augment responses.
///
/// Usage:
/// ```swift
/// let options = WebSearchOptions(
///     searchContextSize: .medium,
///     userLocation: .init(approximate: .init(city: "Seattle", country: "US"))
/// )
/// ```
public struct WebSearchOptions: Codable, Sendable, Hashable {

    /// The amount of context to use from web search results.
    public var searchContextSize: SearchContextSize?

    /// The user's approximate location for search relevance.
    public var userLocation: UserLocation?

    public init(
        searchContextSize: SearchContextSize? = nil,
        userLocation: UserLocation? = nil
    ) {
        self.searchContextSize = searchContextSize
        self.userLocation = userLocation
    }

    // MARK: - SearchContextSize

    /// Amount of context from web search results.
    public enum SearchContextSize: String, Codable, Sendable, Hashable {
        case low
        case medium
        case high
    }

    // MARK: - UserLocation

    /// The user's location for search relevance.
    ///
    /// Wire format:
    /// ```json
    /// {"type": "approximate", "approximate": {"city": "Seattle", "country": "US"}}
    /// ```
    public struct UserLocation: Codable, Sendable, Hashable {
        /// The location type. Always `"approximate"`.
        public let type: String
        /// The approximate location details.
        public var approximate: Approximate

        public init(approximate: Approximate) {
            self.type = "approximate"
            self.approximate = approximate
        }

        private enum CodingKeys: String, CodingKey {
            case type, approximate
        }

        // MARK: - Approximate

        /// Approximate location details for web search.
        public struct Approximate: Codable, Sendable, Hashable {
            /// The city name.
            public var city: String?
            /// The ISO 3166-1 alpha-2 country code.
            public var country: String?
            /// The region or state name.
            public var region: String?
            /// The IANA timezone identifier (e.g. `"America/Los_Angeles"`).
            public var timezone: String?

            public init(
                city: String? = nil,
                country: String? = nil,
                region: String? = nil,
                timezone: String? = nil
            ) {
                self.city = city
                self.country = country
                self.region = region
                self.timezone = timezone
            }
        }
    }
}
