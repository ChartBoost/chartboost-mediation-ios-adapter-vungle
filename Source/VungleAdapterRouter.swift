// Copyright 2022-2023 Chartboost, Inc.
// 
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

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
        ad(for: placementID, prioritizeVisibleBanner: false)?.vungleAdPlayabilityUpdate?(isAdPlayable, placementID: placementID, adMarkup: adMarkup, error: partnerError)
    }
    
    func vungleWillShowAd(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID, prioritizeVisibleBanner: false)?.vungleWillShowAd?(forPlacementID: placementID, adMarkup: adMarkup)
    }
    
    func vungleDidShowAd(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID, prioritizeVisibleBanner: false)?.vungleDidShowAd?(forPlacementID: placementID, adMarkup: adMarkup)
    }
    
    func vungleAdViewed(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID, prioritizeVisibleBanner: false)?.vungleAdViewed?(forPlacementID: placementID, adMarkup: adMarkup)
    }
    
    func vungleTrackClick(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID, prioritizeVisibleBanner: true)?.vungleTrackClick?(forPlacementID: placementID, adMarkup: adMarkup)
    }
    
    func vungleWillLeaveApplication(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID, prioritizeVisibleBanner: true)?.vungleWillLeaveApplication?(forPlacementID: placementID, adMarkup: adMarkup)
    }
    
    func vungleWillCloseAd(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID, prioritizeVisibleBanner: true)?.vungleWillCloseAd?(forPlacementID: placementID, adMarkup: adMarkup)
    }
    
    func vungleDidCloseAd(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID, prioritizeVisibleBanner: true)?.vungleDidCloseAd?(forPlacementID: placementID, adMarkup: adMarkup)
    }
    
    func vungleRewardUser(forPlacementID placementID: String?, adMarkup: String?) {
        ad(for: placementID, prioritizeVisibleBanner: true)?.vungleRewardUser?(forPlacementID: placementID, adMarkup: adMarkup)
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
    func ad(for partnerPlacement: String?, prioritizeVisibleBanner: Bool, functionName: StaticString = #function) -> VungleSDKHBDelegate? {
        guard let partnerPlacement = partnerPlacement else {
            adapter.log("\(functionName) call ignored with nil placementID.")
            return nil
        }
        guard let ad = adapter.storage.ads.last(where: { $0.request.partnerPlacement == partnerPlacement }) as? VungleAdapterAd else {
            adapter.log("\(functionName) call ignored with placementID \(partnerPlacement), no corresponding partner ad found.")
            return nil
        }
        // It is possible that multiple banner ads with the same placement are created given that Helium preloads the next banner while the previous one is
        // still visible as part of its auto-refresh process.
        // Knowing which `PartnerAd` instance corresponds to each delegate method call gets tricky.
        // Here we do a best attempt at it by forwarding calls we know should happen only on visible banners to the currently visible banner ad.
        // Other calls are forwarded to the latest created ad.
        // The solution is not ideal but the only one to make this work without preventing multiple loads for ads with the same placement, which would make
        // Helium banner auto-refresh stop if the same partner placement won over and over again.
        // It should work fine under the assumption that Helium does not support the creation of multiple banners with the same placement by publishers, which means
        // at a single point in time there should be at most two Vungle banners with the same placement loaded: the visible one and the preloaded one intended to replace it.
        if ad.request.format == .banner && prioritizeVisibleBanner {
            let firstVisibleBanner = adapter.storage.ads.first(where: { $0.request.partnerPlacement == partnerPlacement && $0.inlineView?.window != nil }) as? VungleAdapterAd
            return firstVisibleBanner ?? ad
        }
        return ad
    }
}
