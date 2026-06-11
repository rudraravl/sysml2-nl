package MedicalDeviceHijackMitigationModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def CyberRiskLevel {
        enum values { Low; Moderate; High; Critical; }
    }

    attribute def DeviceTrustState {
        enum values { Trusted; Suspect; Compromised; Isolated; Restored; }
    }

    attribute def AlarmPriority {
        enum values { Advisory; Warning; Critical; }
    }

    attribute def TherapyMode {
        enum values { NormalTherapy; SafeTherapy; SuspendedTherapy; ManualOverride; }
    }

    item def DrugSolution {
        attribute concentration : Real;
        attribute concentrationUnit : String = "mg/mL";
    }

    item def TherapyCommand {
        attribute commandedRate : Real;
        attribute rateUnit : String = "mL/h";
        attribute doseLimit : Real;
        attribute authenticated : Boolean;
        attribute commandSequenceNumber : Integer;
    }

    item def TelemetryPacket {
        attribute measuredRate : Real;
        attribute reservoirVolume : Real;
        attribute batteryLevel : Real;
        attribute signedByDevice : Boolean;
        attribute timestampAge : Real;
        attribute timestampAgeUnit : String = "s";
    }

    item def SecurityEvent {
        attribute risk : CyberRiskLevel;
        attribute sourceAddress : String;
        attribute failedAuthenticationCount : Integer;
        attribute anomalousCommand : Boolean;
        attribute unauthorizedDoseChange : Boolean;
    }

    item def AlarmSignal {
        attribute priority : AlarmPriority;
        attribute message : String;
        attribute audible : Boolean;
        attribute visual : Boolean;
    }

    item def ClinicalSetting {
        attribute prescribedRate : Real;
        attribute prescribedRateUnit : String = "mL/h";
        attribute maxRate : Real;
        attribute maxRateUnit : String = "mL/h";
        attribute patientWeight : Real;
        attribute patientWeightUnit : String = "kg";
    }

    port def CommandInputPort {
        in item command : TherapyCommand;
    }

    port def TelemetryOutputPort {
        out item telemetry : TelemetryPacket;
    }

    port def DrugInputPort {
        in item drug : DrugSolution;
    }

    port def DrugOutputPort {
        out item drug : DrugSolution;
    }

    port def SecurityEventPort {
        out item event : SecurityEvent;
    }

    port def AlarmOutputPort {
        out item alarm : AlarmSignal;
    }

    port def ClinicalSettingPort {
        in item setting : ClinicalSetting;
    }

    part def NetworkedInfusionPump {
        attribute trustState : DeviceTrustState = DeviceTrustState::Trusted;
        attribute therapyMode : TherapyMode = TherapyMode::NormalTherapy;
        attribute currentInfusionRate : Real;
        attribute currentInfusionRateUnit : String = "mL/h";
        attribute maxSafeInfusionRate : Real = 100.0;
        attribute maxSafeInfusionRateUnit : String = "mL/h";
        attribute batteryPercent : Real;
        attribute reservoirVolume : Real;
        attribute reservoirVolumeUnit : String = "mL";

        port commandIn : CommandInputPort;
        port telemetryOut : TelemetryOutputPort;
        port drugIn : DrugInputPort;
        port drugOut : DrugOutputPort;
        port clinicalSettingIn : ClinicalSettingPort;
        port alarmOut : AlarmOutputPort;

        action validateTherapyCommand {
            in item command : TherapyCommand;
            in item setting : ClinicalSetting;
            out valid : Boolean;

            first start;
            then checkAuthentication;
            then checkSequence;
            then checkDoseLimit;
            then decision;

            action checkAuthentication {
                in item command : TherapyCommand;
                out authenticated : Boolean;
            }

            action checkSequence {
                in item command : TherapyCommand;
                out freshCommand : Boolean;
            }

            action checkDoseLimit {
                in item command : TherapyCommand;
                in item setting : ClinicalSetting;
                out withinLimit : Boolean;
            }

            action decision {
                in authenticated : Boolean;
                in freshCommand : Boolean;
                in withinLimit : Boolean;
                out valid : Boolean;
            }
        }

        action enterSafeTherapy {
            in item setting : ClinicalSetting;
            out safeRate : Real;
        }

        action suspendTherapy {
            out suspendedRate : Real = 0.0;
        }

        action emitCriticalAlarm {
            out item alarm : AlarmSignal;
        }

        state def PumpTherapyStateMachine {
            state Normal;
            state Safe;
            state Suspended;
            state ManualOverride;

            initial then Normal;

            transition Normal_to_Safe
                first Normal
                accept event : SecurityEvent
                if event.risk == CyberRiskLevel::High
                then Safe;

            transition Normal_to_Suspended
                first Normal
                accept event : SecurityEvent
                if event.risk == CyberRiskLevel::Critical
                then Suspended;

            transition Safe_to_Suspended
                first Safe
                accept event : SecurityEvent
                if event.unauthorizedDoseChange == true
                then Suspended;

            transition Safe_to_Normal
                first Safe
                accept restored : Boolean
                if restored == true
                then Normal;

            transition Suspended_to_ManualOverride
                first Suspended
                accept clinicianOverride : Boolean
                if clinicianOverride == true
                then ManualOverride;

            transition ManualOverride_to_Normal
                first ManualOverride
                accept restored : Boolean
                if restored == true
                then Normal;
        }
    }

    part def WirelessClinicalNetwork {
        attribute encryptionEnabled : Boolean = true;
        attribute segmentationEnabled : Boolean = true;
        attribute allowedDeviceCount : Integer;
        attribute observedUnknownEndpointCount : Integer;

        port commandOut : CommandInputPort;
        port telemetryIn : TelemetryOutputPort;
        port securityEventOut : SecurityEventPort;

        action inspectNetworkTraffic {
            in item command : TherapyCommand;
            out item event : SecurityEvent;
        }
    }

    part def HijackDetectionController {
        attribute failedLoginThreshold : Integer = 3;
        attribute maxTimestampAge : Real = 5.0;
        attribute maxTimestampAgeUnit : String = "s";
        attribute doseChangeTolerance : Real = 5.0;
        attribute doseChangeToleranceUnit : String = "percent";
        attribute detectedRisk : CyberRiskLevel = CyberRiskLevel::Low;

        port telemetryIn : TelemetryOutputPort;
        port securityEventIn : SecurityEventPort;
        port alarmOut : AlarmOutputPort;
        port commandGateOut : CommandInputPort;

        action assessDeviceHijackRisk {
            in item telemetry : TelemetryPacket;
            in item event : SecurityEvent;
            out risk : CyberRiskLevel;
        }

        action blockUnauthorizedCommand {
            in item command : TherapyCommand;
            out blocked : Boolean;
        }

        action requestDeviceIsolation {
            in risk : CyberRiskLevel;
            out isolate : Boolean;
        }

        state def DetectionStateMachine {
            state Monitoring;
            state SuspiciousActivity;
            state HijackConfirmed;
            state MitigationActive;
            state RecoveryVerification;

            initial then Monitoring;

            transition Monitoring_to_SuspiciousActivity
                first Monitoring
                accept event : SecurityEvent
                if event.failedAuthenticationCount >= 3 or event.anomalousCommand == true
                then SuspiciousActivity;

            transition SuspiciousActivity_to_HijackConfirmed
                first SuspiciousActivity
                accept event : SecurityEvent
                if event.unauthorizedDoseChange == true
                then HijackConfirmed;

            transition HijackConfirmed_to_MitigationActive
                first HijackConfirmed
                accept isolate : Boolean
                if isolate == true
                then MitigationActive;

            transition MitigationActive_to_RecoveryVerification
                first MitigationActive
                accept resetComplete : Boolean
                if resetComplete == true
                then RecoveryVerification;

            transition RecoveryVerification_to_Monitoring
                first RecoveryVerification
                accept verifiedClean : Boolean
                if verifiedClean == true
                then Monitoring;
        }
    }

    part def ClinicalAlarmConsole {
        attribute activeAlarmCount : Integer;
        attribute highestPriority : AlarmPriority = AlarmPriority::Advisory;

        port alarmIn : AlarmOutputPort;

        action displayAlarm {
            in item alarm : AlarmSignal;
        }

        action notifyClinician {
            in item alarm : AlarmSignal;
        }
    }

    part def ClinicianWorkstation {
        attribute clinicianAuthenticated : Boolean;
        attribute sessionTimeout : Real = 300.0;
        attribute sessionTimeoutUnit : String = "s";

        port clinicalSettingOut : ClinicalSettingPort;
        port commandOut : CommandInputPort;
        port alarmIn : AlarmOutputPort;

        action prescribeTherapy {
            out item setting : ClinicalSetting;
        }

        action approveManualOverride {
            in clinicianAuthenticated : Boolean;
            out approved : Boolean;
        }
    }

    part def Patient {
        attribute weight : Real;
        attribute weightUnit : String = "kg";
        attribute receivedVolume : Real;
        attribute receivedVolumeUnit : String = "mL";

        port therapyIn : DrugOutputPort;
    }

    part def MedicalDeviceHijackProtectionSystem {
        doc /* Primary function: protect a networked infusion pump from medical device hijack by authenticating therapy commands, detecting anomalous or unauthorized control attempts, isolating compromised communication paths, preserving safe therapy limits, and alerting clinicians before patient harm can occur. */

        part pump : NetworkedInfusionPump;
        part network : WirelessClinicalNetwork;
        part detector : HijackDetectionController;
        part console : ClinicalAlarmConsole;
        part workstation : ClinicianWorkstation;
        part patient : Patient;

        item drugSupply : DrugSolution {
            attribute concentration = 2.0;
            attribute concentrationUnit = "mg/mL";
        }

        item nominalSetting : ClinicalSetting {
            attribute prescribedRate = 25.0;
            attribute prescribedRateUnit = "mL/h";
            attribute maxRate = 60.0;
            attribute maxRateUnit = "mL/h";
            attribute patientWeight = 70.0;
            attribute patientWeightUnit = "kg";
        }

        connect workstation.commandOut to network.commandOut;
        connect network.commandOut to pump.commandIn;
        connect pump.telemetryOut to detector.telemetryIn;
        connect network.securityEventOut to detector.securityEventIn;
        connect detector.alarmOut to console.alarmIn;
        connect pump.alarmOut to console.alarmIn;
        connect workstation.clinicalSettingOut to pump.clinicalSettingIn;
        connect pump.drugOut to patient.therapyIn;
        connect workstation.alarmIn to console.alarmIn;

        action operateProtectedTherapy {
            first prescribe;
            then validate;
            then deliver;
            then monitor;
            then respond;

            action prescribe {
                out item setting : ClinicalSetting;
            }

            action validate {
                in item command : TherapyCommand;
                in item setting : ClinicalSetting;
                out accepted : Boolean;
            }

            action deliver {
                in accepted : Boolean;
                out deliveredRate : Real;
            }

            action monitor {
                in item telemetry : TelemetryPacket;
                in item event : SecurityEvent;
                out risk : CyberRiskLevel;
            }

            action respond {
                in risk : CyberRiskLevel;
                out item alarm : AlarmSignal;
                out isolated : Boolean;
            }
        }
    }

    requirement def PreventUnauthorizedDoseChange {
        subject system : MedicalDeviceHijackProtectionSystem;

        require constraint {
            system.pump.currentInfusionRate <= system.pump.maxSafeInfusionRate
        }

        doc /* The system shall prevent an unauthenticated or anomalous command from increasing infusion rate above the prescribed clinical maximum. */
    }

    requirement def DetectLikelyHijack {
        subject detector : HijackDetectionController;

        require constraint {
            detector.failedLoginThreshold <= 3
        }

        doc /* The detector shall classify repeated failed authentication attempts or unauthorized dose changes as a high or critical cyber risk. */
    }

    requirement def EnterSafeModeOnCriticalRisk {
        subject pump : NetworkedInfusionPump;

        require constraint {
            pump.trustState != DeviceTrustState::Compromised or pump.therapyMode == TherapyMode::SuspendedTherapy
        }

        doc /* The pump shall suspend therapy or enter safe therapy when device compromise is confirmed. */
    }

    requirement def AlertClinicianOnHijack {
        subject console : ClinicalAlarmConsole;

        require constraint {
            console.highestPriority == AlarmPriority::Critical
        }

        doc /* The alarm console shall present a critical audible and visual alarm when a hijack is confirmed. */
    }

    requirement def PreserveTelemetryIntegrity {
        subject packet : TelemetryPacket;

        require constraint {
            packet.signedByDevice == true and packet.timestampAge <= 5.0
        }

        doc /* Telemetry used for clinical and cybersecurity decisions shall be signed and recent. */
    }

    requirement def IsolateCompromisedCommunication {
        subject network : WirelessClinicalNetwork;

        require constraint {
            network.segmentationEnabled == true and network.encryptionEnabled == true
        }

        doc /* The clinical network shall support encrypted, segmented communication so a suspected hijack path can be isolated without disabling all clinical monitoring. */
    }

    satisfy PreventUnauthorizedDoseChange by MedicalDeviceHijackProtectionSystem::pump;
    satisfy DetectLikelyHijack by MedicalDeviceHijackProtectionSystem::detector;
    satisfy EnterSafeModeOnCriticalRisk by MedicalDeviceHijackProtectionSystem::pump;
    satisfy AlertClinicianOnHijack by MedicalDeviceHijackProtectionSystem::console;
    satisfy IsolateCompromisedCommunication by MedicalDeviceHijackProtectionSystem::network;
}