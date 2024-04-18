// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import VungleAdsSDK

/// Chartboost Mediation Vungle adapter banner ad.
final class VungleAdapterBannerAd: VungleAdapterAd, PartnerAd {

    /// Holds a refernce to the Vungle ad between the time load() exits and the delegate is called
    private var ad: VungleBanner?

    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    var inlineView: UIView? = UIView()

    /// The loaded partner ad banner size.
    /// Should be `nil` for full-screen ads.
    var bannerSize: PartnerBannerSize?

    /// Indicates if the Vungle banner was displayed with a successful call to Vungle SDK's `addAdView`.
    private var adWasDisplayed = false

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.loadStarted)
        loadCompletion = completion

        // Fail if we cannot fit a fixed size banner in the requested size.
        guard let (_, vungleSize) = fixedBannerSize(for: request.size ?? IABStandardAdSize) else {
            let error = error(.loadFailureInvalidBannerSize)
            log(.loadFailed(error))
            return completion(.failure(error))
        }

        let banner = VungleBanner(placementId: request.partnerPlacement, size: vungleSize)
        ad = banner
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

        // Fail if inlineView container is unavailable. This should never happen since it is set on load.
        guard let inlineView = inlineView else {
            let error = error(.loadFailureNoInlineView, description: "Vungle adapter inlineView is nil.")
            log(.loadFailed(error))
            loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
            loadCompletion = nil
            return
        }

        // Fail if ad size is missing from request. This should never happen.
        guard let requestSize = request.size,
              let (size, _) = fixedBannerSize(for: requestSize) else {
            let error = error(.loadFailureInvalidAdRequest, description: "No size was specified.")
            log(.loadFailed(error))
            loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
            loadCompletion = nil
            return
        }

        // All checks passed
        log(.loadSucceeded)

        bannerSize = PartnerBannerSize(size: size, type: .fixed)
        
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil

        // View must be set to the same size as the ad
        inlineView.frame = CGRect(origin: .zero, size: size)
        banner.present(on: inlineView)
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

// MARK: - Helpers
extension VungleAdapterBannerAd {
    private func fixedBannerSize(for requestedSize: CGSize) -> (size: CGSize, partnerSize: VungleAdsSDK.BannerSize)? {
        let sizes: [(size: CGSize, partnerSize: VungleAdsSDK.BannerSize)] = [
            (size: IABLeaderboardAdSize, partnerSize: .leaderboard),
            (size: IABMediumAdSize, partnerSize: .mrec),
            (size: IABStandardAdSize, partnerSize: .regular)
        ]
        // Find the largest size that can fit in the requested size.
        for (size, partnerSize) in sizes {
            // If height is 0, the pub has requested an ad of any height, so only the width matters.
            if requestedSize.width >= size.width &&
                (size.height == 0 || requestedSize.height >= size.height) {
                return (size, partnerSize)
            }
        }
        // The requested size cannot fit any fixed size banners.
        return nil
    }
}
