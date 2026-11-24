import Foundation

/// One key of the dial pad: the character it types and the letters printed under it.
struct KeypadKey: Hashable {
    let digit: String
    let letters: String

    static let rows: [[KeypadKey]] = [
        [KeypadKey(digit: "1", letters: ""), KeypadKey(digit: "2", letters: "ABC"), KeypadKey(digit: "3", letters: "DEF")],
        [KeypadKey(digit: "4", letters: "GHI"), KeypadKey(digit: "5", letters: "JKL"), KeypadKey(digit: "6", letters: "MNO")],
        [KeypadKey(digit: "7", letters: "PQRS"), KeypadKey(digit: "8", letters: "TUV"), KeypadKey(digit: "9", letters: "WXYZ")],
        [KeypadKey(digit: "*", letters: ""), KeypadKey(digit: "0", letters: "+"), KeypadKey(digit: "#", letters: "")],
    ]
}
