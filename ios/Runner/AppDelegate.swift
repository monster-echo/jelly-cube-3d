import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    JellyAudioHost.shared.attach(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
  }
}

/// Offline PCM playback for the procedurally synthesised jelly sounds.
/// The sound design itself lives in Dart; this tiny host only schedules the
/// resulting 44.1 kHz mono float buffers on a small AVAudioPlayerNode pool.
final class JellyAudioHost {
  static let shared = JellyAudioHost()

  private let engine = AVAudioEngine()
  private let format = AVAudioFormat(
    standardFormatWithSampleRate: 44_100,
    channels: 1
  )!
  private var players: [AVAudioPlayerNode] = []
  private var channel: FlutterMethodChannel?
  private var configured = false
  private var nextPlayer = 0

  private init() {}

  func attach(messenger: FlutterBinaryMessenger) {
    guard channel == nil else { return }
    let methodChannel = FlutterMethodChannel(
      name: "tech.zhongbei/jellycube3d_audio",
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "init":
        self.configure()
        result(nil)
      case "play":
        guard
          let args = call.arguments as? [String: Any],
          let typed = args["pcm"] as? FlutterStandardTypedData
        else {
          result(FlutterError(code: "bad-audio", message: "Missing PCM", details: nil))
          return
        }
        let volume = (args["volume"] as? NSNumber)?.floatValue ?? 0.8
        self.play(typed.data, volume: volume)
        result(nil)
      case "dispose":
        self.stop()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    channel = methodChannel
  }

  private func configure() {
    guard !configured else { return }
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)
    } catch {
      // A silent route should never interrupt the toy.
    }

    for _ in 0..<6 {
      let player = AVAudioPlayerNode()
      engine.attach(player)
      engine.connect(player, to: engine.mainMixerNode, format: format)
      players.append(player)
    }
    engine.mainMixerNode.outputVolume = 0.92
    engine.prepare()
    do {
      try engine.start()
      configured = true
    } catch {
      configured = false
    }
  }

  private func play(_ data: Data, volume: Float) {
    if !configured {
      configure()
    }
    guard configured, engine.isRunning, !players.isEmpty else { return }
    let count = data.count / MemoryLayout<Float>.size
    guard count > 0 else { return }
    var samples = [Float](repeating: 0, count: count)
    _ = samples.withUnsafeMutableBytes { destination in
      data.copyBytes(to: destination)
    }
    guard
      let buffer = AVAudioPCMBuffer(
        pcmFormat: format,
        frameCapacity: AVAudioFrameCount(count)
      ),
      let channelData = buffer.floatChannelData
    else {
      return
    }
    buffer.frameLength = AVAudioFrameCount(count)
    samples.withUnsafeBufferPointer { source in
      guard let base = source.baseAddress else { return }
      channelData[0].update(from: base, count: count)
    }

    let player = players[nextPlayer % players.count]
    nextPlayer += 1
    if player.isPlaying {
      player.stop()
    }
    player.volume = max(0, min(1, volume))
    player.scheduleBuffer(buffer, completionHandler: nil)
    player.play()
  }

  private func stop() {
    for player in players {
      player.stop()
    }
    engine.stop()
    configured = false
  }
}
