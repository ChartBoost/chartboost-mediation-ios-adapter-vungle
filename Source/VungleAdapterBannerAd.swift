// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import VungleSDK

/// Chartboost Mediation Vungle adapter banner ad.
final class VungleAdapterBannerAd: VungleAdapterAd, PartnerAd {
    
    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    var inlineView: UIView? = UIView()
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        
        let bannerSize = vungleBannerSize(for: request.size)
        
        // If ad already loaded succeed immediately
        guard !(request.adm == nil && VungleSDK.shared().isAdCached(forPlacementID: request.partnerPlacement, with: bannerSize))
           && !(request.adm != nil && VungleSDK.shared().isAdCached(forPlacementID: request.partnerPlacement, adMarkup: request.adm, with: bannerSize))
        else {
            log(.loadSucceeded)
            completion(.success([:]))
            return
        }
        
        loadCompletion = completion
        
        // If ad loading already in progress wait for it to finish.
        // Vungle does not handle well loadPlacement() calls when a load for the same placement is already ongoing.
        // This may happen after a PartnerAd has been created and invalidated, since Vungle will keep the load going
        // even after Chartboost Mediation has discarded the PartnerAd instance.
        if router.isLoadInProgress(for: request) {
            // `loadCompletion` is executed when the ongoing load finishes leading to a `vungleAdPlayabilityUpdate()` call
            return
        }
        
        // Start loading
        router.recordLoadStart(for: request)
        do {
            if let adm = request.adm {
                try VungleSDK.shared().loadPlacement(withID: request.partnerPlacement, adMarkup: adm, with: bannerSize)
            } else {
                try VungleSDK.shared().loadPlacement(withID: request.partnerPlacement, with: bannerSize)
            }
        } catch {
            router.recordLoadEnd(for: request)
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
        /// NO-OP
    }
    
    /// Map Chartboost Mediation's banner sizes to the Vungle SDK's supported sizes.
    /// - Parameter size: The Chartboost Mediation's banner size.
    /// - Returns: The corresponding Vungle banner size.
    private func vungleBannerSize(for size: CGSize?) -> VungleAdSize {
        let height = size?.height ?? 50
        
        switch height {
        case 50...89:
            return VungleAdSize.banner
        case 90...249:
            return VungleAdSize.bannerLeaderboard
        default:
            return VungleAdSize.banner
        }
    }
    
    /// Get a CGSize corresponding to the given Vungle banner size.
    /// - Parameter size: The Vungle banner size.
    /// - Returns: The corresponding CGSize.
    private func cgSize(for size: VungleAdSize) -> CGSize {
        size == .banner
            ? CGSize(width: 320, height: 50)
            : CGSize(width: 728, height: 90)
    }
}

// MARK: - VungleSDKHBDelegate

extension VungleAdapterBannerAd {
    
    func vungleAdPlayabilityUpdate(_ isAdPlayable: Bool, placementID: String?, adMarkup: String?, error partnerError: Error?) {
        // Vungle will call this method several times, we only care about the first one to know if the load succeeded or not.
        guard loadCompletion != nil else {
            log(.delegateCallIgnored)
            return
        }
        if isAdPlayable {
            // Report load success
            DispatchQueue.main.async { [self] in
                do {
                    if let inlineView = inlineView {
                        // Set the frame for the container.
                        inlineView.frame = CGRect(origin: .zero, size: cgSize(for: vungleBannerSize(for: request.size)))
                        // Attach vungle view to the inlineView container.
                        try VungleSDK.shared().addAdView(to: inlineView, withOptions: [:], placementID: request.partnerPlacement)
                        log(.loadSucceeded)
                        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
                    } else {
                        // Fail if inlineView container is unavailable. This should never happen since it is set on load.
                        let error = error(.loadFailureNoInlineView, description: "Vungle adapter inlineView is nil.", error: partnerError)
                        log(.loadFailed(error))
                        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
                    }
                } catch {
                    // Fail to attach vungle view to inlineView container.
                    log(.loadFailed(error))
                    loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
                }
                
                loadCompletion = nil
            }
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
        log(.delegateCallIgnored)
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
        log(.delegateCallIgnored)
    }
    
    func vungleRewardUser(forPlacementID placementID: String?, adMarkup: String?) {
        log(.delegateCallIgnored)
    }
}
