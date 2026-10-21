import CoreAudioKit
import DrumCore
import SwiftUI

/// Apple's Bluetooth MIDI pairing screen. Bluetooth MIDI adapters do not show up in the iPad's Bluetooth settings:
/// they are paired from inside an app, after which they appear as ordinary MIDI sources.
struct BluetoothMIDIPairing: UIViewControllerRepresentable {
    let onDone: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let central = CABTMIDICentralViewController()
        central.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { _ in onDone() })
        central.navigationItem.title = L("MIDI Bluetooth", "Bluetooth MIDI")
        return UINavigationController(rootViewController: central)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}
}

/// Opens the pairing screen in a sheet.
struct BluetoothMIDIButton: View {
    @State private var pairing = false
    var body: some View {
        CardButton(L("Ghép nối MIDI Bluetooth", "Pair Bluetooth MIDI"), systemImage: "dot.radiowaves.left.and.right") { pairing = true }
            .sheet(isPresented: $pairing) { BluetoothMIDIPairing { pairing = false }.ignoresSafeArea() }
    }
}
