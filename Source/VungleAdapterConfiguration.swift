// Copyright 2022-2026 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import VungleAdsSDK

/// A list of externally configurable properties pertaining to the partner SDK that can be retrieved and set by publishers.
@objc public class VungleAdapterConfiguration: NSObject, PartnerAdapterConfiguration {
    /// The version of the partner SDK.
    @objc public static var partnerSDKVersion: String {
        VungleAds.sdkVersion
    }

    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Chartboost Mediation SDK's major version, the
    /// last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Chartboost Mediation major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.
    /// <Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    @objc public static let adapterVersion = "5.7.7.0.0"

    /// The partner's unique identifier.
    @objc public static let partnerID = "vungle"

    /// The human-friendly partner name.
    @objc public static let partnerDisplayName = "Vungle"

    /// Use to manually set the consent status on the Vungle SDK.
    /// This is generally unnecessary as the Mediation SDK will set the consent status automatically based on the latest consent info.
    @objc public static func setGDPRStatusOverride(_ status: Bool) {
        isGDPRStatusOverridden = true
        VunglePrivacySettings.setGDPRStatus(status)
        log("GDPR status override set to \(status)")
    }

    /// Use to manually set the consent status on the Vungle SDK.
    /// This is generally unnecessary as the Mediation SDK will set the consent status automatically based on the latest consent info.
    @objc public static func setCCPAStatusOverride(_ status: Bool) {
        isCCPAStatusOverridden = true
        VunglePrivacySettings.setCCPAStatus(status)
        log("CCPA status override set to \(status)")
    }

    /// Internal flag that indicates if the GDPR status has been overridden by the publisher.
    private(set) static var isGDPRStatusOverridden = false

    /// Internal flag that indicates if the CCPA status has been overridden by the publisher.
    private(set) static var isCCPAStatusOverridden = false
}
