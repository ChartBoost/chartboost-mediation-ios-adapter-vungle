// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import VungleAdsSDK

/// Chartboost Mediation Vungle adapter fullscreen ad.
final class VungleAdapterInterstitialAd: VungleAdapterAd, PartnerAd {

    /// Holds a refernce to the Vungle ad between the time load() exits and the delegate is called
    private var ad: VungleInterstitial?
    
    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    var inlineView: UIView? { nil }

    /// The loaded partner ad banner size.
    /// Should be `nil` for full-screen ads.
    var bannerSize: PartnerBannerSize? { nil }

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.loadStarted)
        
        loadCompletion = completion

        let interstitial = VungleInterstitial(placementId: request.partnerPlacement)
        ad = interstitial
        interstitial.delegate = self
        // If the adm is nil, that's the same as telling it to load a non-programatic ad
        interstitial.load(request.adm)
    }
    
    /// Shows a loaded ad.
    /// It will never get called for banner ads. You may leave the implementation blank for that ad format.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.showStarted)

        guard let ad = self.ad else {
            let error = error(.showFailureAdNotFound)
            log(.showFailed(error))
            completion(.failure(error))
            return
        }

        if ad.canPlayAd() {
            showCompletion = completion
            ad.present(with: viewController)
        } else {
            let error = error(.showFailureAdNotReady)
            log(.showFailed(error))
            completion(.failure(error))
        }
    }
}

// MARK: - VungleInterstitialDelegate
extension VungleAdapterInterstitialAd: VungleInterstitialDelegate {
    // Ad load events
    func interstitialAdDidLoad(_ interstitial: VungleInterstitial) {
        log(.loadSucceeded)
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func interstitialAdDidFailToLoad(_ interstitial: VungleInterstitial, withError: NSError) {
        log(.loadFailed(withError))
        loadCompletion?(.failure(withError)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    // Ad Lifecycle Events
    func interstitialAdWillPresent(_ interstitial: VungleInterstitial) {
        log(.delegateCallIgnored)
    }

    func interstitialAdDidPresent(_ interstitial: VungleInterstitial) {
        log(.showSucceeded)
        showCompletion?(.success([:])) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func interstitialAdDidFailToPresent(_ interstitial: VungleInterstitial, withError: NSError) {
        log(.showFailed(withError))
        showCompletion?(.failure(withError)) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func interstitialAdDidTrackImpression(_ interstitial: VungleInterstitial) {
        log(.didTrackImpression)
        delegate?.didTrackImpression(self, details: [:]) ?? log(.delegateUnavailable)
    }

    func interstitialAdDidClick(_ interstitial: VungleInterstitial) {
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:])  ?? log(.delegateUnavailable)
    }

    func interstitialAdWillLeaveApplication(_ interstitial: VungleInterstitial) {
        log(.delegateCallIgnored)
    }

    func interstitialAdWillClose(_ interstitial: VungleInterstitial) {
        log(.delegateCallIgnored)
    }

    func interstitialAdDidClose(_ interstitial: VungleInterstitial) {
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, details: [:], error: nil) ?? log(.delegateUnavailable)
    }
}
