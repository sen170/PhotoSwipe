import AVFoundation

final class SoundManager {
    static let shared = SoundManager()

    private var players: [String: AVAudioPlayer] = [:]

    private init() {
        setupAudioSession()
        preloadSounds()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {}
    }

    private func preloadSounds() {
        players["delete"] = loadPlayer("Pop")
        players["keep"] = loadPlayer("Bottle")
        players["favorite"] = loadPlayer("Glass")
        players["classify"] = loadPlayer("Funk")

        for (_, player) in players {
            player.prepareToPlay()
        }
    }

    private func loadPlayer(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "aiff") else { return nil }
        return try? AVAudioPlayer(contentsOf: url)
    }

    func playDelete() {
        play("delete")
    }

    func playKeep() {
        play("keep")
    }

    func playFavorite() {
        play("favorite")
    }

    func playClassify() {
        play("classify")
    }

    private func play(_ name: String) {
        guard let player = players[name] else { return }
        player.currentTime = 0
        player.play()
    }
}
