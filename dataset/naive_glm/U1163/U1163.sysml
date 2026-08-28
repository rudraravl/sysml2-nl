package PlatformFragmentationManagementSystem {
    import ScalarValues::*;
    import SI::*;

    // ============================================================
    // Custom Units and Value Types
    // ============================================================

    package CustomUnits {
        public import SI::*;

        attribute def PercentUnit :> Unit {
            attribute symbol : String = "%";
            attribute conversionFactor : Real = 0.01;
            attribute conversionOffset : Real = 0.0;
        }

        value type Percent :> Real {
            redef unit = PercentUnit;
        }

        value type UserCount :> Integer;

        value type ApiVersionNumber :> Integer;

        value type FragmentationIndex :> Real {
            redef unit = PercentUnit;
        }

        value type ScanIntervalHours :> Real {
            redef unit = h;
        }
    }

    // ============================================================
    // Item Definitions
    // ============================================================

    item def PlatformData {
        attribute platformName : String;
        attribute platformType : String;
        attribute apiVersion : CustomUnits::ApiVersionNumber;
        attribute marketShare : CustomUnits::Percent;
        attribute userBase : CustomUnits::UserCount;
    }

    item def PlatformEcosystemSnapshot {
        attribute snapshotId : String;
        attribute timestamp : DateTime;
        attribute platforms : PlatformData[0..*] ordered;
        attribute totalDetectedPlatforms : Integer;
    }

    item def FragmentationAnalysisResult {
        attribute analysisId : String;
        attribute fragmentationScore : CustomUnits::FragmentationIndex;
        attribute criticalPlatforms : PlatformData[0..*] ordered;
        attribute thresholdExceeded : Boolean;
        attribute totalUserBase : CustomUnits::UserCount;
    }

    item def ApplicationComponent {
        attribute componentName : String;
        attribute sourceVersion : String;
        attribute baseCode : String;
    }

    item def AdaptationRequest {
        attribute requestId : String;
        attribute originalComponent : ApplicationComponent;
        attribute targetPlatform : PlatformData;
    }

    item def AdaptedPackage {
        attribute packageId : String;
        attribute adaptedComponent : ApplicationComponent;
        attribute targetPlatform : PlatformData;
        attribute generatedTimestamp : DateTime;
        attribute adaptationNotes : String;
    }

    item def ValidationReport {
        attribute reportId : String;
        attribute testedPackage : AdaptedPackage;
        attribute isValid : Boolean;
        attribute functionalTestPassed : Boolean;
        attribute compatibilityTestPassed : Boolean;
        attribute coverage : CustomUnits::Percent;
        attribute failureReason : String;
    }

    item def DeploymentManifest {
        attribute manifestId : String;
        attribute validatedPackages : AdaptedPackage[0..*] ordered;
        attribute totalCoverage : CustomUnits::Percent;
        attribute deploymentTimestamp : DateTime;
    }

    // ============================================================
    // Port Definitions
    // ============================================================

    port def PlatformDataOut {
        out snapshot : PlatformEcosystemSnapshot;
    }

    port def PlatformDataIn {
        in snapshot : PlatformEcosystemSnapshot;
    }

    port def AnalysisResultOut {
        out result : FragmentationAnalysisResult;
    }

    port def AnalysisResultIn {
        in result : FragmentationAnalysisResult;
    }

    port def AdaptationRequestOut {
        out request : AdaptationRequest;
    }

    port def AdaptationRequestIn {
        in request : AdaptationRequest;
    }

    port def AdaptedPackageOut {
        out pkg : AdaptedPackage;
    }

    port def AdaptedPackageIn {
        in pkg : AdaptedPackage;
    }

    port def ValidationReportOut {
        out report : ValidationReport;
    }

    port def ValidationReportIn {
        in report : ValidationReport;
    }

    port def DeploymentOut {
        out manifest : DeploymentManifest;
    }

    // ============================================================
    // Functional Module Definitions
    // ============================================================

    part def PlatformDiscoveryModule {
        port dataOut : PlatformDataOut;

        attribute scanInterval : CustomUnits::ScanIntervalHours = 24.0;
        attribute supportedPlatformTypes : String[0..*] = {"Android", "WebBrowser", "IoT", "DesktopOS"};

        perform action scanEcosystem {
            in scanTypes : String[0..*];
            out snapshot : PlatformEcosystemSnapshot;
        }

        perform action gatherPlatformData {
            in platformName : String;
            out platformData : PlatformData;
        }
    }

    part def FragmentationAnalysisModule {
        port dataIn : PlatformDataIn;
        port resultOut : AnalysisResultOut;

        attribute fragmentationThreshold : CustomUnits::FragmentationIndex = 60.0;
        attribute criticalPlatformUserBaseMin : CustomUnits::UserCount = 100000;

        perform action analyzeFragmentation {
            in snapshot : PlatformEcosystemSnapshot;
            out result : FragmentationAnalysisResult;
        }

        perform action calculateFragmentationScore {
            in platforms : PlatformData[0..*];
            out score : CustomUnits::FragmentationIndex;
        }

        perform action identifyCriticalPlatforms {
            in platforms : PlatformData[0..*];
            out criticalPlatforms : PlatformData[0..*];
        }
    }

    part def ComponentAdaptationModule {
        port requestIn : AdaptationRequestIn;
        port packageOut : AdaptedPackageOut;

        attribute adapterId : String;
        attribute supportedPlatformTypes : String[0..*];

        perform action generateAdaptedPackage {
            in request : AdaptationRequest;
            out pkg : AdaptedPackage;
        }

        perform action transformComponent {
            in originalComponent : ApplicationComponent;
            in targetPlatform : PlatformData;
            out adaptedComponent : ApplicationComponent;
        }
    }

    part def CompatibilityValidationModule {
        port packageIn : AdaptedPackageIn;
        port reportOut : ValidationReportOut;
        port deploymentOut : DeploymentOut;

        perform action validatePackage {
            in pkg : AdaptedPackage;
            out report : ValidationReport;
        }

        perform action runFunctionalTests {
            in pkg : AdaptedPackage;
            out passed : Boolean;
        }

        perform action runCompatibilityTests {
            in pkg : AdaptedPackage;
            out passed : Boolean;
        }

        perform action calculateCoverage {
            in validatedPackages : AdaptedPackage[0..*];
            in totalUserBase : CustomUnits::UserCount;
            out coverage : CustomUnits::Percent;
        }

        perform action generateDeploymentManifest {
            in validatedPackages : AdaptedPackage[0..*];
            in coverage : CustomUnits::Percent;
            out manifest : DeploymentManifest;
        }
    }

    // ============================================================
    // System Lifecycle State Machine
    // ============================================================

    state def FragmentationManagementLifecycle {
        attribute fragmentationThreshold : CustomUnits::FragmentationIndex = 60.0;

        entry action {
            // Initialize system
        }

        state monitoring {
            entry action {
                // Begin scanning platform ecosystem
            }
            perform action monitorEcosystem {
                out snapshot : PlatformEcosystemSnapshot;
            }
        }

        state analyzing {
            entry action {
                // Analyze platform fragmentation
            }
            perform action analyzeSnapshot {
                in snapshot : PlatformEcosystemSnapshot;
                out result : FragmentationAnalysisResult;
            }
        }

        state adapting {
            entry action {
                // Generate adapted packages for critical platforms
            }
            perform action adaptComponents {
                in criticalPlatforms : PlatformData[0..*];
                out adaptedPackages : AdaptedPackage[0..*];
            }
        }

        state validating {
            entry action {
                // Validate adapted packages
            }
            perform action validateAdaptedPackages {
                in adaptedPackages : AdaptedPackage[0..*];
                out validationReports : ValidationReport[0..*];
            }
        }

        state deploying {
            entry action {
                // Deploy validated packages
            }
            perform action deployValidatedPackages {
                in validationReports : ValidationReport[0..*];
                out manifest : DeploymentManifest;
            }
        }

        transition monitoring_to_analyzing
            first monitoring
            if snapshotReceived
            to analyzing;

        transition analyzing_to_adapting
            first analyzing
            if analysisResult.thresholdExceeded == true
            to adapting;

        transition analyzing_to_monitoring
            first analyzing
            if analysisResult.thresholdExceeded == false
            to monitoring;

        transition adapting_to_validating
            first adapting
            if adaptationComplete
            to validating;

        transition validating_to_deploying
            first validating
            if allPackagesValid
            to deploying;

        transition validating_to_adapting
            first validating
            if somePackagesInvalid
            to adapting;

        transition deploying_to_monitoring
            first deploying
            if deploymentComplete
            to monitoring;
    }

    // ============================================================
    // System Definition
    // ============================================================

    part def FragmentationManagementSystem {
        attribute systemId : String;
        attribute systemName : String = "Platform Fragmentation Management System";

        port ecosystemInput : PlatformDataIn;
        port deploymentOutput : DeploymentOut;

        part discovery : PlatformDiscoveryModule {
            redef scanInterval = 12.0;
        }

        part analysis : FragmentationAnalysisModule {
            redef fragmentationThreshold = 55.0;
            redef criticalPlatformUserBaseMin = 50000;
        }

        part adapters : ComponentAdaptationModule[1..*] {
            attribute adapterId : String;
        }

        part validation : CompatibilityValidationModule;

        // Connections between modules
        connect discovery.dataOut to analysis.dataIn;
        connect analysis.resultOut to adapters.requestIn;
        connect adapters.packageOut to validation.packageIn;
        connect validation.reportOut to validation.deploymentOut;
        connect validation.deploymentOut to deploymentOutput;

        // Lifecycle behavior
        exhibit FragmentationManagementLifecycle {
            redef fragmentationThreshold = 55.0;
        }
    }

    // ============================================================
    // Requirements
    // ============================================================

    requirement def PlatformCompatibilityRequirement {
        attribute id : String = "PCR-001";
        attribute text : String = "The system shall ensure the application maintains broad compatibility across diverse target platforms.";
    }

    requirement def EcosystemMonitoringRequirement {
        attribute id : String = "EMR-002";
        attribute text : String = "The system shall continuously monitor the platform ecosystem and identify all platforms currently in use.";
        attribute scanIntervalMax : CustomUnits::ScanIntervalHours = 24.0;
    }

    requirement def FragmentationAnalysisRequirement {
        attribute id : String = "FAR-003";
        attribute text : String = "The system shall calculate a fragmentation score and identify critical platforms based on user base size.";
        attribute minCriticalUserBase : CustomUnits::UserCount = 100000;
    }

    requirement def ComponentAdaptationRequirement {
        attribute id : String = "CAR-004";
        attribute text : String = "The system shall automatically generate adapted software packages tailored to specific target platforms when fragmentation exceeds the threshold.";
        attribute maxAdaptationTime : Time = 3600 [s];
    }

    requirement def CompatibilityValidationRequirement {
        attribute id : String = "CVR-005";
        attribute text : String = "The system shall validate adapted packages for functional correctness and platform compatibility, and calculate resulting user base coverage.";
        attribute minCoverageTarget : CustomUnits::Percent = 90.0;
    }

    requirement def LifecycleContinuityRequirement {
        attribute id : String = "LCR-006";
        attribute text : String = "The system shall operate through a continuous lifecycle of monitoring, analyzing, adapting, validating, and deploying, returning to monitoring after each cycle.";
    }

    requirement def MultiAdapterConcurrencyRequirement {
        attribute id : String = "MAC-007";
        attribute text : String = "The system shall support multiple component adaptation modules operating concurrently.";
        attribute minConcurrentAdapters : Integer = 2;
    }

    // Requirement satisfaction
    satisfaction satisfy PlatformCompatibilityRequirement by FragmentationManagementSystem;
    satisfaction satisfy EcosystemMonitoringRequirement by PlatformDiscoveryModule;
    satisfaction satisfy FragmentationAnalysisRequirement by FragmentationAnalysisModule;
    satisfaction satisfy ComponentAdaptationRequirement by ComponentAdaptationModule;
    satisfaction satisfy CompatibilityValidationRequirement by CompatibilityValidationModule;
    satisfaction satisfy LifecycleContinuityRequirement by FragmentationManagementLifecycle;
    satisfaction satisfy MultiAdapterConcurrencyRequirement by FragmentationManagementSystem::adapters;

    // ============================================================
    // Instantiated System
    // ============================================================

    part fragmentationManagementSystemInstance : FragmentationManagementSystem {
        redef systemId = "PFMS-2024-001";
        redef systemName = "Global Platform Fragmentation Manager";

        part discovery {
            redef scanInterval = 6.0;
            redef supportedPlatformTypes = {"Android", "WebBrowser", "IoT", "DesktopOS", "MobileOS"};
        }

        part analysis {
            redef fragmentationThreshold = 50.0;
            redef criticalPlatformUserBaseMin = 25000;
        }

        part adapters[3] {
            attribute adapterId = {"Adapter-Android", "Adapter-Web", "Adapter-IoT"};
            attribute supportedPlatformTypes = {{"Android", "MobileOS"}, {"WebBrowser", "DesktopOS"}, {"IoT"}};
        }

        part validation {
            // default configuration
        }
    }
}
