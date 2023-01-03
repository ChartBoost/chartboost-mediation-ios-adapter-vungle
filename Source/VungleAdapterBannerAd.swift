//
//  VungleAdapterBannerAd.swift
//  ChartboostHeliumAdapterVungle
//
//  Created by Vu Chau on 9/16/22.
//

import Foundation
import HeliumSdk
import VungleSDK

/// Helium Vungle adapter banner ad.
final class VungleAdapterBannerAd: VungleAdapterAd, PartnerAd {
    
    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    lazy var inlineView: UIView? = UIView()
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        
        loadCompletion = completion
        
        let bannerSize = vungleBannerSize(for: request.size)
        
        // If ad already loaded succeed immediately
        guard !VungleSDK.shared().isAdCached(forPlacementID: request.partnerPlacement, adMarkup: request.adm, with: bannerSize) else {
            log(.loadSucceeded)
            completion(.success([:]))
            return
        }
        
        // Start loading
        do {
            try VungleSDK.shared().loadPlacement(withID: request.partnerPlacement, adMarkup: request.adm, with: bannerSize)
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
        /// NO-OP
    }
    
    /// Map Helium's banner sizes to the Vungle SDK's supported sizes.
    /// - Parameter size: The Helium's banner size.
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
                    let error = self.error(.loadFailureUnknown, error: error)
                    log(.loadFailed(error))
                    loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
                }
                
                loadCompletion = nil
            }
        } else {
            // Report load failure
            let error = error(.loadFailureUnknown, error: partnerError)
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
