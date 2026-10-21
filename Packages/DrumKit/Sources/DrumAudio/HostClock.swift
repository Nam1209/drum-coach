import Darwin
import Foundation

/// Single time base for clicks, MIDI and microphone: host time in seconds.
public enum HostClock {
    private static let timebase: (numer: Double, denom: Double) = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return (Double(info.numer), Double(info.denom))
    }()

    public static func seconds(fromHostTime t: UInt64) -> TimeInterval {
        Double(t) * timebase.numer / timebase.denom / 1_000_000_000
    }

    public static func hostTime(fromSeconds s: TimeInterval) -> UInt64 {
        UInt64((s * 1_000_000_000 * timebase.denom / timebase.numer).rounded())
    }

    public static func now() -> TimeInterval { seconds(fromHostTime: mach_absolute_time()) }
}
