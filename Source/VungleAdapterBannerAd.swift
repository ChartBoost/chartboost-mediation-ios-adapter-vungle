//
//  VungleAdapterBannerAd.swift
//  ChartboostHeliumAdapterVungle
//
//  Created by Vu Chau on 9/16/22.
//

import Foundation
import HeliumSdk
import VungleSDK

/// Helium Vungle banner ad adapter.
final class VungleAdapterBannerAd: VungleAdapterAd, PartnerAd, VungleRouterDelegate {
    var inlineView: UIView?
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        
        loadCompletion = completion
        
        let bannerSize = getVungleBannerSize(size: request.size)
        
        DispatchQueue.main.async {
            self.inlineView = UIView(frame: self.getFrameSize(size: bannerSize))
        }
        
        VungleRouter.requestAd(request: request, delegate: self, bannerSize: bannerSize)
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
    
    func vungleAdDidLoad() {
        DispatchQueue.main.async {
            do {
                if let inlineView = self.inlineView {
                    try VungleSDK.shared().addAdView(to: inlineView, withOptions: [:], placementID: self.request.partnerPlacement)
                    
                    self.log(.loadSucceeded)
                    self.loadCompletion?(.success([:])) ?? self.log(.loadResultIgnored)
                } else {
                    let error = self.error(.loadFailure, description: "Vungle inline View is nil.")
                    self.log(.loadFailed(error))
                    self.loadCompletion?(.failure(error)) ?? self.log(.loadResultIgnored)
                }
            } catch {
                self.log(.loadFailed(error))
                self.loadCompletion?(.failure(error)) ?? self.log(.loadResultIgnored)
            }
            
            self.loadCompletion = nil
        }
    }
    
    func vungleAdDidFailToLoad(error: Error?) {
        if let error = error {
            log(.loadFailed(error))
            loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        }
        
        loadCompletion = nil
    }
    
    func vungleAdWillShow(placementID: String?) {
        // NO-OP for banners
    }
    
    func vungleAdDidShow() {
        // NO-OP for banners
    }
    
    func vungleAdDidFailToShow(error: Error?) {
        // NO-OP for banners
    }
    
    func vungleAdViewed() {
        log(.didTrackImpression)
        delegate?.didTrackImpression(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    func vungleAdDidClick() {
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    func vungleAdWillLeaveApplication(placementID: String?) {
        // NO-OP for banners
    }
    
    func vungleAdWillClose(placementID: String?) {
        // NO-OP for banners
    }
    
    func vungleAdDidClose() {
        // NO-OP for banners
    }
    
    func vungleAdDidReward() {
        // NO-OP for banners
    }
}
