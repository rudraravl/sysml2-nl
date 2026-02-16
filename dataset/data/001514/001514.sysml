package NeuroethicsSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import RiskMetadata::*;
    private import RiskLevelEnum::*;
    private import ModelingMetadata::*;

    attribute def EthicalScore {
        attribute value : Real;
        attribute confidence : Real;
    }

    attribute def NeuralDataQuality {
        attribute signalToNoiseRatio : Real;
        attribute spatialResolution : LengthValue;
        attribute temporalResolution : TimeValue;
    }

    item def ConsentRecord {
        attribute participantID : String;
        attribute consentGiven : Boolean;
        attribute consentTimestamp : String;
        attribute withdrawalAllowed : Boolean;
        attribute informedConsentVerified : Boolean;
    }

    item def NeuralData {
        attribute dataID : String;
        attribute quality : NeuralDataQuality;
        attribute isAnonymized : Boolean;
        attribute containsSensitiveInfo : Boolean;
        attribute timestamp : String;
    }

    item def EthicalAssessment {
        attribute assessmentID : String;
        attribute privacyScore : EthicalScore;
        attribute autonomyScore : EthicalScore;
        attribute beneficenceScore : EthicalScore;
        attribute justiceScore : EthicalScore;
        attribute overallScore : EthicalScore;
        attribute recommendation : String;
        attribute approved : Boolean;
    }

    item def AlertNotification {
        attribute alertID : String;
        attribute severity : String;
        attribute violationType : String;
        attribute timestamp : String;
    }

    port def ConsentPort {
        in consentRequest : ConsentRecord;
        out consentValidation : Boolean;
    }

    port def DataPort {
        in rawData : NeuralData;
        out processedData : NeuralData;
    }

    port def AssessmentPort {
        in assessmentRequest : EthicalAssessment;
        out assessmentResult : EthicalAssessment;
    }

    port def MonitoringPort {
        in monitoringData : NeuralData;
        out alertOutput : AlertNotification;
    }

    action def ValidateConsent {
        in record : ConsentRecord;
        out isValid : Boolean;
        out reason : String;
    }

    action def AnonymizeData {
        in rawData : NeuralData;
        out anonymizedData : NeuralData;
    }

    action def EvaluatePrivacy {
        in data : NeuralData;
        in consent : ConsentRecord;
        out score : EthicalScore;
    }

    action def EvaluateAutonomy {
        in consent : ConsentRecord;
        out score : EthicalScore;
    }

    action def EvaluateBeneficence {
        in data : NeuralData;
        out score : EthicalScore;
    }

    action def EvaluateJustice {
        in data : NeuralData;
        out score : EthicalScore;
    }

    action def GenerateRecommendation {
        in assessment : EthicalAssessment;
        out recommendation : String;
        out approved : Boolean;
    }

    action def DetectViolation {
        in currentData : NeuralData;
        in currentConsent : ConsentRecord;
        out violationDetected : Boolean;
        out violationType : String;
    }

    part def ConsentManagementModule {
        port consentIn : ConsentPort;
        port consentOut : ConsentPort;

        attribute consentDatabase : ConsentRecord[*];

        action validateConsentAction : ValidateConsent;

        action trackWithdrawal {
            in participantID : String;
            out withdrawalProcessed : Boolean;
        }

        perform action manageConsent {
            first start;
            then action validate : ValidateConsent {
                in record;
                out isValid;
                out reason;
            }
            then decide;
                if validate.isValid then storeConsent;
                if not validate.isValid then rejectConsent;
            action storeConsent;
            then done;
            action rejectConsent;
            then done;
        }
    }

    part def DataPrivacyModule {
        port dataIn : DataPort;
        port dataOut : DataPort;

        action anonymizeAction : AnonymizeData;

        action assessPrivacyRisk {
            in data : NeuralData;
            out riskLevel : Real;
            out vulnerabilities : String[*];
        }

        action encryptData {
            in data : NeuralData;
            out encryptedData : NeuralData;
        }

        perform action processData {
            first start;
            then action anonymize : AnonymizeData {
                in rawData;
                out anonymizedData;
            }
            then action encrypt : encryptData {
                in data = anonymize.anonymizedData;
                out encryptedData;
            }
            then action assessRisk : assessPrivacyRisk {
                in data = encrypt.encryptedData;
                out riskLevel;
                out vulnerabilities;
            }
            then done;
        }
    }

    part def EthicalReviewEngine {
        port assessmentIn : AssessmentPort;
        port assessmentOut : AssessmentPort;

        action evaluatePrivacyAction : EvaluatePrivacy;
        action evaluateAutonomyAction : EvaluateAutonomy;
        action evaluateBeneficenceAction : EvaluateBeneficence;
        action evaluateJusticeAction : EvaluateJustice;
        action generateRecommendationAction : GenerateRecommendation;

        perform action conductReview {
            first start;
            fork;
                then action evalPrivacy : EvaluatePrivacy {
                    in data;
                    in consent;
                    out score;
                }
            join;
                then action evalAutonomy : EvaluateAutonomy {
                    in consent;
                    out score;
                }
            join;
                then action evalBeneficence : EvaluateBeneficence {
                    in data;
                    out score;
                }
            join;
                then action evalJustice : EvaluateJustice {
                    in data;
                    out score;
                }
            join;
            then action computeOverall {
                in privacyScore = evalPrivacy.score;
                in autonomyScore = evalAutonomy.score;
                in beneficenceScore = evalBeneficence.score;
                in justiceScore = evalJustice.score;
                out overallScore : EthicalScore;
            }
            then action recommend : GenerateRecommendation {
                in assessment;
                out recommendation;
                out approved;
            }
            then done;
        }
    }

    part def ContinuousMonitoringModule {
        port monitoringIn : MonitoringPort;
        port monitoringOut : MonitoringPort;

        action detectViolationAction : DetectViolation;

        action triggerAlert {
            in violationType : String;
            out alertSent : Boolean;
        }

        perform action monitorContinuously {
            first start;
            then merge continueMonitoring;
            then action detect : DetectViolation {
                in currentData;
                in currentConsent;
                out violationDetected;
                out violationType;
            }
            then decide;
                if detect.violationDetected then alert;
                if not detect.violationDetected then continueMonitoring;
            action alert : triggerAlert {
                in violationType = detect.violationType;
                out alertSent;
            }
            then done;
        }
    }

    part def NeuroethicsSystem {
        part consentMgmt : ConsentManagementModule;
        part dataPrivacy : DataPrivacyModule;
        part ethicalReview : EthicalReviewEngine;
        part monitoring : ContinuousMonitoringModule;

        perform action conductEthicalAssessment {
            first start;
            then action receiveConsent {
                in participantID : String;
                in consentData : ConsentRecord;
                out validationResult : Boolean;
            }
            then decide;
                if receiveConsent.validationResult then processData;
                if not receiveConsent.validationResult then rejectRequest;
            action processData {
                in rawNeuralData : NeuralData;
                out processedData : NeuralData;
            }
            then performReview;
            action performReview {
                in neuralData : NeuralData;
                in consent : ConsentRecord;
                out assessment : EthicalAssessment;
            }
            then evaluateAssessment;
            action evaluateAssessment {
                in assessment : EthicalAssessment;
            }
            then decide;
                if performReview.assessment.overallScore.value >= 0.7 then approveUsage;
                if performReview.assessment.overallScore.value < 0.7 then flagForReview;
            action approveUsage;
            then monitorContinuously;
            action flagForReview;
            then done;
            action rejectRequest;
            then done;
            action monitorContinuously;
            then done;
        }
    }

    part neuroethicsSystem : NeuroethicsSystem;

    requirement def EthicalPrinciple {
        doc /* Base requirement for ethical principles in neuroethics */
    }

    requirement <'NE-001'> informedConsentRequired : EthicalPrinciple {
        doc /* All neural data collection must be preceded by valid informed consent from participants */
        @StatusInfo {
            status = StatusKind::required;
            risk {
                totalRisk = high;
                technicalRisk = medium;
                scheduleRisk = low;
                costRisk = medium;
            }
            originator = "EthicsBoard";
            owner = "ComplianceOfficer";
        }
    }

    requirement <'NE-002'> dataPrivacyProtection : EthicalPrinciple {
        doc /* Neural data must be anonymized and encrypted to protect participant privacy */
        @StatusInfo {
            status = StatusKind::required;
            risk {
                totalRisk = high;
                technicalRisk = high;
                scheduleRisk = low;
                costRisk = medium;
            }
            originator = "DataProtectionOfficer";
            owner = "SecurityTeam";
        }
    }

    requirement <'NE-003'> autonomyRespect : EthicalPrinciple {
        doc /* Participants must retain the right to withdraw consent at any time */
        @StatusInfo {
            status = StatusKind::required;
            risk {
                totalRisk = medium;
                technicalRisk = low;
                scheduleRisk = low;
                costRisk = low;
            }
            originator = "EthicsBoard";
            owner = "ConsentManager";
        }
    }

    requirement <'NE-004'> beneficenceMaximization : EthicalPrinciple {
        doc /* Neural data usage must maximize benefits while minimizing harm to participants */
        @StatusInfo {
            status = StatusKind::required;
            risk {
                totalRisk = high;
                technicalRisk = medium;
                scheduleRisk = medium;
                costRisk = high;
            }
            originator = "ResearchDirector";
            owner = "EthicsReviewBoard";
        }
    }

    requirement <'NE-005'> justiceInAccess : EthicalPrinciple {
        doc /* Benefits and risks of neurotechnology must be distributed fairly across populations */
        @StatusInfo {
            status = StatusKind::required;
            risk {
                totalRisk = medium;
                technicalRisk = low;
                scheduleRisk = medium;
                costRisk = medium;
            }
            originator = "EthicsBoard";
            owner = "EquityOfficer";
        }
    }

    requirement <'NE-006'> continuousEthicalMonitoring : EthicalPrinciple {
        doc /* Ethical compliance must be continuously monitored throughout data lifecycle */
        @StatusInfo {
            status = StatusKind::required;
            risk {
                totalRisk = high;
                technicalRisk = high;
                scheduleRisk = low;
                costRisk = high;
            }
            originator = "ComplianceOfficer";
            owner = "MonitoringTeam";
        }
    }

    requirement neuroethicsCompliance {
        doc /* The neuroethics system must satisfy all core ethical principles to ensure responsible neural data handling */
        assume constraint validDataQuality {
            doc /* Input neural data meets minimum quality standards for ethical assessment */
        }
        require informedConsentRequired;
        require dataPrivacyProtection;
        require autonomyRespect;
        require beneficenceMaximization;
        require justiceInAccess;
        require continuousEthicalMonitoring;
    }
}
