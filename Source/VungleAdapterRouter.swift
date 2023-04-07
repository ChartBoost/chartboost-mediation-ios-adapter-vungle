// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import VungleSDK

/// Routes Vungle singleton delegate calls to the corresponding `PartnerAd` instances.
final class VungleAdapterRouter: NSObject, VungleSDKHBDelegate, VungleSDKDelegate {
    
    /// The Vungle partner adapter.
    let adapter: VungleAdapter
    
    /// Set of placements in process of loading by the Vungle SDK.
    /// We need to keep track of this to avoid making a `loadPlacement()` call when a previous one is still ongoing, which is not supported by Vungle.
    private var loadingPlacements: Set<String> = []
    
    /// Similar to `loadingPlacements`, but keeps track of loading markups for programmatic loads.
    private var loadingMarkups: Set<String> = []
    
    init(adapter: VungleAdapter) {
        self.adapter = adapter
    }
    
    func isLoadInProgress(for request: PartnerAdLoadRequest) -> Bool {
        if let adm = request.adm {
            return loadingMarkups.contains(adm)
        } else {
            return loadingPlacements.contains(request.partnerPlacement)
        }
    }
    
    func recordLoadStart(for request: PartnerAdLoadRequest) {
        if let adm = request.adm {
            loadingMarkups.insert(adm)
        } else {
            loadingPlacements.insert(request.partnerPlacement)
        }
    }
    
    func recordLoadEnd(for request: PartnerAdLoadRequest) {
        if let adm = request.adm {
            recordLoadEnd(forMarkup: adm)
        } else {
            recordLoadEnd(forPlacement: request.partnerPlacement)
        }
    }
    
    private func recordLoadEnd(forMarkup markup: String) {
        loadingMarkups.remove(markup)
    }
    
    private func recordLoadEnd(forPlacement placement: String) {
        loadingPlacements.remove(placement)
    }
}

// MARK: - VungleSDKHBDelegate

extension VungleAdapterRouter {
    
    func vungleAdPlayabilityUpdate(_ isAdPlayable: Bool, placementID: String?, adMarkup: String?, error partnerError: Error?) {
        /// Record loading ended so another load can start with the same placement.
        if let adMarkup = adMarkup {
            recordLoadEnd(forMarkup: adMarkup)
        } else if let placementID = placementID {
            recordLoadEnd(forPlacement: placementID)
        }
        ad(for: placementID, adMarkup: adMarkup)?.vungleAdPlayabilityUpdate?(isAdPlayable, placementID: placementID, adMarkup: adMarkup, error: partnerError)
    }
    
    func vungleWillShowAd(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID, adMarkup: adMarkup)?.vungleWillShowAd?(forPlacementID: placementID, adMarkup: adMarkup)
    }
    
    func vungleDidShowAd(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID, adMarkup: adMarkup)?.vungleDidShowAd?(forPlacementID: placementID, adMarkup: adMarkup)
    }
    
    func vungleAdViewed(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID, adMarkup: adMarkup)?.vungleAdViewed?(forPlacementID: placementID, adMarkup: adMarkup)
    }
    
    func vungleTrackClick(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID, adMarkup: adMarkup)?.vungleTrackClick?(forPlacementID: placementID, adMarkup: adMarkup)
    }
    
    func vungleWillLeaveApplication(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID, adMarkup: adMarkup)?.vungleWillLeaveApplication?(forPlacementID: placementID, adMarkup: adMarkup)
    }
    
    func vungleWillCloseAd(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID, adMarkup: adMarkup)?.vungleWillCloseAd?(forPlacementID: placementID, adMarkup: adMarkup)
    }
    
    func vungleDidCloseAd(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID, adMarkup: adMarkup)?.vungleDidCloseAd?(forPlacementID: placementID, adMarkup: adMarkup)
    }
    
    func vungleRewardUser(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID, adMarkup: adMarkup)?.vungleRewardUser?(forPlacementID: placementID, adMarkup: adMarkup)
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
    func ad(for partnerPlacement: String?, adMarkup: String?, functionName: StaticString = #function) -> VungleSDKHBDelegate? {
        
        func adMatchesPlacementAndMarkup(_ ad: PartnerAd) -> Bool {
            ad.request.partnerPlacement == partnerPlacement && ad.request.adm == adMarkup
        }
        
        guard let partnerPlacement = partnerPlacement else {
            adapter.log("\(functionName) call ignored with nil placementID.")
            return nil
        }
        guard let ad = adapter.storage.ads.last(where: adMatchesPlacementAndMarkup) as? VungleAdapterAd else {
            adapter.log("\(functionName) call ignored with placementID \(partnerPlacement), no corresponding partner ad found.")
            return nil
        }
        return ad
    }
}
