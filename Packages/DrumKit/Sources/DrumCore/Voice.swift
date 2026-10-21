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

    public var displayName: String {
        switch self {
        case .kick: "KICK"
        case .snare: "SNARE"
        case .hiHat: "HI-HAT"
        case .hiHatOpen: "OPEN HI-HAT"
        case .hiHatPedal: "HI-HAT FOOT"
        case .tom1: "TOM 1"
        case .tom2: "TOM 2"
        case .floorTom: "FLOOR TOM"
        case .ride: "RIDE"
        case .crash: "CRASH"
        case .sideStick: "SIDE STICK"
        }
    }

    /// General MIDI percussion map; `overrides` (e.g. from MIDI learn) take precedence.
    public static func from(midiNote: UInt8, overrides: [UInt8: Voice] = [:]) -> Voice? {
        if let v = overrides[midiNote] { return v }
        switch midiNote {
        case 35, 36: return .kick
        case 37: return .sideStick
        case 38, 40: return .snare
        case 42: return .hiHat
        case 44: return .hiHatPedal
        case 46: return .hiHatOpen
        case 41, 43: return .floorTom
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
