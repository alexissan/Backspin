import Foundation
import Testing
@testable import BackspinCore

@Suite struct ColorValueTests {
    private func bytes(_ c: ColorValue) -> [Int] {
        [c.red, c.green, c.blue].map { Int(($0 * 255).rounded()) }
    }

    @Test(arguments: [
        ("#FF2DCC", [255, 45, 204]), ("#ff2dcc", [255, 45, 204]), ("#F2C", [255, 34, 204]),
        ("  #000000\n", [0, 0, 0]), ("rgb(255, 45, 204)", [255, 45, 204]), ("RGB(255,45,204)", [255, 45, 204]),
        ("rgb(255 45 204)", [255, 45, 204]), ("rgb(100%, 0%, 0%)", [255, 0, 0]),
        ("hsl(315, 100%, 59%)", [255, 46, 203]), ("hsl(0, 100%, 50%)", [255, 0, 0]),
        ("hsl(120deg 100% 25%)", [0, 128, 0]), ("hsl(-120, 100%, 50%)", [0, 0, 255]),
    ])
    func parses(_ input: String, _ expected: [Int]) throws {
        let color = try #require(ColorValue(input))
        #expect(bytes(color) == expected)
        #expect(color.alpha == 1)
    }

    @Test func parsesAlpha() throws {
        let short = try #require(ColorValue("#F008"))
        let long = try #require(ColorValue("#FF2DCC80"))
        let rgba = try #require(ColorValue("rgba(255,45,204,0.5)"))
        let slash = try #require(ColorValue("rgb(255 45 204 / 50%)"))
        let hsla = try #require(ColorValue("hsla(315, 100%, 59%, 0.25)"))
        let clamped = try #require(ColorValue("rgba(0,0,0,7)"))
        #expect(short.alpha == Double(0x88) / 255)
        #expect(abs(long.alpha - 128.0 / 255) < 1e-9)
        #expect(rgba.alpha == 0.5)
        #expect(slash.alpha == 0.5)
        #expect(hsla.alpha == 0.25)
        #expect(clamped.alpha == 1)
    }

    @Test(arguments: [
        "", "   ", "FF2DCC", "#", "#12", "#12345", "#1234567", "#123456789", "#GGGGGG", "red",
        "rgb(1,2)", "rgb(1,2,3,4,5)", "rgb(a,b,c)", "foo(1,2,3)", "rgb 1,2,3", "rgb(1,2,3", "hsl(a, 1%, 1%)", "#fff #000",
    ])
    func rejects(_ input: String) {
        #expect(ColorValue(input) == nil)
    }

    @Test func clampsOutOfRangeChannels() throws {
        let color = try #require(ColorValue("rgb(300, -5, 128)"))
        #expect(color.red == 1)
        #expect(color.green == 0)
    }

    @Test func formatsOpaque() {
        let c = ColorValue(red: 1, green: 45.0 / 255, blue: 204.0 / 255)
        #expect(c.hex == "#FF2DCC")
        #expect(c.rgb == "rgb(255, 45, 204)")
        #expect(c.hsl == "hsl(315, 100%, 59%)")
    }

    @Test func formatsTranslucent() {
        let c = ColorValue(red: 1, green: 45.0 / 255, blue: 204.0 / 255, alpha: 0.5)
        #expect(c.hex == "#FF2DCC80")
        #expect(c.rgb == "rgba(255, 45, 204, 0.5)")
        #expect(c.hsl == "hsla(315, 100%, 59%, 0.5)")
    }

    @Test func formatsGrayAndExtremes() {
        #expect(ColorValue(red: 0, green: 0, blue: 0).hsl == "hsl(0, 0%, 0%)")
        #expect(ColorValue(red: 1, green: 1, blue: 1).hsl == "hsl(0, 0%, 100%)")
        #expect(ColorValue(red: 1, green: 1, blue: 1).hex == "#FFFFFF")
        #expect(ColorValue(red: 0, green: 0, blue: 1).hsl == "hsl(240, 100%, 50%)")
    }

    @Test(arguments: ["#FF2DCC", "#00FF7F", "#123456", "#FFFFFF", "#000000", "#FF2DCC80", "#0A0B0CFF"])
    func hexRoundTrips(_ input: String) throws {
        let color = try #require(ColorValue(input))
        let expected = input.count == 9 && input.hasSuffix("FF") ? String(input.dropLast(2)) : input
        #expect(color.hex == expected)
    }

    @Test(arguments: ["#FF2DCC", "#00FF7F", "#123456", "#7F7F7F", "#FF2DCC80"])
    func rgbAndHslRoundTripWithinOneStep(_ input: String) throws {
        let original = try #require(ColorValue(input))
        let viaRGB = try #require(ColorValue(original.rgb))
        #expect(viaRGB.hex.prefix(7) == original.hex.prefix(7))
        let viaHSL = try #require(ColorValue(original.hsl))
        let a = bytes(original), b = bytes(viaHSL)
        for i in 0..<3 { #expect(abs(a[i] - b[i]) <= 3) }
    }

    @Test func lightness() throws {
        for hex in ["#FFFFFF", "#FFFF00"] {
            let color = try #require(ColorValue(hex))
            #expect(color.isLight)
        }
        for hex in ["#000000", "#0000FF", "#FF2DCC"] {
            let color = try #require(ColorValue(hex))
            #expect(!color.isLight)
        }
    }
}
