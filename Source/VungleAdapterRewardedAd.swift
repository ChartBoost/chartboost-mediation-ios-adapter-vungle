// Copyright 2022-2025 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import VungleAdsSDK

/// Chartboost Mediation Vungle adapter fullscreen ad.
final class VungleAdapterRewardedAd: VungleAdapterAd, PartnerFullscreenAd {
    /// Holds a refernce to the Vungle ad between the time load() exits and the delegate is called
    private var ad: VungleRewarded?

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Error?) -> Void) {
        log(.loadStarted)

        loadCompletion = completion

        let rewarded = VungleRewarded(placementId: request.partnerPlacement)
        ad = rewarded
        rewarded.delegate = self
        // If the adm is nil, that's the same as telling it to load a non-programatic ad
        rewarded.load(request.adm)
    }

    /// Shows a loaded ad.
    /// Chartboost Mediation SDK will always call this method from the main thread.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Error?) -> Void) {
        log(.showStarted)

        guard let ad = self.ad else {
            let error = error(.showFailureAdNotFound)
            log(.showFailed(error))
            completion(error)
            return
        }

        if ad.canPlayAd() {
            showCompletion = completion
            ad.present(with: viewController)
        } else {
            let error = error(.showFailureAdNotReady)
            log(.showFailed(error))
            completion(error)
        }
    }
}

// MARK: - VungleRewardedDelegate
extension VungleAdapterRewardedAd: VungleRewardedDelegate {
    // Ad load events
    func rewardedAdDidLoad(_ rewarded: VungleRewarded) {
        log(.loadSucceeded)
        loadCompletion?(nil) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func rewardedAdDidFailToLoad(_ rewarded: VungleRewarded, withError: NSError) {
        log(.loadFailed(withError))
        loadCompletion?(withError) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    // Ad Lifecycle Events
    func rewardedAdWillPresent(_ rewarded: VungleRewarded) {
        log(.delegateCallIgnored)
    }

    func rewardedAdDidPresent(_ rewarded: VungleRewarded) {
        log(.showSucceeded)
        showCompletion?(nil) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func rewardedAdDidFailToPresent(_ rewarded: VungleRewarded, withError: NSError) {
        log(.showFailed(withError))
        showCompletion?(withError) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func rewardedAdDidTrackImpression(_ rewarded: VungleRewarded) {
        log(.didTrackImpression)
        delegate?.didTrackImpression(self) ?? log(.delegateUnavailable)
    }

    func rewardedAdDidClick(_ rewarded: VungleRewarded) {
        log(.didClick(error: nil))
        delegate?.didClick(self) ?? log(.delegateUnavailable)
    }

    func rewardedAdWillLeaveApplication(_ rewarded: VungleRewarded) {
        log(.delegateCallIgnored)
    }

    func rewardedAdDidRewardUser(_ rewarded: VungleRewarded) {
        log(.didReward)
        delegate?.didReward(self) ?? log(.delegateUnavailable)
    }

    func rewardedAdWillClose(_ rewarded: VungleRewarded) {
        log(.delegateCallIgnored)
    }

    func rewardedAdDidClose(_ rewarded: VungleRewarded) {
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, error: nil) ?? log(.delegateUnavailable)
    }
}
