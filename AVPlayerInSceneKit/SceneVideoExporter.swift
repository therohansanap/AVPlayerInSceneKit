//
//  SceneVideoExporter.swift
//  AVPlayerInSceneKit
//
//  Created by Rohan Sanap on 28/09/20.
//

import Foundation
import SceneKit
import Metal
import MetalKit
import AVFoundation

class SceneVideoExporter: NSObject {

  let scene: SCNScene
  let renderer: SCNRenderer
  let duration: Double

  let device: MTLDevice
  let commandQueue: MTLCommandQueue
  let renderPassDescriptor: MTLRenderPassDescriptor

  let width: Int = 1080
  let height: Int = 1920

  let target: MTLTexture
  let videoRecorder: VideoRecorder

  let exportQueue = DispatchQueue(label: "exportQueue")
  let seekingQueue = DispatchQueue(label: "seekingQueue", attributes: .concurrent)

  let forLoopQueue = DispatchQueue(label: "forLoopQueue")

  let player1: AVPlayer
  let player2: AVPlayer

  let assetReader1: AVAssetReader
  let trackOutput1: AVAssetReaderTrackOutput

  let assetReader2: AVAssetReader
  let trackOutput2: AVAssetReaderTrackOutput

  let node1: SCNNode
  let node2: SCNNode

  var counter = 0

  lazy var img1: UIImage = {
    let url = Bundle.main.url(forResource: "img-1", withExtension: "JPG")!
    let data = try! Data(contentsOf: url)
    return UIImage(data: data)!
  }()

  lazy var img2: UIImage = {
    let url = Bundle.main.url(forResource: "img-2", withExtension: "JPG")!
    let data = try! Data(contentsOf: url)
    return UIImage(data: data)!
  }()

  var textureCache: CVMetalTextureCache?

  init(scene: SCNScene, duration: Double, player1: AVPlayer, player2: AVPlayer) {
    self.scene = scene
    self.duration = duration
    self.device = MTLCreateSystemDefaultDevice()!

    self.renderer = SCNRenderer(device: self.device, options: nil)
    self.renderer.scene = scene

    self.commandQueue = self.device.makeCommandQueue()!
    self.player1 = player1
    self.player2 = player2

    self.node1 = scene.rootNode.childNode(withName: "1", recursively: false)!
    self.node2 = scene.rootNode.childNode(withName: "2", recursively: false)!

    let outputSettings: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferMetalCompatibilityKey as String: true
    ]

    let asset1 = player1.currentItem!.asset
    self.assetReader1 = try! AVAssetReader(asset: asset1)
    let track1 = asset1.tracks(withMediaType: .video).first!
    self.trackOutput1 = AVAssetReaderTrackOutput(track: track1, outputSettings: outputSettings)
    self.assetReader1.add(self.trackOutput1)
    self.assetReader1.startReading()

    let asset2 = player2.currentItem!.asset
    self.assetReader2 = try! AVAssetReader(asset: asset2)
    let track2 = asset2.tracks(withMediaType: .video).first!
    self.trackOutput2 = AVAssetReaderTrackOutput(track: track2, outputSettings: outputSettings)
    self.assetReader2.add(self.trackOutput2)
    self.assetReader2.startReading()

    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm_srgb,
      width: width,
      height: height,
      mipmapped: false
    )
    textureDescriptor.usage = .renderTarget
    self.target = self.device.makeTexture(descriptor: textureDescriptor)!

    let renderPassDescriptor = MTLRenderPassDescriptor()
    renderPassDescriptor.colorAttachments[0].texture = self.target
    renderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderPassDescriptor.colorAttachments[0].storeAction = .store
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 1, blue: 0, alpha: 1)
    self.renderPassDescriptor = renderPassDescriptor

    self.videoRecorder = VideoRecorder(size: CGSize(width: width, height: height))!

    guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, self.device, nil, &self.textureCache) == kCVReturnSuccess
      else { fatalError() }

    super.init()
  }

  func exportVideo() {
    let date = Date()
    self.videoRecorder.startRecording()
    for time in stride(from: 0, to: self.duration, by: 0.04) {
      autoreleasepool {
        print("Iteration for: \(time)s")
        let nextTime = time

        let sampleBuffer1 = self.trackOutput1.copyNextSampleBuffer()
        let pixelBuffer1 = CMSampleBufferGetImageBuffer(sampleBuffer1!)! as CVPixelBuffer
        let texture1 = self.buildTextureForPixelBuffer(pixelBuffer1)!
        self.node1.geometry?.firstMaterial?.diffuse.contents = texture1

        let sampleBuffer2 = self.trackOutput2.copyNextSampleBuffer()
        let pixelBuffer2 = CMSampleBufferGetImageBuffer(sampleBuffer2!)! as CVPixelBuffer
        let texture2 = self.buildTextureForPixelBuffer(pixelBuffer2)!
        self.node2.geometry?.firstMaterial?.diffuse.contents = texture2

        print("All player seek invoked completion block")

        let group = DispatchGroup()
        group.enter()
        self.draw(target: self.target, time: nextTime) { (texture) in
          print("render pass complete")
          self.videoRecorder.writeFrame(forTexture: texture, time: nextTime)
          print("frame write complete")
          group.leave()
        }

        group.wait()
        print("-------------------------------")
      }
    }

    self.videoRecorder.endRecording {
      print("****************")
      printTime(since: date)
    }
  }

  func draw(target: MTLTexture, time: TimeInterval, completion: @escaping (MTLTexture) -> Void) {
    guard let commandBuffer = commandQueue.makeCommandBuffer(),
          let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
      return
    }

    commandEncoder.endEncoding()

    commandBuffer.addCompletedHandler { (handler) in
      completion(target)
    }

    renderer.sceneTime = time
    renderer.render(
      atTime: 0,
      viewport: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)),
      commandBuffer: commandBuffer,
      passDescriptor: self.renderPassDescriptor
    )

    commandBuffer.commit()
  }

  func drawIn(view: MTKView, time: TimeInterval, completion: @escaping (MTLTexture) -> Void) {
    print("================")
    print(time)
    view.device = self.device

    guard let drawable = view.currentDrawable,
          let commandBuffer = commandQueue.makeCommandBuffer(),
          let renderPassDescriptor = view.currentRenderPassDescriptor,
          let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
      return
    }

    commandEncoder.endEncoding()

    commandBuffer.addCompletedHandler { (_) in
      completion(drawable.texture)
    }

    let sampleBuffer1 = self.trackOutput1.copyNextSampleBuffer()!
    let pixelBuffer1 = CMSampleBufferGetImageBuffer(sampleBuffer1)! as CVPixelBuffer
    print(CMTimeGetSeconds(sampleBuffer1.presentationTimeStamp))
    let texture1 = self.buildTextureForPixelBuffer(pixelBuffer1)!
    self.node1.geometry?.firstMaterial?.diffuse.contents = texture1

    let sampleBuffer2 = self.trackOutput2.copyNextSampleBuffer()!
    let pixelBuffer2 = CMSampleBufferGetImageBuffer(sampleBuffer2)! as CVPixelBuffer
    print(CMTimeGetSeconds(sampleBuffer2.presentationTimeStamp))
    let texture2 = self.buildTextureForPixelBuffer(pixelBuffer2)!
    self.node2.geometry?.firstMaterial?.diffuse.contents = texture2

    self.renderer.sceneTime = time
    self.renderer.render(
      atTime: 0,
      viewport: CGRect(origin: .zero, size: view.drawableSize),
      commandBuffer: commandBuffer,
      passDescriptor: renderPassDescriptor
    )

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }

  func buildTextureForPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> MTLTexture? {
    let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
    let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)

    guard let metalTextureCache = textureCache else { return nil }

    var texture: CVMetalTexture?
    /*
     CVMetalTextureCacheCreateTextureFromImage is used to create a Metal texture (CVMetalTexture) from a
     CVPixelBuffer (or more precisely, a texture from the IOSurface that backs a CVPixelBuffer).

     Note: Calling CVMetalTextureCacheCreateTextureFromImage does not increment the use count of the
     IOSurface; only the CVPixelBuffer, and the CVMTLTexture own this IOSurface. At least one of the two
     must be retained until Metal rendering is done. The MTLCommandBuffer completion handler is good for
     this purpose.
     */
    let status =
      CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, metalTextureCache, pixelBuffer, nil,
                                                MTLPixelFormat.bgra8Unorm, width, height, 0, &texture)
    if status == kCVReturnSuccess {
      guard let textureFromImage = texture else { return nil }

      guard let metalTexture = CVMetalTextureGetTexture(textureFromImage) else { return nil }

      return metalTexture
    } else { return nil }
  }

}
