package GNUGPLSystem {
    attribute def validationRequest;
    attribute def distributionComplete;
    attribute def enforcementComplete;
    attribute def enforcementFailed;

	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	metadata def LicenseMetadata {
		attribute licenseName : String;
		attribute version : String;
		attribute copyleftRequired : Boolean;
		attribute sourceCodeDisclosure : Boolean;
		attribute derivativeWorksAllowed : Boolean;
		attribute commercialUseAllowed : Boolean;
	}
	
	@LicenseMetadata {
		licenseName = "GNU General Public License";
		version = "3.0";
		copyleftRequired = true;
		sourceCodeDisclosure = true;
		derivativeWorksAllowed = true;
		commercialUseAllowed = true;
	}
	attribute def GPLv3License;
	
	value def SourceCodeVersion {
		attribute major : Integer;
		attribute minor : Integer;
		attribute patch : Integer;
	}
	
	attribute def ComplianceLevel :> Real;
	
	item def SourceCodePackage {
		attribute version : SourceCodeVersion;
		attribute sizeInBytes : ISQ::MassValue;
		attribute checksum : String;
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def LicenseNotice {
		attribute fullText : String;
		attribute copyrightHolder : String;
		attribute effectiveDate : String;
	}
	
	item def ModificationRecord {
		attribute modifiedBy : String;
		attribute modificationDate : String;
		attribute changeDescription : String;
		attribute previousVersion : SourceCodeVersion;
	}
	
	port def SourceDistributionPort {
		out item sourcePackage : SourceCodePackage;
		out item licenseNotice : LicenseNotice;
	}
	
	port def ComplianceMonitoringPort {
		in item modificationRecord : ModificationRecord;
		out item complianceReport : String;
	}
	
	port def UserAccessPort {
		in item accessRequest : String;
		out item sourcePackage : SourceCodePackage;
	}
	
	part def SoftwareComponent {
		attribute componentName : String;
		attribute version : SourceCodeVersion;
		attribute licenseType : String;
		attribute sourceAvailable : Boolean;
		port licensePort;
	}
	
	part def SourceCodeRepository {
		attribute repositoryURL : String;
		attribute publicAccess : Boolean;
		attribute totalSize : ISQ::MassValue;
		port distributionPort : SourceDistributionPort;
	}
	
	part def ModificationTracker {
		attribute recordAllChanges : Boolean;
		attribute modificationHistory : ModificationRecord[*];
		port monitoringPort : ComplianceMonitoringPort;
	}
	
	part def DistributionManager {
		attribute preserveNotices : Boolean;
		attribute distributionCount : Integer;
		port accessPort : UserAccessPort;
	}
	
	part def ComplianceValidator {
		attribute validationEnabled : Boolean;
		attribute complianceScore : ComplianceLevel;
		port validationPort;
	}
	
	requirement def SourceCodeAvailabilityRequirement {
		doc /* The system shall make complete corresponding source code available 
		        to all recipients of the software in machine-readable form. */
		subject sourceRepository : SourceCodeRepository;
		require constraint {
			sourceRepository.publicAccess == true
		}
	}
	
	requirement def CopyleftEnforcementRequirement {
		doc /* All derivative works and modified versions shall be licensed 
		        under the same GNU GPL terms as the original work. */
		subject derivativeWork : SoftwareComponent;
		require constraint {
			derivativeWork.licenseType == "GPLv3"
		}
	}
	
	requirement def ModificationDocumentationRequirement {
		doc /* All modifications to the software shall be clearly documented 
		        with dates and descriptions of changes made. */
		subject modificationTracker : ModificationTracker;
		require constraint {
			modificationTracker.recordAllChanges == true
		}
	}
	
	requirement def LicenseNoticePreservationRequirement {
		doc /* All copyright notices and license text shall be preserved 
		        in all copies and derivative works. */
		subject distributionManager : DistributionManager;
		require constraint {
			distributionManager.preserveNotices == true
		}
	}
	
	requirement <'GPL-SYS-1'> systemComplianceRequirement {
		doc /* The system shall ensure full compliance with all provisions 
		        of the GNU General Public License version 3.0. */
		assume requirement srcAvail : SourceCodeAvailabilityRequirement;
		assume requirement copyleft : CopyleftEnforcementRequirement;
		assume requirement modDoc : ModificationDocumentationRequirement;
		assume requirement noticePreserve : LicenseNoticePreservationRequirement;
	}
	
	action def ValidateCompliance {
		in component : SoftwareComponent;
		in licenseNotice : LicenseNotice;
		out isCompliant : Boolean;
		out complianceScore : ComplianceLevel;
		
		first start;
		then action checkSourceAvailability {
			in sourceAvailable : Boolean;
			out sourceCheck : Boolean;
		}
		then action checkLicenseType {
			in licenseType : String;
			out licenseCheck : Boolean;
		}
		then action computeScore {
			in sourceCheck : Boolean;
			in licenseCheck : Boolean;
			out score : ComplianceLevel;
		}
		then assign isCompliant := (computeScore.score >= 95.0);
		then assign complianceScore := computeScore.score;
		then done;
	}
	
	action def DistributeSourceCode {
		in repo : SourceCodeRepository;
		in requestingUser : String;
		out sourcePackage : SourceCodePackage;
		out licenseNotice : LicenseNotice;
		
		first start;
		then action retrieveSource {
			in repository : SourceCodeRepository;
			out package : SourceCodePackage;
		}
		then action attachLicense {
			in package : SourceCodePackage;
			out packageWithLicense : SourceCodePackage;
			out notice : LicenseNotice;
		}
		then assign sourcePackage := attachLicense.packageWithLicense;
		then assign licenseNotice := attachLicense.notice;
		then done;
	}
	
	action def TrackModification {
		in component : SoftwareComponent;
		in modifiedBy : String;
		in changeDescription : String;
		out modificationRecord : ModificationRecord;
		
		first start;
		then action createRecord {
			in componentVersion : SourceCodeVersion;
			in modifier : String;
			in description : String;
			out record : ModificationRecord;
		}
		then action validateModification {
			in record : ModificationRecord;
			out isValid : Boolean;
		}
		then decide;
			if validateModification.isValid then acceptModification;
			if !validateModification.isValid then rejectModification;
		action acceptModification {
			in record : ModificationRecord;
			out acceptedRecord : ModificationRecord;
		}
		then assign modificationRecord := acceptModification.acceptedRecord;
		then done;
		action rejectModification;
		then done;
	}
	
	action def EnforceCopyleft {
		in derivativeComponent : SoftwareComponent;
		in originalLicense : LicenseNotice;
		out enforcementAction : String;
		out newLicenseApplied : Boolean;
		
		first start;
		then action checkDerivativeStatus {
			in component : SoftwareComponent;
			out isDerivative : Boolean;
		}
		then decide;
			if checkDerivativeStatus.isDerivative then applyGPL;
			if !checkDerivativeStatus.isDerivative then skipEnforcement;
		action applyGPL {
			in license : LicenseNotice;
			in component : SoftwareComponent;
			out applied : Boolean;
			out action : String;
		}
		then assign newLicenseApplied := applyGPL.applied;
		then assign enforcementAction := applyGPL.action;
		then done;
		action skipEnforcement;
		then assign newLicenseApplied := false;
		then assign enforcementAction := "No enforcement needed";
		then done;
	}
	
	action def GPLComplianceWorkflow {
		in softwareComponent : SoftwareComponent;
		in sourceRepository : SourceCodeRepository;
		in requestingUser : String;
		out finalCompliance : Boolean;
		out distributedPackage : SourceCodePackage;
		
		first start;
		then merge checkPoint;
		then action validate : ValidateCompliance {
			in component = softwareComponent;
			in licenseNotice;
			out isCompliant;
			out complianceScore;
		}
		then decide;
			if validate.isCompliant then proceedWithDistribution;
			if !validate.isCompliant then enforceCopyleftAction;
		action proceedWithDistribution : DistributeSourceCode {
			in repo = sourceRepository;
			in requestingUser = requestingUser;
			out sourcePackage;
			out licenseNotice;
		}
		then assign distributedPackage := proceedWithDistribution.sourcePackage;
		then assign finalCompliance := true;
		then done;
		action enforceCopyleftAction : EnforceCopyleft {
			in derivativeComponent = softwareComponent;
			in originalLicense;
			out enforcementAction;
			out newLicenseApplied;
		}
		then decide;
			if enforceCopyleftAction.newLicenseApplied then checkPoint;
			if !enforceCopyleftAction.newLicenseApplied then failCompliance;
		action failCompliance;
		then assign finalCompliance := false;
		then done;
	}
	
	state def GPLSystemLifecycle {
		entry; then idle;
		state idle;
		transition idleToValidating
			first idle
			accept validationRequest
			then validating;
		state validating;
		transition validatingToDistributing
			first validating
			if complianceAchieved
			then distributing;
		transition validatingToEnforcing
			first validating
			if complianceNotAchieved
			then enforcing;
		state distributing;
		transition distributingToIdle
			first distributing
			accept distributionComplete
			then idle;
		state enforcing;
		transition enforcingToValidating
			first enforcing
			accept enforcementComplete
			then validating;
		transition enforcingToIdle
			first enforcing
			accept enforcementFailed
			then idle;
	}
	
	part gnuGPLSystem {
		doc /* 
		This system implements and enforces the GNU General Public License (GPL) version 3.0 
		for software distribution, modification, and derivative works. Its primary function is 
		to ensure that all software components distributed under the GPL maintain full compliance 
		with copyleft requirements, provide complete source code access to all recipients, properly 
		track and document all modifications, and enforce GPL terms on derivative works.
		
		The system operates through an integrated workflow that validates software components 
		against GPL requirements, manages a publicly accessible source code repository, tracks 
		all modifications with detailed records, enforces copyleft provisions on derivative works, 
		and distributes source code packages with appropriate license notices to requesting users.
		
		Key capabilities include automated compliance validation, secure source code distribution, 
		comprehensive modification tracking, copyleft enforcement, and license notice preservation 
		across all distributed copies and derivative works.
		*/
		
		part softwareComponents : SoftwareComponent[1..*] {
			attribute :>> sourceAvailable = true;
			attribute :>> licenseType = "GPLv3";
		}
		
		part sourceRepository : SourceCodeRepository {
			attribute :>> publicAccess = true;
			attribute :>> repositoryURL = "https://source.gnu.org/gpl-system";
			attribute :>> totalSize = 5000000000 [SI::kg];
		}
		
		part modificationTracker : ModificationTracker {
			attribute :>> recordAllChanges = true;
		}
		
		part distributionManager : DistributionManager {
			attribute :>> preserveNotices = true;
			attribute :>> distributionCount = 0;
		}
		
		part complianceValidator : ComplianceValidator {
			attribute :>> validationEnabled = true;
			attribute :>> complianceScore = 100.0;
		}
		
		part gplLicenseDocument : LicenseNotice {
			attribute :>> fullText = "GNU General Public License Version 3.0 Complete Text";
			attribute :>> copyrightHolder = "Free Software Foundation";
			attribute :>> effectiveDate = "2007-06-29";
		}
		
		perform action complianceWorkflow : GPLComplianceWorkflow[*] ordered;
		
		state lifecycle : GPLSystemLifecycle;
		
		connection sourceToDistribution connect 
			sourceRepository.distributionPort to distributionManager.accessPort;
		
		connection modificationToCompliance connect 
			modificationTracker.monitoringPort to complianceValidator.validationPort;
		
		connection componentsToLicense connect 
			softwareComponents.licensePort to complianceValidator.validationPort;
		
		satisfy systemComplianceRequirement;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import GNUGPLSystem::*;

    part testSubject : SoftwareComponent {
        exhibit state sm : GPLSystemLifecycle;
    }

    action orchestrator {
        action proceedWithDistributionProbe : DistributeSourceCode {
            // TODO(human): unsupported input type for repo: SourceCodeRepository (type is not a primitive, enum, extracted payload def, or known value type)
            in requestingUser = "";
        }
        attribute testValidationRequest : validationRequest;
        attribute testDistributionComplete : distributionComplete;
        action triggervalidationRequest send testValidationRequest to testSubject;
        action triggerdistributionComplete send testDistributionComplete to testSubject;
        first proceedWithDistributionProbe;
        then triggervalidationRequest;
        then triggerdistributionComplete;
    }
}
