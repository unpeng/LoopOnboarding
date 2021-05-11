//
//  OnboardingUIController.swift
//  LoopOnboardingKitUI
//
//  Created by Pete Schwamb on 9/7/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import os.log
import Foundation
import HealthKit
import SwiftUI
import LoopKit
import LoopKitUI

enum OnboardingScreen: CaseIterable {
    case welcome
    case nightscoutChooser
    case suspendThresholdInfo
    case suspendThresholdEditor
    case correctionRangeInfo
    case correctionRangeEditor
    case correctionRangePreMealOverrideInfo
    case correctionRangePreMealOverrideEditor
    case correctionRangeWorkoutOverrideInfo
    case correctionRangeWorkoutOverrideEditor
    case basalRatesInfo
    case basalRatesEditor
    case deliveryLimitsInfo
    case deliveryLimitsEditor
    case insulinModelInfo
    case insulinModelEditor
    case carbRatioInfo
    case carbRatioEditor
    case insulinSensitivityInfo
    case insulinSensitivityEditor
    case therapySettingsRecap

    func next() -> OnboardingScreen? {
        guard let nextIndex = Self.allCases.firstIndex(where: { $0 == self }).map({ $0 + 1 }),
              nextIndex < Self.allCases.count else {
            return nil
        }
        return Self.allCases[nextIndex]
    }
}

class OnboardingUICoordinator: UINavigationController, CGMManagerOnboarding, PumpManagerOnboarding, ServiceOnboarding, CompletionNotifying {
    public weak var onboardingDelegate: OnboardingDelegate?
    public weak var cgmManagerOnboardingDelegate: CGMManagerOnboardingDelegate?
    public weak var pumpManagerOnboardingDelegate: PumpManagerOnboardingDelegate?
    public weak var serviceOnboardingDelegate: ServiceOnboardingDelegate?
    public weak var completionDelegate: CompletionDelegate?

    private let onboarding: LoopOnboardingUI
    private let onboardingProvider: OnboardingProvider
    private let initialTherapySettings: TherapySettings
    private let displayGlucoseUnitObservable: DisplayGlucoseUnitObservable
    private let colorPalette: LoopUIColorPalette

    private var screenStack = [OnboardingScreen]()
    private var currentScreen: OnboardingScreen { return screenStack.last! }

    private var service: Service?

    private var therapySettingsViewModel: TherapySettingsViewModel? // Used for keeping track of & updating settings

    private let log = OSLog(category: "OnboardingUICoordinator")

    private static let serviceIdentifier = "NightscoutService"

    init(onboarding: LoopOnboardingUI, onboardingProvider: OnboardingProvider, initialTherapySettings: TherapySettings, displayGlucoseUnitObservable: DisplayGlucoseUnitObservable, colorPalette: LoopUIColorPalette) {
        self.onboarding = onboarding
        self.onboardingProvider = onboardingProvider
        self.initialTherapySettings = initialTherapySettings
        self.displayGlucoseUnitObservable = displayGlucoseUnitObservable
        self.colorPalette = colorPalette
        self.service = onboardingProvider.activeServices.first(where: { $0.serviceIdentifier == OnboardingUICoordinator.serviceIdentifier })

        super.init(navigationBarClass: UINavigationBar.self, toolbarClass: UIToolbar.self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        delegate = self

        navigationBar.prefersLargeTitles = true // Ensure nav bar text is displayed correctly
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        screenStack = [.welcome]
        let viewController = viewControllerForScreen(currentScreen)
        setViewControllers([viewController], animated: false)
    }

    private func viewControllerForScreen(_ screen: OnboardingScreen) -> UIViewController {
        switch screen {
        case .welcome:
            let view = WelcomeView { [weak self] in
                self?.stepFinished()
            }
            let hostedView = hostingController(rootView: view)
            return hostedView
        case .nightscoutChooser:
            let view = OnboardingChooserView(setupWithNightscout: setupWithNightscout, setupWithoutNightscout: setupWithoutNightscout)
            let hostedView = hostingController(rootView: view)
            return hostedView
        case .suspendThresholdInfo:
            therapySettingsViewModel = constructTherapySettingsViewModel(therapySettings: initialTherapySettings)
            let exiting: (() -> Void) = { [weak self] in
                self?.stepFinished()
            }
            let view = SuspendThresholdInformationView(onExit: exiting)
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.largeTitleDisplayMode = .always // TODO: hack to fix jumping, will be removed once editors have titles
            hostedView.title = TherapySetting.suspendThreshold.title
            return hostedView
        case .suspendThresholdEditor:
            let view = SuspendThresholdEditor(mode: .acceptanceFlow, therapySettingsViewModel: therapySettingsViewModel!)
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.largeTitleDisplayMode = .never // TODO: hack to fix jumping, will be removed once editors have titles
            return hostedView
        case .correctionRangeInfo:
            let onExit: (() -> Void) = { [weak self] in
                self?.stepFinished()
            }
            let view = CorrectionRangeInformationView(onExit: onExit)
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.largeTitleDisplayMode = .always // TODO: hack to fix jumping, will be removed once editors have titles
            hostedView.title = TherapySetting.glucoseTargetRange.title
            return hostedView
        case .correctionRangeEditor:
            let view = CorrectionRangeScheduleEditor(mode: .acceptanceFlow, therapySettingsViewModel: therapySettingsViewModel!)
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.largeTitleDisplayMode = .never // TODO: hack to fix jumping, will be removed once editors have titles
            return hostedView
        case .correctionRangePreMealOverrideInfo:
            let exiting: (() -> Void) = { [weak self] in
                self?.stepFinished()
            }
            let view = CorrectionRangeOverrideInformationView(preset: .preMeal, onExit: exiting)
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.largeTitleDisplayMode = .always // TODO: hack to fix jumping, will be removed once editors have titles
            hostedView.title = TherapySetting.preMealCorrectionRangeOverride.smallTitle
            return hostedView
        case .correctionRangePreMealOverrideEditor:
            let view = CorrectionRangeOverridesEditor(mode: .acceptanceFlow, therapySettingsViewModel: therapySettingsViewModel!, preset: .preMeal)
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.largeTitleDisplayMode = .never // TODO: hack to fix jumping, will be removed once editors have titles
            return hostedView
        case .correctionRangeWorkoutOverrideInfo:
            let exiting: (() -> Void) = { [weak self] in
                self?.stepFinished()
            }
            let view = CorrectionRangeOverrideInformationView(preset: .workout, onExit: exiting)
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.largeTitleDisplayMode = .always // TODO: hack to fix jumping, will be removed once editors have titles
            hostedView.title = TherapySetting.workoutCorrectionRangeOverride.smallTitle
            return hostedView
        case .correctionRangeWorkoutOverrideEditor:
            let view = CorrectionRangeOverridesEditor(mode: .acceptanceFlow, therapySettingsViewModel: therapySettingsViewModel!, preset: .workout)
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.largeTitleDisplayMode = .never // TODO: hack to fix jumping, will be removed once editors have titles
            return hostedView
        case .basalRatesInfo:
            let exiting: (() -> Void) = { [weak self] in
                self?.stepFinished()
            }
            let view = BasalRatesInformationView(onExit: exiting)
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.largeTitleDisplayMode = .always // TODO: hack to fix jumping, will be removed once editors have titles
            hostedView.title = TherapySetting.basalRate.title
            return hostedView
        case .basalRatesEditor:
            let view = BasalRateScheduleEditor(mode: .acceptanceFlow, therapySettingsViewModel: therapySettingsViewModel!)
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.largeTitleDisplayMode = .never // TODO: hack to fix jumping, will be removed once editors have titles
            return hostedView
        case .deliveryLimitsInfo:
            let exiting: (() -> Void) = { [weak self] in
                self?.stepFinished()
            }
            let view = DeliveryLimitsInformationView(onExit: exiting)
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.largeTitleDisplayMode = .always // TODO: hack to fix jumping, will be removed once editors have titles
            hostedView.title = TherapySetting.deliveryLimits.title
            return hostedView
        case .deliveryLimitsEditor:
            let view = DeliveryLimitsEditor(mode: .acceptanceFlow, therapySettingsViewModel: therapySettingsViewModel!)
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.largeTitleDisplayMode = .never // TODO: hack to fix jumping, will be removed once editors have titles
            return hostedView
        case .insulinModelInfo:
            let onExit: (() -> Void) = { [weak self] in
                self?.stepFinished()
            }
            let view = InsulinModelInformationView(onExit: onExit).environment(\.appName, Bundle.main.bundleDisplayName)
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.largeTitleDisplayMode = .always // TODO: hack to fix jumping, will be removed once editors have titles
            hostedView.title = TherapySetting.insulinModel.title
            return hostedView
        case .insulinModelEditor:
            let view = InsulinModelSelection(mode: .acceptanceFlow, therapySettingsViewModel: therapySettingsViewModel!, chartColors: colorPalette.chartColorPalette).environment(\.appName, Bundle.main.bundleDisplayName)
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.largeTitleDisplayMode = .always // TODO: hack to fix jumping, will be removed once editors have titles
            hostedView.title = TherapySetting.insulinModel.title
            return hostedView
        case .carbRatioInfo:
            let onExit: (() -> Void) = { [weak self] in
                self?.stepFinished()
            }
            let view = CarbRatioInformationView(onExit: onExit)
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.largeTitleDisplayMode = .always // TODO: hack to fix jumping, will be removed once editors have titles
            hostedView.title = TherapySetting.carbRatio.title
            return hostedView
        case .carbRatioEditor:
            let view = CarbRatioScheduleEditor(mode: .acceptanceFlow, therapySettingsViewModel: therapySettingsViewModel!)
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.largeTitleDisplayMode = .never // TODO: hack to fix jumping, will be removed once editors have titles
            return hostedView
        case .insulinSensitivityInfo:
            let onExit: (() -> Void) = { [weak self] in
                self?.stepFinished()
            }
            let view = InsulinSensitivityInformationView(onExit: onExit)
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.largeTitleDisplayMode = .always // TODO: hack to fix jumping, will be removed once editors have titles
            hostedView.title = TherapySetting.insulinSensitivity.title
            return hostedView
        case .insulinSensitivityEditor:
            let view = InsulinSensitivityScheduleEditor(mode: .acceptanceFlow, therapySettingsViewModel: therapySettingsViewModel!)
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.largeTitleDisplayMode = .never // TODO: hack to fix jumping, will be removed once editors have titles
            return hostedView
        case .therapySettingsRecap:
            therapySettingsViewModel?.prescription = nil
            let nextButtonString = LocalizedString("Save Settings", comment: "Therapy settings save button title")
            let actionButton = TherapySettingsView.ActionButton(localizedString: nextButtonString) { [weak self] in
                if let self = self {
                    self.onboarding.therapySettings = self.therapySettingsViewModel?.therapySettings
                    self.onboarding.isOnboarded = true
                    self.stepFinished()
                }
            }
            let view = TherapySettingsView(mode: .acceptanceFlow, viewModel: therapySettingsViewModel!, actionButton: actionButton)
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.largeTitleDisplayMode = .always // TODO: hack to fix jumping, will be removed once editors have titles
            hostedView.title = LocalizedString("Therapy Settings", comment: "Navigation view title")
            return hostedView
        }
    }

    private func hostingController<Content: View>(rootView: Content) -> DismissibleHostingController {
        return DismissibleHostingController(rootView: rootView.environmentObject(displayGlucoseUnitObservable), colorPalette: colorPalette)
    }

    private func stepFinished() {
        var nextScreen: OnboardingScreen?

        nextScreen = currentScreen.next()

        // If the next screen is the Nightscout service chooser, but the Nightscout service
        // is already created and onboarded, then simply skip to the next screen
        if nextScreen == .nightscoutChooser && service?.isOnboarded == true {
            nextScreen = nextScreen?.next()
        }

        if let nextScreen = nextScreen {
            navigate(to: nextScreen)
        } else {
            completionDelegate?.completionNotifyingDidComplete(self)
        }
    }

    private func navigate(to screen: OnboardingScreen) {
        var viewControllers = self.viewControllers

        // Remove the Nightscout chooser from the view controller hierarchy if the Nightscout service is fully onboarded
        if currentScreen == .nightscoutChooser && service?.isOnboarded == true {
            screenStack.removeLast()
            viewControllers.removeLast()
        }

        screenStack.append(screen)
        viewControllers.append(viewControllerForScreen(screen))
        setViewControllers(viewControllers, animated: true)
    }

    private func setupWithNightscout() {
        switch onboardingProvider.onboardService(withIdentifier: OnboardingUICoordinator.serviceIdentifier) {
        case .failure(let error):
            log.debug("Failure to create and setup service with identifier '%{public}@': %{public}@", OnboardingUICoordinator.serviceIdentifier, String(describing: error))
        case .success(let success):
            switch success {
            case .userInteractionRequired(var setupViewController):
                setupViewController.serviceOnboardingDelegate = self
                setupViewController.completionDelegate = self
                show(setupViewController, sender: self)
            case .createdAndOnboarded(let service):
                self.service = service
                stepFinished()
            }
        }
    }

    private func setupWithoutNightscout() {
        stepFinished()
    }

    private func constructTherapySettingsViewModel(therapySettings: TherapySettings) -> TherapySettingsViewModel? {
        let supportedBasalRates = (1...600).map { round(Double($0) / Double(1.0/0.05) * 100.0) / 100.0 }

        let maximumBasalScheduleEntryCount = 24

        let supportedBolusVolumes = (1...600).map { Double($0) / Double(1/0.05) }

        let pumpSupportedIncrements = PumpSupportedIncrements(
            basalRates: supportedBasalRates,
            bolusVolumes: supportedBolusVolumes,
            maximumBasalScheduleEntryCount: maximumBasalScheduleEntryCount
        )
        let supportedInsulinModelSettings = SupportedInsulinModelSettings(fiaspModelEnabled: true, walshModelEnabled: false)

        return TherapySettingsViewModel(
            therapySettings: therapySettings,
            supportedInsulinModelSettings: supportedInsulinModelSettings,
            pumpSupportedIncrements: { pumpSupportedIncrements },
            syncPumpSchedule: {
                { _, _ in
                    // Since pump isn't set up, this syncing shouldn't do anything
                    assertionFailure()
                }
            },
            prescription: nil
        ) { [weak self] _, _ in
            self?.stepFinished()
        }
    }
}

extension OnboardingUICoordinator: UINavigationControllerDelegate {
    public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        // Pop the current screen from the stack if we're navigating back
        while viewControllers.count < screenStack.count {
            screenStack.removeLast()
        }
    }
}

extension OnboardingUICoordinator: CGMManagerOnboardingDelegate {
    func cgmManagerOnboarding(didCreateCGMManager cgmManager: CGMManagerUI) {
        cgmManagerOnboardingDelegate?.cgmManagerOnboarding(didCreateCGMManager: cgmManager)
    }

    func cgmManagerOnboarding(didOnboardCGMManager cgmManager: CGMManagerUI) {
        cgmManagerOnboardingDelegate?.cgmManagerOnboarding(didOnboardCGMManager: cgmManager)
    }
}

extension OnboardingUICoordinator: PumpManagerOnboardingDelegate {
    func pumpManagerOnboarding(didCreatePumpManager pumpManager: PumpManagerUI) {
        pumpManagerOnboardingDelegate?.pumpManagerOnboarding(didCreatePumpManager: pumpManager)
    }

    func pumpManagerOnboarding(didOnboardPumpManager pumpManager: PumpManagerUI, withFinalSettings settings: PumpManagerSetupSettings) {
        pumpManagerOnboardingDelegate?.pumpManagerOnboarding(didOnboardPumpManager: pumpManager, withFinalSettings: settings)
    }
}

extension OnboardingUICoordinator: ServiceOnboardingDelegate {
    func serviceOnboarding(didCreateService service: Service) {
        self.service = service
        serviceOnboardingDelegate?.serviceOnboarding(didCreateService: service)
    }

    func serviceOnboarding(didOnboardService service: Service) {
        serviceOnboardingDelegate?.serviceOnboarding(didOnboardService: service)
    }
}

extension OnboardingUICoordinator: CompletionDelegate {
    func completionNotifyingDidComplete(_ object: CompletionNotifying) {
        if let viewController = object as? UIViewController {
            if presentedViewController === viewController {
                dismiss(animated: true, completion: nil)
            } else {
                viewController.dismiss(animated: true, completion: nil)
            }
            if service == nil || service!.isOnboarded {
                stepFinished()
            }
        }
    }
}
