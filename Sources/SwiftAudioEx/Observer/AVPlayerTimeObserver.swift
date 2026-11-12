//
//  AudioPlayerTimeEventObserver.swift
//  SwiftAudio
//
//  Created by Jørgen Henrichsen on 09/03/2018.
//  Copyright © 2018 Jørgen Henrichsen. All rights reserved.
//

import Foundation
import AVFoundation

protocol AVPlayerTimeObserverDelegate: AnyObject {
    func audioDidStart()
    func timeEvent(time: CMTime)
}

/**
 Class for observing time-based events from the AVPlayer
 */
class AVPlayerTimeObserver {
    
    /// The time to use as start boundary time. Cannot be zero.
    private static let startBoundaryTime: CMTime = CMTime(value: 1, timescale: 1000)
    
    var boundaryTimeStartObserverToken: Any?
    var periodicTimeObserverToken: Any?

    /// The player that created each token. AVPlayer.removeTimeObserver(_:) throws an
    /// NSInvalidArgumentException when it is given a token that another AVPlayer
    /// created, or one that was already removed, so a token is only ever handed back
    /// to the player that made it.
    private weak var boundaryTokenOwner: AVPlayer?
    private weak var periodicTokenOwner: AVPlayer?

    /// Register, unregister and the interval change can arrive from different queues.
    private let tokenLock = NSRecursiveLock()
    
    weak var player: AVPlayer? {
        willSet {
            unregisterForBoundaryTimeEvents()
            unregisterForPeriodicEvents()
        }
    }
    
    /// The frequence to receive periodic time events.
    /// Setting this to a new value will trigger a re-registering to the periodic events of the player.
    var periodicObserverTimeInterval: CMTime {
        didSet {
            if oldValue != periodicObserverTimeInterval {
                registerForPeriodicTimeEvents()
            }
        }
    }
    
    weak var delegate: AVPlayerTimeObserverDelegate?
    
    init(periodicObserverTimeInterval: CMTime) {
        self.periodicObserverTimeInterval = periodicObserverTimeInterval
    }
    
    deinit {
        unregisterForPeriodicEvents()
        unregisterForBoundaryTimeEvents()
    }
    
    /**
     Will register for the AVPlayer BoundaryTimeEvents, to trigger start and complete events.
     */
    func registerForBoundaryTimeEvents() {
        tokenLock.lock()
        defer { tokenLock.unlock() }
        guard let player = player else {
            return
        }
        unregisterForBoundaryTimeEvents()
        boundaryTokenOwner = player
        boundaryTimeStartObserverToken = player.addBoundaryTimeObserver(
            forTimes: [AVPlayerTimeObserver.startBoundaryTime].map({
                NSValue(time: $0)
            }),
            queue: nil,
            using: { [weak self] in
                self?.delegate?.audioDidStart()
            }
        )
    }
    
    /**
     Unregister from the boundary events of the player.
     */
    func unregisterForBoundaryTimeEvents() {
        tokenLock.lock()
        defer { tokenLock.unlock() }
        guard let token = boundaryTimeStartObserverToken else { return }
        // Forget the token first, so it can never be removed twice.
        boundaryTimeStartObserverToken = nil
        // The owner is gone: its observers went with it.
        boundaryTokenOwner?.removeTimeObserver(token)
        boundaryTokenOwner = nil
    }
    
    /**
     Start observing periodic time events.
     Will trigger unregisterForPeriodicEvents() first to avoid multiple subscriptions.
     */
    func registerForPeriodicTimeEvents() {
        tokenLock.lock()
        defer { tokenLock.unlock() }
        guard let player = player else {
            return
        }
        unregisterForPeriodicEvents()
        periodicTokenOwner = player
        periodicTimeObserverToken = player.addPeriodicTimeObserver(forInterval: periodicObserverTimeInterval, queue: nil, using: { [weak self] (time) in
            self?.delegate?.timeEvent(time: time)
        })
    }
    
    /**
     Unregister for periodic events.
     */
    func unregisterForPeriodicEvents() {
        tokenLock.lock()
        defer { tokenLock.unlock() }
        guard let token = periodicTimeObserverToken else { return }
        periodicTimeObserverToken = nil
        periodicTokenOwner?.removeTimeObserver(token)
        periodicTokenOwner = nil
    }
    
}
