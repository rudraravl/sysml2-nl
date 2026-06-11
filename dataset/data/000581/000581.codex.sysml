package DefibrillatorSystemModel {
    import ScalarValues::*;
    import SI::*;

    value def Voltage {
        doc /* Electric potential difference used for sensing, charging, and therapy delivery. */
        unit : Unit = V;
        quantityKind : QuantityKind = electricPotential;
    }

    value def Current {
        unit : Unit = A;
        quantityKind : QuantityKind = electricCurrent;
    }

    value def Energy {
        unit : Unit = J;
        quantityKind : QuantityKind = energy;
    }

    value def Power {
        unit : Unit = W;
        quantityKind : QuantityKind = power;
    }

    value def Time {
        unit : Unit = s;
        quantityKind : QuantityKind = time;
    }

    value def Resistance {
        unit : Unit = Ohm;
        quantityKind : QuantityKind = resistance;
    }

    value def HeartRate {
        unit : Unit = 1/min;
    }

    value def Temperature {
        unit : Unit = degC;
        quantityKind : QuantityKind = thermodynamicTemperature;
    }

    enum def RhythmClassification {
        enum sinus;
        enum ventricularTachycardia;
        enum ventricularFibrillation;
        enum asystole;
        enum unknown;
    }

    enum def TherapyDecision {
        enum shockAdvised;
        enum shockNotAdvised;
        enum analysisInconclusive;
    }

    enum def BatteryState {
        enum full;
        enum nominal;
        enum low;
        enum depleted;
    }

    item def ECGSignal {
        attribute leadI_mV : Real;
        attribute leadII_mV : Real;
        attribute sampleRate_Hz : Real;
        attribute detectedHeartRate : HeartRate;
        attribute rhythm : RhythmClassification;
        attribute signalQualityPercent : Real;
    }

    item def PatientContactStatus {
        attribute padsAttached : Boolean;
        attribute measuredImpedance : Resistance;
        attribute contactQualityPercent : Real;
    }

    item def DefibrillationPulse {
        attribute deliveredEnergy : Energy;
        attribute peakVoltage : Voltage;
        attribute peakCurrent : Current;
        attribute pulseDuration : Time;
        attribute biphasic : Boolean;
    }

    item def ElectricalEnergyPacket {
        attribute storedEnergy : Energy;
        attribute chargeVoltage : Voltage;
    }

    item def UserCommand {
        attribute powerOn : Boolean;
        attribute analyze : Boolean;
        attribute charge : Boolean;
        attribute shock : Boolean;
        attribute cancel : Boolean;
    }

    item def UserMessage {
        attribute messageText : String;
        attribute audible : Boolean;
        attribute visual : Boolean;
        attribute priority : Integer;
    }

    port def PatientSensingPort {
        in item contact : PatientContactStatus;
        in item ecg : ECGSignal;
    }

    port def TherapyOutputPort {
        out item pulse : DefibrillationPulse;
    }

    port def OperatorInputPort {
        in item command : UserCommand;
    }

    port def OperatorOutputPort {
        out item message : UserMessage;
    }

    port def PowerPort {
        in item energyIn : ElectricalEnergyPacket;
        out item energyOut : ElectricalEnergyPacket;
    }

    part def Patient {
        attribute bodyImpedance : Resistance = 75 [Ohm];
        attribute intrinsicHeartRate : HeartRate = 0 [1/min];
        attribute currentRhythm : RhythmClassification = ventricularFibrillation;

        port sensingInterface : PatientSensingPort;
        port therapyInterface : ~TherapyOutputPort;
    }

    part def ElectrodePads {
        attribute padArea_cm2 : Real = 80.0;
        attribute maxSkinImpedance : Resistance = 150 [Ohm];
        attribute attached : Boolean = false;

        port patientSide : ~PatientSensingPort;
        port defibrillatorSide : PatientSensingPort;
        port therapyIn : ~TherapyOutputPort;
        port therapyOut : TherapyOutputPort;
    }

    part def BatteryPack {
        attribute nominalVoltage : Voltage = 14.4 [V];
        attribute remainingEnergy : Energy = 72000 [J];
        attribute state : BatteryState = nominal;
        attribute minimumOperatingEnergy : Energy = 5000 [J];

        port powerOut : PowerPort;
    }

    part def ECGAcquisitionModule {
        attribute samplingRate_Hz : Real = 500.0;
        attribute inputNoiseLimit_mV : Real = 0.05;
        attribute minSignalQualityPercent : Real = 70.0;

        port patientInput : PatientSensingPort;
        port signalOut : PatientSensingPort;
    }

    part def RhythmAnalysisProcessor {
        attribute analysisWindow : Time = 8 [s];
        attribute shockableHeartRateThreshold : HeartRate = 150 [1/min];
        attribute minConfidencePercent : Real = 90.0;
        attribute lastDecision : TherapyDecision = analysisInconclusive;

        port ecgIn : PatientSensingPort;
        port operatorOut : OperatorOutputPort;
    }

    part def CapacitorBank {
        attribute maximumStoredEnergy : Energy = 220 [J];
        attribute selectedEnergy : Energy = 150 [J];
        attribute storedEnergy : Energy = 0 [J];
        attribute maximumChargeVoltage : Voltage = 2000 [V];
        attribute charged : Boolean = false;

        port powerIn : ~PowerPort;
        port therapyEnergyOut : PowerPort;
    }

    part def ChargeController {
        attribute chargeTimeLimit : Time = 10 [s];
        attribute targetEnergy : Energy = 150 [J];
        attribute chargingEnabled : Boolean = false;

        port batteryIn : ~PowerPort;
        port capacitorOut : PowerPort;
        port operatorOut : OperatorOutputPort;
    }

    part def ShockDeliveryCircuit {
        attribute maxDeliveredEnergy : Energy = 200 [J];
        attribute maxPeakCurrent : Current = 50 [A];
        attribute pulseDuration : Time = 0.012 [s];
        attribute biphasicWaveform : Boolean = true;
        attribute dischargeArmed : Boolean = false;

        port energyIn : ~PowerPort;
        port patientOut : TherapyOutputPort;
        port operatorOut : OperatorOutputPort;
    }

    part def UserInterface {
        attribute displayBrightnessPercent : Real = 80.0;
        attribute speakerVolumePercent : Real = 90.0;
        attribute shockButtonGuarded : Boolean = true;

        port operatorIn : OperatorInputPort;
        port operatorOut : OperatorOutputPort;
    }

    part def SafetyInterlock {
        attribute maxAllowedPatientImpedance : Resistance = 200 [Ohm];
        attribute minAllowedPatientImpedance : Resistance = 25 [Ohm];
        attribute shockEnabled : Boolean = false;
        attribute faultDetected : Boolean = false;

        port patientStatusIn : PatientSensingPort;
        port commandIn : OperatorInputPort;
        port operatorOut : OperatorOutputPort;
    }

    action def AcquireECG {
        in item contact : PatientContactStatus;
        out item ecg : ECGSignal;

        constraint sufficientContact {
            contact.padsAttached == true and
            contact.contactQualityPercent >= 70.0
        }
    }

    action def AnalyzeRhythm {
        in item ecg : ECGSignal;
        out decision : TherapyDecision;

        constraint shockableRhythmRule {
            decision == TherapyDecision::shockAdvised implies
            (ecg.rhythm == RhythmClassification::ventricularFibrillation or
             ecg.rhythm == RhythmClassification::ventricularTachycardia)
        }
    }

    action def ChargeCapacitor {
        in targetEnergy : Energy;
        in item batteryEnergy : ElectricalEnergyPacket;
        out item storedEnergy : ElectricalEnergyPacket;

        constraint chargeLimit {
            storedEnergy.storedEnergy <= 220 [J]
        }
    }

    action def DeliverShock {
        in item storedEnergy : ElectricalEnergyPacket;
        in impedance : Resistance;
        out item pulse : DefibrillationPulse;

        constraint deliveredEnergyRange {
            pulse.deliveredEnergy >= 120 [J] and
            pulse.deliveredEnergy <= 200 [J]
        }

        constraint currentSafetyLimit {
            pulse.peakCurrent <= 50 [A]
        }
    }

    action def AnnouncePrompt {
        in text : String;
        out item message : UserMessage;
    }

    state def DefibrillatorOperatingState {
        entry action AnnouncePrompt {
            in text = "Power on self test";
        }

        state Off;
        state SelfTest;
        state Ready;
        state PadsCheck;
        state Analyze;
        state ShockAdvised;
        state Charging;
        state Charged;
        state ShockDelivered;
        state NoShockAdvised;
        state Fault;
        state Shutdown;

        transition initial then Off;

        transition Off_to_SelfTest
            first Off
            accept UserCommand
            if command.powerOn == true
            then SelfTest;

        transition SelfTest_to_Ready
            first SelfTest
            if true
            then Ready;

        transition Ready_to_PadsCheck
            first Ready
            accept UserCommand
            if command.analyze == true
            then PadsCheck;

        transition PadsCheck_to_Analyze
            first PadsCheck
            if true
            then Analyze;

        transition PadsCheck_to_Fault
            first PadsCheck
            if false
            then Fault;

        transition Analyze_to_ShockAdvised
            first Analyze
            if true
            then ShockAdvised;

        transition Analyze_to_NoShockAdvised
            first Analyze
            if false
            then NoShockAdvised;

        transition ShockAdvised_to_Charging
            first ShockAdvised
            accept UserCommand
            if command.charge == true
            then Charging;

        transition Charging_to_Charged
            first Charging
            if true
            then Charged;

        transition Charged_to_ShockDelivered
            first Charged
            accept UserCommand
            if command.shock == true
            then ShockDelivered;

        transition ShockDelivered_to_Ready
            first ShockDelivered
            then Ready;

        transition NoShockAdvised_to_Ready
            first NoShockAdvised
            then Ready;

        transition Any_to_Shutdown
            first Ready
            accept UserCommand
            if command.powerOn == false
            then Shutdown;
    }

    part def Defibrillator {
        doc /* A defibrillator monitors the patient's cardiac electrical activity, determines whether a shockable rhythm is present, charges an internal energy store, and delivers a controlled electrical pulse through electrode pads to help restore effective cardiac rhythm. */

        attribute maximumTherapyEnergy : Energy = 200 [J];
        attribute defaultAdultTherapyEnergy : Energy = 150 [J];
        attribute maximumChargeTime : Time = 10 [s];
        attribute operatingTemperatureMin : Temperature = 0 [degC];
        attribute operatingTemperatureMax : Temperature = 50 [degC];

        port patientSense : PatientSensingPort;
        port therapyOut : TherapyOutputPort;
        port operatorInput : OperatorInputPort;
        port operatorOutput : OperatorOutputPort;

        part battery : BatteryPack;
        part ecgAcquisition : ECGAcquisitionModule;
        part analyzer : RhythmAnalysisProcessor;
        part charger : ChargeController;
        part capacitors : CapacitorBank;
        part deliveryCircuit : ShockDeliveryCircuit;
        part interface : UserInterface;
        part interlock : SafetyInterlock;

        perform stateMachine : DefibrillatorOperatingState;

        connect patientSense to ecgAcquisition.patientInput;
        connect ecgAcquisition.signalOut to analyzer.ecgIn;
        connect patientSense to interlock.patientStatusIn;
        connect operatorInput to interface.operatorIn;
        connect operatorInput to interlock.commandIn;
        connect battery.powerOut to charger.batteryIn;
        connect charger.capacitorOut to capacitors.powerIn;
        connect capacitors.therapyEnergyOut to deliveryCircuit.energyIn;
        connect deliveryCircuit.patientOut to therapyOut;
        connect analyzer.operatorOut to operatorOutput;
        connect charger.operatorOut to operatorOutput;
        connect deliveryCircuit.operatorOut to operatorOutput;
        connect interlock.operatorOut to operatorOutput;
        connect interface.operatorOut to operatorOutput;
    }

    part def DefibrillatorUseContext {
        part patient : Patient;
        part pads : ElectrodePads;
        part device : Defibrillator;

        connect patient.sensingInterface to pads.patientSide;
        connect pads.defibrillatorSide to device.patientSense;
        connect device.therapyOut to pads.therapyIn;
        connect pads.therapyOut to patient.therapyInterface;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall provide high-level defibrillation support by sensing cardiac electrical activity, identifying shockable rhythms, and delivering controlled electrical therapy when indicated. */

        subject device : Defibrillator;

        require constraint primaryFunction {
            device.maximumTherapyEnergy >= 150 [J] and
            device.maximumTherapyEnergy <= 220 [J]
        }
    }

    requirement def RhythmAnalysisRequirement {
        subject analyzer : RhythmAnalysisProcessor;

        require constraint analysisWindowBound {
            analyzer.analysisWindow <= 10 [s]
        }

        require constraint confidenceBound {
            analyzer.minConfidencePercent >= 90.0
        }
    }

    requirement def EnergyDeliveryRequirement {
        subject delivery : ShockDeliveryCircuit;

        require constraint therapyEnergyLimit {
            delivery.maxDeliveredEnergy <= 200 [J]
        }

        require constraint peakCurrentLimit {
            delivery.maxPeakCurrent <= 50 [A]
        }
    }

    requirement def ChargeTimeRequirement {
        subject charger : ChargeController;

        require constraint chargeTime {
            charger.chargeTimeLimit <= 10 [s]
        }
    }

    requirement def PatientContactRequirement {
        subject interlock : SafetyInterlock;

        require constraint impedanceWindow {
            interlock.minAllowedPatientImpedance >= 25 [Ohm] and
            interlock.maxAllowedPatientImpedance <= 200 [Ohm]
        }
    }

    requirement def OperatorPromptRequirement {
        subject ui : UserInterface;

        require constraint promptOutputsAvailable {
            ui.displayBrightnessPercent > 0.0 and
            ui.speakerVolumePercent > 0.0
        }
    }

    satisfy PrimaryFunctionRequirement by Defibrillator;
    satisfy RhythmAnalysisRequirement by RhythmAnalysisProcessor;
    satisfy EnergyDeliveryRequirement by ShockDeliveryCircuit;
    satisfy ChargeTimeRequirement by ChargeController;
    satisfy PatientContactRequirement by SafetyInterlock;
    satisfy OperatorPromptRequirement by UserInterface;
}