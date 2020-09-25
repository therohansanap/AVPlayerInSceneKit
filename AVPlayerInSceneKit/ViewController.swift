import UIKit
import SceneKit
import AVKit

class ViewController: UIViewController {

  @IBOutlet weak var scnView: SCNView!
  @IBOutlet weak var seeker: UISlider!
  @IBOutlet weak var playButton: UIButton!
  @IBOutlet weak var exportButton: UIButton!

  var timeObservationToken: Any?

  let duration: Float = 5
  let scene = SCNScene()
  let player1 = AVPlayer()
  let player2 = AVPlayer()

  let asset1 = AVAsset(url: Bundle.main.url(forResource: "video1", withExtension: "mp4")!)
  let asset2 = AVAsset(url: Bundle.main.url(forResource: "video", withExtension: "mp4")!)
  let playerQueue = DispatchQueue(label: "avPlayerQueue", qos: .userInitiated, attributes: .concurrent)
  let seekQueue = DispatchQueue(label: "seekQueue", attributes: .concurrent)
  let playerGroup = DispatchGroup()

  var timer: Timer?

  lazy var displayLink: CADisplayLink = {
    let link = CADisplayLink(target: self, selector: #selector(displayLinkTrigger(_:)))
    link.preferredFramesPerSecond = 30
    link.add(to: .main, forMode: .common)
    link.isPaused = true
    return link
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    setupSeeker()
    setupScene()

    scnView.scene = scene
    scnView.isPlaying = false
    scnView.delegate = self
  }

  @IBAction func playTapped(_ sender: UIButton) {
//    let alertController = UIAlertController(title: "Title", message: "Some random message", preferredStyle: .alert)
//    let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
//    alertController.addAction(okAction)
//    present(alertController, animated: true, completion: nil)

    player1.play()
    player2.play()
    displayLink.isPaused = false
  }

  @IBAction func seeked(_ sender: UISlider) {
    scnView.sceneTime = TimeInterval(sender.value)
  }

  @IBAction func exportTapped(_ sender: UIButton) {
//    if displayLink.isPaused {
//      displayLink.isPaused = false
//    }

    self.timer = Timer.scheduledTimer(timeInterval: 0.033, target: self, selector: #selector(displayLinkTrigger(_:)), userInfo: nil, repeats: true)
  }

  private func setupSeeker() {
    seeker.minimumValue = 0
    seeker.maximumValue = duration
    seeker.value = 0
  }

  private func setupScene() {
    let plane1 = SCNPlane(width: 540, height: 960)
    let material1 = SCNMaterial()

    let playerItem1 = AVPlayerItem(asset: asset1)
    player1.replaceCurrentItem(with: playerItem1)
    material1.diffuse.contents = player1

    plane1.materials = [material1]
    let videoNode1 = SCNNode(geometry: plane1)
    videoNode1.name = "1"
    videoNode1.position = SCNVector3(300, 0, 0)
    scene.rootNode.addChildNode(videoNode1)

    let plane2 = SCNPlane(width: 540, height: 960)
    let material2 = SCNMaterial()

    let playerItem2 = AVPlayerItem(asset: asset2)
    player2.replaceCurrentItem(with: playerItem2)
    material2.diffuse.contents = player2

    plane2.materials = [material2]
    let videoNode2 = SCNNode(geometry: plane2)
    videoNode2.name = "2"
    videoNode2.position = SCNVector3(-300, 0, -100)
    scene.rootNode.addChildNode(videoNode2)

    let camera = SCNCamera()
    camera.zFar = 3000
    let cameraNode = SCNNode()
    cameraNode.camera = camera
    cameraNode.position = SCNVector3(0, 0, 1662.9135)
    scene.rootNode.addChildNode(cameraNode)

    scene.background.contents = UIColor.green

    let translate200Animation = CABasicAnimation(keyPath: "transform.translation.y")
    translate200Animation.fromValue = 0
    translate200Animation.toValue = 300
    translate200Animation.beginTime = 0
    translate200Animation.usesSceneTimeBase = true
    translate200Animation.duration = CFTimeInterval(duration)

    videoNode1.addAnimation(translate200Animation, forKey: nil)

    let translateNeg200Animation = CABasicAnimation(keyPath: "transform.translation.y")
    translateNeg200Animation.fromValue = 0
    translateNeg200Animation.toValue = -300
    translateNeg200Animation.beginTime = 0
    translateNeg200Animation.usesSceneTimeBase = true
    translateNeg200Animation.duration = CFTimeInterval(duration)

    videoNode2.addAnimation(translateNeg200Animation, forKey: nil)
  }

  @objc func displayLinkTrigger(_ sender: Any) {

    guard let timer = sender as? Timer else {
      if let link = sender as? CADisplayLink {
        scnView.sceneTime += link.duration
      }
      return
    }

    print("triggered")
    let date = Date()
    if scnView.sceneTime < Double(duration) {
      let nextTime = scnView.sceneTime + timer.timeInterval
      print("Next time = \(nextTime)")
      let mediaTime = CMTime(seconds: nextTime, preferredTimescale: 600)

      let group = DispatchGroup()
      group.enter()
      seekQueue.async {
        self.player1.seek(to: mediaTime, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
          print("player1 seeked - \(finished) - \(self.printAndGetQueueLabel())")
          group.leave()
        }
      }

      group.enter()
      seekQueue.async {
        self.player2.seek(to: mediaTime, toleranceBefore: .zero, toleranceAfter: .zero) { (finished) in
          print("player2 seeked - \(finished) - \(self.printAndGetQueueLabel())")
          group.leave()
        }
      }

      group.notify(queue: .main) {
        self.scnView.sceneTime = nextTime
        self.printTime(since: date)
      }
    }else {
      displayLink.isPaused = true
      timer.invalidate()
    }
  }

  private func printTime(since date: Date) {
    let formatter = NumberFormatter()
    formatter.maximumFractionDigits = 5
    let number = NSNumber(value: Date().timeIntervalSince(date))
    print("Execution time: \(formatter.string(from: number)!)")
  }

  @discardableResult
  private func printAndGetQueueLabel() -> String { String(validatingUTF8: __dispatch_queue_get_label(nil))! }

  func seekAllPlayers() {
    let date = Date()

//    let foo = String(validatingUTF8: __dispatch_queue_get_label(nil))
//    print(foo!)

    let mediaTime = CMTime(seconds: scnView.sceneTime, preferredTimescale: 600)
    let group = DispatchGroup()

    group.enter()
    playerQueue.async {
      self.player1.seek(to: mediaTime, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: { finished in
        print("player1 seeked - \(finished) - \(String(validatingUTF8: __dispatch_queue_get_label(nil))!)")
        self.playerQueue.async { group.leave() }
      })
    }

    group.enter()
    playerQueue.async {
      self.player2.seek(to: mediaTime, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: { finished in
        print("player2 seeked - \(finished) - \(String(validatingUTF8: __dispatch_queue_get_label(nil))!)")
        self.playerQueue.async { group.leave() }
      })
    }

    group.wait()

    printTime(since: date)
  }

}

extension ViewController: SCNSceneRendererDelegate {

  func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
    self.printAndGetQueueLabel()
  }

  func seekingComplete(startTime: Date) {
    printTime(since: startTime)
  }
}
