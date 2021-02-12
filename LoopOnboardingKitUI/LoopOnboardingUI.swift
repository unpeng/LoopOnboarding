//
//  LoopOnboardingUI.swift
//  LoopOnboardingKitUI
//
//  Created by Darin Krauss on 1/23/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit
import LoopKitUI
import LoopOnboardingKit

public final class LoopOnboardingUI: OnboardingUI {
    public let onboardingIdentifier = "LoopOnboarding"

    public static func createOnboarding() -> OnboardingUI {
        return LoopOnboardingUI()
    }

    public func onboardingViewController(preferredGlucoseUnit: HKUnit, cgmManagerProvider: CGMManagerProvider, pumpManagerProvider: PumpManagerProvider, serviceProvider: ServiceProvider, colorPalette: LoopUIColorPalette) -> (UIViewController & OnboardingViewController) {
        return OnboardingUICoordinator(initialTherapySettings: TherapySettings(), preferredGlucoseUnit: preferredGlucoseUnit, cgmManagerProvider: cgmManagerProvider, pumpManagerProvider: pumpManagerProvider, serviceProvider: serviceProvider, colorPalette: colorPalette)
    }
}
