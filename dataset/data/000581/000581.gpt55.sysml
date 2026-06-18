package DefibrillatorSpecification {

    import ScalarValues::*;

    attribute def Voltage_V :> Real {
        attribute unitSymbol : String = "V";
        attribute quantityKind : String = "electric potential";
    }

    attribute def Current_A :> Real {
        attribute unitSymbol : String = "A";
        attribute quantityKind : String = "electric current";
    }

    attribute def Energy_J :> Real {
        attribute unitSymbol : String = "J";
        attribute quantityKind : String = "energy";
    }

    attribute def Power_W :> Real {
        attribute unitSymbol : String = "W";
        attribute quantityKind : String = "power";
    }

    attribute def Resistance_Ohm :> Real {
        attribute unitSymbol : String = "ohm";
        attribute quantityKind : String = "electrical resistance";
    }

    attribute def Capacitance_F :> Real {
        attribute unitSymbol : String = "F";
        attribute quantityKind : String = "capacitance";
    }

    attribute def Time_s :> Real {
        attribute unitSymbol : String = "s";
        attribute quantityKind : String = "time";
    }

    attribute def HeartRate_bpm :> Real {
        attribute unitSymbol : String = "beat/min";
        attribute quantityKind : String = "heart rate";
    }

    attribute def Mass_kg :> Real {
        attribute unitSymbol : String = "kg";
        attribute quantityKind : String = "mass";
    }

    attribute def Temperature_degC :> Real {
        attribute unitSymbol : String = "degC";
        attribute quantityKind : "temperature";
    }

    enum def ShockMode {
        enum AED;
        enum Manual;
        enum SynchronizedCardioversion;
    }

    enum def RhythmClassification {
        enum Unknown;
        enum NormalSinus;
        enum VentricularFibrillation;
        enum PulselessVentricularTachycardia;
        enum Asystole;
        enum NonShockable;
    }

    enum def DeviceReadiness {
        enum NotReady;
        enum SelfTestInProgress;
        enum Ready;
        enum Charging;
        enum Charged;
        enum DeliveringTherapy;
        enum Faulted;
    }

    enum def AlarmPriority {
        enum Informational;
        enum Advisory;
        enum High;
        enum Critical;
    }

    item def ElectricalEnergy {
        attribute amount : Energy_J;
    }

    item def DefibrillationPulse {
        attribute deliveredEnergy : Energy_J;
        attribute peakVoltage : Voltage_V;
        attribute peakCurrent : Current_A;
        attribute pulseDuration : Time_s;
        attribute biphasic : Boolean;
    }

    item def ECGSignal {
        attribute amplitude_mV : Real;
        attribute sampleRate_Hz : Real;
        attribute heartRate : HeartRate_bpm;
        attribute detectedRhythm : RhythmClassification;
    }

    item def PatientImpedanceMeasurement {
        attribute impedance : Resistance_Ohm;
        attribute measurementTime : Time_s;
        attribute valid : Boolean;
    }

    item def UserCommand {
        attribute requestedMode : ShockMode;
        attribute requestedEnergy : Energy_J;
        attribute shockButtonPressed : Boolean;
        attribute chargeButtonPressed : Boolean;
        attribute powerButtonPressed : Boolean;
        attribute syncRequested : Boolean;
    }

    item def AudioVisualMessage {
        attribute text : String;
        attribute priority : AlarmPriority;
        attribute audible : Boolean;
        attribute visual : Boolean;
    }

    item def TherapyRecord {
        attribute mode : ShockMode;
        attribute selectedEnergy : Energy_J;
        attribute deliveredEnergy : Energy_J;
        attribute patientImpedance : Resistance_Ohm;
        attribute rhythmBeforeShock : RhythmClassification;
        attribute rhythmAfterShock : RhythmClassification;
        attribute deliveryTime : Time_s;
        attribute successfulDelivery : Boolean;
    }

    item def BatteryEnergy {
        attribute stateOfCharge_percent : Real;
        attribute voltage : Voltage_V;
        attribute availableEnergy : Energy_J;
    }

    item def ACInputPower {
        attribute rmsVoltage : Voltage_V;
        attribute frequency_Hz : Real;
        attribute maximumPower : Power_W;
    }

    item def DiagnosticStatus {
        attribute readiness : DeviceReadiness;
        attribute batteryHealthy : Boolean;
        attribute capacitorHealthy : Boolean;
        attribute padsConnected : Boolean;
        attribute isolationHealthy : Boolean;
        attribute lastSelfTestAge : Time_s;
    }

    port def ElectrodeTherapyPort {
        out item pulse : DefibrillationPulse;
        in item ecg : ECGSignal;
        in item impedance : PatientImpedanceMeasurement;
    }

    port def PatientContactPort {
        in item pulse : DefibrillationPulse;
        out item ecg : ECGSignal;
        out item impedance : PatientImpedanceMeasurement;
    }

    port def ECGPort {
        in item ecg : ECGSignal;
    }

    port def ImpedancePort {
        in item impedance : PatientImpedanceMeasurement;
    }

    port def ControlCommandPort {
        in item command : UserCommand;
    }

    port def ControlStatusPort {
        out item status : DiagnosticStatus;
        out item message : AudioVisualMessage;
    }

    port def TherapyControlPort {
        out item command : UserCommand;
        in item status : DiagnosticStatus;
        in item record : TherapyRecord;
    }

    port def EnergyTransferPort {
        out item energy : ElectricalEnergy;
    }

    port def EnergyReceivePort {
        in item energy : ElectricalEnergy;
    }

    port def BatteryPort {
        out item batteryEnergy : BatteryEnergy;
    }

    port def ACInputPort {
        in item acPower : ACInputPower;
    }

    port def DataRecordPort {
        in item record : TherapyRecord;
        in item signal : ECGSignal;
        in item status : DiagnosticStatus;
    }

    port def UserInterfacePort {
        in item message : AudioVisualMessage;
        out item command : UserCommand;
    }

    connection def TherapyLeadConnection {
        end therapySource : ElectrodeTherapyPort;
        end patientContact : PatientContactPort;
    }

    connection def EnergyConnection {
        end supplier : EnergyTransferPort;
        end receiver : EnergyReceivePort;
    }

    connection def ControlConnection {
        end userSide : UserInterfacePort;
        end controllerSide : ControlCommandPort;
    }

    part def Patient {
        attribute transthoracicImpedance : Resistance_Ohm = 75.0;
        attribute intrinsicHeartRate : HeartRate_bpm = 0.0;
        attribute currentRhythm : RhythmClassification = RhythmClassification::VentricularFibrillation;

        port apexContact : PatientContactPort;
        port sternumContact : PatientContactPort;
    }

    part def ElectrodePad {
        attribute gelArea_cm2 : Real = 85.0;
        attribute maximumContactResistance : Resistance_Ohm = 5.0;
        attribute disposable : Boolean = true;
        attribute expirationInterval_days : Real = 730.0;

        port patientSide : PatientContactPort;
        port deviceSide : ElectrodeTherapyPort;
    }

    part def ElectrodeCableSet {
        part apexPad : ElectrodePad;
        part sternumPad : ElectrodePad;

        port apexDevicePort : ElectrodeTherapyPort;
        port sternumDevicePort : ElectrodeTherapyPort;
        port apexPatientPort : PatientContactPort;
        port sternumPatientPort : PatientContactPort;

        connect apexDevicePort to apexPad.deviceSide;
        connect apexPad.patientSide to apexPatientPort;
        connect sternumDevicePort to sternumPad.deviceSide;
        connect sternumPad.patientSide to sternumPatientPort;
    }

    part def BatteryPack {
        attribute nominalVoltage : Voltage_V = 14.8;
        attribute capacity : Energy_J = 266400.0;
        attribute stateOfCharge_percent : Real = 100.0;
        attribute maximumDischargePower : Power_W = 350.0;
        attribute minimumOperatingVoltage : Voltage_V = 11.0;
        attribute mass : Mass_kg = 0.65;

        port batteryOutput : BatteryPort;
    }

    part def ACPowerSupply {
        attribute inputVoltageMin : Voltage_V = 100.0;
        attribute inputVoltageMax : Voltage_V = 240.0;
        attribute outputVoltage : Voltage_V = 18.0;
        attribute maximumOutputPower : Power_W = 220.0;

        port acInput : ACInputPort;
        port dcEnergyOut : EnergyTransferPort;
    }

    part def HighVoltageCapacitorBank {
        attribute capacitance : Capacitance_F = 0.00018;
        attribute maximumVoltage : Voltage_V = 2200.0;
        attribute storedEnergy : Energy_J = 0.0;
        attribute maximumStoredEnergy : Energy_J = 435.0;
        attribute leakageResistance : Resistance_Ohm = 10000000.0;

        port chargeInput : EnergyReceivePort;
        port dischargeOutput : EnergyTransferPort;
    }

    part def Charger {
        attribute chargePower : Power_W = 180.0;
        attribute maximumChargeTimeTo200J : Time_s = 8.0;
        attribute outputVoltageLimit : Voltage_V = 2200.0;
        attribute isolationResistance : Resistance_Ohm = 50000000.0;

        port batteryEnergyInput : BatteryPort;
        port acEnergyInput : EnergyReceivePort;
        port capacitorEnergyOutput : EnergyTransferPort;
    }

    part def ShockDeliverySwitch {
        attribute maximumPeakCurrent : Current_A = 80.0;
        attribute maximumBlockingVoltage : Voltage_V = 2500.0;
        attribute switchingLatency : Time_s = 0.010;
        attribute supportsBiphasicWaveform : Boolean = true;

        port capacitorInput : EnergyReceivePort;
        port apexOutput : ElectrodeTherapyPort;
        port sternumOutput : ElectrodeTherapyPort;
        port controlInput : ControlCommandPort;
    }

    part def ECGAcquisitionModule {
        attribute inputImpedance : Resistance_Ohm = 10000000.0;
        attribute sampleRate_Hz : Real = 500.0;
        attribute bandwidthLow_Hz : Real = 0.5;
        attribute bandwidthHigh_Hz : Real = 40.0;
        attribute isolationVoltage : Voltage_V = 5000.0;

        port apexLead : ECGPort;
        port sternumLead : ECGPort;
        port ecgOut : ECGPort;
    }

    part def ImpedanceMeasurementModule {
        attribute probeCurrent : Current_A = 0.001;
        attribute impedanceMin : Resistance_Ohm = 15.0;
        attribute impedanceMax : Resistance_Ohm = 200.0;
        attribute measurementInterval : Time_s = 0.5;

        port apexMeasurement : ImpedancePort;
        port sternumMeasurement : ImpedancePort;
        port impedanceOut : ImpedancePort;
    }

    part def RhythmAnalyzer {
        attribute analysisWindow : Time_s = 6.0;
        attribute vfSensitivity_percent : Real = 95.0;
        attribute nonShockableSpecificity_percent : Real = 95.0;
        attribute artifactRejectionEnabled : Boolean = true;

        port ecgInput : ECGPort;
        port statusOutput : ControlStatusPort;
    }

    part def UserInterface {
        attribute displayDiagonal_cm : Real = 17.8;
        attribute speakerSoundPressure_dBA : Real = 85.0;
        attribute hasShockButton : Boolean = true;
        attribute hasChargeButton : Boolean = true;
        attribute hasEnergySelector : Boolean = true;

        port operatorPort : UserInterfacePort;
        port controllerPort : ControlCommandPort;
        port annunciationPort : ControlStatusPort;
    }

    part def EventRecorder {
        attribute storageCapacity_records : Integer = 1000;
        attribute ecgRetentionTime_s : Time_s = 7200.0;
        attribute clockAccuracy_sPerDay : Real = 2.0;

        port recordInput : DataRecordPort;
    }

    part def SafetyInterlock {
        attribute maximumAllowedLeakageCurrent : Current_A = 0.0001;
        attribute minimumPadImpedance : Resistance_Ohm = 15.0;
        attribute maximumPadImpedance : Resistance_Ohm = 200.0;
        attribute requiresOperatorConfirmation : Boolean = true;
        attribute dischargeInhibitOnFault : Boolean = true;

        port commandInput : ControlCommandPort;
        port statusOutput : ControlStatusPort;
    }

    part def DefibrillatorController {
        attribute selectedEnergy : Energy_J = 200.0;
        attribute selectedMode : ShockMode = ShockMode::AED;
        attribute readiness : DeviceReadiness = DeviceReadiness::NotReady;
        attribute shockAdvised : Boolean = false;
        attribute synchronizedDeliveryEnabled : Boolean = false;
        attribute maximumEnergySetting : Energy_J = 360.0;
        attribute minimumEnergySetting : Energy_J = 2.0;

        port userCommandInput : ControlCommandPort;
        port rhythmStatusInput : ControlStatusPort;
        port safetyStatusInput : ControlStatusPort;
        port chargerCommandOutput : TherapyControlPort;
        port switchCommandOutput : ControlCommandPort;
        port uiStatusOutput : ControlStatusPort;
        port recorderOutput : DataRecordPort;
    }

    action def AcquirePatientECG {
        in ecgSignal : ECGSignal;
        out filteredECG : ECGSignal;
    }

    action def MeasurePatientImpedance {
        in rawImpedance : PatientImpedanceMeasurement;
        out validatedImpedance : PatientImpedanceMeasurement;
    }

    action def AnalyzeRhythm {
        in filteredECG : ECGSignal;
        out classification : RhythmClassification;
        out shockAdvised : Boolean;
    }

    action def ChargeEnergyStorage {
        in requestedEnergy : Energy_J;
        in sourceAvailable : Boolean;
        out storedEnergy : Energy_J;
        out charged : Boolean;
    }

    action def AnnounceOperatorPrompt {
        in messageText : String;
        in priority : AlarmPriority;
        out promptIssued : Boolean;
    }

    action def DeliverTherapyPulse {
        in selectedEnergy : Energy_J;
        in impedance : Resistance_Ohm;
        in mode : ShockMode;
        out pulse : DefibrillationPulse;
        out deliverySucceeded : Boolean;
    }

    action def RecordTherapyEvent {
        in pulse : DefibrillationPulse;
        in rhythmBefore : RhythmClassification;
        in rhythmAfter : RhythmClassification;
        in impedance : Resistance_Ohm;
        out record : TherapyRecord;
    }

    action def PrimaryDefibrillationFunction {
        in patientECG : ECGSignal;
        in patientImpedance : PatientImpedanceMeasurement;
        in operatorCommand : UserCommand;
        out therapyRecord : TherapyRecord;

        action acquire : AcquirePatientECG;
        action measure : MeasurePatientImpedance;
        action analyze : AnalyzeRhythm;
        action charge : ChargeEnergyStorage;
        action prompt : AnnounceOperatorPrompt;
        action deliver : DeliverTherapyPulse;
        action record : RecordTherapyEvent;

        flow acquire.filteredECG to analyze.filteredECG;
        flow measure.validatedImpedance to deliver.impedance;
        flow analyze.classification to record.rhythmBefore;
        flow operatorCommand.requestedEnergy to charge.requestedEnergy;
        flow charge.storedEnergy to deliver.selectedEnergy;
        flow deliver.pulse to record.pulse;
        flow deliver.deliverySucceeded to record.successfulDelivery;
        flow record.record to therapyRecord;
    }

    state def DefibrillatorOperationalStateMachine {
        state Off;
        state StartingSelfTest;
        state ReadyForMonitoring;
        state MonitoringPatient;
        state AnalyzingRhythm;
        state ShockAdvised;
        state ChargingCapacitor;
        state Armed;
        state DeliveringShock;
        state PostShockAssessment;
        state Disarming;
        state Fault;

        transition initial then Off;

        transition PowerOn
            first Off
            accept UserCommand
            if command.powerButtonPressed
            then StartingSelfTest;

        transition SelfTestPassed
            first StartingSelfTest
            if status.readiness == DeviceReadiness::Ready
            then ReadyForMonitoring;

        transition SelfTestFailed
            first StartingSelfTest
            if status.readiness == DeviceReadiness::Faulted
            then Fault;

        transition PadsConnected
            first ReadyForMonitoring
            if status.padsConnected
            then MonitoringPatient;

        transition BeginAnalysis
            first MonitoringPatient
            then AnalyzingRhythm;

        transition ShockableRhythmDetected
            first AnalyzingRhythm
            if ecg.detectedRhythm == RhythmClassification::VentricularFibrillation or ecg.detectedRhythm == RhythmClassification::PulselessVentricularTachycardia
            then ShockAdvised;

        transition NonShockableRhythmDetected
            first AnalyzingRhythm
            if ecg.detectedRhythm == RhythmClassification::NormalSinus or ecg.detectedRhythm == RhythmClassification::Asystole or ecg.detectedRhythm == RhythmClassification::NonShockable
            then MonitoringPatient;

        transition ChargeRequested
            first ShockAdvised
            accept UserCommand
            if command.chargeButtonPressed
            then ChargingCapacitor;

        transition ChargeComplete
            first ChargingCapacitor
            if status.readiness == DeviceReadiness::Charged
            then Armed;

        transition ShockButtonPressed
            first Armed
            accept UserCommand
            if command.shockButtonPressed
            then DeliveringShock;

        transition ShockDelivered
            first DeliveringShock
            then PostShockAssessment;

        transition Reassess
            first PostShockAssessment
            then MonitoringPatient;

        transition ChargeTimeoutOrCancel
            first Armed
            after 30.0
            then Disarming;

        transition Disarmed
            first Disarming
            then MonitoringPatient;

        transition AnyCriticalFault
            first MonitoringPatient
            if status.readiness == DeviceReadiness::Faulted
            then Fault;
    }

    part def Defibrillator {
        attribute modelName : String = "High-Level Biphasic External Defibrillator";
        attribute primaryFunction : String = "Analyze patient cardiac activity and, when indicated and authorized, deliver a controlled electrical shock through external electrodes to terminate life-threatening ventricular arrhythmias.";
        attribute maximumDeliveredEnergy : Energy_J = 360.0;
        attribute defaultAdultEnergy : Energy_J = 200.0;
        attribute defaultPediatricEnergy : Energy_J = 50.0;
        attribute maximumChargeTime : Time_s = 10.0;
        attribute operatingTemperatureMin : Temperature_degC = 0.0;
        attribute operatingTemperatureMax : Temperature_degC = 50.0;
        attribute massWithBattery : Mass_kg = 6.2;

        part battery : BatteryPack;
        part acSupply : ACPowerSupply;
        part charger : Charger;
        part capacitorBank : HighVoltageCapacitorBank;
        part deliverySwitch : ShockDeliverySwitch;
        part electrodes : ElectrodeCableSet;
        part ecgAcquisition : ECGAcquisitionModule;
        part impedanceMeasurement : ImpedanceMeasurementModule;
        part analyzer : RhythmAnalyzer;
        part controller : DefibrillatorController;
        part userInterface : UserInterface;
        part recorder : EventRecorder;
        part safetyInterlock : SafetyInterlock;

        port operatorInterface : UserInterfacePort;
        port acPowerInput : ACInputPort;
        port apexPatientInterface : PatientContactPort;
        port sternumPatientInterface : PatientContactPort;

        connect acPowerInput to acSupply.acInput;
        connect acSupply.dcEnergyOut to charger.acEnergyInput;
        connect battery.batteryOutput to charger.batteryEnergyInput;
        connect charger.capacitorEnergyOutput to capacitorBank.chargeInput;
        connect capacitorBank.dischargeOutput to deliverySwitch.capacitorInput;

        connect deliverySwitch.apexOutput to electrodes.apexDevicePort;
        connect deliverySwitch.sternumOutput to electrodes.sternumDevicePort;
        connect electrodes.apexPatientPort to apexPatientInterface;
        connect electrodes.sternumPatientPort to sternumPatientInterface;

        connect electrodes.apexDevicePort to ecgAcquisition.apexLead;
        connect electrodes.sternumDevicePort to ecgAcquisition.sternumLead;
        connect electrodes.apexDevicePort to impedanceMeasurement.apexMeasurement;
        connect electrodes.sternumDevicePort to impedanceMeasurement.sternumMeasurement;

        connect ecgAcquisition.ecgOut to analyzer.ecgInput;
        connect analyzer.statusOutput to controller.rhythmStatusInput;
        connect safetyInterlock.statusOutput to controller.safetyStatusInput;

        connect operatorInterface to userInterface.operatorPort;
        connect userInterface.controllerPort to controller.userCommandInput;
        connect controller.uiStatusOutput to userInterface.annunciationPort;

        connect controller.switchCommandOutput to deliverySwitch.controlInput;
        connect controller.switchCommandOutput to safetyInterlock.commandInput;
        connect controller.recorderOutput to recorder.recordInput;
    }

    part def DefibrillatorUseContext {
        part defibrillator : Defibrillator;
        part patient : Patient;

        connect defibrillator.apexPatientInterface to patient.apexContact;
        connect defibrillator.sternumPatientInterface to patient.sternumContact;
    }

    requirement def PrimaryFunctionRequirement {
        subject defib : Defibrillator;

        doc
        /* The defibrillator shall provide the primary clinical function of monitoring cardiac electrical activity, determining whether a shockable ventricular rhythm is present, charging an energy storage element to a selected therapeutic energy level, and delivering a controlled biphasic electrical pulse through external electrodes to the patient when therapy is indicated and authorized. */

        require constraint {
            defib.maximumDeliveredEnergy >= 200.0
        }
    }

    requirement def SafeEnergyDeliveryRequirement {
        subject defib : Defibrillator;

        doc
        /* The defibrillator shall inhibit shock delivery unless patient impedance is within the allowed therapy range and the device is in the armed state. */

        require constraint {
            defib.safetyInterlock.minimumPadImpedance >= 15.0 and
            defib.safetyInterlock.maximumPadImpedance <= 200.0
        }
    }

    requirement def ChargeTimeRequirement {
        subject defib : Defibrillator;

        doc
        /* The defibrillator shall charge to a selected 200 J adult therapy energy level within 10 s using a healthy battery or valid AC input. */

        require constraint {
            defib.maximumChargeTime <= 10.0
        }
    }

    requirement def BiphasicPulseRequirement {
        subject defib : Defibrillator;

        doc
        /* The defibrillator shall deliver therapy as a controlled biphasic pulse to reduce transthoracic energy requirement while maintaining therapeutic effectiveness. */

        require constraint {
            defib.deliverySwitch.supportsBiphasicWaveform == true
        }
    }

    requirement def OperatorPromptRequirement {
        subject defib : Defibrillator;

        doc
        /* The defibrillator shall provide clear audible and visual prompts for pad placement, rhythm analysis, charging, stand-clear warning, shock authorization, and post-shock reassessment. */

        require constraint {
            defib.userInterface.hasShockButton == true and
            defib.userInterface.speakerSoundPressure_dBA >= 80.0
        }
    }

    requirement def EventRecordingRequirement {
        subject defib : Defibrillator;

        doc
        /* The defibrillator shall record therapy events including selected energy, delivered energy, patient impedance, rhythm classification, delivery time, and delivery success. */

        require constraint {
            defib.recorder.storageCapacity_records >= 1000
        }
    }

    requirement def ElectricalIsolationRequirement {
        subject defib : Defibrillator;

        doc
        /* The defibrillator shall maintain patient isolation between internal power circuitry and patient-applied electrode connections. */

        require constraint {
            defib.ecgAcquisition.isolationVoltage >= 5000.0 and
            defib.charger.isolationResistance >= 50000000.0
        }
    }

    requirement def AEDAnalysisPerformanceRequirement {
        subject defib : Defibrillator;

        doc
        /* In AED mode, the rhythm analyzer shall identify shockable ventricular fibrillation or pulseless ventricular tachycardia with high sensitivity while avoiding shock advice for non-shockable rhythms. */

        require constraint {
            defib.analyzer.vfSensitivity_percent >= 90.0 and
            defib.analyzer.nonShockableSpecificity_percent >= 90.0
        }
    }

    satisfy PrimaryFunctionRequirement by Defibrillator;
    satisfy SafeEnergyDeliveryRequirement by SafetyInterlock;
    satisfy ChargeTimeRequirement by Charger;
    satisfy BiphasicPulseRequirement by ShockDeliverySwitch;
    satisfy OperatorPromptRequirement by UserInterface;
    satisfy EventRecordingRequirement by EventRecorder;
    satisfy ElectricalIsolationRequirement by ECGAcquisitionModule;
    satisfy AEDAnalysisPerformanceRequirement by RhythmAnalyzer;
}
