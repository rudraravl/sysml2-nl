package EPLComplianceSystem {

    import ScalarValues::*;

    package Units {
        unit def Count;
        unit def Byte;
        unit def Millisecond;
    }

    // ---- Value types ----
    value type FileCount :> Integer { unit Units::Count; }
    value type PackageSize :> Integer { unit Units::Byte; }
    value type ProcessingTime :> Integer { unit Units::Millisecond; }
    value type ChecksumValue :> String;
    value type VersionString :> String;
    value type ContributorId :> String;
    value type FilePath :> String;

    // ---- Enumerations ----
    enum ContributionStatus { pending, validated, accepted, rejected }
    enum ComplianceStatus { compliant, nonCompliant, pendingReview }
    enum DistributionStatus { idle, compiling, generatingDocs, bundling, verifying, completed, failed }
    enum HeaderCheckResult { valid, missing, malformed }

    // ---- Item definitions ----
    item def SourceFile {
        attribute path : FilePath;
        attribute headerResult : HeaderCheckResult;
    }
    item def Contributor {
        attribute id : ContributorId;
        attribute claSigned : Boolean;
    }
    item def Contribution {
        attribute id : String;
        attribute contributor : Contributor;
        attribute files : SourceFile[*];
        attribute status : ContributionStatus;
    }
    item def CLADocument {
        attribute contributorId : ContributorId;
        attribute signed : Boolean;
    }
    item def BinaryApplication {
        attribute version : VersionString;
        attribute size : PackageSize;
    }
    item def LicenseDocument {
        attribute licenseName : String = "Eclipse Public License 2.0";
    }
    item def NoticeDocument {
        attribute contents : String;
    }
    item def DistributablePackage {
        attribute version : VersionString;
        attribute binary : BinaryApplication;
        attribute license : LicenseDocument;
        attribute notice : NoticeDocument;
        attribute checksum : ChecksumValue;
        attribute size : PackageSize;
    }
    item def ComplianceReport {
        attribute sourceDisclosed : Boolean;
        attribute noticesIncluded : Boolean;
        attribute patentRightsHandled : Boolean;
        attribute overall : ComplianceStatus;
    }
    item def PatentDisclosure {
        attribute disclosed : Boolean;
    }
    item def ReleaseRequest {
        attribute version : VersionString;
    }

    // ---- Requirements ----
    requirement def EPLComplianceRequirement {
        doc "The system shall ensure full compliance with the Eclipse Public License (EPL) 2.0 throughout development, contribution, and distribution."
    }
    requirement def LicenseHeaderRequirement :> EPLComplianceRequirement {
        doc "Each source file shall contain the correct EPL 2.0 license header."
        subject sourceFile : SourceFile;
        predicate :>> sourceFile.headerResult == HeaderCheckResult::valid;
    }
    requirement def CLARequirement :> EPLComplianceRequirement {
        doc "Each contributor shall have a signed Contributor License Agreement on file."
        subject contributor : Contributor;
        predicate :>> contributor.claSigned == true;
    }
    requirement def SourceDisclosureRequirement :> EPLComplianceRequirement {
        doc "Source code shall be properly disclosed for all distributed software."
    }
    requirement def LegalNoticesRequirement :> EPLComplianceRequirement {
        doc "All distributions shall include the required EPL 2.0 license and notice documents."
    }
    requirement def PatentRightsRequirement :> EPLComplianceRequirement {
        doc "Patent rights shall be handled as stipulated by EPL 2.0."
    }
    requirement def PackageIntegrityRequirement :> EPLComplianceRequirement {
        doc "Each distributable package shall have a verified checksum."
    }

    // ---- Port definitions ----
    port def ContributionInputPort {
        in item contributions : Contribution[*];
    }
    port def ContributionDecisionPort {
        out item accepted : Contribution[*];
        out item rejected : Contribution[*];
    }
    port def RepositoryWritePort {
        in item files : SourceFile[*];
    }
    port def RepositoryReadPort {
        out item files : SourceFile[*];
    }
    port def ReleaseRequestPort {
        in item requests : ReleaseRequest[*];
    }
    port def PackageOutputPort {
        out item packages : DistributablePackage[*];
    }
    port def ComplianceMonitorPort {
        in item sourceFiles : SourceFile[*];
        in item packages : DistributablePackage[*];
    }
    port def ComplianceReportPort {
        out item reports : ComplianceReport[*];
    }
    port def FeedbackPort {
        in item reports : ComplianceReport[*];
    }

    // ---- Contribution Processor ----
    part def ContributionProcessor {

        port contributionIn : ContributionInputPort;
        port decisionOut : ContributionDecisionPort;
        port repoWrite : RepositoryWritePort;
        port feedbackIn : FeedbackPort;

        attribute processedCount : FileCount = 0;
        attribute acceptedCount : FileCount = 0;
        attribute rejectedCount : FileCount = 0;
        attribute avgProcessingTime : ProcessingTime = 0;

        requirement headerReq : LicenseHeaderRequirement;
        requirement claReq : CLARequirement;

        part headerChecker {
            attribute lastResult : HeaderCheckResult = HeaderCheckResult::missing;
            action checkHeader {
                in file : SourceFile;
                out result : HeaderCheckResult;
            }
        }

        part claVerifier {
            attribute lastValid : Boolean = false;
            action verifyCLA {
                in contributor : Contributor;
                out valid : Boolean;
            }
        }

        action processContribution {
            in contribution : Contribution;
            out accepted : Contribution;
            out rejected : Contribution;
            perform headerChecker.checkHeader;
            perform claVerifier.verifyCLA;
        }

        state processorBehavior {
            entry; then idle;
            state idle {
                doc "Awaiting incoming contributions.";
            }
            state validating {
                doc "Checking license headers and CLA status.";
            }
            state accepting {
                doc "Forwarding accepted contribution to repository."
                do send Contribution via decisionOut;
            }
            state rejecting {
                doc "Returning rejected contribution to submitter."
                do send Contribution via decisionOut;
            }
            transition idle_to_validating
                first idle
                then validating
                accept Contribution via contributionIn;
            transition validating_to_accepting
                first validating
                then accepting
                when headerChecker.lastResult == HeaderCheckResult::valid and claVerifier.lastValid;
            transition validating_to_rejecting
                first validating
                then rejecting
                when headerChecker.lastResult != HeaderCheckResult::valid or not claVerifier.lastValid;
            transition accepting_to_idle
                first accepting
                then idle;
            transition rejecting_to_idle
                first rejecting
                then idle;
        }

        satisfy headerReq;
        satisfy claReq;
    }

    // ---- Source Code Repository ----
    part def SourceCodeRepository {

        port repoWrite : RepositoryWritePort;
        port repoRead : RepositoryReadPort;

        attribute fileCount : FileCount = 0;
        attribute currentVersion : VersionString = "0.0.0";

        item storedFiles : SourceFile[*] = ();

        action store {
            in files : SourceFile[*];
            then assign storedFiles = storedFiles->union(files);
            then assign fileCount = storedFiles->size();
        }

        action retrieve {
            out files : SourceFile[*] = storedFiles;
        }

        action tagVersion {
            in version : VersionString;
            then assign currentVersion = version;
        }

        state repositoryBehavior {
            entry; then ready;
            state ready;
            state storing;
            state retrieving;
            transition ready_to_storing
                first ready
                then storing
                accept SourceFile via repoWrite;
            transition storing_to_ready
                first storing
                then ready;
            transition ready_to_retrieving
                first ready
                then retrieving
                when repoRead.requested;
            transition retrieving_to_ready
                first retrieving
                then ready;
        }
    }

    // ---- Distribution Manager ----
    part def DistributionManager {

        port releaseRequest : ReleaseRequestPort;
        port repoRead : RepositoryReadPort;
        port packageOut : PackageOutputPort;

        attribute status : DistributionStatus = DistributionStatus::idle;
        attribute lastChecksum : ChecksumValue = "";
        attribute lastPackageSize : PackageSize = 0;

        requirement integrityReq : PackageIntegrityRequirement;

        part compiler {
            action compile {
                in source : SourceFile[*];
                out binary : BinaryApplication;
            }
        }

        part documentGenerator {
            action generateLicense {
                out doc : LicenseDocument;
            }
            action generateNotice {
                out doc : NoticeDocument;
            }
        }

        part packager {
            action bundle {
                in binary : BinaryApplication;
                in license : LicenseDocument;
                in notice : NoticeDocument;
                out pkg : DistributablePackage;
            }
            action calculateChecksum {
                in pkg : DistributablePackage;
                out sum : ChecksumValue;
            }
        }

        action produceRelease {
            in request : ReleaseRequest;
            in source : SourceFile[*];
            out package : DistributablePackage;
            perform compiler.compile;
            perform documentGenerator.generateLicense;
            perform documentGenerator.generateNotice;
            perform packager.bundle;
            perform packager.calculateChecksum;
        }

        state distributionBehavior {
            entry; then waiting;
            state waiting {
                doc "Idle, awaiting release request."
            }
            state compiling {
                doc "Compiling source into binary application."
            }
            state generatingDocs {
                doc "Generating EPL 2.0 license and notice documents."
            }
            state bundling {
                doc "Bundling binary and documents into distributable package."
            }
            state verifying {
                doc "Calculating and verifying package checksum."
            }
            state completed {
                doc "Package ready for distribution."
                do send DistributablePackage via packageOut;
            }
            state failed {
                doc "Release process failed."
            }
            transition waiting_to_compiling
                first waiting
                then compiling
                accept ReleaseRequest via releaseRequest;
            transition compiling_to_generatingDocs
                first compiling
                then generatingDocs
                when compiler.compile.done;
            transition generatingDocs_to_bundling
                first generatingDocs
                then bundling
                when documentGenerator.generateLicense.done and documentGenerator.generateNotice.done;
            transition bundling_to_verifying
                first bundling
                then verifying
                when packager.bundle.done;
            transition verifying_to_completed
                first verifying
                then completed
                when packager.calculateChecksum.done;
            transition completed_to_waiting
                first completed
                then waiting;
            transition compiling_to_failed
                first compiling
                then failed
                when compiler.compile.failed;
            transition failed_to_waiting
                first failed
                then waiting;
        }

        satisfy integrityReq;
    }

    // ---- Compliance Validator ----
    part def ComplianceValidator {

        port monitorIn : ComplianceMonitorPort;
        port reportOut : ComplianceReportPort;

        attribute status : ComplianceStatus = ComplianceStatus::pendingReview;
        attribute reportsGenerated : FileCount = 0;

        requirement sourceDisclosureReq : SourceDisclosureRequirement;
        requirement legalNoticesReq : LegalNoticesRequirement;
        requirement patentRightsReq : PatentRightsRequirement;

        part sourceDisclosureChecker {
            attribute sourceDisclosed : Boolean = false;
            action checkDisclosure {
                in files : SourceFile[*];
                in pkg : DistributablePackage;
                out result : Boolean;
            }
        }

        part legalNoticesChecker {
            attribute noticesIncluded : Boolean = false;
            action checkNotices {
                in pkg : DistributablePackage;
                out result : Boolean;
            }
        }

        part patentRightsChecker {
            attribute patentRightsHandled : Boolean = false;
            action checkPatentRights {
                in pkg : DistributablePackage;
                out result : Boolean;
            }
        }

        action validateCompliance {
            in sourceFiles : SourceFile[*];
            in packages : DistributablePackage[*];
            out report : ComplianceReport;
            perform sourceDisclosureChecker.checkDisclosure;
            perform legalNoticesChecker.checkNotices;
            perform patentRightsChecker.checkPatentRights;
        }

        state validationBehavior {
            entry; then monitoring;
            state monitoring {
                doc "Continuously monitoring project artifacts."
            }
            state evaluating {
                doc "Evaluating EPL 2.0 obligations."
            }
            state reporting {
                doc "Emitting compliance report."
                do send ComplianceReport via reportOut;
            }
            transition monitoring_to_evaluating
                first monitoring
                then evaluating
                when monitorIn.sourceFiles->notEmpty() or monitorIn.packages->notEmpty();
            transition evaluating_to_reporting
                first evaluating
                then reporting
                when sourceDisclosureChecker.sourceDisclosed and legalNoticesChecker.noticesIncluded and patentRightsChecker.patentRightsHandled;
            transition reporting_to_monitoring
                first reporting
                then monitoring;
        }

        satisfy sourceDisclosureReq;
        satisfy legalNoticesReq;
        satisfy patentRightsReq;
    }

    // ---- Top-level system ----
    part def EPLComplianceLifecycleSystem {

        requirement masterReq : EPLComplianceRequirement;

        part contributionProcessor : ContributionProcessor;
        part sourceRepository : SourceCodeRepository;
        part distributionManager : DistributionManager;
        part complianceValidator : ComplianceValidator;

        connection contributionProcessor.repoWrite to sourceRepository.repoWrite;
        connection sourceRepository.repoRead to distributionManager.repoRead;
        connection sourceRepository.repoRead to complianceValidator.monitorIn;
        connection distributionManager.packageOut to complianceValidator.monitorIn;
        connection complianceValidator.reportOut to contributionProcessor.feedbackIn;

        satisfy masterReq by contributionProcessor;
        satisfy masterReq by sourceRepository;
        satisfy masterReq by distributionManager;
        satisfy masterReq by complianceValidator;
    }
}
