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

  init(scene: SCNScene, duration: Double, player1: AVPlayer, player2: AVPlayer) {
    self.scene = scene
    self.duration = duration
    self.device = MTLCreateSystemDefaultDevice()!

    self.renderer = SCNRenderer(device: self.device, options: nil)
    self.renderer.scene = scene

    self.commandQueue = self.device.makeCommandQueue()!
    self.player1 = player1
    self.player2 = player2

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

    super.init()
  }

  func exportVideo() {
    self.forLoopQueue.async {
      let date = Date()
      self.videoRecorder.startRecording()
      for time in stride(from: 0, to: self.duration, by: 0.033) {
        print("Iteration for: \(time)s")
        let nextTime = time
        let nextMediaTime = CMTime(seconds: nextTime, preferredTimescale: 600)

        let group = DispatchGroup()

        group.enter()
        self.seekingQueue.async {
          self.player1.seek(to: nextMediaTime, toleranceBefore: .zero, toleranceAfter: .zero) { (finished) in
            print("Player1 seek complete - \(finished)")
            self.seekingQueue.async { group.leave() }
          }
        }

        group.enter()
        self.seekingQueue.async {
          self.player2.seek(to: nextMediaTime, toleranceBefore: .zero, toleranceAfter: .zero) { (finished) in
            print("Player2 seek complete - \(finished)")
            self.seekingQueue.async { group.leave() }
          }
        }

        group.wait()

        print("All player seek invoked completion block")

        group.enter()
        self.exportQueue.async {
          self.draw(target: self.target, time: nextTime) { (texture) in
            print("render pass complete")
            self.videoRecorder.writeFrame(forTexture: texture, time: nextTime)
            print("frame write complete")
            group.leave()
          }
        }

        group.wait()
        print("-------------------------------")
      }

      self.videoRecorder.endRecording {
        print("****************")
        printTime(since: date)
      }
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
    view.device = self.device

    guard let drawable = view.currentDrawable,
          let commandBuffer = commandQueue.makeCommandBuffer(),
          let renderPassDescriptor = view.currentRenderPassDescriptor else {
      return
    }

    commandBuffer.addCompletedHandler { (_) in
      completion(drawable.texture)
    }

    let mediaTime = CMTime(seconds: time, preferredTimescale: 600)
    self.forLoopQueue.sync {
      let group = DispatchGroup()

      group.enter()
      self.seekingQueue.async {
        self.player1.seek(to: mediaTime, toleranceBefore: .zero, toleranceAfter: .zero) { (finished) in
          print("Player 1 seeked - \(finished)")
          self.seekingQueue.async { group.leave() }
        }
      }

      group.enter()
      self.seekingQueue.async {
        self.player2.seek(to: mediaTime, toleranceBefore: .zero, toleranceAfter: .zero) { (finished) in
          print("Player 2 seeked - \(finished)")
          self.seekingQueue.async { group.leave() }
        }
      }

      group.wait()
    }

    renderer.sceneTime = time
    renderer.render(
      atTime: 0,
      viewport: CGRect(origin: .zero, size: view.drawableSize),
      commandBuffer: commandBuffer,
      passDescriptor: renderPassDescriptor
    )

    commandBuffer.present(drawable)
    commandBuffer.commit()
  }

}
