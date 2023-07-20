// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import VungleAdsSDK

/// Chartboost Mediation Vungle adapter banner ad.
final class VungleAdapterBannerAd: VungleAdapterAd, PartnerAd {

    var ad: VungleBanner?

    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    var inlineView: UIView? = UIView()

    /// Indicates if the Vungle banner was displayed with a successful call to Vungle SDK's `addAdView`.
    private var adWasDisplayed = false

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        loadCompletion = completion

        ad = VungleBanner(placementId: request.partnerPlacement, size: self.vungleAdSize)
        ad?.delegate = self
        // If the adm is nil, that's the same as telling it to load a non-programatic ad
        ad?.load(request.adm)
    }

    /// Shows a loaded ad.
    /// It will never get called for banner ads. You may leave the implementation blank for that ad format.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        /// NO-OP
    }

    /// Invalidates a loaded ad.
    /// Chartboost Mediation SDK calls this method right before disposing of an ad.
    ///
    /// A default implementation is provided that does nothing.
    /// Only implement if there is some special cleanup required by the partner SDK before disposing of the ad instance.
    func invalidate() throws {
    }

    /// Mapping of the request ad size to Vungle's ad size type. Nil means a MREC banner.
    private var vungleAdSize: BannerSize {
        switch request.size {
        case IABStandardAdSize:
            return BannerSize.regular
        case CGSize(width: 300, height: 50):
            return BannerSize.short
        case IABLeaderboardAdSize:
            return BannerSize.leaderboard
        case IABMediumAdSize:
            return BannerSize.mrec
        default:
            log("Unrecognized banner size.")
            // Ad is unlikely to load if the size doesn't match, but we need to return something
            return BannerSize.regular
        }
    }
}

// MARK: - VungleBannerDelegate
extension VungleAdapterBannerAd: VungleBannerDelegate {
    func bannerAdDidLoad(_ banner: VungleBanner) {
        log(.loadSucceeded)
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)

        // Check that the ad object is non-nil
        guard let ad = self.ad else {
            let error = error(.showFailureAdNotFound)
            log(.showFailed(error))
            return
        }

        // Check that the ad is ready
        guard ad.canPlayAd() == true else {
            let error = error(.showFailureAdNotReady)
            log(.showFailed(error))
            return
        }

        // Fail if inlineView container is unavailable. This should never happen since it is set on load.
        guard let inlineView = inlineView else {
            let error = error(.loadFailureNoInlineView, description: "Vungle adapter inlineView is nil.")
            log(.showFailed(error))
            return
        }

        // Fail if ad size is missing from request. This should never happen.
        guard let size = request.size else {
            let error = error(.loadFailureInvalidAdRequest, description: "No size was specified.")
            log(.showFailed(error))
            return
        }

        // View must be set to the same size as the ad
        inlineView.frame = CGRect(origin: .zero, size: size)
        ad.present(on: inlineView)
    }

    func bannerAdDidFailToLoad(_ banner: VungleBanner, withError: NSError) {
        log(.loadFailed(withError))
        loadCompletion?(.failure(withError)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    // Ad Lifecycle Events
    func bannerAdWillPresent(_ banner: VungleBanner) {
        log(.showStarted)
    }

    func bannerAdDidPresent(_ banner: VungleBanner) {
        log(.showSucceeded)
    }

    func bannerAdDidFailToPresent(_ banner: VungleBanner, withError: NSError) {
        log(.showFailed(withError))
    }

    func bannerAdDidTrackImpression(_ banner: VungleBanner) {
        log(.didTrackImpression)
        delegate?.didTrackImpression(self, details: [:]) ?? log(.delegateUnavailable)
    }

    func bannerAdDidClick(_ banner: VungleBanner) {
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:])  ?? log(.delegateUnavailable)
    }

    func bannerAdWillLeaveApplication(_ banner: VungleBanner) {
        log(.delegateCallIgnored)
    }

    func bannerAdWillClose(_ banner: VungleBanner) {
        log(.delegateCallIgnored)
    }

    func bannerAdDidClose(_ banner: VungleBanner) {
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, details: [:], error: nil) ?? log(.delegateUnavailable)
    }
}
