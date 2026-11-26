import Foundation
import Testing
@testable import BackspinCore

@Suite struct ContentClassifierTests {
    @Test(arguments: [
        "https://example.com", "http://example.com/path?q=1#frag", "  https://example.com/a  \n",
        "ftp://files.example.com/x.zip", "mailto:me@example.com", "HTTPS://EXAMPLE.COM",
        "www.example.com/docs", "http://localhost:8080/x",
    ])
    func detectsLinks(_ input: String) {
        #expect(ContentClassifier.url(in: input) != nil)
        #expect(ContentClassifier.kind(of: input) == .link)
    }

    @Test(arguments: [
        "see https://x.com now", "https://", "example.com", "www.", "www.com", "mailto:", "mailto:nobody",
        "hello", "", "   ", "https://a.com https://b.com", "file:///tmp/x", "javascript:alert(1)",
    ])
    func rejectsNonLinks(_ input: String) {
        #expect(ContentClassifier.url(in: input) == nil)
        #expect(ContentClassifier.kind(of: input) != .link)
    }

    @Test func bareWwwBecomesHTTPS() {
        #expect(ContentClassifier.url(in: "www.example.com/a")?.absoluteString == "https://www.example.com/a")
        #expect(ContentClassifier.url(in: "https://example.com")?.scheme == "https")
    }

    @Test(arguments: ["#FF2DCC", "#fff", "rgb(255, 45, 204)", "hsl(315, 100%, 59%)", " #abcdef80 "])
    func detectsColors(_ input: String) {
        #expect(ContentClassifier.kind(of: input) == .color)
    }

    @Test(arguments: ["FF2DCC", "#GGG", "#12345", "red", "rgb(1,2)"])
    func nonColorsAreText(_ input: String) {
        #expect(ContentClassifier.kind(of: input) == .text)
    }

    @Test func plainTextKind() {
        #expect(ContentClassifier.kind(of: "Just a note to self") == .text)
    }

    @Test(arguments: [
        "func greet(name: String) -> String {\n    return \"Hi \\(name)\"\n}",
        "const x = 5;",
        "import Foundation",
        "def add(a, b):\n    return a + b",
        "let total = items.map { $0.price }.reduce(0, +)",
        "npm install && npm test",
        "$ ls -la",
        "git status",
        "swift build",
        "curl -s https://example.com | jq .",
        "ps aux | grep node",
        "{\"name\": \"Backspin\", \"version\": 1}",
        "[1, 2, 3, {\"a\": 1}]",
        "<div class=\"a\">hi</div>",
        "<?xml version=\"1.0\"?><a/>",
        "items.map(x => x * 2)",
        "class Foo {\n  var a = 1\n  var b = 2\n}",
    ])
    func detectsCode(_ input: String) {
        #expect(ContentClassifier.looksLikeCode(input))
    }

    @Test(arguments: [
        "Hello, how are you doing today?",
        "Let me know if that works for you.",
        "Meeting moved to 3pm tomorrow. Please bring the report and the slides.",
        "Dear Alex,\nThanks for the update.\nSpeak soon,\nSam",
        "Remember to buy milk, eggs and bread.",
        "", "   ",
        "I think the class starts at nine and we return after lunch.",
    ])
    func proseIsNotCode(_ input: String) {
        #expect(!ContentClassifier.looksLikeCode(input))
    }

    @Test func hashIsLowercaseHexSHA256() {
        #expect(ContentClassifier.contentHash(text: "abc")
            == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(ContentClassifier.contentHash(text: "") 
            == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        #expect(ContentClassifier.contentHash(data: Data("abc".utf8)) == ContentClassifier.contentHash(text: "abc"))
        #expect(ContentClassifier.contentHash(text: "a") != ContentClassifier.contentHash(text: "b"))
    }
}
