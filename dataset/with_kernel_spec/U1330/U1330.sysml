package EPL2ComplianceSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def LicenseHeader {
        attribute text : String;
    }
    attribute def CLASignature {
        attribute signerId : String;
        attribute valid : Boolean;
    }
    attribute def ComplianceStatus :> String;

    attribute def ContributionReceived;
    attribute def ContributionAccepted;
    attribute def SourceStored;
    attribute def PackageReady;
    attribute def ReportReady;
    attribute def DistributionComplete;

    item def Contribution {
        attribute contributorId : String;
        attribute submissionDate : String;
    }
    item def SourceCode {
        attribute filePath : String;
        attribute content : String;
        attribute licenseHeader : LicenseHeader;
    }
    item def ContributorLicenseAgreement {
        attribute signerId : String;
        attribute signatureDate : String;
        attribute status : String;
    }
    item def BinaryApplication {
        attribute packagePath : String;
        attribute version : String;
    }
    item def LicenseDocument {
        attribute content : String;
    }
    item def NoticeDocument {
        attribute content : String;
    }
    item def Checksum {
        attribute hash : String;
        attribute algorithm : String;
    }
    item def DistributablePackage {
        attribute binary : BinaryApplication;
        attribute licenseDoc : LicenseDocument;
        attribute noticeDoc : NoticeDocument;
        attribute checksum : Checksum;
    }
    item def ComplianceReport {
        attribute status : ComplianceStatus;
        attribute findings : String[*];
    }

    action def CheckLicenseHeader {
        in sourceCode : SourceCode;
        out valid : Boolean;
    }
    action def VerifyCLA {
        in cla : ContributorLicenseAgreement;
        out isSigned : Boolean;
    }
    action def StoreSourceCode {
        in sourceCode : SourceCode;
        out stored : Boolean;
    }
    action def CompileSource {
        in sourceCode : SourceCode;
        out binary : BinaryApplication;
    }
    action def GenerateLicenseDoc {
        out licenseDoc : LicenseDocument;
    }
    action def GenerateNoticeDoc {
        out noticeDoc : NoticeDocument;
    }
    action def ComputeChecksum {
        in binary : BinaryApplication;
        out checksum : Checksum;
    }
    action def ValidateSourceDisclosure {
        in sourceCode : SourceCode;
        out disclosed : Boolean;
    }
    action def ValidateNotices {
        in licenseDoc : LicenseDocument;
        in noticeDoc : NoticeDocument;
        out valid : Boolean;
    }
    action def ValidatePatentRights {
        out valid : Boolean;
    }
    action def GenerateComplianceReport {
        in sourceDisclosed : Boolean;
        in noticesValid : Boolean;
        in patentsValid : Boolean;
        out report : ComplianceReport;
    }

    port def ContributionSubmissionPort {
        in contribution : Contribution;
        in sourceCode : SourceCode;
        in cla : ContributorLicenseAgreement;
    }
    port def AcceptedContributionPort {
        out acceptedSourceCode : SourceCode;
    }
    port def SourceCodePort {
        out sourceCode : SourceCode;
    }
    port def SourceCodeInputPort {
        in sourceCode : SourceCode;
    }
    port def DistributionPackagePort {
        out distributablePackage : DistributablePackage;
    }
    port def DistributionPackageInputPort {
        in distributablePackage : DistributablePackage;
    }
    port def ComplianceReportPort {
        out complianceReport : ComplianceReport;
    }

    part def ContributionProcessor {
        port contributionIn : ContributionSubmissionPort;
        port acceptedOut : AcceptedContributionPort;

        action processContribution {
            in contribution : Contribution;
            in sourceCode : SourceCode;
            in cla : ContributorLicenseAgreement;
            out acceptedSourceCode : SourceCode;

            action checkLicenseHeader : CheckLicenseHeader {
                in sourceCode = processContribution::sourceCode;
            }
            action verifyCLA : VerifyCLA {
                in cla = processContribution::cla;
            }
            action acceptStep {
                out acceptedSourceCode = processContribution::sourceCode;
            }

            first start;
            then checkLicenseHeader;
            then verifyCLA;
            then acceptStep;
            then done;
        }
    }

    part def SourceCodeRepository {
        port storeIn : SourceCodeInputPort;
        port retrieveOut : SourceCodePort;

        action storeContribution : StoreSourceCode {
            in sourceCode = storeIn.sourceCode;
        }
        action retrieveSource {
            out sourceCode : SourceCode;
        }
    }

    part def DistributionManager {
        port sourceIn : SourceCodeInputPort;
        port packageOut : DistributionPackagePort;

        action createDistribution {
            in sourceCode : SourceCode;
            out distributablePackage : DistributablePackage;

            action compile : CompileSource {
                in sourceCode = createDistribution::sourceCode;
            }
            action genLicense : GenerateLicenseDoc;
            action genNotice : GenerateNoticeDoc;
            action checksum : ComputeChecksum {
                in binary = compile.binary;
            }

            first start;
            then compile;
            then genLicense;
            then genNotice;
            then checksum;
            then done;
        }
    }

    part def ComplianceValidator {
        port sourceIn : SourceCodeInputPort;
        port packageIn : DistributionPackageInputPort;
        port reportOut : ComplianceReportPort;

        action validateCompliance {
            in sourceCode : SourceCode;
            in distributablePackage : DistributablePackage;
            out complianceReport : ComplianceReport;

            action validateSource : ValidateSourceDisclosure {
                in sourceCode = validateCompliance::sourceCode;
            }
            action validateNotices : ValidateNotices {
                in licenseDoc = validateCompliance::distributablePackage.licenseDoc;
                in noticeDoc = validateCompliance::distributablePackage.noticeDoc;
            }
            action validatePatents : ValidatePatentRights;
            action generateReport : GenerateComplianceReport {
                in sourceDisclosed = validateSource.disclosed;
                in noticesValid = validateNotices.valid;
                in patentsValid = validatePatents.valid;
                out complianceReport = validateCompliance::complianceReport;
            }

            first start;
            then validateSource;
            then validateNotices;
            then validatePatents;
            then generateReport;
            then done;
        }
    }

    part def EPL2LifecycleSystem {
        port externalContributionIn : ContributionSubmissionPort;
        port externalPackageOut : DistributionPackagePort;
        port externalReportOut : ComplianceReportPort;

        part contributionProcessor : ContributionProcessor;
        part sourceCodeRepository : SourceCodeRepository;
        part distributionManager : DistributionManager;
        part complianceValidator : ComplianceValidator;

        bind externalContributionIn = contributionProcessor.contributionIn;
        bind externalPackageOut = distributionManager.packageOut;
        bind externalReportOut = complianceValidator.reportOut;

        flow acceptedContributionFlow of SourceCode
            from contributionProcessor.acceptedOut.acceptedSourceCode
            to sourceCodeRepository.storeIn.sourceCode;

        flow sourceCodeToDistributionFlow of SourceCode
            from sourceCodeRepository.retrieveOut.sourceCode
            to distributionManager.sourceIn.sourceCode;

        flow sourceCodeToValidationFlow of SourceCode
            from sourceCodeRepository.retrieveOut.sourceCode
            to complianceValidator.sourceIn.sourceCode;

        flow packageToValidationFlow of DistributablePackage
            from distributionManager.packageOut.distributablePackage
            to complianceValidator.packageIn.distributablePackage;
    }

    state def LifecycleStates {
        entry; then idle;
        state idle;
        accept ContributionReceived then processing;
        state processing;
        accept ContributionAccepted then storing;
        state storing;
        accept SourceStored then packaging;
        state packaging;
        accept PackageReady then validating;
        state validating;
        accept ReportReady then distributing;
        state distributing;
        accept DistributionComplete then idle;
    }

    requirement def EPL2ComplianceRequirement {
        attribute id : String;
        attribute description : String;
    }

    requirement Req_LicenseHeaderPresence :> EPL2ComplianceRequirement {
        doc /* All source files must contain the EPL 2.0 license header. */
    }
    requirement Req_CLASigned :> EPL2ComplianceRequirement {
        doc /* Contributors must sign a valid Contributor License Agreement before code acceptance. */
    }
    requirement Req_SourceDisclosure :> EPL2ComplianceRequirement {
        doc /* Source code must be made available upon distribution. */
    }
    requirement Req_NoticeInclusion :> EPL2ComplianceRequirement {
        doc /* Distributions must include official license and notice documents. */
    }
    requirement Req_PatentRights :> EPL2ComplianceRequirement {
        doc /* Patent rights must be handled as stipulated in EPL 2.0 Section 6. */
    }
    requirement Req_ChecksumIntegrity :> EPL2ComplianceRequirement {
        doc /* Distributable packages must include a checksum for integrity verification. */
    }

    satisfy Req_LicenseHeaderPresence by ContributionProcessor::processContribution;
    satisfy Req_CLASigned by ContributionProcessor::processContribution;
    satisfy Req_SourceDisclosure by ComplianceValidator::validateCompliance;
    satisfy Req_NoticeInclusion by DistributionManager::createDistribution;
    satisfy Req_PatentRights by ComplianceValidator::validateCompliance;
    satisfy Req_ChecksumIntegrity by DistributionManager::createDistribution;
}
