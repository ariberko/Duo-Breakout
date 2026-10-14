import Foundation

/// A brick layout. Every row has the same number of characters.
/// "." empty, "1"-"3" bricks that take that many hits, "#" steel (can't break).
struct LevelPattern {
    let rows: [String]

    var columns: Int { rows.first?.count ?? 0 }

    func bricks() -> [Brick] {
        var result: [Brick] = []
        for (row, line) in rows.enumerated() {
            for (column, char) in line.enumerated() {
                switch char {
                case "1", "2", "3":
                    result.append(Brick(column: column, row: row, hp: Int(String(char)) ?? 1, steel: false))
                case "#":
                    result.append(Brick(column: column, row: row, hp: 1, steel: true))
                default:
                    break
                }
            }
        }
        return result
    }
}

enum Levels {
    /// One player levels. After the last one they repeat, but faster.
    static let solo: [LevelPattern] = [
        LevelPattern(rows: [
            "1111111111",
            "1111111111",
            "2222222222",
            "1111111111",
            "1111111111",
        ]),
        LevelPattern(rows: [
            "....33....",
            "...2222...",
            "..111111..",
            ".11111111.",
            "1111111111",
            "2222222222",
        ]),
        LevelPattern(rows: [
            "....11....",
            "...1221...",
            "..123321..",
            ".12333321.",
            "..123321..",
            "...1221...",
            "....11....",
        ]),
        LevelPattern(rows: [
            "2222222222",
            "1#11##11#1",
            "1111111111",
            "..2....2..",
            "3333333333",
        ]),
        LevelPattern(rows: [
            "..1....1..",
            "...1..1...",
            "..222222..",
            ".22.22.22.",
            "3333333333",
            "1.111111.1",
            "1.1....1.1",
            "...11.11..",
        ]),
        LevelPattern(rows: [
            "#22222222#",
            "#21111112#",
            "#21.33.12#",
            "#21111112#",
            "#22222222#",
            "##......##",
        ]),
    ]

    /// Two player levels. They sit in the middle of the open screen, right on the fold.
    static let duo: [LevelPattern] = [
        LevelPattern(rows: [
            "1111111111",
            "2222222222",
            "3333333333",
            "2222222222",
            "1111111111",
        ]),
        LevelPattern(rows: [
            "1.2.3.3.2.",
            ".1.2.33.2.",
            "#..#11#..#",
            ".2.33.2.1.",
            ".2.3.3.2.1",
        ]),
        LevelPattern(rows: [
            "..222222..",
            ".21111112.",
            "2113##3112",
            ".21111112.",
            "..222222..",
        ]),
    ]

    static func solo(level: Int) -> LevelPattern {
        solo[(level - 1) % solo.count]
    }
}
