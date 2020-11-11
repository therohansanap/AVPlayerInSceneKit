import Foundation
import AVFoundation
import SceneKit

public func printTime(since date: Date) {
  let formatter = NumberFormatter()
  formatter.maximumFractionDigits = 5
  let number = NSNumber(value: Date().timeIntervalSince(date))
  print("Execution time: \(formatter.string(from: number)!)")
}

public func getQueueLabel() -> String {
  String(validatingUTF8: __dispatch_queue_get_label(nil))!
}

@discardableResult
public func printAndGetQueueLabel() -> String {
  let queueLabel = getQueueLabel()
  print(queueLabel)
  return queueLabel
}

public func setupScene() -> (scene: SCNScene, player1: AVPlayer, player2: AVPlayer, duration: TimeInterval) {
  let duration: TimeInterval = 5.0
  let scene = SCNScene()

  let plane1 = SCNPlane(width: 540, height: 960)
  let material1 = SCNMaterial()

  let asset1 = AVAsset(url: Bundle.main.url(forResource: "video1-25", withExtension: "mp4")!)
  let playerItem1 = AVPlayerItem(asset: asset1)
  let player1 = AVPlayer()
  player1.replaceCurrentItem(with: playerItem1)
  material1.diffuse.contents = player1

  plane1.materials = [material1]
  let videoNode1 = SCNNode(geometry: plane1)
  videoNode1.name = "1"
  videoNode1.position = SCNVector3(300, 0, 0)
  scene.rootNode.addChildNode(videoNode1)

  let plane2 = SCNPlane(width: 540, height: 960)
  let material2 = SCNMaterial()

  let asset2 = AVAsset(url: Bundle.main.url(forResource: "video-25", withExtension: "mp4")!)
  let playerItem2 = AVPlayerItem(asset: asset2)
  let player2 = AVPlayer()
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

  return (scene, player1, player2, duration)
}
