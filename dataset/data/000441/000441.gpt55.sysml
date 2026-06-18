package DefibrillationSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    enum def TherapyMode {
        enum standby;
        enum monitorOnly;
        enum semiAutomaticDefibrillation;
        enum manualDefibrillation;
        enum maintenance;
    }

    enum def RhythmClassification {
        enum unknown;
        enum normalSinus;
        enum asystole;
        enum ventricularFibrillation;
        enum pulselessVentricularTachycardia;
        enum nonShockableTachycardia;
        enum artifact;
    }

    enum def ContactQuality {
        enum disconnected;
        enum poor;
        enum acceptable;
        enum good;
    }

    enum def ShockAuthorization {
        enum inhibited;
        enum advised;
        enum chargedAndReady;
        enum delivered;
        enum aborted;
    }

    enum def BatteryHealth {
        enum healthy;
        enum degraded;
        enum replaceRequired;
    }

    attribute def Voltage :> ISQ::electricPotential {
        :>> unit = SI::V;
    }

    attribute def Current :> ISQ::electricCurrent {
        :>> unit = SI::A;
    }

    attribute def Energy :> ISQ::energy {
        :>> unit = SI::J;
    }

    attribute def Power :> ISQ::power {
        :>> unit = SI::W;
    }

    attribute def Resistance :> ISQ::resistance {
        :>> unit = SI::ohm;
    }

    attribute def TimeDuration :> ISQ::time {
        :>> unit = SI::s;
    }

    attribute def Frequency :> ISQ::frequency {
        :>> unit = SI::Hz;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        :>> unit = SI::K;
    }

    attribute def Percentage :> ScalarValues::Real {
        attribute minimum : Real = 0.0;
        attribute maximum : Real = 100.0;
        attribute unitSymbol : String = "%";
    }

    item def ECGSignal {
        attribute amplitude : Voltage;
        attribute samplingRate : Frequency;
        attribute measuredHeartRate : Frequency;
        attribute artifactLevel : Percentage;
        attribute acquisitionDuration : TimeDuration;
    }

    item def PatientImpedanceMeasurement {
        attribute impedance : Resistance;
        attribute contactQuality : ContactQuality;
        attribute measuredAt : TimeDuration;
    }

    item def DCPower {
        attribute voltage : Voltage;
        attribute currentLimit : Current;
        attribute availablePower : Power;
    }

    item def BatteryEnergy {
        attribute storedEnergy : Energy;
        attribute stateOfCharge : Percentage;
        attribute health : BatteryHealth;
    }

    item def ShockPrescription {
        attribute selectedEnergy : Energy;
        attribute maximumVoltage : Voltage;
        attribute phaseOneDuration : TimeDuration;
        attribute phaseTwoDuration : TimeDuration;
        attribute authorization : ShockAuthorization;
        attribute mode : TherapyMode;
    }

    item def TherapeuticShock {
        attribute deliveredEnergy : Energy;
        attribute peakVoltage : Voltage;
        attribute peakCurrent : Current;
        attribute patientImpedance : Resistance;
        attribute phaseOneDuration : TimeDuration;
        attribute phaseTwoDuration : TimeDuration;
    }

    item def VoicePrompt {
        attribute promptText : String;
        attribute promptDuration : TimeDuration;
        attribute priority : Integer;
    }

    item def VisualPrompt {
        attribute messageText : String;
        attribute flashRate : Frequency;
        attribute priority : Integer;
    }

    item def OperatorCommand {
        attribute commandName : String;
        attribute requestedMode : TherapyMode;
    }

    port def DCPowerOutputPort {
        out item power : DCPower;
    }

    port def DCPowerInputPort {
        in item power : DCPower;
    }

    port def EnergyStorageChargePort {
        in item chargingPower : DCPower;
        out item storedEnergy : BatteryEnergy;
    }

    port def ECGInputPort {
        in item ecg : ECGSignal;
        in item impedance : PatientImpedanceMeasurement;
    }

    port def ShockOutputPort {
        in item prescription : ShockPrescription;
        out item shock : TherapeuticShock;
    }

    port def PatientElectrodePort {
        out item ecg : ECGSignal;
        out item impedance : PatientImpedanceMeasurement;
        in item shock : TherapeuticShock;
    }

    port def UserInputPort {
        in item operatorCommand : OperatorCommand;
    }

    port def UserOutputPort {
        out item voice : VoicePrompt;
        out item visual : VisualPrompt;
    }

    port def InternalDataPort {
        inout item ecg : ECGSignal;
        inout item impedance : PatientImpedanceMeasurement;
        inout item prescription : ShockPrescription;
    }

    interface def DCPowerTransfer {
        end source : DCPowerOutputPort;
        end sink : DCPowerInputPort;
        flow item suppliedPower : DCPower from source to sink;
    }

    interface def PatientSignalAcquisition {
        end electrode : PatientElectrodePort;
        end monitor : ECGInputPort;
        flow item acquiredECG : ECGSignal from electrode to monitor;
        flow item measuredImpedance : PatientImpedanceMeasurement from electrode to monitor;
    }

    interface def ShockDeliveryInterface {
        end therapyOutput : ShockOutputPort;
        end electrode : PatientElectrodePort;
        flow item deliveredShock : TherapeuticShock from therapyOutput to electrode;
    }

    interface def UserInteractionInterface {
        end panel : UserInputPort;
        end annunciator : UserOutputPort;
    }

    constraint def DeliveredEnergyWithinPrescription {
        in prescriptionEnergy : Energy;
        in deliveredEnergy : Energy;
        constraint energyTolerance {
            deliveredEnergy >= prescriptionEnergy * 0.85 and deliveredEnergy <= prescriptionEnergy * 1.15
        }
    }

    constraint def SafePatientImpedanceForShock {
        in patientImpedance : Resistance;
        constraint impedanceWindow {
            patientImpedance >= 25 [SI::ohm] and patientImpedance <= 180 [SI::ohm]
        }
    }

    constraint def CapacitorChargedForPrescription {
        in storedEnergy : Energy;
        in prescriptionEnergy : Energy;
        constraint sufficientStoredEnergy {
            storedEnergy >= prescriptionEnergy * 1.20
        }
    }

    constraint def ECGAnalysisDurationAdequate {
        in acquisitionDuration : TimeDuration;
        constraint minimumAnalysisWindow {
            acquisitionDuration >= 6 [SI::s]
        }
    }

    action def AcquireECG {
        in item rawECG : ECGSignal;
        in item rawImpedance : PatientImpedanceMeasurement;
        out item filteredECG : ECGSignal;
        out item contactMeasurement : PatientImpedanceMeasurement;

        first start;
        then filterLineNoise;
        then estimateArtifact;
        then validateElectrodeContact;
        then publishMeasurement;
        then done;

        action filterLineNoise;
        action estimateArtifact;
        action validateElectrodeContact;
        action publishMeasurement;
    }

    action def AnalyzeRhythm {
        in item filteredECG : ECGSignal;
        in item contactMeasurement : PatientImpedanceMeasurement;
        out classification : RhythmClassification;
        out item recommendation : ShockPrescription;

        first start;
        then verifyAnalysisWindow;
        then detectQRSComplexes;
        then evaluateRateAndMorphology;
        then classifyRhythm;
        then generatePrescription;
        then done;

        action verifyAnalysisWindow;
        action detectQRSComplexes;
        action evaluateRateAndMorphology;
        action classifyRhythm;
        action generatePrescription;
    }

    action def ChargeEnergyStorage {
        in item dcPower : DCPower;
        in item prescription : ShockPrescription;
        out item chargedEnergy : BatteryEnergy;

        first start;
        then closeChargeRelay;
        then boostVoltage;
        then monitorStoredEnergy;
        then openChargeRelay;
        then done;

        action closeChargeRelay;
        action boostVoltage;
        action monitorStoredEnergy;
        action openChargeRelay;
    }

    action def DeliverBiphasicShock {
        in item prescription : ShockPrescription;
        in item contactMeasurement : PatientImpedanceMeasurement;
        out item shock : TherapeuticShock;

        first start;
        then verifyAuthorization;
        then verifySafeImpedance;
        then announceStandClear;
        then dischargePhaseOne;
        then reversePolarity;
        then dischargePhaseTwo;
        then measureDeliveredEnergy;
        then done;

        action verifyAuthorization;
        action verifySafeImpedance;
        action announceStandClear;
        action dischargePhaseOne;
        action reversePolarity;
        action dischargePhaseTwo;
        action measureDeliveredEnergy;
    }

    action def DefibrillationPrimaryFunction {
        in item patientECG : ECGSignal;
        in item patientImpedance : PatientImpedanceMeasurement;
        in item operatorCommand : OperatorCommand;
        out item deliveredShock : TherapeuticShock;
        out classification : RhythmClassification;
        out authorization : ShockAuthorization;

        first start;
        then acquireECG : AcquireECG;
        then analyzeRhythm : AnalyzeRhythm;
        then decideShock;
        then chargeIfAdvised : ChargeEnergyStorage;
        then deliverIfAuthorized : DeliverBiphasicShock;
        then reassessPatient;
        then done;

        action decideShock;
        action reassessPatient;
    }

    state def DefibrillatorOperationalStateMachine {
        entry; then off;

        state off;
        state selfTest;
        state standby;
        state padsConnected;
        state analyzing;
        state shockAdvised;
        state charging;
        state chargedReady;
        state deliveringShock;
        state postShockAssessment;
        state shockInhibited;
        state fault;

        transition powerOn
            first off
            accept OperatorCommand
            if operatorCommand.commandName == "PowerOn"
            then selfTest;

        transition selfTestPassed
            first selfTest
            if true
            then standby;

        transition selfTestFailed
            first selfTest
            if false
            then fault;

        transition electrodeContactDetected
            first standby
            accept PatientImpedanceMeasurement
            if impedance.contactQuality == ContactQuality::acceptable or impedance.contactQuality == ContactQuality::good
            then padsConnected;

        transition beginAnalysis
            first padsConnected
            accept ECGSignal
            then analyzing;

        transition rhythmShockable
            first analyzing
            if classification == RhythmClassification::ventricularFibrillation or classification == RhythmClassification::pulselessVentricularTachycardia
            then shockAdvised;

        transition rhythmNotShockable
            first analyzing
            if classification == RhythmClassification::normalSinus or classification == RhythmClassification::asystole or classification == RhythmClassification::nonShockableTachycardia
            then shockInhibited;

        transition startCharge
            first shockAdvised
            then charging;

        transition chargeComplete
            first charging
            if authorization == ShockAuthorization::chargedAndReady
            then chargedReady;

        transition commandShock
            first chargedReady
            accept OperatorCommand
            if operatorCommand.commandName == "Shock"
            then deliveringShock;

        transition shockComplete
            first deliveringShock
            then postShockAssessment;

        transition reassess
            first postShockAssessment
            then analyzing;

        transition inhibitRecovery
            first shockInhibited
            then padsConnected;

        transition powerOffFromStandby
            first standby
            accept OperatorCommand
            if operatorCommand.commandName == "PowerOff"
            then off;

        transition faultDetected
            first standby
            then fault;
    }

    part def BatteryPack {
        attribute nominalVoltage : Voltage = 14.4 [SI::V];
        attribute maximumDischargeCurrent : Current = 12.0 [SI::A];
        attribute usableEnergy : Energy = 180000 [SI::J];
        attribute stateOfCharge : Percentage = 100.0;
        attribute health : BatteryHealth = BatteryHealth::healthy;

        port dcOutput : DCPowerOutputPort;
    }

    part def PowerManagementUnit {
        attribute regulatedBusVoltage : Voltage = 24.0 [SI::V];
        attribute maximumOutputPower : Power = 250.0 [SI::W];
        attribute lowBatteryThreshold : Percentage = 20.0;

        port batteryInput : DCPowerInputPort;
        port logicPowerOutput : DCPowerOutputPort;
        port therapyPowerOutput : DCPowerOutputPort;
    }

    part def ECGFrontEnd {
        attribute inputImpedance : Resistance = 10000000 [SI::ohm];
        attribute sampleRate : Frequency = 500 [SI::Hz];
        attribute bandwidthLow : Frequency = 0.5 [SI::Hz];
        attribute bandwidthHigh : Frequency = 40 [SI::Hz];

        port patientInput : ECGInputPort;
        port signalOutput : InternalDataPort;

        perform action acquire : AcquireECG;
    }

    part def RhythmAnalysisProcessor {
        attribute requiredAnalysisWindow : TimeDuration = 6 [SI::s];
        attribute shockableVFRateThreshold : Frequency = 2.5 [SI::Hz];
        attribute shockableVTRateThreshold : Frequency = 3.0 [SI::Hz];
        attribute artifactRejectThreshold : Percentage = 35.0;

        port signalInput : InternalDataPort;
        port decisionOutput : InternalDataPort;

        perform action analyze : AnalyzeRhythm;
    }

    part def HighVoltageCharger {
        attribute maximumCapacitorVoltage : Voltage = 2200 [SI::V];
        attribute chargeTimeTo200J : TimeDuration = 8 [SI::s];
        attribute chargerEfficiency : Percentage = 82.0;

        port powerInput : DCPowerInputPort;
        port prescriptionInput : InternalDataPort;
        port storagePort : EnergyStorageChargePort;

        perform action charge : ChargeEnergyStorage;
    }

    part def EnergyStorageCapacitorBank {
        attribute capacitanceMicrofarads : Real = 180.0;
        attribute ratedVoltage : Voltage = 2300 [SI::V];
        attribute maximumStoredEnergy : Energy = 475 [SI::J];
        attribute storedEnergy : Energy = 0 [SI::J];

        port chargeInput : EnergyStorageChargePort;
        port therapyOutput : DCPowerOutputPort;
    }

    part def BiphasicShockSwitch {
        attribute phaseOneNominalDuration : TimeDuration = 6 [SI::ms];
        attribute phaseTwoNominalDuration : TimeDuration = 4 [SI::ms];
        attribute maximumPeakCurrent : Current = 60 [SI::A];
        attribute isolationResistance : Resistance = 50000000 [SI::ohm];

        port energyInput : DCPowerInputPort;
        port commandInput : InternalDataPort;
        port shockOutput : ShockOutputPort;

        perform action deliver : DeliverBiphasicShock;
    }

    part def ElectrodePadSet {
        attribute adhesiveAreaSquareCentimeters : Real = 120.0;
        attribute nominalSkinContactImpedance : Resistance = 75 [SI::ohm];
        attribute cableResistance : Resistance = 0.5 [SI::ohm];
        attribute maximumSingleUseDuration : TimeDuration = 8 [SI::hour];

        port patientPort : PatientElectrodePort;
        port devicePort : PatientElectrodePort;
    }

    part def UserInterface {
        attribute speakerSoundPressureLevel : Real = 85.0;
        attribute displayBrightnessCandelaPerSquareMeter : Real = 550.0;
        attribute shockButtonGuarded : Boolean = true;

        port input : UserInputPort;
        port output : UserOutputPort;
    }

    part def SafetyController {
        attribute maximumAdultEnergy : Energy = 200 [SI::J];
        attribute pediatricEnergy : Energy = 50 [SI::J];
        attribute minimumSafeImpedance : Resistance = 25 [SI::ohm];
        attribute maximumSafeImpedance : Resistance = 180 [SI::ohm];
        attribute automaticDisarmTime : TimeDuration = 30 [SI::s];

        port dataInput : InternalDataPort;
        port commandOutput : InternalDataPort;
        port userOutput : UserOutputPort;
    }

    part def EventRecorder {
        attribute memoryCapacityMinutes : Real = 120.0;
        attribute storedEventCount : Integer = 0;

        port dataInput : InternalDataPort;
    }

    part def AutomatedExternalDefibrillator {
        attribute primaryFunction : String =
            "Detect a shockable cardiac rhythm and deliver a controlled biphasic electrical shock through patient electrodes to depolarize the myocardium and support restoration of organized cardiac activity.";
        attribute supportedMode : TherapyMode = TherapyMode::semiAutomaticDefibrillation;
        attribute adultDefaultEnergy : Energy = 150 [SI::J];
        attribute adultMaximumEnergy : Energy = 200 [SI::J];
        attribute pediatricDefaultEnergy : Energy = 50 [SI::J];
        attribute operatingTemperatureMinimum : Temperature = 273.15 [SI::K];
        attribute operatingTemperatureMaximum : Temperature = 323.15 [SI::K];

        port patientConnection : PatientElectrodePort;
        port operatorInput : UserInputPort;
        port operatorOutput : UserOutputPort;

        part battery : BatteryPack;
        part powerManagement : PowerManagementUnit;
        part ecgFrontEnd : ECGFrontEnd;
        part rhythmProcessor : RhythmAnalysisProcessor;
        part charger : HighVoltageCharger;
        part capacitorBank : EnergyStorageCapacitorBank;
        part shockSwitch : BiphasicShockSwitch;
        part electrodes : ElectrodePadSet;
        part userInterface : UserInterface;
        part safetyController : SafetyController;
        part recorder : EventRecorder;

        connection batteryToPowerManagement : DCPowerTransfer
            connect battery.dcOutput to powerManagement.batteryInput;

        connection logicPowerToECG : DCPowerTransfer
            connect powerManagement.logicPowerOutput to ecgFrontEnd.patientInput;

        connection therapyPowerToCharger : DCPowerTransfer
            connect powerManagement.therapyPowerOutput to charger.powerInput;

        connection patientToPads
            connect patientConnection to electrodes.patientPort;

        connection padsToECG : PatientSignalAcquisition
            connect electrodes.devicePort to ecgFrontEnd.patientInput;

        connection ecgToRhythmProcessor
            connect ecgFrontEnd.signalOutput to rhythmProcessor.signalInput;

        connection rhythmToSafety
            connect rhythmProcessor.decisionOutput to safetyController.dataInput;

        connection safetyToCharger
            connect safetyController.commandOutput to charger.prescriptionInput;

        connection chargerToCapacitor
            connect charger.storagePort to capacitorBank.chargeInput;

        connection capacitorToShockSwitch : DCPowerTransfer
            connect capacitorBank.therapyOutput to shockSwitch.energyInput;

        connection safetyToShockSwitch
            connect safetyController.commandOutput to shockSwitch.commandInput;

        connection shockSwitchToPads : ShockDeliveryInterface
            connect shockSwitch.shockOutput to electrodes.devicePort;

        connection userInputToPanel
            connect operatorInput to userInterface.input;

        connection annunciationToOperator
            connect userInterface.output to operatorOutput;

        connection safetyPromptsToUser
            connect safetyController.userOutput to userInterface.output;

        connection recorderFromProcessor
            connect rhythmProcessor.decisionOutput to recorder.dataInput;

        perform action primaryFunctionBehavior : DefibrillationPrimaryFunction;

        exhibit state operationalStates : DefibrillatorOperationalStateMachine;
    }

    requirement def PrimaryDefibrillationFunctionRequirement {
        subject defibrillator : AutomatedExternalDefibrillator;

        doc
            "The system shall provide defibrillation as its primary high-level function by acquiring patient ECG through electrodes, determining whether the rhythm is shockable, charging an energy-storage subsystem, and delivering a controlled biphasic therapeutic shock when authorized.";

        require constraint {
            defibrillator.supportedMode == TherapyMode::semiAutomaticDefibrillation
        }
    }

    requirement def ShockableRhythmDetectionRequirement {
        subject processor : RhythmAnalysisProcessor;

        doc
            "The rhythm analysis processor shall classify ventricular fibrillation and pulseless ventricular tachycardia as shockable rhythms using at least a six-second ECG analysis window when electrode contact is acceptable or good.";

        require constraint {
            processor.requiredAnalysisWindow >= 6 [SI::s]
        }
    }

    requirement def EnergyDeliveryAccuracyRequirement {
        subject shockSwitch : BiphasicShockSwitch;

        doc
            "For an authorized adult prescription, the delivered shock energy shall be within plus or minus fifteen percent of the selected energy when patient impedance is within the safe operating range.";

        require constraint deliveredEnergyAccuracy : DeliveredEnergyWithinPrescription {
            in prescriptionEnergy = 150 [SI::J];
            in deliveredEnergy = 150 [SI::J];
        }
    }

    requirement def PatientImpedanceSafetyRequirement {
        subject controller : SafetyController;

        doc
            "The system shall inhibit shock delivery unless measured patient impedance is between 25 ohms and 180 ohms inclusive.";

        require constraint safeImpedance : SafePatientImpedanceForShock {
            in patientImpedance = 75 [SI::ohm];
        }
    }

    requirement def ChargeTimeRequirement {
        subject charger : HighVoltageCharger;

        doc
            "The high-voltage charger shall charge the energy-storage capacitor bank to support a 200 joule shock in no more than eight seconds from a healthy battery.";

        require constraint {
            charger.chargeTimeTo200J <= 8 [SI::s]
        }
    }

    requirement def UserPromptRequirement {
        subject userInterface : UserInterface;

        doc
            "The user interface shall provide clear audible and visual prompts for pad placement, analysis in progress, stand clear, shock advised, shock button activation, and post-shock reassessment.";

        require constraint {
            userInterface.shockButtonGuarded == true
        }
    }

    requirement def AutomaticDisarmRequirement {
        subject controller : SafetyController;

        doc
            "After the capacitor bank is charged, the system shall automatically disarm therapy energy if shock delivery is not completed within thirty seconds or if electrode contact becomes unsafe.";

        require constraint {
            controller.automaticDisarmTime <= 30 [SI::s]
        }
    }

    requirement def ElectricalIsolationRequirement {
        subject switch : BiphasicShockSwitch;

        doc
            "The therapy output path shall maintain high isolation resistance from low-voltage electronics to protect the operator and non-therapy circuits during high-voltage charging and discharge.";

        require constraint {
            switch.isolationResistance >= 50000000 [SI::ohm]
        }
    }

    part def DefibrillationUseContext {
        part defibrillator : AutomatedExternalDefibrillator;

        item patientECG : ECGSignal {
            attribute amplitude = 1.2 [SI::mV];
            attribute samplingRate = 500 [SI::Hz];
            attribute measuredHeartRate = 5.0 [SI::Hz];
            attribute artifactLevel = 10.0;
            attribute acquisitionDuration = 8 [SI::s];
        }

        item patientContact : PatientImpedanceMeasurement {
            attribute impedance = 75 [SI::ohm];
            attribute contactQuality = ContactQuality::good;
            attribute measuredAt = 0 [SI::s];
        }

        item adultShockPrescription : ShockPrescription {
            attribute selectedEnergy = 150 [SI::J];
            attribute maximumVoltage = 1800 [SI::V];
            attribute phaseOneDuration = 6 [SI::ms];
            attribute phaseTwoDuration = 4 [SI::ms];
            attribute authorization = ShockAuthorization::advised;
            attribute mode = TherapyMode::semiAutomaticDefibrillation;
        }

        satisfy PrimaryDefibrillationFunctionRequirement by defibrillator;
        satisfy ShockableRhythmDetectionRequirement by defibrillator.rhythmProcessor;
        satisfy EnergyDeliveryAccuracyRequirement by defibrillator.shockSwitch;
        satisfy PatientImpedanceSafetyRequirement by defibrillator.safetyController;
        satisfy ChargeTimeRequirement by defibrillator.charger;
        satisfy UserPromptRequirement by defibrillator.userInterface;
        satisfy AutomaticDisarmRequirement by defibrillator.safetyController;
        satisfy ElectricalIsolationRequirement by defibrillator.shockSwitch;
    }
}
