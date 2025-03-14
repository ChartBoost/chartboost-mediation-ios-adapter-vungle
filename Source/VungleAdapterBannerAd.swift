// Copyright 2022-2025 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import VungleAdsSDK

/// Chartboost Mediation Vungle adapter banner ad.
final class VungleAdapterBannerAd: VungleAdapterAd, PartnerBannerAd {
    /// The partner banner ad view to display.
    var view: UIView?

    /// The loaded partner ad banner size.
    var size: PartnerBannerSize?

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Error?) -> Void) {
        log(.loadStarted)
        loadCompletion = completion

        // Fail if we cannot fit a fixed size banner in the requested size.
        guard
            let requestedSize = request.bannerSize,
            let loadedSize = BannerSize.largestStandardFixedSizeThatFits(in: requestedSize),
            let vungleSize = loadedSize.vungleAdSize
        else {
            let error = error(.loadFailureInvalidBannerSize)
            log(.loadFailed(error))
            completion(error)
            return
        }

        let bannerView = VungleBannerView(placementId: request.partnerPlacement, vungleAdSize: vungleSize)
        bannerView.delegate = self
        view = bannerView

        size = PartnerBannerSize(size: loadedSize.size, type: .fixed)
        // If the adm is nil, that's the same as telling it to load a non-programatic ad
        bannerView.load(request.adm)
    }

    /// Shows a loaded ad.
    /// Chartboost Mediation SDK will always call this method from the main thread.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Error?) -> Void) {
        // NO-OP
    }
}

// MARK: - VungleBannerDelegate
extension VungleAdapterBannerAd: VungleBannerViewDelegate {
    func bannerAdDidLoad(_ bannerView: VungleBannerView) {
        // Fail if the banner container is unavailable. This should never happen since it is set on load.
        if view == nil || size == nil {
            let error = error(.loadFailureNoBannerView, description: "Vungle adapter bannerView is nil.")
            log(.loadFailed(error))
            loadCompletion?(error) ?? log(.loadResultIgnored)
            loadCompletion = nil
            return
        }

        // All checks passed
        log(.loadSucceeded)
        loadCompletion?(nil) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func bannerAdDidFail(_ bannerView: VungleBannerView, withError: NSError) {
        log(.loadFailed(withError))
        loadCompletion?(withError) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    // Ad Lifecycle Events
    func bannerAdWillPresent(_ banner: VungleBannerView) {
        log(.showStarted)
    }

    func bannerAdDidPresent(_ banner: VungleBannerView) {
        log(.showSucceeded)
    }

    func bannerAdDidFailToPresent(_ banner: VungleBannerView, withError: NSError) {
        log(.showFailed(withError))
    }

    func bannerAdDidTrackImpression(_ banner: VungleBannerView) {
        log(.didTrackImpression)
        delegate?.didTrackImpression(self) ?? log(.delegateUnavailable)
    }

    func bannerAdDidClick(_ banner: VungleBannerView) {
        log(.didClick(error: nil))
        delegate?.didClick(self) ?? log(.delegateUnavailable)
    }

    func bannerAdWillLeaveApplication(_ banner: VungleBannerView) {
        log(.delegateCallIgnored)
    }

    func bannerAdWillClose(_ banner: VungleBannerView) {
        log(.delegateCallIgnored)
    }

    func bannerAdDidClose(_ banner: VungleBannerView) {
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, error: nil) ?? log(.delegateUnavailable)
    }
}

extension ChartboostMediationSDK.BannerSize {
    fileprivate var vungleAdSize: VungleAdsSDK.VungleAdSize? {
        switch self {
        case .standard:
            .VungleAdSizeBannerRegular
        case .medium:
            .VungleAdSizeMREC
        case .leaderboard:
            .VungleAdSizeLeaderboard
        default:
            nil
        }
    }
}
