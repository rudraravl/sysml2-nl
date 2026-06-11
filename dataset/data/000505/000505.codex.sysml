package SubcutaneousImplantableDefibrillatorModel {

    import ScalarValues::*;
    import SI::*;

    attribute def Voltage { unit : Unit = volt; }
    attribute def Current { unit : Unit = ampere; }
    attribute def Energy { unit : Unit = joule; }
    attribute def Power { unit : Unit = watt; }
    attribute def Time { unit : Unit = second; }
    attribute def Frequency { unit : Unit = hertz; }
    attribute def Impedance { unit : Unit = ohm; }
    attribute def Temperature { unit : Unit = kelvin; }
    attribute def HeartRate { unit : Unit = hertz; }

    item def SubcutaneousECG {
        attribute amplitude : Voltage;
        attribute sampleRate : Frequency;
        attribute timestamp : Time;
    }

    item def ArrhythmiaClassification {
        attribute ventricularTachycardiaDetected : Boolean;
        attribute ventricularFibrillationDetected : Boolean;
        attribute confidence : Real;
        attribute measuredHeartRate : HeartRate;
    }

    item def ShockPulse {
        attribute deliveredEnergy : Energy;
        attribute peakVoltage : Voltage;
        attribute pulseWidth : Time;
        attribute biphasic : Boolean;
    }

    item def BatteryStatus {
        attribute remainingEnergy : Energy;
        attribute terminalVoltage : Voltage;
        attribute replacementRecommended : Boolean;
    }

    item def DeviceStatus {
        attribute therapyEnabled : Boolean;
        attribute leadIntegrityOk : Boolean;
        attribute capacitorReady : Boolean;
        attribute faultActive : Boolean;
        attribute caseTemperature : Temperature;
    }

    item def TelemetryPacket {
        attribute patientEpisodeSummary : String;
        attribute storedECGIncluded : Boolean;
        attribute batteryStatusIncluded : Boolean;
        attribute deviceStatusIncluded : Boolean;
    }

    item def ProgrammerCommand {
        attribute enableTherapy : Boolean;
        attribute requestEpisodeData : Boolean;
        attribute setShockEnergy : Energy;
        attribute setDetectionThreshold : HeartRate;
    }

    port def SensePort {
        in item cardiacSignal : SubcutaneousECG;
    }

    port def TherapyPort {
        out item shock : ShockPulse;
    }

    port def PowerPort {
        out item status : BatteryStatus;
    }

    port def TelemetryPort {
        in item command : ProgrammerCommand;
        out item report : TelemetryPacket;
    }

    port def StatusPort {
        out item status : DeviceStatus;
    }

    part def SubcutaneousElectrodeLead {
        attribute leadImpedance : Impedance;
        attribute parasternalPositioned : Boolean;
        port sense : SensePort;
        port therapy : TherapyPort;
    }

    part def PulseGeneratorCan {
        attribute canElectrodeArea : Real;
        attribute hermeticSealOk : Boolean;
        port therapy : TherapyPort;
    }

    part def Battery {
        attribute nominalVoltage : Voltage = 3.2 [volt];
        attribute usableEnergy : Energy = 18000 [joule];
        port powerStatus : PowerPort;
    }

    part def CapacitorBank {
        attribute storedEnergy : Energy;
        attribute chargeVoltage : Voltage;
        attribute maximumEnergy : Energy = 80 [joule];
    }

    part def AnalogFrontEnd {
        attribute inputNoise : Voltage;
        attribute commonModeRejection : Real;
        port senseIn : SensePort;
    }

    part def ArrhythmiaDetector {
        attribute vtThreshold : HeartRate;
        attribute vfThreshold : HeartRate;
        attribute sensingVectorSelected : String;
        in item ecg : SubcutaneousECG;
        out item classification : ArrhythmiaClassification;
    }

    part def TherapyController {
        attribute therapyEnabled : Boolean;
        attribute programmedShockEnergy : Energy = 80 [joule];
        in item classification : ArrhythmiaClassification;
        out item requestedShock : ShockPulse;
        port statusOut : StatusPort;
    }

    part def TelemetryModule {
        attribute communicationRange : Real;
        port telemetry : TelemetryPort;
    }

    part def Memory {
        attribute episodeCapacity : Integer = 128;
        attribute storedEpisodeCount : Integer;
    }

    action def AcquireSubcutaneousECG {
        in item rawSignal : SubcutaneousECG;
        out item sampledSignal : SubcutaneousECG;
    }

    action def DetectShockableRhythm {
        in item sampledSignal : SubcutaneousECG;
        out item result : ArrhythmiaClassification;
    }

    action def ChargeCapacitor {
        in attribute targetEnergy : Energy;
        out attribute capacitorReady : Boolean;
    }

    action def DeliverDefibrillationShock {
        in item requestedShock : ShockPulse;
        out item deliveredShock : ShockPulse;
    }

    action def StoreEpisodeAndReportStatus {
        in item classification : ArrhythmiaClassification;
        in item deliveredShock : ShockPulse;
        out item telemetryReport : TelemetryPacket;
    }

    state def TherapyControlStateMachine {
        state ImplantInactive;
        state Standby;
        state Monitoring;
        state SuspectedArrhythmia;
        state Charging;
        state ShockArmed;
        state DeliveringShock;
        state PostShockAssessment;
        state FaultSafe;

        transition first ImplantInactive then Standby;
        transition Standby then Monitoring
            if therapyEnabled == true;

        transition Monitoring then SuspectedArrhythmia
            if ventricularTachycardiaDetected == true or ventricularFibrillationDetected == true;

        transition SuspectedArrhythmia then Monitoring
            if confidence < 0.80;

        transition SuspectedArrhythmia then Charging
            if confidence >= 0.80;

        transition Charging then ShockArmed
            if capacitorReady == true;

        transition ShockArmed then DeliveringShock
            if therapyEnabled == true and leadIntegrityOk == true;

        transition DeliveringShock then PostShockAssessment;

        transition PostShockAssessment then Monitoring
            if ventricularTachycardiaDetected == false and ventricularFibrillationDetected == false;

        transition PostShockAssessment then Charging
            if ventricularTachycardiaDetected == true or ventricularFibrillationDetected == true;

        transition Monitoring then FaultSafe
            if faultActive == true;

        transition Charging then FaultSafe
            if faultActive == true;

        transition ShockArmed then FaultSafe
            if faultActive == true;
    }

    part def SubcutaneousImplantableDefibrillator {
        attribute deviceIdentifier : String;
        attribute implantedSubcutaneously : Boolean = true;
        attribute transvenousLeadRequired : Boolean = false;
        attribute chronicBradycardiaPacingSupported : Boolean = false;

        part lead : SubcutaneousElectrodeLead;
        part can : PulseGeneratorCan;
        part battery : Battery;
        part capacitorBank : CapacitorBank;
        part analogFrontEnd : AnalogFrontEnd;
        part detector : ArrhythmiaDetector;
        part controller : TherapyController;
        part telemetryModule : TelemetryModule;
        part memory : Memory;

        port patientSense : SensePort;
        port patientTherapy : TherapyPort;
        port clinicianTelemetry : TelemetryPort;
        port deviceStatus : StatusPort;

        connect patientSense to lead.sense;
        connect lead.sense to analogFrontEnd.senseIn;
        connect analogFrontEnd.senseIn.cardiacSignal to detector.ecg;
        connect detector.classification to controller.classification;
        connect controller.requestedShock to patientTherapy.shock;
        connect controller.statusOut to deviceStatus;
        connect telemetryModule.telemetry to clinicianTelemetry;
        connect battery.powerStatus.status to telemetryModule.telemetry.report;
        connect can.therapy to patientTherapy;
        connect lead.therapy to patientTherapy;

        perform action monitorAndTreat : MonitorAndTreatArrhythmia;
        exhibit state therapyStates : TherapyControlStateMachine;
    }

    action def MonitorAndTreatArrhythmia {
        in item sensedECG : SubcutaneousECG;
        out item deliveredTherapy : ShockPulse;
        out item episodeReport : TelemetryPacket;

        action acquire : AcquireSubcutaneousECG {
            in rawSignal = sensedECG;
        }

        action classify : DetectShockableRhythm {
            in sampledSignal = acquire.sampledSignal;
        }

        action charge : ChargeCapacitor {
            in targetEnergy = 80 [joule];
        }

        action shock : DeliverDefibrillationShock {
            in requestedShock.deliveredEnergy = 80 [joule];
            in requestedShock.peakVoltage = 1400 [volt];
            in requestedShock.pulseWidth = 0.010 [second];
            in requestedShock.biphasic = true;
        }

        action record : StoreEpisodeAndReportStatus {
            in classification = classify.result;
            in deliveredShock = shock.deliveredShock;
        }

        flow acquire.sampledSignal to classify.sampledSignal;
        flow classify.result to record.classification;
        flow shock.deliveredShock to deliveredTherapy;
        flow record.telemetryReport to episodeReport;
    }

    requirement def PrimaryFunctionRequirement {
        subject sicd : SubcutaneousImplantableDefibrillator;

        doc
        /* The system shall continuously monitor subcutaneous cardiac electrical activity, identify shockable ventricular tachyarrhythmias, and deliver a high-energy biphasic defibrillation shock between the pulse generator can and subcutaneous electrode lead to terminate the arrhythmia while avoiding intravascular or transvenous leads. */

        require constraint {
            sicd.implantedSubcutaneously == true and
            sicd.transvenousLeadRequired == false and
            sicd.controller.therapyEnabled == true
        }
    }

    requirement def ShockTherapyEnergyRequirement {
        subject therapy : TherapyController;

        require constraint {
            therapy.programmedShockEnergy <= 80 [joule] and
            therapy.programmedShockEnergy > 0 [joule]
        }
    }

    requirement def RhythmDetectionRequirement {
        subject detector : ArrhythmiaDetector;

        require constraint {
            detector.vtThreshold > 2.5 [hertz] and
            detector.vfThreshold >= detector.vtThreshold
        }
    }

    requirement def LeadIntegrityRequirement {
        subject lead : SubcutaneousElectrodeLead;

        require constraint {
            lead.leadImpedance > 20 [ohm] and
            lead.leadImpedance < 200 [ohm] and
            lead.parasternalPositioned == true
        }
    }

    requirement def BatteryStatusRequirement {
        subject battery : Battery;

        require constraint {
            battery.nominalVoltage > 2.5 [volt] and
            battery.usableEnergy >= 10000 [joule]
        }
    }

    requirement def NoChronicPacingRequirement {
        subject sicd : SubcutaneousImplantableDefibrillator;

        require constraint {
            sicd.chronicBradycardiaPacingSupported == false
        }
    }

    part sicdSystem : SubcutaneousImplantableDefibrillator {
        attribute deviceIdentifier = "S-ICD high-level functional model";
        part detector {
            attribute vtThreshold = 3.0 [hertz];
            attribute vfThreshold = 4.0 [hertz];
            attribute sensingVectorSelected = "primary subcutaneous vector";
        }
        part lead {
            attribute leadImpedance = 75 [ohm];
            attribute parasternalPositioned = true;
        }
        part controller {
            attribute therapyEnabled = true;
            attribute programmedShockEnergy = 80 [joule];
        }
        part capacitorBank {
            attribute maximumEnergy = 80 [joule];
            attribute storedEnergy = 0 [joule];
            attribute chargeVoltage = 0 [volt];
        }
        part can {
            attribute hermeticSealOk = true;
        }
    }

    satisfy PrimaryFunctionRequirement by sicdSystem;
    satisfy ShockTherapyEnergyRequirement by sicdSystem.controller;
    satisfy RhythmDetectionRequirement by sicdSystem.detector;
    satisfy LeadIntegrityRequirement by sicdSystem.lead;
    satisfy BatteryStatusRequirement by sicdSystem.battery;
    satisfy NoChronicPacingRequirement by sicdSystem;
}