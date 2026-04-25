import Foundation

enum KeyKind: Equatable {
    case code(key: String, label: String)       // e.g. ("a", "日") — 倉頡 radical key
    case symbol(String)                          // literal char to insert (e.g. "，")
    case delete
    case space
    case `return`
    case toggleSymbols                           // switch to number/symbol layout (123)
    case toggleMoreSymbols                       // switch to extended symbol layout (#+=)
    case toggleChinese                           // switch back to Chinese layout
    case toggleSimpTrad                          // cycle simplified/traditional
    case globe                                   // advanceToNextInputMode
}

struct KeyRow {
    let keys: [KeyKind]
}

enum KeyLayouts {
    // Native iOS 速成 layout (3 code rows + bottom control row)
    static let chineseRows: [KeyRow] = [
        KeyRow(keys: [
            .code(key: "q", label: "手"),
            .code(key: "w", label: "田"),
            .code(key: "e", label: "水"),
            .code(key: "r", label: "口"),
            .code(key: "t", label: "廿"),
            .code(key: "y", label: "卜"),
            .code(key: "u", label: "山"),
            .code(key: "i", label: "戈"),
            .code(key: "o", label: "人"),
            .code(key: "p", label: "心")
        ]),
        KeyRow(keys: [
            .code(key: "a", label: "日"),
            .code(key: "s", label: "尸"),
            .code(key: "d", label: "木"),
            .code(key: "f", label: "火"),
            .code(key: "g", label: "土"),
            .code(key: "h", label: "竹"),
            .code(key: "j", label: "十"),
            .code(key: "k", label: "大"),
            .code(key: "l", label: "中")
        ]),
        KeyRow(keys: [
            .code(key: "z", label: "重"),
            .code(key: "x", label: "難"),
            .code(key: "c", label: "金"),
            .code(key: "v", label: "女"),
            .code(key: "b", label: "月"),
            .code(key: "n", label: "弓"),
            .code(key: "m", label: "一"),
            .delete
        ]),
        KeyRow(keys: [
            .toggleSymbols,
            .globe,
            .space,
            .toggleSimpTrad,
            .return
        ])
    ]

    static let symbolRows: [KeyRow] = [
        KeyRow(keys: [
            .symbol("1"), .symbol("2"), .symbol("3"), .symbol("4"), .symbol("5"),
            .symbol("6"), .symbol("7"), .symbol("8"), .symbol("9"), .symbol("0")
        ]),
        KeyRow(keys: [
            .symbol("-"), .symbol("/"), .symbol(":"), .symbol(";"), .symbol("("),
            .symbol(")"), .symbol("$"), .symbol("@"), .symbol("「"), .symbol("」")
        ]),
        KeyRow(keys: [
            .toggleMoreSymbols,
            .symbol("。"), .symbol("，"), .symbol("、"), .symbol("？"),
            .symbol("！"), .symbol("．"), .delete
        ]),
        KeyRow(keys: [
            .toggleChinese, .globe, .space, .return
        ])
    ]

    static let moreSymbolRows: [KeyRow] = [
        KeyRow(keys: [
            .symbol("["), .symbol("]"), .symbol("{"), .symbol("}"), .symbol("#"),
            .symbol("%"), .symbol("^"), .symbol("*"), .symbol("+"), .symbol("=")
        ]),
        KeyRow(keys: [
            .symbol("_"), .symbol("\\"), .symbol("|"), .symbol("~"), .symbol("<"),
            .symbol(">"), .symbol("¥"), .symbol("€"), .symbol("£"), .symbol("·")
        ]),
        KeyRow(keys: [
            .toggleSymbols,
            .symbol("."), .symbol(","), .symbol("?"), .symbol("!"),
            .symbol("'"), .delete
        ]),
        KeyRow(keys: [
            .toggleChinese, .globe, .space, .return
        ])
    ]
}
