package EPL2_0_Based_OpenSourcePlatform {

    import ScalarValues::*;
    import ISQ::*;

    attribute def VersionString : String;
    attribute def SPDXIdentifier : String;
    attribute def URI : String;
    attribute def Hash256 : String;

    enum def ComplianceState {
        enum pending;
        enum compliant;
        enum nonCompliant;
        enum blocked;
    }

    enum def DistributionMode {
        enum source;
        enum binary;
        enum sourceAndBinary;
    }

    enum def ComponentRole {
        enum coreRuntime;
        enum extension;
        enum documentation;
        enum testAsset;
        enum buildTool;
    }

    item def SourceCodePackage {
        attribute name : String;
        attribute version : VersionString;
        attribute repositoryUrl : URI;
        attribute commitHash : Hash256;
        attribute licenseId : SPDXIdentifier = "EPL-2.0";
        attribute role : ComponentRole;
    }

    item def BinaryArtifact {
        attribute name : String;
        attribute version : VersionString;
        attribute checksum : Hash256;
        attribute licenseId : SPDXIdentifier = "EPL-2.0";
        attribute size : MassValue;
    }

    item def LicenseNotice {
        attribute licenseName : String = "Eclipse Public License 2.0";
        attribute spdxId : SPDXIdentifier = "EPL-2.0";
        attribute canonicalUrl : URI = "https://www.eclipse.org/legal/epl-2.0/";
        attribute copyrightText : String;
        attribute sourceAvailabilityStatement : String;
    }

    item def ContributionRecord {
        attribute contributorName : String;
        attribute contributionId : String;
        attribute receivedAt : DateTime;
        attribute accepted : Boolean;
        attribute licenseId : SPDXIdentifier = "EPL-2.0";
    }

    item def ComplianceReport {
        attribute generatedAt : DateTime;
        attribute state : ComplianceState;
        attribute findingCount : Integer;
        attribute distributionMode : DistributionMode;
    }

    item def PlatformRequest {
        attribute requestId : String;
        attribute command : String;
        attribute payloadSize : MassValue;
    }

    item def PlatformResponse {
        attribute requestId : String;
        attribute statusCode : Integer;
        attribute summary : String;
    }

    port def SourcePort {
        out sourcePackage : SourceCodePackage;
        in contribution : ContributionRecord;
    }

    port def ArtifactPort {
        out artifact : BinaryArtifact;
    }

    port def NoticePort {
        out notice : LicenseNotice;
    }

    port def CompliancePort {
        in sourcePackage : SourceCodePackage;
        in artifact : BinaryArtifact;
        in notice : LicenseNotice;
        out report : ComplianceReport;
    }

    port def ServicePort {
        in request : PlatformRequest;
        out response : PlatformResponse;
    }

    action def ValidateEPL2Compliance {
        in sourcePackage : SourceCodePackage;
        in notice : LicenseNotice;
        out report : ComplianceReport;

        first start;
        then verifySPDX;
        then verifyNotice;
        then verifySourceAvailability;
        then publishReport;
        then done;

        action verifySPDX;
        action verifyNotice;
        action verifySourceAvailability;
        action publishReport;
    }

    action def BuildRuntimeArtifact {
        in sourcePackage : SourceCodePackage;
        out artifact : BinaryArtifact;

        first prepareBuild;
        then compile;
        then packageBinary;
        then attachLicenseMetadata;
        then complete;

        action prepareBuild;
        action compile;
        action packageBinary;
        action attachLicenseMetadata;
    }

    action def ProcessPlatformRequest {
        in request : PlatformRequest;
        out response : PlatformResponse;

        first acceptRequest;
        then executeCoreFunction;
        then recordOperation;
        then returnResponse;

        action acceptRequest;
        action executeCoreFunction;
        action recordOperation;
        action returnResponse;
    }

    state def ComplianceLifecycle {
        entry; then Draft;

        state Draft;
        state Reviewing;
        state Approved;
        state RemediationRequired;
        state ReleaseBlocked;
        state Released;

        transition Draft_to_Reviewing
            first Draft
            accept submitForReview
            then Reviewing;

        transition Reviewing_to_Approved
            first Reviewing
            accept allLicenseObligationsSatisfied
            then Approved;

        transition Reviewing_to_RemediationRequired
            first Reviewing
            accept missingNoticeOrSourceOffer
            then RemediationRequired;

        transition RemediationRequired_to_Reviewing
            first RemediationRequired
            accept remediationCompleted
            then Reviewing;

        transition RemediationRequired_to_ReleaseBlocked
            first RemediationRequired
            accept remediationDeadlineMissed
            then ReleaseBlocked;

        transition Approved_to_Released
            first Approved
            accept releasePublished
            then Released;
    }

    part def EPL2LicensePolicy {
        attribute licenseName : String = "Eclipse Public License 2.0";
        attribute spdxId : SPDXIdentifier = "EPL-2.0";
        attribute permitsCommercialUse : Boolean = true;
        attribute permitsModification : Boolean = true;
        attribute permitsDistribution : Boolean = true;
        attribute requiresLicenseNotice : Boolean = true;
        attribute requiresSourceAvailabilityForCoveredCode : Boolean = true;
        attribute providesPatentGrant : Boolean = true;
        attribute allowsSecondaryLicenseOption : Boolean = true;
        attribute primaryFunctionDescription : String =
            "Provide a high-level open-source software platform whose covered source code, binaries, notices, and contribution records are managed under Eclipse Public License 2.0 obligations.";
    }

    part def SourceRepository {
        port sourcePort : SourcePort;

        part coreSource : SourceCodePackage {
            attribute name = "EPL2PlatformCore";
            attribute version = "1.0.0";
            attribute repositoryUrl = "https://example.org/epl2-platform/core";
            attribute commitHash = "8d3f4a3ad2b7a9d6f6f88a8b5a66b2c4390b78d5b6f87a6e7a5b1c9d2e0a1234";
            attribute role = ComponentRole::coreRuntime;
        }

        part extensionSource : SourceCodePackage {
            attribute name = "EPL2PlatformExtensionAPI";
            attribute version = "1.0.0";
            attribute repositoryUrl = "https://example.org/epl2-platform/extensions";
            attribute commitHash = "4b8fa2c49dbf6d4216bcb37425b8702d53f12e78987c7731a9a2c4b5d6e7f801";
            attribute role = ComponentRole::extension;
        }
    }

    part def BuildSubsystem {
        port sourceInput : SourcePort;
        port artifactOutput : ArtifactPort;

        perform buildCore : BuildRuntimeArtifact;

        part runtimeBinary : BinaryArtifact {
            attribute name = "epl2-platform-runtime";
            attribute version = "1.0.0";
            attribute checksum = "c91b42c217ef06d3e715c87e27ac5e7fd5e422d8f91e83c4522a70ac649e4d29";
            attribute licenseId = "EPL-2.0";
            attribute size = 42 [kg];
        }
    }

    part def NoticeManager {
        port noticePort : NoticePort;

        part primaryNotice : LicenseNotice {
            attribute copyrightText =
                "Copyright contributors to the EPL2 Platform.";
            attribute sourceAvailabilityStatement =
                "Covered source code is available from the public source repository and is distributed under Eclipse Public License 2.0.";
        }
    }

    part def ComplianceSubsystem {
        port compliancePort : CompliancePort;

        attribute currentState : ComplianceState = ComplianceState::pending;

        perform validation : ValidateEPL2Compliance;

        exhibit state complianceLifecycle : ComplianceLifecycle;

        part latestReport : ComplianceReport {
            attribute state = ComplianceState::compliant;
            attribute findingCount = 0;
            attribute distributionMode = DistributionMode::sourceAndBinary;
        }
    }

    part def RuntimeService {
        port servicePort : ServicePort;

        attribute availabilityTarget : Real = 99.9;
        attribute maximumResponseTime : TimeValue = 250 [ms];
        attribute supportedConcurrentUsers : Integer = 1000;

        perform requestProcessing : ProcessPlatformRequest;
    }

    part def ContributionRegistry {
        port contributionPort : SourcePort;

        part acceptedContribution : ContributionRecord {
            attribute contributorName = "Example Contributor";
            attribute contributionId = "CONTRIB-0001";
            attribute accepted = true;
            attribute licenseId = "EPL-2.0";
        }
    }

    part def EPL2BasedSoftwareSystem {
        attribute systemName : String = "EPL2 Based Open Source Platform";
        attribute primaryFunction : String =
            "Coordinate source distribution, binary publication, contribution intake, and runtime request processing for software governed by Eclipse Public License 2.0.";
        attribute releaseVersion : VersionString = "1.0.0";

        part licensePolicy : EPL2LicensePolicy;
        part repository : SourceRepository;
        part builder : BuildSubsystem;
        part noticeManager : NoticeManager;
        part compliance : ComplianceSubsystem;
        part runtime : RuntimeService;
        part contributions : ContributionRegistry;

        port publicService : ServicePort;

        connect repository.sourcePort to builder.sourceInput;
        connect repository.sourcePort to compliance.compliancePort;
        connect builder.artifactOutput to compliance.compliancePort;
        connect noticeManager.noticePort to compliance.compliancePort;
        connect contributions.contributionPort to repository.sourcePort;
        connect runtime.servicePort to publicService;
    }

    requirement def EPL2LicenseBasisRequirement {
        subject system : EPL2BasedSoftwareSystem;

        doc /* The system shall identify Eclipse Public License 2.0 as the governing license for covered source code and distributed artifacts. */

        require constraint {
            system.licensePolicy.spdxId == "EPL-2.0"
        }
    }

    requirement def NoticeDistributionRequirement {
        subject system : EPL2BasedSoftwareSystem;

        doc /* The system shall distribute a license notice with source and binary artifacts. */

        require constraint {
            system.licensePolicy.requiresLicenseNotice == true
        }
    }

    requirement def SourceAvailabilityRequirement {
        subject system : EPL2BasedSoftwareSystem;

        doc /* The system shall provide source availability information for covered code distributed under Eclipse Public License 2.0. */

        require constraint {
            system.licensePolicy.requiresSourceAvailabilityForCoveredCode == true
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : EPL2BasedSoftwareSystem;

        doc /* The system shall provide a high-level open-source platform function consisting of runtime service execution, source publication, binary artifact generation, compliance reporting, and contribution tracking. */

        require constraint {
            system.runtime.supportedConcurrentUsers >= 1000
        }
    }

    requirement def RuntimeResponsivenessRequirement {
        subject system : EPL2BasedSoftwareSystem;

        doc /* The runtime service shall respond to normal platform requests within the defined maximum response time. */

        require constraint {
            system.runtime.maximumResponseTime <= 250 [ms]
        }
    }

    requirement def ComplianceReleaseGateRequirement {
        subject system : EPL2BasedSoftwareSystem;

        doc /* The system shall block release when EPL 2.0 notice, source availability, or artifact metadata obligations are not satisfied. */

        require constraint {
            system.compliance.latestReport.findingCount == 0
        }
    }

    satisfy EPL2LicenseBasisRequirement by EPL2BasedSoftwareSystem::licensePolicy;
    satisfy NoticeDistributionRequirement by EPL2BasedSoftwareSystem::noticeManager;
    satisfy SourceAvailabilityRequirement by EPL2BasedSoftwareSystem::repository;
    satisfy PrimaryFunctionRequirement by EPL2BasedSoftwareSystem::runtime;
    satisfy RuntimeResponsivenessRequirement by EPL2BasedSoftwareSystem::runtime;
    satisfy ComplianceReleaseGateRequirement by EPL2BasedSoftwareSystem::compliance;
}