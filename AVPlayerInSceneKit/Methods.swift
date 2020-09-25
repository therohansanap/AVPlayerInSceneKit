//
//func addPeriodicTimeObserver() {
//  let time = CMTime(value: 1, timescale: 30)
//
//  timeObservationToken = player1.addPeriodicTimeObserver(forInterval: time, queue: .main) { [weak self] time in
//    print("observed")
//    guard let self = self else { return }
//    print("Status - \(self.player1.status.rawValue)")
//  }
//}
//
//func removePeriodicTimeObserver() {
//  if let timeObservationToken = timeObservationToken {
//    player1.removeTimeObserver(timeObservationToken)
//    self.timeObservationToken = nil
//  }
//}
//
//override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
//  guard context == &playerItem1Context else {
//    super.observeValue(
//      forKeyPath: keyPath,
//      of: object,
//      change: change,
//      context: context
//    )
//    return
//  }
//
//  if keyPath == #keyPath(AVPlayerItem.status) {
//    let status: AVPlayerItem.Status
//    if let statusNumber = change?[.newKey] as? NSNumber {
//      status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
//    }else {
//      status = .unknown
//    }
//
//    switch status {
//    case .readyToPlay: print("Ready")
//    case .failed: print("Failed")
//    case .unknown: print("Unknown")
//    @unknown default:
//      print("Future unknown")
//    }
//  }
//}
