//
//  VungleAdAdapter+Banner.swift
//  ChartboostHeliumAdapterVungle
//
//  Created by Vu Chau on 9/16/22.
//

import Foundation
import HeliumSdk
import VungleSDK

/// Collection of banner-sepcific API implementations
extension VungleAdAdapter {
    /// Attempt to load a banner ad.
    /// - Parameters:
    ///   - viewController: The ViewController for ad presentation purposes.
    ///   - request: The relevant data associated with the current ad load call.
    func loadBannerAd(viewController: UIViewController?, request: PartnerAdLoadRequest) {
        let bannerSize = getVungleBannerSize(size: request.size)
        
        if (VungleAdapter.sdk?.isAdCached(forPlacementID: request.partnerPlacement, adMarkup: request.adm, with: bannerSize) == true) {
            loadCompletion?(.success(partnerAd)) ?? log(.loadResultIgnored)
            loadCompletion = nil
            
            return
        }
        
        do {
            try VungleAdapter.sdk?.loadPlacement(withID: request.partnerPlacement, adMarkup: request.adm, with: bannerSize)
        } catch {
            loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
            loadCompletion = nil
        }
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
}
