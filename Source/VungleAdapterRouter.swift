//
//  VungleAdapterRouter.swift
//  ChartboostHeliumAdapterVungle
//
//  Created by Vu Chau on 9/16/22.
//

import Foundation
import HeliumSdk
import VungleSDK

/// Routes Vungle singleton delegate calls to the corresponding `PartnerAd` instances.
final class VungleAdapterRouter: NSObject, VungleSDKHBDelegate, VungleSDKDelegate {
    
    /// The Vungle partner adapter.
    let adapter: VungleAdapter
    
    init(adapter: VungleAdapter) {
        self.adapter = adapter
    }
}

// MARK: - VungleSDKHBDelegate

extension VungleAdapterRouter {
    
    func vungleAdPlayabilityUpdate(_ isAdPlayable: Bool, placementID: String?, adMarkup: String?, error partnerError: Error?) {
        ad(for: placementID)?.vungleAdPlayabilityUpdate?(isAdPlayable, placementID: placementID, adMarkup: adMarkup, error: partnerError)
    }
    
    func vungleWillShowAd(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID)?.vungleWillShowAd?(forPlacementID: placementID, adMarkup: adMarkup)
    }
    
    func vungleDidShowAd(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID)?.vungleDidShowAd?(forPlacementID: placementID, adMarkup: adMarkup)
    }
    
    func vungleAdViewed(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID)?.vungleAdViewed?(forPlacementID: placementID, adMarkup: adMarkup)
    }
    
    func vungleTrackClick(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID)?.vungleTrackClick?(forPlacementID: placementID, adMarkup: adMarkup)
    }
    
    func vungleWillLeaveApplication(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID)?.vungleWillLeaveApplication?(forPlacementID: placementID, adMarkup: adMarkup)
    }
    
    func vungleWillCloseAd(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID)?.vungleWillCloseAd?(forPlacementID: placementID, adMarkup: adMarkup)
    }
    
    func vungleDidCloseAd(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID)?.vungleDidCloseAd?(forPlacementID: placementID, adMarkup: adMarkup)
    }
    
    func vungleRewardUser(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID)?.vungleRewardUser?(forPlacementID: placementID, adMarkup: adMarkup)
    }
}

// MARK: - VungleSDKDelegate

extension VungleAdapterRouter {
    
    // Here we just forward calls to the corresponding header-bidding methods passing a nil ad markup, since the same logic applies for them.
    
    func vungleAdPlayabilityUpdate(_ isAdPlayable: Bool, placementID: String?, error: Error?) {
        vungleAdPlayabilityUpdate(isAdPlayable, placementID: placementID, adMarkup: nil, error: error)
    }
    
    func vungleWillShowAd(forPlacementID placementID: String?) {
        vungleWillShowAd(forPlacementID: placementID, adMarkup: nil)
    }
    
    func vungleDidShowAd(forPlacementID placementID: String?) {
        vungleDidShowAd(forPlacementID: placementID, adMarkup: nil)
    }
    
    func vungleAdViewed(forPlacement placementID: String) {
        vungleAdViewed(forPlacementID: placementID, adMarkup: nil)
    }
    
    func vungleTrackClick(forPlacementID placementID: String?) {
        vungleTrackClick(forPlacementID: placementID, adMarkup: nil)
    }
    
    func vungleWillLeaveApplication(forPlacementID placementID: String?) {
        vungleWillLeaveApplication(forPlacementID: placementID, adMarkup: nil)
    }
    
    func vungleWillCloseAd(forPlacementID placementID: String) {
        vungleWillCloseAd(forPlacementID: placementID, adMarkup: nil)
    }
    
    func vungleDidCloseAd(forPlacementID placementID: String) {
        vungleDidCloseAd(forPlacementID: placementID, adMarkup: nil)
    }
    
    func vungleRewardUser(forPlacementID placementID: String?) {
        vungleRewardUser(forPlacementID: placementID, adMarkup: nil)
    }
    
    // These two are not forwarded to any PartnerAd but to the VungleAdapter, who needs them to identify when Vungle initialization is finished.
    
    func vungleSDKDidInitialize() {
        adapter.vungleSDKDidInitialize()
    }
    
    func vungleSDKFailedToInitializeWithError(_ error: Error) {
        adapter.vungleSDKFailedToInitializeWithError(error)
    }
}

// MARK: - Helpers

private extension VungleAdapterRouter {
    
    /// Fetches a stored ad adapter and logs an error if none is found.
    func ad(for partnerPlacement: String?, functionName: StaticString = #function) -> VungleSDKHBDelegate? {
        guard let partnerPlacement = partnerPlacement else {
            adapter.log("\(functionName) call ignored with nil placementID.")
            return nil
        }
        guard let ad = adapter.storage.ads.first(where: { $0.request.partnerPlacement == partnerPlacement }) as? VungleAdapterAd else {
            adapter.log("\(functionName) call ignored with placementID \(partnerPlacement), no corresponding partner ad found.")
            return nil
        }
        return ad
    }
}
