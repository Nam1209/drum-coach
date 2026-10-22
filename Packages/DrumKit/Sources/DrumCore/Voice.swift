/// A sound source on the kit, with its place on a percussion staff.
public enum Voice: String, Codable, CaseIterable, Sendable {
    case kick, snare, hiHat, hiHatOpen, hiHatPedal, tom1, tom2, floorTom, ride, crash, sideStick

    /// 0 = bottom staff line; each step is one line or space upward.
    public var staffStep: Int {
        switch self {
        case .hiHatPedal: -1
        case .kick: 1
        case .floorTom: 3
        case .snare, .sideStick: 5
        case .tom2: 6
        case .tom1: 7
        case .ride: 8
        case .hiHat, .hiHatOpen: 9
        case .crash: 10
        }
    }

    public var usesXNotehead: Bool {
        switch self {
        case .hiHat, .hiHatOpen, .hiHatPedal, .ride, .crash, .sideStick: true
        default: false
        }
    }

    /// Short uppercase label drawn on the staff.
    public var displayName: String { localizedName.uppercased() }

    /// Name in the app language (English drum terms kept in Vietnamese where drummers use them).
    public var localizedName: String {
        switch self {
        case .kick: L("Trống bass", "Bass drum")
        case .snare: "Snare"
        case .hiHat: "Hi-hat"
        case .hiHatOpen: L("Hi-hat mở", "Open hi-hat")
        case .hiHatPedal: L("Hi-hat chân", "Hi-hat foot")
        case .tom1: L("Tom cao", "High tom")
        case .tom2: L("Tom giữa", "Mid tom")
        case .floorTom: L("Tom sàn", "Floor tom")
        case .ride: "Ride"
        case .crash: "Crash"
        case .sideStick: L("Gõ vành", "Side stick")
        }
    }

    /// General MIDI percussion map; `overrides` (e.g. from MIDI learn) take precedence.
    public static func from(midiNote: UInt8, overrides: [UInt8: Voice] = [:]) -> Voice? {
        if let v = overrides[midiNote] { return v }
        switch midiNote {
        case 35, 36: return .kick
        case 37: return .sideStick
        case 38, 40: return .snare
        case 42, 22: return .hiHat            // 22: Roland hi-hat edge, closed
        case 44: return .hiHatPedal
        case 46, 26: return .hiHatOpen        // 26: Roland hi-hat edge, open
        case 41, 43, 58: return .floorTom     // 58: Roland floor-tom rim
        case 45, 47: return .tom2
        case 48, 50: return .tom1
        case 49, 52, 55, 57: return .crash
        case 51, 53, 59: return .ride
        default: return nil
        }
    }
}

public enum Hand: String, Codable, Sendable {
    case right = "R", left = "L", foot = "F"
}

public enum Articulation: String, Codable, Sendable {
    case normal, accent, ghost, flam, drag, buzz
}

extension Voice: CodingKeyRepresentable {}
extension Hand: CodingKeyRepresentable {}
