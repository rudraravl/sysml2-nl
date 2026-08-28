package PlatformFragmentationManagement {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    doc
    /*
     * This model describes a software management system that automatically
     * handles platform fragmentation by monitoring, analyzing, adapting,
     * and validating application components across diverse platforms.
     */

    attribute def Percentage :> Real;
    attribute def FragmentationScore :> Real;
    attribute def UserBase :> Integer;

    item def PlatformInfo {
        attribute platformName : String;
        attribute apiVersion : String;
        attribute marketShare : Percentage;
        attribute userBase : UserBase;
    }

    item def PlatformSet {
        attribute platforms : PlatformInfo[0..*];
    }

    item def FragmentationReport {
        attribute fragmentationScore : FragmentationScore;
        attribute criticalPlatforms : PlatformInfo[0..*];
        attribute threshold : FragmentationScore;
    }

    item def AdaptedPackage {
        attribute componentName : String;
        attribute targetPlatformName : String;
        attribute targetApiVersion : String;
        attribute buildId : String;
        attribute valid : Boolean;
    }

    item def ValidationReport {
        attribute pkg : AdaptedPackage;
        attribute compatible : Boolean;
        attribute coverage : Percentage;
    }

    port def PlatformDataOut {
        out platformSet : PlatformSet;
    }
    port def PlatformDataIn {
        in platformSet : PlatformSet;
    }
    port def FragmentationReportOut {
        out report : FragmentationReport;
    }
    port def FragmentationReportIn {
        in report : FragmentationReport;
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

    action scanPlatforms { out platformSet : PlatformSet; }
    action analyzeFragmentation { out report : FragmentationReport; }
    action adaptComponent { out pkg : AdaptedPackage; }
    action validatePackage { out report : ValidationReport; }
    action deployPackages { }

    part def PlatformDiscoveryModule {
        port platformDataOut : PlatformDataOut;
        attribute scanInterval : DurationValue = 24 [h];
    }

    part def FragmentationAnalysisModule {
        port platformDataIn : PlatformDataIn;
        port fragmentationReportOut : FragmentationReportOut;
        attribute fragmentationThreshold : FragmentationScore = 0.6;
    }

    part def ComponentAdaptationModule {
        port fragmentationReportIn : FragmentationReportIn;
        port adaptedPackageOut : AdaptedPackageOut;
        attribute originalComponentName : String = "AppCore";
    }

    part def CompatibilityValidationModule {
        port adaptedPackageIn : AdaptedPackageIn;
        port validationReportOut : ValidationReportOut;
        attribute totalUserBase : UserBase = 1000000;
    }

    requirement def MaintainCompatibility {
        doc /* The system shall ensure broad compatibility across fragmented platforms. */
        attribute minCoverage : Percentage = 80.0;
    }
    requirement def DiscoverPlatformsReq {
        doc /* The system shall scan the platform ecosystem and gather data. */
    }
    requirement def QuantifyFragmentationReq {
        doc /* The system shall calculate a fragmentation score and identify critical platforms. */
        attribute maxScore : FragmentationScore = 1.0;
    }
    requirement def AdaptComponentsReq {
        doc /* The system shall generate adapted packages for critical target platforms. */
    }
    requirement def ValidateCompatibilityReq {
        doc /* The system shall validate adapted packages and calculate resulting coverage. */
    }
    requirement def ContinuousLifecycleReq {
        doc /* The system shall operate through a continuous lifecycle. */
    }

    requirement maintainCompat : MaintainCompatibility;
    requirement discoverPlats : DiscoverPlatformsReq;
    requirement quantifyFrag : QuantifyFragmentationReq;
    requirement adaptComps : AdaptComponentsReq;
    requirement validateCompat : ValidateCompatibilityReq;
    requirement continuousLife : ContinuousLifecycleReq;

    part def FragmentationManagementSystem {
        attribute fragmentationThreshold : FragmentationScore = 0.6;
        attribute totalUserBase : UserBase = 1000000;

        part discovery : PlatformDiscoveryModule;
        part fragAnalysis : FragmentationAnalysisModule;
        part adaptation : ComponentAdaptationModule[1..*];
        part validation : CompatibilityValidationModule;

        connect discovery.platformDataOut to fragAnalysis.platformDataIn;
        connect fragAnalysis.fragmentationReportOut to adaptation.fragmentationReportIn;
        connect adaptation.adaptedPackageOut to validation.adaptedPackageIn;

        satisfy maintainCompat;
        satisfy continuousLife;

        state lifecycle {
            entry; then monitoring;

            state monitoring {
                do scanPlatforms;
            }
            accept after 24 [h]
                then analyzing;

            state analyzing {
                do analyzeFragmentation;
            }
            accept when analyzeFragmentation.report.fragmentationScore > fragmentationThreshold
                then adapting;
            accept when analyzeFragmentation.report.fragmentationScore <= fragmentationThreshold
                then monitoring;

            state adapting {
                do adaptComponent;
            }
            accept when adaptComponent.pkg.valid == true
                then validating;

            state validating {
                do validatePackage;
            }
            accept when validatePackage.report.compatible == true
                then deploying;
            accept when validatePackage.report.compatible == false
                then adapting;

            state deploying {
                do deployPackages;
            }
            accept after 1 [h]
                then monitoring;
        }
    }

    part managementSystem : FragmentationManagementSystem;
}
