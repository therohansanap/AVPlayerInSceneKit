import UIKit
import SceneKit
import AVKit

class ViewController: UIViewController {

  @IBOutlet weak var scnView: SCNView!
  @IBOutlet weak var playButton: UIButton!
  @IBOutlet weak var exportButton: UIButton!

  var timeObservationToken: Any?

  var duration: TimeInterval!
  var scene: SCNScene!
  var player1: AVPlayer!
  var player2: AVPlayer!

  let playerQueue = DispatchQueue(label: "avPlayerQueue", qos: .userInitiated, attributes: .concurrent)
  let seekQueue = DispatchQueue(label: "seekQueue", attributes: .concurrent)

  var timer: Timer?

  lazy var displayLink: CADisplayLink = {
    let link = CADisplayLink(target: self, selector: #selector(trigger(_:)))
    link.preferredFramesPerSecond = 30
    link.add(to: .main, forMode: .common)
    link.isPaused = true
    return link
  }()

  var videoRecorder: VideoRecorder?

  override func viewDidLoad() {
    super.viewDidLoad()

    let tupple = setupScene()
    self.scene = tupple.scene
    self.player1 = tupple.player1
    self.player2 = tupple.player2
    self.duration = tupple.duration

    scnView.scene = scene
  }

  @IBAction func playTapped(_ sender: UIButton) {
    if let timer = self.timer {
      timer.invalidate()
    }else {
      self.timer = Timer.scheduledTimer(
        timeInterval: 0.0333333333333333,
        target: self,
        selector: #selector(trigger(_:)),
        userInfo: nil,
        repeats: true
      )
    }
  }

  @IBAction func exportTapped(_ sender: UIButton) {
    let exporter = SceneVideoExporter(scene: scene, duration: Double(duration), player1: player1, player2: player2)
    exporter.exportVideo()
  }

  @objc func trigger(_ sender: Any) {
    print("triggered")
    var timer: Timer?
    var displayLink: CADisplayLink?
    let nextTime: Double

    if let timerUnwrapped = sender as? Timer {
      timer = timerUnwrapped
      nextTime = scnView.sceneTime + timerUnwrapped.timeInterval
    }else if let displayLinkUnwrapped = sender as? CADisplayLink {
      displayLink = displayLinkUnwrapped
      nextTime = scnView.sceneTime + (displayLinkUnwrapped.targetTimestamp - displayLinkUnwrapped.timestamp)
    }else {
      print("Exit")
      return
    }

    guard scnView.sceneTime < Double(duration) else {
      timer?.invalidate()
      displayLink?.isPaused = true
      print("duration exit")
      return
    }

    let date = Date()
    print("Next time = \(nextTime)")
    let mediaTime = CMTime(seconds: nextTime, preferredTimescale: 600)

    let group = DispatchGroup()
    group.enter()
    seekQueue.async {
      self.player1.seek(to: mediaTime, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
        print("player1 seeked - \(finished) - \(printAndGetQueueLabel())")
        group.leave()
      }
    }

    group.enter()
    seekQueue.async {
      self.player2.seek(to: mediaTime, toleranceBefore: .zero, toleranceAfter: .zero) { (finished) in
        print("player2 seeked - \(finished) - \(printAndGetQueueLabel())")
        group.leave()
      }
    }

    group.notify(queue: .main) {
      self.scnView.sceneTime = nextTime
      printTime(since: date)
    }
  }
}
