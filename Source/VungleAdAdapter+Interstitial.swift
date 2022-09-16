//
//  VungleAdAdapter+Interstitial.swift
//  ChartboostHeliumAdapterVungle
//
//  Created by Vu Chau on 9/16/22.
//

import Foundation
import HeliumSdk
import VungleSDK

/// Collection of interstitial-sepcific API implementations
extension VungleAdAdapter {
    /// Attempt to load a fullscreen ad.
    /// - Parameters:
    ///   - request: The relevant data associated with the current ad load call.
    func loadFullscreenAd(request: PartnerAdLoadRequest) {
        if (VungleAdapter.sdk?.isAdCached(forPlacementID: request.partnerPlacement, adMarkup: request.adm) == true) {
            loadCompletion?(.success(partnerAd)) ?? log(.loadResultIgnored)
            loadCompletion = nil
            
            return
        }
        
        do {
            try VungleAdapter.sdk?.loadPlacement(withID: request.partnerPlacement, adMarkup: request.adm)
        } catch {
            loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
            loadCompletion = nil
        }
    }
    
    /// Attempt to show the currently loaded fullscreen ad.
    /// - Parameter viewController: The ViewController for ad presentation purposes.
    func showFullscreenAd(viewController: UIViewController) {
        /// Vungle's ad playback must be done on the main thread.
        DispatchQueue.main.async {
            do {
                try VungleAdapter.sdk?.playAd(viewController, options: [:], placementID: self.request.partnerPlacement)
            } catch {
                self.showCompletion?(.failure(error)) ?? self.log(.showResultIgnored)
                self.showCompletion = nil
            }
        }
    }
}
