//
//  VungleAdapterBannerAd.swift
//  ChartboostHeliumAdapterVungle
//
//  Created by Vu Chau on 9/16/22.
//

import Foundation
import HeliumSdk
import VungleSDK

final class VungleAdapterBannerAd: VungleAdapterAd, PartnerAd, VungleSDKHBDelegate, VungleSDKDelegate {
    var inlineView: UIView?

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        
        loadCompletion = completion
        
        let bannerSize = getVungleBannerSize(size: request.size)
        inlineView = UIView(frame: getFrameSize(size: bannerSize))
        
        if (VungleAdapter.sdk.isAdCached(forPlacementID: request.partnerPlacement, adMarkup: request.adm, with: bannerSize) == true) {
            loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
            loadCompletion = nil
            
            return
        }
        
        do {
            try VungleAdapter.sdk.loadPlacement(withID: request.partnerPlacement, adMarkup: request.adm, with: bannerSize)
        } catch {
            loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
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
    func getVungleBannerSize(size: CGSize?) -> VungleAdSize {
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
    
    /// Get a CGRect for the container UIView for the given Vungle banner size.
    /// - Parameter size: The Vungle banner size.
    /// - Returns: The corresponding CGRect.
    func getFrameSize(size: VungleAdSize) -> CGRect {
        if (size == .banner) {
            return CGRect(x: 0, y: 0, width: 320, height: 50)
        } else {
            return CGRect(x: 0, y: 0, width: 728, height: 90)
        }
    }
    
    // MARK: - VungleSDKDelegate
    
    internal func vungleAdPlayabilityUpdate(_ isAdPlayable: Bool, placementID: String?, error: Error?) {
        /// Banners are shown upon load
        if (request.format == .banner) {
            do {
                if let inlineView = self.inlineView {
                    try VungleAdapter.sdk.addAdView(to: inlineView, withOptions: [:], placementID: request.partnerPlacement)
                    
                    log(.loadSucceeded)
                    loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
                } else {
                    let error = self.error(.loadFailure, description: "Vungle inline View is nil.")
                    log(.loadFailed(error))
                    loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
                }
            } catch {
                log(.loadFailed(error))
                loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
            }
        } else {
            loadCompletion?(isAdPlayable
                            ? .success([:])
                            : .failure(error ?? self.error(.loadFailure))) ?? log(.loadResultIgnored)
        }
        
        loadCompletion = nil
    }
    
    internal func vungleWillShowAd(forPlacementID placementID: String?) {
        log(.custom("vungleWillShowAdForPlacementID \(String(describing: placementID))"))
    }
    
    internal func vungleDidShowAd(forPlacementID placementID: String?) {
        log(.showSucceeded)
        showCompletion?(.success([:])) ?? log(.showResultIgnored)
        showCompletion = nil
    }
    
    internal func vungleAdViewed(forPlacement placementID: String) {
        log(.didTrackImpression)
        delegate?.didTrackImpression(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    internal func vungleWillCloseAd(forPlacementID placementID: String) {
        log("vungleWillCloseAdForPlacementID \(placementID)")
    }
    
    internal func vungleDidCloseAd(forPlacementID placementID: String) {
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, details: [:], error: nil) ?? log(.delegateUnavailable)
    }
    
    internal func vungleTrackClick(forPlacementID placementID: String?) {
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    internal func vungleWillLeaveApplication(forPlacementID placementID: String?) {
        log("vungleWillLeaveApplicationForPlacementID \(String(describing: placementID))")
    }
    
    internal func vungleRewardUser(forPlacementID placementID: String?) {
        log(.didReward)
        delegate?.didReward(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    // MARK: - VungleSDKHBDelegate
    
    internal func vungleAdPlayabilityUpdate(_ isAdPlayable: Bool, placementID: String?, adMarkup: String?, error: Error?) {
        /// Banners are shown upon load
        if (request.format == .banner) {
            do {
                if let inlineView = self.inlineView {
                    try VungleAdapter.sdk.addAdView(to: inlineView, withOptions: [:], placementID: request.partnerPlacement)
                    loadCompletion?(.success([:]))
                } else {
                    loadCompletion?(.failure(self.error(.loadFailure, description: "Vungle inline View is nil.")))
                }
            } catch {
                loadCompletion?(.failure(error))
            }
        } else {
            loadCompletion?(isAdPlayable
                            ? .success([:])
                            : .failure(error ?? self.error(.loadFailure))) ?? log(.loadResultIgnored)
        }
        
        loadCompletion = nil
    }
    
    internal func vungleWillShowAd(forPlacementID placementID: String?, adMarkup: String?) {
        log("vungleWillShowAdForPlacementID \(String(describing: placementID))")
    }
    
    internal func vungleDidShowAd(forPlacementID placementID: String?, adMarkup: String?) {
        showCompletion?(.success([:])) ?? log(.showResultIgnored)
        showCompletion = nil
    }
    
    internal func vungleAdViewed(forPlacementID placementID: String?, adMarkup: String?) {
        log("vungleAdViewedForPlacementID \(String(describing: placementID))")
    }
    
    internal func vungleWillCloseAd(forPlacementID placementID: String?, adMarkup: String?) {
        log("vungleWillCloseAdForPlacementID \(String(describing: placementID))")
    }
    
    internal func vungleDidCloseAd(forPlacementID placementID: String?, adMarkup: String?) {
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, details: [:], error: nil) ?? log(.delegateUnavailable)
    }
    
    internal func vungleTrackClick(forPlacementID placementID: String?, adMarkup: String?) {
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    internal func vungleWillLeaveApplication(forPlacementID placementID: String?, adMarkup: String?) {
        log("vungleWillLeaveApplicationForPlacementID \(String(describing: placementID))")
    }
    
    internal func vungleRewardUser(forPlacementID placementID: String?, adMarkup: String?) {
        log(.didReward)
        delegate?.didReward(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    internal func invalidateObjects(forPlacementID placementID: String?) {
        log("invalidateObjectsForPlacementID \(String(describing: placementID))")
    }
}
