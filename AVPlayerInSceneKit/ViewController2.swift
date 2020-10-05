import UIKit
import SceneKit
import MetalKit
import AVFoundation

class ViewController2: UIViewController {

  @IBOutlet weak var metalView: MTKView!
  @IBOutlet weak var playButton: UIButton!
  @IBOutlet weak var exportButton: UIButton!

  var sceneVideoExporter: SceneVideoExporter?

  var duration: TimeInterval!
  var scene: SCNScene!
  var player1: AVPlayer!
  var player2: AVPlayer!

  var currentTime: TimeInterval = -0.033

  override func viewDidLoad() {
    super.viewDidLoad()

    let tupple = setupScene()
    self.scene = tupple.scene
    self.player1 = tupple.player1
    self.player2 = tupple.player2
    self.duration = tupple.duration

    self.sceneVideoExporter = SceneVideoExporter(
      scene: self.scene,
      duration: self.duration,
      player1: self.player1,
      player2: self.player2
    )

    self.metalView.device = self.sceneVideoExporter!.device
  }

  @IBAction func playTapped(_ sender: UIButton) {
    self.currentTime += 0.033
    self.sceneVideoExporter?.drawIn(view: self.metalView, time: self.currentTime, completion: { (texture) in
      print(texture.width, texture.height)
      print(self.metalView.drawableSize)
    })
  }

  @IBAction func exportTapped(_ sender: UIButton) {
    self.sceneVideoExporter?.exportVideo()
  }

}
