// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import VungleAdsSDK

/// Chartboost Mediation Vungle adapter banner ad.
final class VungleAdapterBannerAd: VungleAdapterAd, PartnerBannerAd {

    /// Holds a refernce to the Vungle ad between the time load() exits and the delegate is called
    private var ad: VungleBanner?

    /// The partner banner ad view to display.
    var view: UIView? = UIView()

    /// The loaded partner ad banner size.
    var size: PartnerBannerSize?

    /// Indicates if the Vungle banner was displayed with a successful call to Vungle SDK's `addAdView`.
    private var adWasDisplayed = false

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
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
            return completion(.failure(error))
        }

        let banner = VungleBanner(placementId: request.partnerPlacement, size: vungleSize)
        ad = banner
        size = PartnerBannerSize(size: loadedSize.size, type: .fixed)
        banner.delegate = self
        // If the adm is nil, that's the same as telling it to load a non-programatic ad
        banner.load(request.adm)
    }

    /// Shows a loaded ad.
    /// Chartboost Mediation SDK will always call this method from the main thread.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        /// NO-OP
    }
}

// MARK: - VungleBannerDelegate
extension VungleAdapterBannerAd: VungleBannerDelegate {
    func bannerAdDidLoad(_ banner: VungleBanner) {

        // Check that the ad is ready
        guard banner.canPlayAd() == true else {
            let error = error(.loadFailureUnknown, description: "Unable to play ad.")
            log(.loadFailed(error))
            loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
            loadCompletion = nil
            return
        }

        // Fail if the banner container is unavailable. This should never happen since it is set on load.
        guard let view, let size else {
            let error = error(.loadFailureNoBannerView, description: "Vungle adapter bannerView is nil.")
            log(.loadFailed(error))
            loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
            loadCompletion = nil
            return
        }

        // All checks passed
        log(.loadSucceeded)

        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil

        // View must be set to the same size as the ad
        view.frame = CGRect(origin: .zero, size: size.size)
        banner.present(on: view)
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

extension ChartboostMediationSDK.BannerSize {
    fileprivate var vungleAdSize: VungleAdsSDK.BannerSize? {
        switch self {
        case .standard:
            .regular
        case .medium:
            .mrec
        case .leaderboard:
            .leaderboard
        default:
            nil
        }
    }
}
