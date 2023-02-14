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
    lazy var inlineView: UIView? = UIView()
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        
        // If ad already loaded succeed immediately
        guard !adIsCachedByVungle else {
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
            try loadVungleAd()
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
    
    /// Indicates if the Vungle SDK has an ad already cached for this placement.
    /// Note that Vungle cannot load multiple ads for the same placement, so if `isAdCached` returns true we should not call
    /// `loadPlacement` again for this placement.
    private var adIsCachedByVungle: Bool {
        // Programmatic
        if let adm = request.adm {
            if let vungleAdSize = vungleAdSize {
                // Banner
                return VungleSDK.shared().isAdCached(forPlacementID: request.partnerPlacement, adMarkup: adm, with: vungleAdSize)
            } else {
                // MREC
                return VungleSDK.shared().isAdCached(forPlacementID: request.partnerPlacement, adMarkup: adm)
            }
        } else {
        // Non-programmatic
            if let vungleAdSize = vungleAdSize {
                // Banner
                return VungleSDK.shared().isAdCached(forPlacementID: request.partnerPlacement, with: vungleAdSize)
            } else {
                // MREC
                return VungleSDK.shared().isAdCached(forPlacementID: request.partnerPlacement)
            }
        }
    }
    
    private func loadVungleAd() throws {
        // Programmatic
        if let adm = request.adm {
            if let vungleAdSize = vungleAdSize {
                // Banner
                try VungleSDK.shared().loadPlacement(withID: request.partnerPlacement, adMarkup: adm, with: vungleAdSize)
            } else {
                // MREC
                try VungleSDK.shared().loadPlacement(withID: request.partnerPlacement, adMarkup: adm)
            }
        } else {
        // Non-programmatic
            if let vungleAdSize = vungleAdSize {
                // Banner
                try VungleSDK.shared().loadPlacement(withID: request.partnerPlacement, with: vungleAdSize)
            } else {
                // MREC
                try VungleSDK.shared().loadPlacement(withID: request.partnerPlacement)
            }
        }
    }
    
    /// Mapping of the request ad size to Vungle's ad size type. Nil means a MREC banner.
    private var vungleAdSize: VungleAdSize? {
        let size = request.size ?? IABStandardAdSize
        switch size {
        case IABMediumAdSize:
            // Note that Vungle MREC ads are not considered banners by Vungle and require using a different set of methods.
            // We return nil here to signify that this is not a Vungle banner, but an MREC ad.
            return nil
        case IABLeaderboardAdSize:
            return .bannerLeaderboard
        default:
            return .banner
        }
    }
    
    /// A size for the Vungle banner/MREC ad container compatible with that specific Vungle ad type.
    /// Note that this size must match Vungle's expectations or the ad rendering will fail.
    /// See Vungle's documentation on banner ads: https://support.vungle.com/hc/en-us/articles/360048572771
    /// See Vungle's documentation on MREC ads: https://support.vungle.com/hc/en-us/articles/360048079292
    private var adContainerSize: CGSize {
        switch vungleAdSize {
        case nil:
            // A nil vungleAdSize means the ad is not technically a Vungle banner, but a Vungle MREC ad.
            // MREC ads must always have a size 300x250 per Vungle's documentation.
            return IABMediumAdSize
        case .banner:
            return IABStandardAdSize
        case .bannerShort:
            return CGSize(width: 300, height: 50)
        case .bannerLeaderboard:
            return IABLeaderboardAdSize
        case .unknown:
            return IABStandardAdSize
        @unknown default:
            return IABStandardAdSize
        }
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
                        inlineView.frame = CGRect(origin: .zero, size: adContainerSize)
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
