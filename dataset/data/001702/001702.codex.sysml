package GPL_Based_Software_System {
    import ScalarValues::*;
    import SI::*;

    attribute def DataSize {
        :> Real;
        unit = "MiB";
    }

    attribute def Duration {
        :> Real;
        unit = "s";
    }

    attribute def VersionNumber {
        :> String;
    }

    item def SourceFile {
        attribute path : String;
        attribute language : String;
        attribute size : DataSize;
        attribute copyrightNotice : String;
        attribute licenseHeaderPresent : Boolean;
    }

    item def SourceTree {
        attribute projectName : String;
        attribute version : VersionNumber;
        attribute totalSize : DataSize;
        attribute fileCount : Integer;
    }

    item def BuildArtifact {
        attribute artifactName : String;
        attribute version : VersionNumber;
        attribute binarySize : DataSize;
        attribute targetPlatform : String;
        attribute reproducibleBuild : Boolean;
    }

    item def LicenseText {
        attribute name : String = "GNU General Public License";
        attribute version : String = "GPL-3.0-or-later";
        attribute permitsUse : Boolean = true;
        attribute permitsModification : Boolean = true;
        attribute permitsRedistribution : Boolean = true;
        attribute requiresCorrespondingSource : Boolean = true;
        attribute requiresSameLicenseForDerivativeWorks : Boolean = true;
    }

    item def ComplianceReport {
        attribute reportId : String;
        attribute checkedVersion : VersionNumber;
        attribute sourceAvailable : Boolean;
        attribute licenseIncluded : Boolean;
        attribute noticesIncluded : Boolean;
        attribute copyleftSatisfied : Boolean;
    }

    item def UserRequest {
        attribute requestId : String;
        attribute requestedFunction : String;
    }

    item def ExecutionResult {
        attribute requestId : String;
        attribute success : Boolean;
        attribute elapsedTime : Duration;
        attribute summary : String;
    }

    port def UserServicePort {
        in item request : UserRequest;
        out item result : ExecutionResult;
    }

    port def SourceAccessPort {
        out item source : SourceTree;
        out item license : LicenseText;
    }

    port def BuildOutputPort {
        out item artifact : BuildArtifact;
    }

    port def CompliancePort {
        in item source : SourceTree;
        in item artifact : BuildArtifact;
        out item report : ComplianceReport;
    }

    part def GPLLicenseManager {
        attribute acceptedLicense : String = "GPL-3.0-or-later";
        port sourceAccess : SourceAccessPort;

        action publishLicenseAndSource {
            out item publishedLicense : LicenseText;
            out item publishedSource : SourceTree;
        }
    }

    part def SourceRepository {
        attribute defaultBranch : String = "main";
        attribute retainedHistoryYears : Real = 10.0;
        port sourceOut : SourceAccessPort;

        part licenseFile : LicenseText;
        part sourceTree : SourceTree;

        action provideCorrespondingSource {
            out item source : SourceTree;
            out item license : LicenseText;
        }
    }

    part def BuildService {
        attribute cleanBuildTimeLimit : Duration = 600.0;
        port sourceIn : SourceAccessPort;
        port artifactOut : BuildOutputPort;

        action compileAndPackage {
            in item source : SourceTree;
            out item artifact : BuildArtifact;
        }
    }

    part def ComplianceAuditor {
        port auditPort : CompliancePort;

        action verifyGPLCompliance {
            in item source : SourceTree;
            in item artifact : BuildArtifact;
            out item report : ComplianceReport;
        }
    }

    part def PrimaryApplicationRuntime {
        attribute primaryFunction : String =
            "Execute the application feature set for users while ensuring the complete corresponding source code and GPL license terms remain available with every distributed version.";

        port service : UserServicePort;

        action executeUserRequest {
            in item request : UserRequest;
            out item result : ExecutionResult;
        }

        state behavior RuntimeLifecycle {
            entry action initializeRuntime;

            state Idle;
            state ProcessingRequest;
            state ReturningResult;
            state ErrorHandling;

            transition initial then Idle;

            transition receiveRequest
                first Idle
                accept UserRequest
                then ProcessingRequest;

            transition requestCompleted
                first ProcessingRequest
                then ReturningResult;

            transition resultDelivered
                first ReturningResult
                then Idle;

            transition processingFailed
                first ProcessingRequest
                then ErrorHandling;

            transition errorReported
                first ErrorHandling
                then Idle;
        }
    }

    part def GPLBasedSoftwareSystem {
        attribute systemName : String = "GPL Based Software System";
        attribute highLevelPurpose : String =
            "Provide a redistributable software application whose primary function is delivered to users together with the freedoms and obligations defined by the GNU General Public License.";

        port userInterface : UserServicePort;
        port sourceDistribution : SourceAccessPort;
        port binaryDistribution : BuildOutputPort;
        port complianceInterface : CompliancePort;

        part repository : SourceRepository;
        part licenseManager : GPLLicenseManager;
        part builder : BuildService;
        part auditor : ComplianceAuditor;
        part runtime : PrimaryApplicationRuntime;

        connect userInterface to runtime.service;
        connect repository.sourceOut to builder.sourceIn;
        connect repository.sourceOut to sourceDistribution;
        connect licenseManager.sourceAccess to sourceDistribution;
        connect builder.artifactOut to binaryDistribution;
        connect repository.sourceOut to complianceInterface;
        connect builder.artifactOut to complianceInterface;
        connect complianceInterface to auditor.auditPort;

        action releaseGPLVersion {
            in item releaseSource : SourceTree;
            out item releaseArtifact : BuildArtifact;
            out item releaseReport : ComplianceReport;

            first compile : builder.compileAndPackage {
                in source = releaseSource;
                out artifact = releaseArtifact;
            }

            then audit : auditor.verifyGPLCompliance {
                in source = releaseSource;
                in artifact = releaseArtifact;
                out report = releaseReport;
            }
        }

        state behavior ReleaseLifecycle {
            state Draft;
            state SourceComplete;
            state Built;
            state ComplianceChecked;
            state Published;
            state Blocked;

            transition initial then Draft;

            transition sourceReady
                first Draft
                then SourceComplete;

            transition buildSucceeded
                first SourceComplete
                then Built;

            transition auditPassed
                first Built
                guard auditor.auditPort.report.copyleftSatisfied == true
                then ComplianceChecked;

            transition publishRelease
                first ComplianceChecked
                then Published;

            transition auditFailed
                first Built
                guard auditor.auditPort.report.copyleftSatisfied == false
                then Blocked;

            transition repairRelease
                first Blocked
                then Draft;
        }
    }

    requirement def GPLLicenseAvailabilityRequirement {
        subject system : GPLBasedSoftwareSystem;

        require constraint {
            system.sourceDistribution.license.requiresCorrespondingSource == true
        }

        doc /* Every distributed version shall include or provide access to the applicable GNU General Public License text. */
    }

    requirement def CorrespondingSourceRequirement {
        subject system : GPLBasedSoftwareSystem;

        require constraint {
            system.repository.sourceTree.fileCount > 0 and
            system.repository.sourceTree.totalSize > 0.0
        }

        doc /* The system shall make complete corresponding source code available for each distributed executable artifact. */
    }

    requirement def CopyleftPreservationRequirement {
        subject report : ComplianceReport;

        require constraint {
            report.licenseIncluded == true and
            report.sourceAvailable == true and
            report.noticesIncluded == true and
            report.copyleftSatisfied == true
        }

        doc /* The release shall preserve GPL obligations for modified and redistributed versions. */
    }

    requirement def PrimaryFunctionRequirement {
        subject runtime : PrimaryApplicationRuntime;

        require constraint {
            runtime.primaryFunction != ""
        }

        doc /* The runtime shall provide a clearly defined high-level primary function to users. */
    }

    requirement def ReproducibleBuildRequirement {
        subject artifact : BuildArtifact;

        require constraint {
            artifact.reproducibleBuild == true
        }

        doc /* Published artifacts should be produced from the published source tree by a documented build process. */
    }

    satisfy GPLLicenseAvailabilityRequirement by GPLBasedSoftwareSystem.licenseManager;
    satisfy CorrespondingSourceRequirement by GPLBasedSoftwareSystem.repository;
    satisfy CopyleftPreservationRequirement by GPLBasedSoftwareSystem.auditor;
    satisfy PrimaryFunctionRequirement by GPLBasedSoftwareSystem.runtime;
    satisfy ReproducibleBuildRequirement by GPLBasedSoftwareSystem.builder;
}