package ICD_System {
    private import ScalarValues::*;
    private import ISQ::*;

    item def ECGSignal;
    item def TherapyPulse;
    item def TelemetryData;
    item def ProgrammerCommand;

    attribute def HeartRateValue :> Real;
    attribute def ShockEnergyValue :> Real;

    attribute def ArrhythmiaDetected;
    attribute def VF_Detected;
    attribute def VT_Detected;
    attribute def Brady_Detected;
    attribute def ChargeComplete;
    attribute def TherapyEffective;
    attribute def TherapyDelivered;

    attribute def ArrhythmiaType;
    attribute def TherapyCommand;

    port def ECGOutPort {
        out signal : ECGSignal;
    }
    port def ECGInPort {
        in signal : ECGSignal;
    }
    port def TherapyOutPort {
        out pulse : TherapyPulse;
    }
    port def TherapyInPort {
        in pulse : TherapyPulse;
    }
    port def TelemetryOutPort {
        out data : TelemetryData;
    }
    port def TelemetryInPort {
        in cmd : ProgrammerCommand;
    }

    part def Heart {
        port atrialECGOut : ECGOutPort;
        port ventricularECGOut : ECGOutPort;
        port therapyIn : TherapyInPort;
    }

    part def Patient {
        part heart : Heart;
    }

    part def LeadSystem {
        port atrialECGIn : ECGInPort;
        port ventricularECGIn : ECGInPort;
        port atrialECGOut : ECGOutPort;
        port ventricularECGOut : ECGOutPort;
        port therapyIn : TherapyInPort;
        port therapyOut : TherapyOutPort;
    }

    part def SensingCircuit {
        port ecgIn : ECGInPort;
        port ecgOut : ECGOutPort;
        perform action filterAmplify : FilterAmplify;
    }

    part def ArrhythmiaDetector {
        port ecgIn : ECGInPort;
        out diagnosis : ArrhythmiaType;
        perform action analyzeRhythm : AnalyzeRhythm;
    }

    part def TherapyController {
        in diagnosis : ArrhythmiaType;
        out therapyCommand : TherapyCommand;
        perform action decideTherapy : DecideTherapy;
    }

    part def HighVoltageTherapyUnit {
        in therapyCommand : TherapyCommand;
        port therapyOut : TherapyOutPort;
        part capacitor;
        perform action chargeCapacitor : ChargeCapacitor;
        perform action deliverShock : DeliverShock;
        perform action deliverPacing : DeliverPacing;
    }

    part def TelemetryUnit {
        in deviceData : TelemetryData;
        port telemetryOut : TelemetryOutPort;
        port telemetryIn : TelemetryInPort;
        perform action logEvent : LogEvent;
    }

    part def BatteryModule {
        attribute capacity : Real;
        attribute status : String;
    }

    part def ExternalProgrammer {
        port telemetryOut : TelemetryOutPort;
        port telemetryIn : TelemetryInPort;
    }

    action def FilterAmplify {
        in rawSignal : ECGSignal;
        out processedSignal : ECGSignal;
    }

    action def AnalyzeRhythm {
        in signal : ECGSignal;
        out result : ArrhythmiaType;
    }

    action def DecideTherapy {
        in diagnosis : ArrhythmiaType;
        out command : TherapyCommand;
    }

    action def ChargeCapacitor {
        out chargeComplete : ChargeComplete;
    }

    action def DeliverShock {
        in energy : ShockEnergyValue;
        out pulse : TherapyPulse;
    }

    action def DeliverPacing {
        out pulse : TherapyPulse;
    }

    action def AssessTherapy {
        in postTherapyECG : ECGSignal;
        out effective : TherapyEffective;
    }

    action def LogEvent {
        in eventData : TelemetryData;
    }

    state def ICDStates {
        entry; then monitoring;
        state monitoring;
        accept ArrhythmiaDetected then analysis;
        state analysis;
        accept VF_Detected then charging;
        accept VT_Detected then charging;
        accept Brady_Detected then pacing;
        state charging;
        accept ChargeComplete then shock;
        state shock;
        accept TherapyDelivered then assess;
        state pacing;
        accept TherapyDelivered then assess;
        state assess;
        accept TherapyEffective then monitoring;
    }

    part def ICDDevice {
        part batteryModule : BatteryModule;
        part leadSystem : LeadSystem;
        part sensingCircuit : SensingCircuit;
        part arrhythmiaDetector : ArrhythmiaDetector;
        part therapyController : TherapyController;
        part highVoltageTherapyUnit : HighVoltageTherapyUnit;
        part telemetryUnit : TelemetryUnit;

        exhibit state icdStates : ICDStates;
    }

    requirement def MonitorHeartRequirement {
        doc /* The ICD shall continuously monitor the patient's heart rhythm. */
    }

    requirement def DetectArrhythmiasRequirement {
        doc /* The ICD shall detect ventricular fibrillation, ventricular tachycardia, and bradycardia. */
    }

    requirement def DeliverTherapyRequirement {
        doc /* The ICD shall deliver high-energy shocks or low-energy pacing pulses based on the detected arrhythmia. */
    }

    requirement def TelemetryRequirement {
        doc /* The ICD shall communicate with an external programmer to review history and adjust settings. */
    }

    requirement def BatteryLifeRequirement {
        doc /* The battery module shall provide power for a minimum of 5 years under normal operating conditions. */
    }

    part icdSystem {
        part patient : Patient;
        part icdDevice : ICDDevice;
        part externalProgrammer : ExternalProgrammer;

        requirement monitorReq : MonitorHeartRequirement {
            subject icdDevice;
        }
        requirement detectReq : DetectArrhythmiasRequirement {
            subject icdDevice;
        }
        requirement therapyReq : DeliverTherapyRequirement {
            subject icdDevice;
        }
        requirement telemetryReq : TelemetryRequirement {
            subject icdDevice;
        }
        requirement batteryReq : BatteryLifeRequirement {
            subject icdDevice.batteryModule;
        }

        connection heartToLeadAtrial connect patient.heart.atrialECGOut to icdDevice.leadSystem.atrialECGIn;
        connection heartToLeadVentricular connect patient.heart.ventricularECGOut to icdDevice.leadSystem.ventricularECGIn;
        connection leadToSensingAtrial connect icdDevice.leadSystem.atrialECGOut to icdDevice.sensingCircuit.ecgIn;
        connection leadToSensingVentricular connect icdDevice.leadSystem.ventricularECGOut to icdDevice.sensingCircuit.ecgIn;
        connection sensingToDetector connect icdDevice.sensingCircuit.ecgOut to icdDevice.arrhythmiaDetector.ecgIn;
        connection detectorToController connect icdDevice.arrhythmiaDetector.diagnosis to icdDevice.therapyController.diagnosis;
        connection controllerToTherapyUnit connect icdDevice.therapyController.therapyCommand to icdDevice.highVoltageTherapyUnit.therapyCommand;
        connection therapyUnitToLead connect icdDevice.highVoltageTherapyUnit.therapyOut to icdDevice.leadSystem.therapyIn;
        connection leadToHeart connect icdDevice.leadSystem.therapyOut to patient.heart.therapyIn;
        connection telemetryToProgrammer connect icdDevice.telemetryUnit.telemetryOut to externalProgrammer.telemetryIn;
        connection programmerToTelemetry connect externalProgrammer.telemetryOut to icdDevice.telemetryUnit.telemetryIn;
    }
}
