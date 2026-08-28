package 'Medicrime Counterfeit Response System' {
	private import ScalarValues::String;
	private import ScalarValues::Boolean;
	private import ScalarValues::Integer;
	private import ISQ::TimeValue;

	unit hour;

	enum def UrgencyLevel { low; medium; high; }

	item def SuspiciousProductReport {
		attribute reportId : String;
		attribute productDescription : String;
		attribute reporterType : String;
		attribute urgency : UrgencyLevel;
		attribute submissionTime : TimeValue;
	}

	item def VerificationRequest {
		attribute caseId : String;
		ref product : SuspiciousProductReport;
	}

	item def LabAnalysisResult {
		attribute caseId : String;
		attribute isCounterfeit : Boolean;
		attribute analysisDetails : String;
	}

	item def RiskAssessment {
		attribute caseId : String;
		attribute riskScore : Integer;
		attribute justification : String;
	}

	item def InvestigationCase {
		attribute caseId : String;
		attribute status : String;
		ref product : SuspiciousProductReport;
	}

	item def SeizureOrder {
		attribute orderId : String;
		attribute caseId : String;
		attribute targetDescription : String;
	}

	item def PublicAlert {
		attribute alertId : String;
		attribute caseId : String;
		attribute riskDescription : String;
		attribute affectedRegions : String;
	}

	item def InternationalNotification {
		attribute notificationId : String;
		attribute caseId : String;
		attribute sharedDetails : String;
		attribute recipientCountries : String;
	}

	item def EvidenceRecord {
		attribute caseId : String;
		attribute handlerId : String;
		attribute timestamp : TimeValue;
		attribute custodyState : String;
	}

	action def ProcessReport {
		action receiveReport;
		action validateReport;
		action verifyProduct;
		action makeDecision;
		action respond;
		action coordinateInternationally;
		action closeCase;
		first receiveReport;
		then validateReport;
		then verifyProduct;
		then makeDecision;
		then respond;
		then coordinateInternationally;
		then closeCase;
	}

	action def AnalyzeProduct {
		action receiveSample;
		action performAnalysis;
		action issueResult;
		first receiveSample;
		then performAnalysis;
		then issueResult;
	}

	part def PublicPortal {
		port out reportSubmission : SuspiciousProductReport;
		perform action acceptReport[*];
	}

	part def NationalCompetentAuthority {
		port in reportReception : SuspiciousProductReport;
		port out verificationRequestOut : VerificationRequest;
		port in labResultIn : LabAnalysisResult;
		port out investigationCaseOut : InvestigationCase;
		port out seizureOrderOut : SeizureOrder;
		port out publicAlertTrigger : PublicAlert;
		port out internationalNotificationOut : InternationalNotification;

		attribute activeCaseId : String;
		attribute reportReceived : Boolean;
		attribute credible : Boolean;
		attribute labResultReceived : Boolean;
		attribute counterfeit : Boolean;
		attribute responseInitiated : Boolean;
		attribute notificationSent : Boolean;

		state caseLifecycle {
			state Monitoring;
			state Validating;
			state Verifying;
			state DecisionMaking;
			state ResponseCoordination;
			state InternationalCoordination;
			state Resolution;

			transition from Monitoring to Validating when reportReceived;
			transition from Validating to Verifying when credible;
			transition from Validating to Resolution when !credible;
			transition from Verifying to DecisionMaking when labResultReceived;
			transition from DecisionMaking to Resolution when !counterfeit;
			transition from DecisionMaking to ResponseCoordination when counterfeit;
			transition from ResponseCoordination to InternationalCoordination when responseInitiated;
			transition from InternationalCoordination to Resolution when notificationSent;
		}

		perform ProcessReport[*];
	}

	part def ForensicLaboratory {
		port in verificationRequestIn : VerificationRequest;
		port out labResultOut : LabAnalysisResult;
		perform AnalyzeProduct[*];
	}

	part def LawEnforcementUnit {
		port in investigationCaseIn : InvestigationCase;
		perform action pursueCriminalCharges[*];
	}

	part def Customs {
		port in seizureOrderIn : SeizureOrder;
		perform action confiscateGoods[*];
	}

	part def PublicHealthAgency {
		port in alertTriggerIn : PublicAlert;
		perform action issuePublicAlert[*];
	}

	part def InternationalCooperationHub {
		port in notificationIn : InternationalNotification;
		perform action notifyPartners[*];
	}

	part medicrimeSystem {
		part portal : PublicPortal;
		part nca : NationalCompetentAuthority;
		part lab : ForensicLaboratory;
		part police : LawEnforcementUnit;
		part customs : Customs;
		part healthAgency : PublicHealthAgency;
		part intlHub : InternationalCooperationHub;

		connect portal.reportSubmission to nca.reportReception;
		connect nca.verificationRequestOut to lab.verificationRequestIn;
		connect lab.labResultOut to nca.labResultIn;
		connect nca.investigationCaseOut to police.investigationCaseIn;
		connect nca.seizureOrderOut to customs.seizureOrderIn;
		connect nca.publicAlertTrigger to healthAgency.alertTriggerIn;
		connect nca.internationalNotificationOut to intlHub.notificationIn;
	}

	requirement def ProcessHighUrgencyReports {
		subject report : SuspiciousProductReport;
		attribute processingTime : TimeValue;
		constraint { report.urgency == UrgencyLevel::high implies processingTime <= 2 [hour]; }
	}

	requirement def MaintainChainOfCustody {
		subject evidence : EvidenceRecord;
		constraint { evidence.custodyState != ""; }
	}

	requirement highUrgencyReq : ProcessHighUrgencyReports;
	requirement custodyReq : MaintainChainOfCustody;

	satisfy highUrgencyReq by medicrimeSystem;
	satisfy custodyReq by medicrimeSystem;
}
