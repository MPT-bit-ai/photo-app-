import AudioToolbox
import Foundation

enum Buzz {
    // снимок сделан: одна долгая вибрация
    static func shutter() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    // фото отправлено: три подряд
    static func sent() {
        Buzz.pulse(2)
    }

    private static func pulse(_ n: Int) {
        guard n > 0 else { return }
        AudioServicesPlaySystemSoundWithCompletion(kSystemSoundID_Vibrate) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { Buzz.pulse(n - 1) }
        }
    }
}
