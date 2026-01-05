package EclipsePublicLicenseSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import Metaobjects::SemanticMetadata;
    private import ModelingMetadata::*;
    
    metadata def LicenseMetadata {
        attribute licenseName : String;
        attribute version : String;
        attribute copyleftType : String;
        attribute allowsCommercialUse : Boolean;
        attribute requiresSourceDisclosure : Boolean;
        attribute grantsPatentRights : Boolean;
    }
    
    #LicenseMetadata {
        licenseName = "Eclipse Public License";
        version = "2.0";
        copyleftType = "weak";
        allowsCommercialUse = true;
        requiresSourceDisclosure = true;
        grantsPatentRights = true;
    }
    
    attribute def LicenseComplianceStatus {
        attribute isCompliant : Boolean;
        attribute hasRequiredNotice : Boolean;
        attribute sourceCodeAvailable : Boolean;
        attribute patentGrantsValid : Boolean;
    }
    
    attribute def ContributorRecord {
        attribute contributorName : String;
        attribute contributionDate : String;
        attribute contributionHash : String;
        attribute signedCLA : Boolean;
    }
    
    item def SourceCodeArtifact {
        attribute linesOfCode : Natural;
        attribute programmingLanguage : String;
        attribute licenseHeaderPresent : Boolean;
        attribute copyrightNotice : String;
    }
    
    item def BinaryDistribution {
        attribute binarySize : MassValue;
        attribute versionNumber : String;
        attribute checksumValue : String;
        attribute buildTimestamp : String;
    }
    
    item def LicenseNoticeDocument {
        attribute noticeText : String;
        attribute includesCopyrightStatement : Boolean;
        attribute includesDisclaimerText : Boolean;
        attribute includesPatentGrant : Boolean;
    }
    
    port def ComplianceVerificationPort {
        out attribute complianceStatus : LicenseComplianceStatus;
        in attribute verificationTrigger : Boolean;
    }
    
    port def ArtifactDistributionPort {
        out item binary : BinaryDistribution;
        out item notice : LicenseNoticeDocument;
        in attribute distributionRequest : Boolean;
    }
    
    port def ContributionIntakePort {
        in item sourceCode : SourceCodeArtifact;
        in attribute contributor : ContributorRecord;
        out attribute acceptanceDecision : Boolean;
    }
    
    port def SourceRepositoryPort {
        inout item sourceArtifacts : SourceCodeArtifact[*];
    }
    
    action def VerifyLicenseCompliance {
        in verificationRequest : Boolean;
        out status : LicenseComplianceStatus;
        
        first start;
        then action checkNoticePresence {
            out noticeFound : Boolean;
        }
        then action checkSourceAvailability {
            out sourceAvailable : Boolean;
        }
        then action checkPatentGrants {
            out patentGrantsValid : Boolean;
        }
        then action evaluateCompliance {
            in hasNotice : Boolean;
            in hasSource : Boolean;
            in hasPatentGrants : Boolean;
            out overallCompliance : Boolean;
        }
        then assign status := LicenseComplianceStatus {
            isCompliant = evaluateCompliance.overallCompliance;
            hasRequiredNotice = checkNoticePresence.noticeFound;
            sourceCodeAvailable = checkSourceAvailability.sourceAvailable;
            patentGrantsValid = checkPatentGrants.patentGrantsValid;
        }
        then done;
    }
    
    action def ProcessContribution {
        in sourceCode : SourceCodeArtifact;
        in contributor : ContributorRecord;
        out accepted : Boolean;
        
        first start;
        then action validateLicenseHeader {
            in code : SourceCodeArtifact;
            out headerValid : Boolean;
        }
        then action verifyCLA {
            in contributorInfo : ContributorRecord;
            out claValid : Boolean;
        }
        then decide;
            if validateLicenseHeader.headerValid and verifyCLA.claValid then acceptContribution;
            if not (validateLicenseHeader.headerValid and verifyCLA.claValid) then rejectContribution;
        action acceptContribution {
            action logContribution {
                in record : ContributorRecord;
            }
            then assign accepted := true;
        }
        action rejectContribution {
            then assign accepted := false;
        }
        then done;
    }
    
    action def PrepareDistribution {
        in distributionRequest : Boolean;
        out binary : BinaryDistribution;
        out notice : LicenseNoticeDocument;
        
        first start;
        then action compileBinary {
            out compiledBinary : BinaryDistribution;
        }
        then action generateLicenseNotice {
            out generatedNotice : LicenseNoticeDocument;
        }
        then action computeChecksum {
            in binaryArtifact : BinaryDistribution;
            out checksummedBinary : BinaryDistribution;
        }
        then action packageDistribution {
            in finalBinary : BinaryDistribution;
            in finalNotice : LicenseNoticeDocument;
            out packageComplete : Boolean;
        }
        then assign binary := computeChecksum.checksummedBinary;
        then assign notice := generateLicenseNotice.generatedNotice;
        then done;
    }
    
    state def SystemOperationalState {
        entry; then idle;
        
        state idle;
        state processingContributions;
        state verifyingCompliance;
        state distributingArtifacts;
        
        transition idleToProcessing {
            first idle;
            accept contributionReceived;
            then processingContributions;
        }
        
        transition processingToVerifying {
            first processingContributions;
            accept contributionProcessed;
            then verifyingCompliance;
        }
        
        transition verifyingToDistributing {
            first verifyingCompliance;
            accept complianceVerified;
            then distributingArtifacts;
        }
        
        transition distributingToIdle {
            first distributingArtifacts;
            accept distributionComplete;
            then idle;
        }
    }
    
    part def ComplianceValidator {
        port compliancePort : ComplianceVerificationPort;
        
        attribute validationCriteria {
            attribute requiresNotice : Boolean = true;
            attribute requiresSource : Boolean = true;
            attribute requiresPatentGrant : Boolean = true;
        }
        
        perform action validateCompliance : VerifyLicenseCompliance {
            in verificationRequest = compliancePort.verificationTrigger;
            out status;
        }
    }
    
    part def ContributionProcessor {
        port contributionPort : ContributionIntakePort;
        
        attribute contributionLog : ContributorRecord[*];
        
        perform action processIncomingContribution : ProcessContribution {
            in sourceCode = contributionPort.sourceCode;
            in contributor = contributionPort.contributor;
            out accepted;
        }
    }
    
    part def DistributionManager {
        port distributionPort : ArtifactDistributionPort;
        
        attribute distributionHistory : BinaryDistribution[*];
        
        perform action prepareAndDistribute : PrepareDistribution {
            in distributionRequest = distributionPort.distributionRequest;
            out binary;
            out notice;
        }
    }
    
    part def SourceCodeRepository {
        port repositoryPort : SourceRepositoryPort;
        
        attribute storedSources : SourceCodeArtifact[*];
        attribute totalCodeSize : Natural;
        
        action def StoreSourceCode {
            in newSource : SourceCodeArtifact;
            
            first start;
            then action validateSource {
                in source : SourceCodeArtifact;
                out valid : Boolean;
            }
            then decide;
                if validateSource.valid then addToRepository;
            action addToRepository {
                in source : SourceCodeArtifact;
            }
            then done;
        }
        
        perform action storeSource : StoreSourceCode {
            in newSource from repositoryPort.sourceArtifacts;
        }
    }
    
    requirement def EPLComplianceRequirement {
        doc /* 
            All software components must comply with Eclipse Public License 2.0 terms,
            including source code disclosure, license notice inclusion, copyleft provisions,
            and patent grant requirements.
        */
        
        require constraint sourceDisclosureRequired {
            doc /* Source code must be made available for all distributed binaries under EPL 2.0 */
        }
        
        require constraint licenseNoticeRequired {
            doc /* All distributions must include complete EPL 2.0 license notice and copyright statements */
        }
        
        require constraint copyleftEnforced {
            doc /* Derivative works and modifications must be released under EPL 2.0 */
        }
        
        require constraint patentGrantRequired {
            doc /* Contributors must grant patent license for their contributions as specified in EPL 2.0 */
        }
    }
    
    requirement def PrimarySystemFunction {
        doc /* 
            The Eclipse Public License System shall manage the complete lifecycle of
            EPL-licensed software, from contribution acceptance through compliant distribution,
            ensuring all license terms are satisfied.
        */
        
        require EPLComplianceRequirement;
        
        require constraint contributionValidation {
            doc /* All contributions must be validated for license compliance before acceptance */
        }
        
        require constraint distributionIntegrity {
            doc /* All distributed artifacts must maintain integrity and include required legal notices */
        }
    }
    
    part def EPLManagedSystem {
        doc /* 
            Eclipse Public License System: Manages EPL-licensed software throughout its lifecycle.
            Primary Function: Ensure all software contributions, storage, and distributions comply
            with Eclipse Public License 2.0 requirements, including source disclosure, license notices,
            copyleft provisions, and patent grants, while maintaining integrity and traceability.
        */
        
        part validator : ComplianceValidator {
            port compliancePort;
        }
        
        part processor : ContributionProcessor {
            port contributionPort;
        }
        
        part distributor : DistributionManager {
            port distributionPort;
        }
        
        part repository : SourceCodeRepository {
            port repositoryPort;
        }
        
        state operationalState : SystemOperationalState;
        
        connect processor.contributionPort to repository.repositoryPort;
        connect validator.compliancePort to distributor.distributionPort;
        
        satisfy primaryFunction : PrimarySystemFunction by validator, processor, distributor;
        satisfy eplCompliance : EPLComplianceRequirement by validator;
        
        perform action manageLicensedSoftware {
            first start;
            then merge continuousOperation;
            
            action acceptContributions {
                perform processor.processIncomingContribution;
            }
            
            action validateCompliance {
                perform validator.validateCompliance;
            }
            
            action distributeArtifacts {
                perform distributor.prepareAndDistribute;
            }
            
            then fork parallelOperations;
                then acceptContributions;
                then validateCompliance;
                then distributeArtifacts;
            then join parallelOperations;
            then continuousOperation;
        }
    }
    
    part eplSystem : EPLManagedSystem;
}
