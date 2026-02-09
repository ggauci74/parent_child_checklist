import Foundation

enum AvatarCatalog {
    struct Avatar: Identifiable, Hashable {
        let id: String
        let displayName: String
        let emoji: String
    }

    /// Preset avatar list. Swap emojis for image assets later without changing stored IDs.
    static let all: [Avatar] = [
        Avatar(id: "astronaut", displayName: "Astronaut", emoji: "👩‍🚀"),
        Avatar(id: "ninja", displayName: "Ninja", emoji: "🥷"),
        Avatar(id: "cat", displayName: "Cat", emoji: "🐱"),
        Avatar(id: "dog", displayName: "Dog", emoji: "🐶"),
        Avatar(id: "unicorn", displayName: "Unicorn", emoji: "🦄"),
        Avatar(id: "robot", displayName: "Robot", emoji: "🤖")
    ]

    static func avatar(for id: String?) -> Avatar {
        guard let id, let found = all.first(where: { $0.id == id }) else {
            return Avatar(id: "__none__", displayName: "Not chosen yet", emoji: "👤")
        }
        return found
    }
}
