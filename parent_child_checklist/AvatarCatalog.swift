//
// AvatarCatalog.swift
// parent_child_checklist
//
// Static, bundled avatar catalog (image assets).
//

import Foundation

enum AvatarCatalog {
    struct Avatar: Identifiable, Hashable {
        let id: String               // stable ID stored in ChildProfile.avatarId
        let displayName: String      // shown in UI / VoiceOver
        let assetName: String        // name of the image in Assets.xcassets
    }

    /// Current catalog (4 to start; add 12 more later).
    static let all: [Avatar] = [
        Avatar(id: "lizard_scout",      displayName: "Lizard",   assetName: "avatar_lizard"),
        Avatar(id: "panda_hoodie",      displayName: "Panda",    assetName: "avatar_panda"),
        Avatar(id: "octopus_coral",     displayName: "Octopus",  assetName: "avatar_octopus"),
        Avatar(id: "ladybird_cityleaf", displayName: "Ladybird", assetName: "avatar_ladybird"),
    ]

    /// Returns a matching avatar or a neutral placeholder descriptor.
    static func avatar(for id: String?) -> Avatar {
        guard let id, let found = all.first(where: { $0.id == id }) else {
            // Placeholder record when no avatar is chosen yet
            return Avatar(id: "__none__", displayName: "Not chosen yet", assetName: "")
        }
        return found
    }
}
