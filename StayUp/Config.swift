import Foundation

/// Change the Stay Up URL here — this is the only place you need to edit it.
enum Config {
    static let urlString = "https://itsurl.com/utilities/stay-up/start"

    /// Browser window width as a fraction of the screen's visible width (0.5 = half).
    static let browserWidthFraction: Double = 0.5

    static var url: URL {
        URL(string: urlString)!
    }
}
