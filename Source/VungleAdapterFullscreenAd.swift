//
//  VungleAdapterFullscreenAd.swift
//  ChartboostHeliumAdapterVungle
//
//  Created by Vu Chau on 9/16/22.
//

import Foundation
import HeliumSdk
import VungleSDK

/// Helium Vungle adapter fullscreen ad.
final class VungleAdapterFullscreenAd: VungleAdapterAd, PartnerAd {
    
    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    var inlineView: UIView? { nil }
        
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        
        // If ad already loaded succeed immediately
        guard !(request.adm == nil && VungleSDK.shared().isAdCached(forPlacementID: request.partnerPlacement))
           && !(request.adm != nil && VungleSDK.shared().isAdCached(forPlacementID: request.partnerPlacement, adMarkup: request.adm))
        else {
            log(.loadSucceeded)
            completion(.success([:]))
            return
        }
        
        // Start loading
        loadCompletion = completion
        do {
            if let adm = request.adm {
                try VungleSDK.shared().loadPlacement(withID: request.partnerPlacement, adMarkup: adm)
            } else {
                try VungleSDK.shared().loadPlacement(withID: request.partnerPlacement)
            }
        } catch {
            log(.loadFailed(error))
            completion(.failure(error))
            loadCompletion = nil
        }
    }
    
    /// Shows a loaded ad.
    /// It will never get called for banner ads. You may leave the implementation blank for that ad format.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.showStarted)
        
        showCompletion = completion
        
        // Show ad
        do {
            if let adm = request.adm {
                try VungleSDK.shared().playAd(viewController, options: [:], placementID: request.partnerPlacement, adMarkup: adm)
            } else {
                try VungleSDK.shared().playAd(viewController, options: [:], placementID: request.partnerPlacement)
            }
        } catch {
            log(.showFailed(error))
            completion(.failure(error))
            showCompletion = nil
        }
    }
}

// MARK: - VungleSDKHBDelegate

extension VungleAdapterFullscreenAd {
    
    func vungleAdPlayabilityUpdate(_ isAdPlayable: Bool, placementID: String?, adMarkup: String?, error partnerError: Error?) {
        // Vungle will call this method several times, we only care about the first one to know if the load succeeded or not.
        guard loadCompletion != nil else {
            log(.delegateCallIgnored)
            return
        }
        if isAdPlayable {
            // Report load success
            log(.loadSucceeded)
            loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
            loadCompletion = nil
        } else {
            // Report load failure
            let error = partnerError ?? error(.loadFailureUnknown)
            log(.loadFailed(error))
            loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
            loadCompletion = nil
        }
    }
    
    func vungleWillShowAd(forPlacementID placementID: String?, adMarkup: String?) {
        log(.delegateCallIgnored)
    }
    
    func vungleDidShowAd(forPlacementID placementID: String?, adMarkup: String?) {
        // Report show success
        log(.showSucceeded)
        showCompletion?(.success([:])) ?? log(.showResultIgnored)
        showCompletion = nil
    }
    
    func vungleAdViewed(forPlacementID placementID: String?, adMarkup: String?) {
        // Report impression tracked
        log(.didTrackImpression)
        delegate?.didTrackImpression(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    func vungleTrackClick(forPlacementID placementID: String?, adMarkup: String?) {
        // Report click
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    func vungleWillLeaveApplication(forPlacementID placementID: String?, adMarkup: String?) {
        log(.delegateCallIgnored)
    }
    
    func vungleWillCloseAd(forPlacementID placementID: String?, adMarkup: String?) {
        log(.delegateCallIgnored)
    }
    
    func vungleDidCloseAd(forPlacementID placementID: String?, adMarkup: String?) {
        // Report dismiss
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, details: [:], error: nil) ?? log(.delegateUnavailable)
    }
    
    func vungleRewardUser(forPlacementID placementID: String?, adMarkup: String?) {
        // Report reward
        log(.didReward)
        delegate?.didReward(self, details: [:]) ?? log(.delegateUnavailable)
    }
}
