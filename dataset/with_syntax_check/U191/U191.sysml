package 'MEDICRIME Convention System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def ProductIdentifier {
        attribute serialNumber : String;
        attribute batchNumber : String;
        attribute manufacturerCode : String;
    }

    item def GeoLocation {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute countryCode : String;
    }

    item def SuspiciousProductReport {
        attribute reportId : String;
        attribute product : ProductIdentifier;
        attribute location : GeoLocation;
        attribute suspicionReason : String;
        attribute reporterType : String;
        attribute timestamp : String;
        attribute urgencyLevel : Integer;
    }

    item def VerificationResult {
        attribute productId : ProductIdentifier;
        attribute isAuthentic : Boolean;
        attribute verificationMethod : String;
        attribute confidence : Real;
    }

    item def InvestigationCase {
        attribute caseId : String;
        attribute originReport : SuspiciousProductReport;
        attribute assignedOfficer : String;
        attribute status : String;
        attribute priority : Integer;
    }

    item def SeizureOrder {
        attribute orderId : String;
        attribute targetProduct : ProductIdentifier;
        attribute targetLocation : GeoLocation;
        attribute legalBasis : String;
        attribute executionDeadline : TimeValue;
    }

    item def PublicAlert {
        attribute alertId : String;
        attribute affectedProduct : ProductIdentifier;
        attribute riskLevel : Integer;
        attribute distributionRegions : GeoLocation[1..*];
        attribute advisoryText : String;
    }

    item def InternationalNotification {
        attribute notificationId : String;
        attribute originCountry : String;
        attribute targetCountries : String[1..*];
        attribute caseDetails : InvestigationCase;
        attribute requestType : String;
    }

    requirement def MEDICRIMEConventionCompliance {
        doc /* "System shall implement the Council of Europe Convention on the Counterfeiting 
                of Medical Products and similar crimes involving threats to public health." */
        
        requirement CriminalizationRequirement {
            doc /* "System shall support prosecution of manufacturing, supplying, offering, 
                    and trafficking of counterfeit medical products." */
        }
        
        requirement PreventionRequirement {
            doc /* "System shall enable preventive measures including supply chain security, 
                    training programs, and public awareness campaigns." */
        }
        
        requirement ProtectionOfVictimsRequirement {
            doc /* "System shall facilitate victim assistance and compensation mechanisms." */
        }
        
        requirement CooperationRequirement {
            doc /* "System shall provide mechanisms for national and international cooperation 
                    including information exchange and joint investigations." */
        }
    }

    requirement def ResponseTimeRequirement {
        doc /* "System shall process high-urgency reports within 2 hours." */
        attribute maxResponseTime : TimeValue = 2[h];
    }

    requirement def DataIntegrityRequirement {
        doc /* "System shall maintain complete chain of custody for all evidence." */
    }

    part def NationalCompetentAuthority {
        port reportIntake;
        port verificationRequest;
        port investigationCoordination;
        port publicCommunication;
        port internationalLiaison;
    }

    part def ForensicLaboratory {
        port sampleIntake;
        port verificationOutput;
    }

    part def LawEnforcementUnit {
        port caseAssignment;
        port seizureExecution;
        port evidenceManagement;
    }

    part def CustomsAuthority {
        port borderInspection;
        port seizureNotification;
    }

    part def PublicHealthAgency {
        port riskAssessment;
        port alertDistribution;
    }

    part def InternationalCooperationHub {
        port incomingNotifications;
        port outgoingNotifications;
        port mutualAssistanceRequests;
    }

    part def PublicReportingPortal {
        port citizenReports;
        port healthcareProfessionalReports;
    }

    action def ReceiveReport {
        in report : SuspiciousProductReport;
        out validatedReport : SuspiciousProductReport;
        out urgencyFlag : Boolean;
    }

    action def VerifyProduct {
        in productId : ProductIdentifier;
        out verificationResult : VerificationResult;
    }

    action def AssessRisk {
        in report : SuspiciousProductReport;
        in verification : VerificationResult;
        out riskLevel : Integer;
        out publicHealthThreat : Boolean;
    }

    action def InitiateInvestigation {
        in report : SuspiciousProductReport;
        in riskLevel : Integer;
        out investigationCase : InvestigationCase;
    }

    action def IssueSeizureOrder {
        in investigationCase : InvestigationCase;
        out seizureOrder : SeizureOrder;
    }

    action def IssuePublicAlert {
        in riskLevel : Integer;
        in productId : ProductIdentifier;
        in affectedRegions : GeoLocation[1..*];
        out alert : PublicAlert;
    }

    action def NotifyInternationalPartners {
        in investigationCase : InvestigationCase;
        in targetCountries : String[1..*];
        out notification : InternationalNotification;
    }

    action def ProcessCounterfeitThreat {
        in incomingReport : SuspiciousProductReport;
        out finalAlert : PublicAlert;
        out internationalNotice : InternationalNotification;
        out seizure : SeizureOrder;

        first start;
        
        then action receive : ReceiveReport {
            in report = incomingReport;
            out validatedReport : SuspiciousProductReport;
            out urgencyFlag : Boolean;
        }

        then action verify : VerifyProduct {
            in productId = receive.validatedReport.product;
            out verificationResult : VerificationResult;
        }

        then action assess : AssessRisk {
            in report = receive.validatedReport;
            in verification = verify.verificationResult;
            out riskLevel : Integer;
            out publicHealthThreat : Boolean;
        }

        then decide;
            if verify.verificationResult.isAuthentic == false then respondToCounterfeit;
            if verify.verificationResult.isAuthentic == true then closeCase;

        fork respondToCounterfeit;

            action investigate : InitiateInvestigation {
                in report = receive.validatedReport;
                in riskLevel = assess.riskLevel;
                out investigationCase : InvestigationCase;
            }

            then action issueSeizure : IssueSeizureOrder {
                in investigationCase = investigate.investigationCase;
                out seizureOrder : SeizureOrder = seizure;
            }

            action alertPublic : IssuePublicAlert {
                in riskLevel = assess.riskLevel;
                in productId = receive.validatedReport.product;
                in affectedRegions = (receive.validatedReport.location);
                out alert : PublicAlert = finalAlert;
            }

            action notifyPartners : NotifyInternationalPartners {
                in investigationCase = investigate.investigationCase;
                in targetCountries = ("EU", "WHO");
                out notification : InternationalNotification = internationalNotice;
            }

        join;

        then action closeCase;
        then done;
    }

    part def MEDICRIMEProtectionSystem;

    part antiCounterfeitingSystem : MEDICRIMEProtectionSystem {
        satisfy MEDICRIMEConventionCompliance;
        satisfy ResponseTimeRequirement;
        satisfy DataIntegrityRequirement;

        part nca : NationalCompetentAuthority;
        part lab : ForensicLaboratory;
        part lawEnforcement : LawEnforcementUnit;
        part customs : CustomsAuthority;
        part publicHealth : PublicHealthAgency;
        part internationalHub : InternationalCooperationHub;
        part reportingPortal : PublicReportingPortal;

        port systemReportIntake;
        port systemAlertOutput;
        port systemInternationalInterface;

        connect reportingPortal.citizenReports to nca.reportIntake;
        connect reportingPortal.healthcareProfessionalReports to nca.reportIntake;
        connect nca.reportIntake to systemReportIntake;
        connect nca.verificationRequest to lab.sampleIntake;
        connect lab.verificationOutput to nca.verificationRequest;
        connect nca.investigationCoordination to lawEnforcement.caseAssignment;
        connect lawEnforcement.seizureExecution to customs.seizureNotification;
        connect nca.publicCommunication to publicHealth.alertDistribution;
        connect publicHealth.alertDistribution to systemAlertOutput;
        connect nca.internationalLiaison to internationalHub.outgoingNotifications;
        connect internationalHub.incomingNotifications to nca.internationalLiaison;
        connect internationalHub.outgoingNotifications to systemInternationalInterface;

        perform action processThreat : ProcessCounterfeitThreat[*] {
            in incomingReport <~ systemReportIntake;
            out finalAlert ~> systemAlertOutput;
            out internationalNotice ~> systemInternationalInterface;
        }
    }

    state machine def ThreatResponseStateMachine {
        state Monitoring {
            entry action monitorReports;
        }
        
        state Investigating {
            entry action conductInvestigation;
        }
        
        state Responding {
            entry action executeResponse;
        }
        
        state Coordinating {
            entry action coordinateInternational;
        }
        
        state Resolved {
            entry action archiveCase;
        }

        transition t1 first Monitoring;
        transition t2 : Monitoring to Investigating;
        transition t3 : Investigating to Responding;
        transition t4 : Responding to Coordinating;
        transition t5 : Coordinating to Resolved;
        transition t6 : Resolved to Monitoring;
    }
}
