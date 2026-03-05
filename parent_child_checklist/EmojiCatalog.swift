//
//  EmojiCatalog.swift
//  parent_child_checklist
//
//  Created by George Gauci on 10/2/2026.
//


//
//  EmojiCatalog.swift
//  parent_child_checklist
//
//  Created by George Gauci on 10/2/2026.
//

import Foundation

/// Kid-friendly emoji catalog grouped by categories.
/// Use `EmojiCatalog.emojis(for:)` to retrieve a list per category.
/// `EmojiCatalog.allEmojis` returns a de-duplicated, sorted list of all emojis.
enum EmojiCatalog {

    enum Category: String, CaseIterable, Identifiable {
        case all = "All"
        case myEmojis = "My Emojis"   // Placeholder for user-added/custom emojis (if/when you wire it up)
        case morning = "Morning"
        case hygiene = "Hygiene"
        case school = "School"
        case chores = "Chores"
        case food = "Food"
        case pets = "Pets"
        case sports = "Sports"
        case time = "Time"
        case rewards = "Fun"
        case health = "Health"
        case outdoors = "Outdoors"

        var id: String { rawValue }
    }

    static func emojis(for category: Category) -> [String] {
        if category == .all { return allEmojis }
        return categoryMap[category] ?? allEmojis
    }

    /// De-duplicated + sorted flat list of all emojis from the category map.
    static let allEmojis: [String] = Array(Set(categoryMap.values.flatMap { $0 }))
        .sorted()

    // MARK: - Curated categories (adjust anytime)
    private static let categoryMap: [Category: [String]] = [
        .morning:  ["☀️","🌤️","🌙","⭐️","⏰","🛏️","🧸","🧦","👕","🪥"],
        .hygiene:  ["🪥","🧴","🧼","🧻","🧽","🪒","🚿","🛁","💧","🧹","🪮"],
        .school:   ["🎒","📚","📖","✏️","🖊️","🖍️","📐","📏","🧠","🧪","🔬","🧾","📅"],
        .chores:   ["✅","☑️","🧹","🧺","🧼","🧽","🗑️","♻️","🔧","🪛","🪣","🧤","🪠"],
        .food:     ["🍎","🍌","🍇","🍓","🥕","🥪","🍳","🥣","🍽️","🥛","🥃","🍞","🍕","🍪"],
        .pets:     ["🐶","🐱","🐰","🐹","🐦","🐠","🐢","🐴","🐾","🦄","🧶"],
        .sports:   ["⚽️","🏀","🏈","🎾","🏐","🏓","🥋","🏊‍♂️","🚴‍♂️","🛹","🏆","🥇"],
        .time:     ["⏱️","⏳","🕒","🗓️","📅","🔔","📌"],
        .rewards:  ["🎮","🎧","🎨","🎭","🎲","🎁","🍿","🍦","🎂","🎉","🥳","🚙","👑","🌈","✨","💎"],
        .health:   ["💊","🩹","🩺","❤️","🧘‍♂️","🥗","💧"],
        .outdoors: ["🌳","🌿","🍃","🌸","🏞️","⛰️","🌊","☔️","❄️","🔥","🚶‍♂️","🚲","📸"],
        .all:      []
    ]
}