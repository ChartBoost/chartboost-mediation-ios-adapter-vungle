//
//  VungleRouter.swift
//  ChartboostHeliumAdapterVungle
//
//  Created by Vu Chau on 9/16/22.
//

import Foundation
import HeliumSdk
import VungleSDK

/// Helium Vungle Router for managing concurrent adapter instances.
final class VungleRouter: NSObject, VungleSDKHBDelegate, VungleSDKDelegate {
    /// Since it is possible to load multiple Vungle ads concurrently, we need to keep track of multiple delegates keyed by the Vungle placement.
    static var delegates: [String:VungleRouterDelegate] = [:]
    
    /// Since it is possible to load multiple Vungle ads concurrently, we need to track whether we have communicated the load result for a specific Vungle placement.
    static var loadResultsTracker: [String:Bool] = [:]
    
    static func requestAd(request: PartnerAdLoadRequest, delegate: VungleRouterDelegate, bannerSize: VungleAdSize?) {
        delegates[request.partnerPlacement] = delegate
        
        VungleSDK.shared().delegate = VungleRouter().self
        
        if (request.format == .banner) {
            if let bannerSize = bannerSize {
                requestBannerAd(request: request, delegate: delegate, bannerSize: bannerSize)
            }
        } else {
            requestFullscreenAd(request: request, delegate: delegate)
        }
    }
    
    static func requestBannerAd(request: PartnerAdLoadRequest, delegate: VungleRouterDelegate, bannerSize: VungleAdSize) {
        if (VungleSDK.shared().isAdCached(forPlacementID: request.partnerPlacement, adMarkup: request.adm, with: bannerSize) == true) {
            let targetDelegate = delegates[request.partnerPlacement]
            targetDelegate?.vungleAdDidLoad()
            
            loadResultsTracker[request.partnerPlacement] = true
            
            return
        }
        
        do {
            try VungleSDK.shared().loadPlacement(withID: request.partnerPlacement, adMarkup: request.adm, with: bannerSize)
        } catch {
            let targetDelegate = delegates[request.partnerPlacement]
            targetDelegate?.vungleAdDidFailToLoad(error: error)
            
            VungleRouter.delegates.removeValue(forKey: request.partnerPlacement)
            VungleRouter.loadResultsTracker.removeValue(forKey: request.partnerPlacement)
        }
    }
    
    static func requestFullscreenAd(request: PartnerAdLoadRequest, delegate: VungleRouterDelegate) {
        if (VungleSDK.shared().isAdCached(forPlacementID: request.partnerPlacement, adMarkup: request.adm) == true) {
            let targetDelegate = delegates[request.partnerPlacement]
            targetDelegate?.vungleAdDidLoad()
            
            loadResultsTracker[request.partnerPlacement] = true
            
            return
        }
        
        do {
            try VungleSDK.shared().loadPlacement(withID: request.partnerPlacement, adMarkup: request.adm)
        } catch {
            let targetDelegate = delegates[request.partnerPlacement]
            targetDelegate?.vungleAdDidFailToLoad(error: error)
            
            VungleRouter.delegates.removeValue(forKey: request.partnerPlacement)
            VungleRouter.loadResultsTracker.removeValue(forKey: request.partnerPlacement)
        }
    }
    
    static func showFullscreenAd(viewController: UIViewController, request: PartnerAdLoadRequest) {
        DispatchQueue.main.async {
            do {
                try VungleSDK.shared().playAd(viewController, options: [:], placementID: request.partnerPlacement)
            } catch {
                let targetDelegate = delegates[request.partnerPlacement]
                targetDelegate?.vungleAdDidFailToShow(error: error)
            }
        }
    }
    
    internal func vungleAdPlayabilityUpdate(_ isAdPlayable: Bool, placementID: String?, error: Error?) {
        onVungleAdPlayabilityUpdate(isAdPlayable, placementID: placementID, error: error)
    }
    
    internal func vungleAdPlayabilityUpdate(_ isAdPlayable: Bool, placementID: String?, adMarkup: String?, error: Error?) {
        onVungleAdPlayabilityUpdate(isAdPlayable, placementID: placementID, error: error)
    }
    
    internal func vungleWillShowAd(forPlacementID placementID: String?, adMarkup: String?) {
        onVungleWillShowAd(placementID: placementID)
    }
    
    internal func vungleWillShowAd(forPlacementID placementID: String?) {
        onVungleWillShowAd(placementID: placementID)
    }
    
    internal func vungleDidShowAd(forPlacementID placementID: String?, adMarkup: String?) {
        onVungleDidShowAd(placementID: placementID)
    }
    
    internal func vungleDidShowAd(forPlacementID placementID: String?) {
        onVungleDidShowAd(placementID: placementID)
    }
    
    internal func vungleAdViewed(forPlacementID placementID: String?, adMarkup: String?) {
        onVungleAdViewed(placementID: placementID)
    }
    
    internal func vungleAdViewed(forPlacement placementID: String) {
        onVungleAdViewed(placementID: placementID)
    }
    
    internal func vungleTrackClick(forPlacementID placementID: String?) {
        onVungleTrackClick(placementID: placementID)
    }
    
    internal func vungleTrackClick(forPlacementID placementID: String?, adMarkup: String?) {
        onVungleTrackClick(placementID: placementID)
    }
    
    internal func vungleWillLeaveApplication(forPlacementID placementID: String?) {
        onVungleWillLeaveApplication(placementID: placementID)
    }
    
    internal func vungleWillLeaveApplication(forPlacementID placementID: String?, adMarkup: String?) {
        onVungleWillLeaveApplication(placementID: placementID)
    }
    
    internal func vungleWillCloseAd(forPlacementID placementID: String) {
        onVungleWillCloseAd(placementID: placementID)
    }
    
    internal func vungleWillCloseAd(forPlacementID placementID: String?, adMarkup: String?) {
        onVungleWillCloseAd(placementID: placementID)
    }
    
    internal func vungleDidCloseAd(forPlacementID placementID: String?, adMarkup: String?) {
        onVungleDidCloseAd(placementID: placementID)
    }
    
    internal func vungleDidCloseAd(forPlacementID placementID: String) {
        onVungleDidCloseAd(placementID: placementID)
    }
    
    internal func vungleRewardUser(forPlacementID placementID: String?) {
        onVungleRewardUser(placementID: placementID)
    }
    
    internal func vungleRewardUser(forPlacementID placementID: String?, adMarkup: String?) {
        onVungleRewardUser(placementID: placementID)
    }
    
    private func onVungleAdPlayabilityUpdate(_ isAdPlayable: Bool, placementID: String?, error: Error?) {
        if let placementID = placementID {
            let targetDelegate = VungleRouter.delegates[placementID]
            let loadResultNotified = VungleRouter.loadResultsTracker[placementID]
            
            if (loadResultNotified == nil || loadResultNotified == false) {
                if (isAdPlayable) {
                    targetDelegate?.vungleAdDidLoad()
                } else {
                    targetDelegate?.vungleAdDidFailToLoad(error: error)
                    
                    VungleRouter.delegates.removeValue(forKey: placementID)
                    VungleRouter.loadResultsTracker.removeValue(forKey: placementID)
                }
                
                VungleRouter.loadResultsTracker[placementID] = true
            }
        }
    }
    
    private func onVungleWillShowAd(placementID: String?) {
        if let placementID = placementID {
            let targetDelegate = VungleRouter.delegates[placementID]
            targetDelegate?.vungleAdWillShow(placementID: placementID)
        }
    }
    
    private func onVungleDidShowAd(placementID: String?) {
        if let placementID = placementID {
            let targetDelegate = VungleRouter.delegates[placementID]
            targetDelegate?.vungleAdDidShow()
        }
    }
    
    private func onVungleAdViewed(placementID: String?) {
        if let placementID = placementID {
            let targetDelegate = VungleRouter.delegates[placementID]
            targetDelegate?.vungleAdViewed()
        }
    }
    
    private func onVungleTrackClick(placementID: String?) {
        if let placementID = placementID {
            let targetDelegate = VungleRouter.delegates[placementID]
            targetDelegate?.vungleAdDidClick()
        }
    }
    
    private func onVungleWillLeaveApplication(placementID: String?) {
        if let placementID = placementID {
            let targetDelegaet = VungleRouter.delegates[placementID]
            targetDelegaet?.vungleAdWillLeaveApplication(placementID: placementID)
        }
    }
    
    private func onVungleWillCloseAd(placementID: String?) {
        if let placementID = placementID {
            let targetDelegate = VungleRouter.delegates[placementID]
            targetDelegate?.vungleAdWillClose(placementID: placementID)
        }
    }
    
    private func onVungleDidCloseAd(placementID: String?) {
        if let placementID = placementID {
            let targetDelegate = VungleRouter.delegates[placementID]
            targetDelegate?.vungleAdDidClose()
            
            VungleRouter.delegates.removeValue(forKey: placementID)
            VungleRouter.loadResultsTracker.removeValue(forKey: placementID)
        }
    }
    
    private func onVungleRewardUser(placementID: String?) {
        if let placementID = placementID {
            let targetDelegate = VungleRouter.delegates[placementID]
            targetDelegate?.vungleAdDidReward()
        }
    }
}

protocol VungleRouterDelegate {
    func vungleAdDidLoad()
    func vungleAdDidFailToLoad(error: Error?)
    func vungleAdWillShow(placementID: String?)
    func vungleAdDidShow()
    func vungleAdDidFailToShow(error: Error?)
    func vungleAdViewed()
    func vungleAdDidClick()
    func vungleAdWillLeaveApplication(placementID: String?)
    func vungleAdWillClose(placementID: String?)
    func vungleAdDidClose()
    func vungleAdDidReward()
}
