// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import Foundation
import os.log
import VungleAdsSDK

/// A list of externally configurable properties pertaining to the partner SDK that can be retrieved and set by publishers.
@objc public class VungleAdapterConfiguration: NSObject {

    /// The version of the partner SDK.
    @objc public static var partnerSDKVersion: String {
        VungleAds.sdkVersion
    }

    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Chartboost Mediation SDK's major version, the last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Chartboost Mediation major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.<Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    @objc public static let adapterVersion = "4.7.3.0.0"

    /// The partner's unique identifier.
    @objc public static let partnerID = "vungle"

    /// The human-friendly partner name.
    @objc public static let partnerDisplayName = "Vungle"

    /// Use to manually set the consent status on the Pangle SDK.
    /// This is generally unnecessary as the Mediation SDK will set the consent status automatically based on the latest consent info.
    @objc public static func setGDPRStatusOverride(_ status: Bool) {
        isGDPRStatusOverriden = true
        VunglePrivacySettings.setGDPRStatus(status)
        os_log(.info, log: log, "Vungle SDK GDPR status override set to %{public}s", "\(status)")
    }

    /// Use to manually set the consent status on the Pangle SDK.
    /// This is generally unnecessary as the Mediation SDK will set the consent status automatically based on the latest consent info.
    @objc public static func setCCPAStatusOverride(_ status: Bool) {
        isCCPAStatusOverriden = true
        VunglePrivacySettings.setCCPAStatus(status)
        os_log(.info, log: log, "Vungle SDK CCPA status override set to %{public}s", "\(status)")
    }

    /// Internal flag that indicates if the GDPR status has been overriden by the publisher.
    static private(set) var isGDPRStatusOverriden = false

    /// Internal flag that indicates if the CCPA status has been overriden by the publisher.
    static private(set) var isCCPAStatusOverriden = false

    private static let log = OSLog(subsystem: "com.chartboost.mediation.adapter.vungle", category: "Configuration")
}
