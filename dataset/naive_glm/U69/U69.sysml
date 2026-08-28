package InfusionPumpCybersecurityAnalysis {

    import ScalarValues::*;
    import ISQ::*;
    import Quantities::*;

    // ---- Value Types with Units ----

    value type DosageRateValue :> Real = mL/h {
        private import Units::mL;
        private import Units::h;
    }

    value type TherapyDurationValue :> Real = min {
        private import Units::min;
    }

    value type VitalRateValue :> Real = beats/min {
        private import Units::min;
    }

    value type TemperatureValue :> Real = degC {
        private import ISQ::Temperature;
    }

    value type SignalStrengthValue :> Real = dBm {
        private import ISQ::Power;
    }

    value type RiskScoreValue :> Real {
        doc
        /* Normalized risk score in range [0.0, 1.0]. */
    }

    value type PacketRateValue :> Real = packet/s {
        private import Units::s;
    }

    // ---- Item Types ----

    item def TherapyCommand {
        attribute commandId : String;
        attribute targetDoseRate : DosageRateValue;
        attribute targetDuration : TherapyDurationValue;
        attribute issuedAt : TimeInstant;
        attribute issuingUser : String;
        attribute issuingDevice : String;
        attribute authenticationToken : String;
        attribute signature : String;
    }

    item def MaliciousCommand {
        attribute commandId : String;
        attribute targetDoseRate : DosageRateValue;
        attribute targetDuration : TherapyDurationValue;
        attribute forgedToken : String;
        attribute forgedSignature : String;
    }

    item def CommandAck {
        attribute commandId : String;
        attribute accepted : Boolean;
        attribute reason : String;
    }

    item def AlarmEvent {
        attribute alarmId : String;
        attribute severity : RiskScoreValue;
        attribute description : String;
        attribute timestamp : TimeInstant;
    }

    item def AuditEntry {
        attribute entryId : String;
        attribute timestamp : TimeInstant;
        attribute actor : String;
        attribute action : String;
        attribute result : String;
        attribute sourceAddress : String;
    }

    item def VitalSigns {
        attribute heartRate : VitalRateValue;
        attribute temperature : TemperatureValue;
        attribute spo2 : Real;
        attribute timestamp : TimeInstant;
    }

    item def NetworkPacket {
        attribute sourceAddress : String;
        attribute destinationAddress : String;
        attribute payload : String;
        attribute timestamp : TimeInstant;
        attribute length : Integer;
    }

    item def DeviceDiscovery {
        attribute deviceAddress : String;
        attribute deviceModel : String;
        attribute firmwareVersion : String;
        attribute openServices : String[*];
    }

    item def CredentialSet {
        attribute username : String;
        attribute password : String;
        attribute role : String;
    }

    // ---- Port Definitions ----

    port def NetworkPort {
        attribute ipAddress : String;
        item packetOut : NetworkPacket;
        item packetIn : NetworkPacket;
    }

    port def ClinicalCommandPort {
        item commands : TherapyCommand;
        item acknowledgments : CommandAck;
    }

    port def TherapyDeliveryPort {
        attribute deliveredRate : DosageRateValue;
        attribute deliveredVolume : DosageRateValue;
    }

    port def PatientMonitoringPort {
        item vitals : VitalSigns;
        item alarmNotifications : AlarmEvent;
    }

    port def AttackCommandPort {
        item maliciousCommands : MaliciousCommand;
        item exploitPayloads : NetworkPacket;
    }

    port def AuditPort {
        item auditEntries : AuditEntry;
    }

    port def AlarmPort {
        item alarms : AlarmEvent;
    }

    // ---- Requirements ----

    requirement def SecurityAnalysisGoal {
        doc
        /* The system shall represent and simulate a hijack scenario against a
            network-connected infusion pump, demonstrating detection and mitigation
            of unauthorized command attempts. */
        attribute scenarioName : String = "InfusionPumpHijack";
        subject : pump;
        subject : attacker;
        subject : network;
        subject : patient;
    }

    requirement def AuthenticationRequirement {
        doc
        /* The pump shall authenticate all incoming commands using the security module
            before applying any therapy parameter change. */
        subject : securityModule;
        attribute maxAuthenticationLatency : TimeDuration = 200 [ms];
        attribute requiredRole : String = "Clinician";
    }

    requirement def AnomalyDetectionRequirement {
        doc
        /* The pump shall detect network anomalies indicative of a cyberattack and
            raise an alarm when suspicious activity is observed. */
        subject : anomalyDetector;
        attribute detectionLatency : TimeDuration = 500 [ms];
        attribute falsePositiveRate : Real = 0.05;
    }

    requirement def SafetyLockdownRequirement {
        doc
        /* Upon detection of an unauthorized command or anomalous behavior, the pump
            shall enter Lockdown, halt therapy, and notify the clinical workstation
            to prevent patient harm. */
        subject : pump;
        attribute maxLockdownDelay : TimeDuration = 1000 [ms];
    }

    requirement def AuditLoggingRequirement {
        doc
        /* The pump shall record all commands and security events in an
            tamper-resistant audit log. */
        subject : auditLogger;
        attribute retentionPeriod : TimeDuration = 90 [d];
    }

    requirement def PatientSafetyRequirement {
        doc
        /* The delivered dosage shall never exceed the prescribed safe dosage, and the
            patient shall be protected from incorrect dosing due to cyberattack. */
        subject : patient;
        subject : pump;
        attribute maxSafeDoseRate : DosageRateValue = 500 [mL/h];
    }

    // ---- Internal parts of the pump ----

    part def SecurityModule {
        port secIn : NetworkPort;
        port secOut : ClinicalCommandPort;
        attribute validCredentials : CredentialSet[*];
        attribute encryptionKey : String;
        attribute authenticationLog : AuditEntry[*];

        action def validateCommand(in cmd : TherapyCommand, out accepted : Boolean, out role : String) {
            if validCredentials->exists(c | c.username == cmd.issuingUser and c.password == cmd.authenticationToken) {
                accepted = true;
                role = "Clinician";
            } else {
                accepted = false;
                role = "None";
            }
        }
    }

    part def TherapyEngine {
        port therapyControl : ClinicalCommandPort;
        port delivery : TherapyDeliveryPort;
        attribute currentRate : DosageRateValue;
        attribute remainingDuration : TherapyDurationValue;

        action def administerTherapy(in cmd : TherapyCommand) {
            currentRate = cmd.targetDoseRate;
            remainingDuration = cmd.targetDuration;
        }

        action def haltTherapy() {
            currentRate = 0 [mL/h];
            remainingDuration = 0 [min];
        }
    }

    part def AnomalyDetector {
        port monitor : NetworkPort;
        port alarm : AlarmPort;
        attribute baselinePacketRate : PacketRateValue;
        attribute currentRisk : RiskScoreValue;
        attribute detectionThreshold : RiskScoreValue = 0.7;

        action def evaluateTraffic(in pkt : NetworkPacket, out risk : RiskScoreValue) {
            // Simplified heuristic: high packet rate or unexpected source raises risk.
            if pkt.payload->size() > 1024 {
                risk = 0.9;
            } else {
                risk = 0.1;
            }
            currentRisk = risk;
        }
    }

    part def AuditLogger {
        port audit : AuditPort;
        attribute entries : AuditEntry[*];
        attribute maxEntries : Integer = 1000000;

        action def recordEntry(in entry : AuditEntry) {
            if entries->size() < maxEntries {
                entries = entries->append(entry);
            }
        }
    }

    // ---- Infusion Pump ----

    part def InfusionPump {
        requirement ref secReq : SecurityAnalysisGoal;
        requirement ref authReq : AuthenticationRequirement;
        requirement ref anomalyReq : AnomalyDetectionRequirement;
        requirement ref lockdownReq : SafetyLockdownRequirement;
        requirement ref auditReq : AuditLoggingRequirement;
        requirement ref patientReq : PatientSafetyRequirement;

        attribute deviceId : String = "PUMP-7421";
        attribute model : String = "MedFlow-X100";
        attribute firmwareVersion : String = "3.4.1";

        port network : NetworkPort;
        port command : ClinicalCommandPort;
        port delivery : TherapyDeliveryPort;
        port monitoring : PatientMonitoringPort;
        port auditOut : AuditPort;
        port alarmOut : AlarmPort;

        part securityModule : SecurityModule {
            attribute encryptionKey = "AES-256-key-material";
            attribute validCredentials : CredentialSet[2] = {
                CredentialSet("nurse.alice", "alice-token-7421", "Clinician"),
                CredentialSet("dr.bob", "bob-token-9982", "Clinician")
            };
        }
        part therapyEngine : TherapyEngine;
        part anomalyDetector : AnomalyDetector {
            attribute baselinePacketRate = 5 [packet/s];
        }
        part auditLogger : AuditLogger;

        attribute currentCommand : TherapyCommand;
        attribute state : String;

        state machine PumpStateMachine {
            entry standby;
            state standby;
            state authenticating;
            state delivering;
            state alarming;
            state lockdown;

            transition standby_to_authenticating : standby -> authenticating
                if network.packetIn->notEmpty();
            transition authenticating_to_delivering : authenticating -> delivering
                if securityModule.validateCommand(currentCommand) and currentCommand.targetDoseRate <= 500 [mL/h];
            transition authenticating_to_alarming : authenticating -> alarming
                if not securityModule.validateCommand(currentCommand);
            transition delivering_to_alarming : delivering -> alarming
                if anomalyDetector.currentRisk > 0.7;
            transition alarming_to_lockdown : alarming -> lockdown
                if anomalyDetector.currentRisk > 0.9;
            transition lockdown_to_standby : lockdown -> standby
                if auditLogger.entries->size() > 0 and command.acknowledgments->notEmpty();
        }

        action def processIncomingCommand(in pkt : NetworkPacket) {
            // Parse packet into command, validate, deliver or alarm.
            var cmd : TherapyCommand;
            cmd.commandId = pkt.payload;
            cmd.targetDoseRate = 100 [mL/h];
            cmd.targetDuration = 60 [min];
            cmd.issuingUser = "external";
            currentCommand = cmd;
            anomalyDetector.evaluateTraffic(pkt, anomalyDetector.currentRisk);
            if securityModule.validateCommand(cmd) {
                therapyEngine.administerTherapy(cmd);
                auditLogger.recordEntry(AuditEntry(
                    "AUD-" + pkt.sourceAddress,
                    TimeInstant(),
                    cmd.issuingUser,
                    "DELIVER",
                    "SUCCESS",
                    pkt.sourceAddress
                ));
            } else {
                auditLogger.recordEntry(AuditEntry(
                    "AUD-" + pkt.sourceAddress,
                    TimeInstant(),
                    cmd.issuingUser,
                    "REJECT",
                    "AUTH_FAILURE",
                    pkt.sourceAddress
                ));
                alarmOut.alarms = AlarmEvent(
                    "ALM-001",
                    0.9,
                    "Unauthorized command detected",
                    TimeInstant()
                );
            }
        }
    }

    // ---- Clinical Workstation ----

    part def ClinicalWorkstation {
        attribute workstationId : String = "WS-ICU-01";
        attribute operatorId : String = "nurse.alice";
        port network : NetworkPort;
        port command : ClinicalCommandPort;
        port alarmIn : AlarmPort;

        action def programTherapy(in rate : DosageRateValue, in duration : TherapyDurationValue,
                                  out cmd : TherapyCommand) {
            cmd = TherapyCommand(
                "CMD-" + workstationId,
                rate,
                duration,
                TimeInstant(),
                operatorId,
                workstationId,
                "alice-token-7421",
                "signature-12345"
            );
        }

        action def receiveAlarm(in alarm : AlarmEvent) {
            // Operator is alerted; therapy may be manually paused.
        }
    }

    // ---- Healthcare Network ----

    part def Firewall {
        port external : NetworkPort;
        port internal : NetworkPort;
        attribute ruleSet : String[*] = {"allow 10.0.0.0/8", "deny 0.0.0.0/0"};

        action def filterPacket(in pkt : NetworkPacket, out allowed : Boolean) {
            allowed = pkt.sourceAddress->startsWith("10.0.0.");
        }
    }

    part def HealthcareNetwork {
        attribute networkId : String = "HOSP-NET-01";
        attribute subnet : String = "10.0.0.0/24";
        port external : NetworkPort;
        port internal : NetworkPort;

        part firewall : Firewall;
    }

    // ---- Patient ----

    part def Patient {
        attribute patientId : String = "PAT-000123";
        attribute weight : MassValue = 70 [kg];
        attribute allergies : String[*] = {"penicillin"};
        port monitoring : PatientMonitoringPort;
        port therapy : TherapyDeliveryPort;

        attribute currentVitals : VitalSigns;

        action def updateVitals(out vitals : VitalSigns) {
            vitals = VitalSigns(72 [beats/min], 36.8 [degC], 98.0, TimeInstant());
            currentVitals = vitals;
        }

        action def receiveThapy(in rate : DosageRateValue) {
            // Physiological response model placeholder.
        }

        action def experienceAdverseEvent(in alarm : AlarmEvent) {
            // Record patient harm if therapy exceeded safe bounds.
        }
    }

    // ---- Attacker ----

    part def ExploitFramework {
        port scan : NetworkPort;
        attribute discoveredDevices : DeviceDiscovery[*];

        action def discoverDevices(in subnet : String, out devices : DeviceDiscovery[*]) {
            devices = DeviceDiscovery("10.0.0.21", "MedFlow-X100", "3.4.1", {"SNMP", "HL7v2"});
            discoveredDevices = devices;
        }

        action def exploitVulnerability(in device : DeviceDiscovery, out success : Boolean) {
            // Attempt to exploit firmware weakness (e.g., weak auth).
            success = true;
        }
    }

    part def CommandInjector {
        port inject : AttackCommandPort;
        attribute forgedRate : DosageRateValue = 1200 [mL/h];
        attribute forgedDuration : TherapyDurationValue = 600 [min];

        action def craftMaliciousCommand(in device : DeviceDiscovery, out cmd : MaliciousCommand) {
            cmd = MaliciousCommand(
                "CMD-EVIL-001",
                forgedRate,
                forgedDuration,
                "forged-token",
                "forged-signature"
            );
        }

        action def injectCommand(in cmd : MaliciousCommand, out pkt : NetworkPacket) {
            pkt = NetworkPacket(
                "192.168.66.6",
                device.deviceAddress,
                cmd.commandId,
                TimeInstant(),
                256
            );
        }
    }

    part def Attacker {
        attribute attackerId : String = "THREAT-ACTOR-7";
        attribute motivation : String = "Patient harm via dosage alteration";
        attribute sophistication : String = "Advanced";
        port network : NetworkPort;
        port attack : AttackCommandPort;

        part exploitFramework : ExploitFramework;
        part commandInjector : CommandInjector;

        action def executeAttackSequence(in targetSubnet : String) {
            var discovered : DeviceDiscovery[*];
            var target : DeviceDiscovery;
            var exploitSuccess : Boolean;
            var maliciousCmd : MaliciousCommand;
            var maliciousPkt : NetworkPacket;

            exploitFramework.discoverDevices(targetSubnet, discovered);
            target = discovered->first();
            exploitFramework.exploitVulnerability(target, exploitSuccess);
            if exploitSuccess {
                commandInjector.craftMaliciousCommand(target, maliciousCmd);
                commandInjector.injectCommand(maliciousCmd, maliciousPkt);
                attack.maliciousCommands = maliciousCmd;
                attack.exploitPayloads = maliciousPkt;
            }
        }
    }

    // ---- System Composition ----

    part CybersecurityAnalysisSystem {
        requirement ref goal : SecurityAnalysisGoal;

        part pump : InfusionPump {
            override attribute deviceId = "PUMP-ICU-7421";
        }
        part workstation : ClinicalWorkstation;
        part network : HealthcareNetwork;
        part patient : Patient {
            override attribute patientId = "PAT-ICU-000123";
        }
        part attacker : Attacker;

        // Internal connections
        connection workstationToNetwork : workstation.network <-> network.external;
        connection networkToPump : network.internal <-> pump.network;
        connection pumpToPatientDelivery : pump.delivery <-> patient.therapy;
        connection patientToPumpMonitoring : patient.monitoring <-> pump.monitoring;
        connection pumpToWorkstationCommand : pump.command <-> workstation.command;
        connection pumpAlarmToWorkstation : pump.alarmOut <-> workstation.alarmIn;
        connection pumpAuditOut : pump.auditOut;

        // Attack connections
        connection attackerToNetwork : attacker.network <-> network.external;
        connection attackerAttackPath : attacker.attack;

        // Security analysis orchestration
        action def runHijackScenario() {
            // Attacker discovers and targets the pump on the hospital subnet.
            var subnet : String = network.subnet;
            attacker.executeAttackSequence(subnet);

            // Attacker packet is delivered through the network.
            var incomingPkt : NetworkPacket;
            var fwAllowed : Boolean;
            network.firewall.filterPacket(attacker.attack.exploitPayloads->first(), fwAllowed);

            if fwAllowed {
                // Misconfigured firewall permits the attack packet.
                pump.processIncomingCommand(attacker.attack.exploitPayloads->first());
            } else {
                // Firewall blocks; attack fails.
                pump.auditLogger.recordEntry(AuditEntry(
                    "AUD-FW-BLOCK",
                    TimeInstant(),
                    attacker.attackerId,
                    "BLOCKED",
                    "FIREWALL_DENY",
                    "192.168.66.6"
                ));
            }

            // Legitimate programming path still exists.
            var legitCmd : TherapyCommand;
            workstation.programTherapy(75 [mL/h], 120 [min], legitCmd);
            pump.processIncomingCommand(NetworkPacket(
                workstation.workstationId,
                pump.deviceId,
                legitCmd.commandId,
                TimeInstant(),
                64
            ));

            // Patient monitoring continues.
            var v : VitalSigns;
            patient.updateVitals(v);
        }
    }

    // ---- Verification ----

    verification def VerifyHijackDetection {
        subject : CybersecurityAnalysisSystem;
        objective {
            doc
            /* Confirm that an injected malicious command exceeding the safe dose
                rate is rejected by the security module, logged by the audit logger,
                and raises an alarm that transitions the pump to Lockdown. */
        }
    }

    verification def VerifyPatientSafety {
        subject : CybersecurityAnalysisSystem;
        objective {
            doc
            /* Confirm that under no simulated scenario does the delivered dose rate
                exceed the maximum safe dose rate of 500 mL/h. */
        }
    }
}
