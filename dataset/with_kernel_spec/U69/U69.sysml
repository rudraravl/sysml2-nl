package InfusionPumpCybersecurityAnalysis {

    private import ScalarValues::*;

    /* ---- Value Types ---- */

    attribute def DosageRateValue :> Real {
        attribute unit : String = "mL/h";
    }

    attribute def DurationValue :> Real {
        attribute unit : String = "min";
    }

    attribute def DosageValue :> Real {
        attribute unit : String = "mg";
    }

    attribute def HeartRateValue :> Real {
        attribute unit : String = "bpm";
    }

    attribute def BloodPressureValue :> Real {
        attribute unit : String = "mmHg";
    }

    attribute def TimeValue :> Real {
        attribute unit : String = "s";
    }

    attribute def AnomalyScoreValue :> Real {
        attribute unit : String = "score";
    }

    /* ---- Item Definitions ---- */

    item def Medication {
        attribute name : String;
        attribute concentration : Real;
    }

    item def TherapyCommand {
        attribute commandId : String;
        attribute flowRate : DosageRateValue;
        attribute duration : DurationValue;
        attribute medication : Medication;
        attribute isAuthorized : Boolean;
        attribute sourceId : String;
        attribute authToken : String;
    }

    item def VitalSigns {
        attribute heartRate : HeartRateValue;
        attribute systolicBP : BloodPressureValue;
        attribute diastolicBP : BloodPressureValue;
        attribute timestamp : TimeValue;
    }

    item def NetworkPacket {
        attribute sourceAddress : String;
        attribute destinationAddress : String;
        attribute payload : String;
        attribute isMalicious : Boolean;
        attribute timestamp : TimeValue;
    }

    item def AuditEntry {
        attribute eventDescription : String;
        attribute severity : String;
        attribute timestamp : TimeValue;
    }

    item def AuthenticationCredential {
        attribute userId : String;
        attribute role : String;
        attribute tokenHash : String;
    }

    item def AnomalyAlert {
        attribute severity : String;
        attribute description : String;
        attribute anomalyScore : AnomalyScoreValue;
    }

    /* ---- Port Definitions ---- */

    port def NetworkPort;
    port def TherapyControlPort;
    port def PatientMonitoringPort;
    port def AttackPort;
    port def AlertPort;
    port def LogPort;

    /* ---- Action Definitions ---- */

    action def AdministerTherapy {
        in command : TherapyCommand;
        out deliveredDose : DosageValue;
    }

    action def ValidateCommand {
        in command : TherapyCommand;
        in credential : AuthenticationCredential;
        out isValid : Boolean;
    }

    action def AuthenticateUser {
        in credential : AuthenticationCredential;
        out isAuthenticated : Boolean;
    }

    action def AnalyzeTraffic {
        in packet : NetworkPacket;
        out anomalyDetected : Boolean;
        out anomalyScore : AnomalyScoreValue;
    }

    action def LogEvent {
        in logEntry : AuditEntry;
    }

    action def SendTherapyCommand {
        in command : TherapyCommand;
        out packet : NetworkPacket;
    }

    action def ScanTarget {
        in target : String;
        out vulnerabilities : String;
    }

    action def CraftExploit {
        in vulnerability : String;
        out payload : String;
    }

    action def InjectCommand {
        in target : String;
        in flowRate : DosageRateValue;
        out command : TherapyCommand;
    }

    action def FilterTraffic {
        in packet : NetworkPacket;
        out filteredPacket : NetworkPacket;
        out isAllowed : Boolean;
    }

    /* ---- State Machine Definitions ---- */

    state def PumpStateMachine {
        initial state Standby;
        state Authenticating;
        state Delivering;
        state Alarming;
        state Lockdown;
        transition from Standby to Authenticating;
        transition from Authenticating to Delivering;
        transition from Authenticating to Alarming;
        transition from Delivering to Standby;
        transition from Delivering to Alarming;
        transition from Alarming to Lockdown;
        transition from Alarming to Standby;
        transition from Lockdown to Standby;
    }

    state def PatientHealthStateMachine {
        initial state Healthy;
        state AdverseEffects;
        state Critical;
        transition from Healthy to AdverseEffects;
        transition from AdverseEffects to Critical;
        transition from Critical to Healthy;
    }

    state def AttackPlanStateMachine {
        initial state Idle;
        state Reconnaissance;
        state Exploiting;
        state Injecting;
        transition from Idle to Reconnaissance;
        transition from Reconnaissance to Exploiting;
        transition from Exploiting to Injecting;
        transition from Injecting to Idle;
    }

    /* ---- Pump Internal Component Definitions ---- */

    part def TherapyEngine {
        attribute currentFlowRate : DosageRateValue;
        attribute prescribedDuration : DurationValue;
        attribute medication : Medication;
        port controlPort : TherapyControlPort;
        port patientPort : PatientMonitoringPort;
        action administer : AdministerTherapy;
    }

    part def SecurityModule {
        attribute encryptionKey : String;
        port networkPort : NetworkPort;
        port commandPort : TherapyControlPort;
        port logPort : LogPort;
        action validate : ValidateCommand;
        action authenticate : AuthenticateUser;
    }

    part def AnomalyDetector {
        attribute detectionThreshold : Real = 0.8;
        attribute anomalyScore : AnomalyScoreValue = 0.0;
        attribute isAnomalyDetected : Boolean = false;
        port monitorPort : NetworkPort;
        port alertPort : AlertPort;
        action analyze : AnalyzeTraffic;
    }

    part def AuditLogger {
        port logPort : LogPort;
        action log : LogEvent;
    }

    /* ---- Infusion Pump Definition ---- */

    part def InfusionPump {
        attribute deviceId : String;
        attribute firmwareVersion : String;
        attribute ipAddress : String;
        port networkPort : NetworkPort;
        port patientPort : PatientMonitoringPort;
        port alertPort : AlertPort;

        part therapyEngine : TherapyEngine;
        part securityModule : SecurityModule;
        part anomalyDetector : AnomalyDetector;
        part auditLogger : AuditLogger;

        connect networkPort to securityModule.networkPort;
        connect securityModule.commandPort to therapyEngine.controlPort;
        connect networkPort to anomalyDetector.monitorPort;
        connect therapyEngine.patientPort to patientPort;
        connect anomalyDetector.alertPort to alertPort;
        connect securityModule.logPort to auditLogger.logPort;

        state machine pumpState : PumpStateMachine;
    }

    /* ---- External System Components ---- */

    part def Patient {
        attribute patientId : String;
        attribute patientName : String;
        attribute currentHeartRate : HeartRateValue;
        attribute isHarmed : Boolean = false;
        port monitoringPort : PatientMonitoringPort;
        state machine healthState : PatientHealthStateMachine;
    }

    part def ClinicalWorkstation {
        attribute workstationId : String;
        attribute authorizedUser : String;
        port networkPort : NetworkPort;
        port controlPort : TherapyControlPort;
        action sendCommand : SendTherapyCommand;
    }

    part def Firewall {
        attribute rules : String;
        attribute isFilteringActive : Boolean = true;
        port internalPort : NetworkPort;
        port externalPort : NetworkPort;
        action filter : FilterTraffic;
    }

    part def HealthcareNetwork {
        attribute networkId : String;
        attribute networkSegment : String;
        part firewall : Firewall;
        port clinicalPort : NetworkPort;
        port pumpPort : NetworkPort;
        port externalPort : NetworkPort;
        connect firewall.internalPort to pumpPort;
        connect firewall.externalPort to externalPort;
        connect clinicalPort to firewall.internalPort;
    }

    part def ExploitFramework {
        attribute targetIp : String;
        port attackPort : AttackPort;
        action scan : ScanTarget;
        action craft : CraftExploit;
    }

    part def CommandInjector {
        attribute injectedFlowRate : DosageRateValue;
        attribute isInjectionActive : Boolean = false;
        port attackPort : AttackPort;
        action inject : InjectCommand;
    }

    part def Attacker {
        attribute attackerId : String;
        attribute attackerIp : String;
        part exploitFramework : ExploitFramework;
        part commandInjector : CommandInjector;
        port networkPort : NetworkPort;
        connect exploitFramework.attackPort to networkPort;
        connect commandInjector.attackPort to networkPort;
        state machine attackPlan : AttackPlanStateMachine;
    }

    /* ---- Top-Level Analysis Scenario ---- */

    part analysisScenario {
        attribute scenarioName : String = "HijackScenario";

        part patient : Patient {
            attribute patientId = "PAT-001";
            attribute patientName = "John Doe";
        }

        part workstation : ClinicalWorkstation {
            attribute workstationId = "WS-001";
            attribute authorizedUser = "Dr. Smith";
        }

        part network : HealthcareNetwork {
            attribute networkId = "NET-CLINICAL-A";
            attribute networkSegment = "ICU";
        }

        part pump : InfusionPump {
            attribute deviceId = "PUMP-001";
            attribute firmwareVersion = "v2.4.1";
            attribute ipAddress = "10.0.1.50";
        }

        part attacker : Attacker {
            attribute attackerId = "ATK-001";
            attribute attackerIp = "192.168.99.100";
        }

        connect workstation.networkPort to network.clinicalPort;
        connect network.pumpPort to pump.networkPort;
        connect attacker.networkPort to network.externalPort;
        connect pump.patientPort to patient.monitoringPort;
    }

    /* ---- Requirements ---- */

    requirement def SecurityRequirement {
        attribute requirementId : String;
        attribute priority : String;
    }

    requirement def AuthenticationRequirement :> SecurityRequirement {
        text "The infusion pump shall authenticate all incoming therapy commands using the security module before any therapy delivery begins.";
    }

    requirement def AnomalyDetectionRequirement :> SecurityRequirement {
        text "The anomaly detector shall monitor all network traffic and trigger an alarm when malicious patterns are detected.";
    }

    requirement def LockdownRequirement :> SecurityRequirement {
        text "The pump shall enter Lockdown state when anomaly score exceeds the detection threshold, halting all therapy delivery.";
    }

    requirement def PatientSafetyRequirement :> SecurityRequirement {
        text "The patient shall not be harmed during a hijack scenario if all security features function correctly.";
    }

    requirement def AuditLoggingRequirement :> SecurityRequirement {
        text "The audit logger shall record all security events including authentication failures, anomaly detections, and state transitions.";
    }

    requirement def SafeDosageRequirement :> SecurityRequirement {
        text "The therapy engine shall prevent delivery of a dangerous dosage by enforcing maximum flow rate limits.";
    }

    package SecurityRequirements {
        requirement authReq : AuthenticationRequirement {
            attribute requirementId = "SEC-001";
            attribute priority = "CRITICAL";
        }
        requirement anomalyReq : AnomalyDetectionRequirement {
            attribute requirementId = "SEC-002";
            attribute priority = "HIGH";
        }
        requirement lockdownReq : LockdownRequirement {
            attribute requirementId = "SEC-003";
            attribute priority = "CRITICAL";
        }
        requirement patientSafetyReq : PatientSafetyRequirement {
            attribute requirementId = "SEC-004";
            attribute priority = "CRITICAL";
        }
        requirement auditReq : AuditLoggingRequirement {
            attribute requirementId = "SEC-005";
            attribute priority = "MEDIUM";
        }
        requirement safeDosageReq : SafeDosageRequirement {
            attribute requirementId = "SEC-006";
            attribute priority = "CRITICAL";
        }
    }

    /* ---- Attack Analysis ---- */

    action def FullAttackSequence {
        in targetPump : InfusionPump;
        in attackerNode : Attacker;
        out outcome : String;
    }

}
