import SwiftUI

#if canImport(UIKit)
import UIKit

/// Reports the system shake gesture into SwiftUI.
///
/// Implemented with a first-responder `UIViewController` rather than by
/// overriding `motionEnded` in a `UIWindow` extension: overriding an ObjC method
/// from a Swift extension is undefined behaviour, and the responder approach
/// also stops listening automatically when the view goes away.
struct ShakeDetector: UIViewControllerRepresentable {
    let onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeResponderViewController {
        let controller = ShakeResponderViewController()
        controller.onShake = onShake
        return controller
    }

    func updateUIViewController(_ controller: ShakeResponderViewController, context: Context) {
        controller.onShake = onShake
    }
}

final class ShakeResponderViewController: UIViewController {
    var onShake: (() -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        resignFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else {
            super.motionEnded(motion, with: event)
            return
        }
        onShake?()
    }
}

extension View {
    /// Runs `action` when the device is shaken while this view is on screen.
    func onDeviceShake(perform action: @escaping () -> Void) -> some View {
        background(ShakeDetector(onShake: action).allowsHitTesting(false))
    }
}

#else

extension View {
    func onDeviceShake(perform action: @escaping () -> Void) -> some View { self }
}

#endif
