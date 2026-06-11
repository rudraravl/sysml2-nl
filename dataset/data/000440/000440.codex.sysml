package DeepBrainStimulationHighLevelModel {
    import ScalarValues::*;
    import SI::*;

    doc /* Primary function: deliver clinician-programmed, precisely timed electrical stimulation pulses from an implanted pulse generator through implanted leads to selected deep brain targets, while monitoring device status, therapy limits, battery state, and patient-safe operating conditions. */

    enum def TherapyMode {
        enum Off;
        enum Standby;
        enum ContinuousStimulation;
        enum AdaptiveStimulation;
        enum ClinicianProgramming;
        enum FaultSafe;
    }

    enum def BrainTarget {
        enum SubthalamicNucleus;
        enum GlobusPallidusInterna;
        enum VentralIntermediateNucleus;
        enum NucleusAccumbens;
    }

    enum def LeadContactPolarity {
        enum Anode;
        enum Cathode;
        enum Floating;
    }

    enum def FaultKind {
        enum None;
        enum LeadImpedanceTooLow;
        enum LeadImpedanceTooHigh;
        enum BatteryDepleted;
        enum OverTemperature;
        enum PulseParameterOutOfRange;
        enum TelemetryAuthenticationFailed;
    }

    attribute def Voltage_mV :> Real {
        doc /* Electrical potential in millivolts. */
    }

    attribute def Current_mA :> Real {
        doc /* Stimulation current in milliamperes. */
    }

    attribute def Frequency_Hz :> Real {
        doc /* Pulse repetition rate in hertz. */
    }

    attribute def PulseWidth_us :> Real {
        doc /* Pulse active duration in microseconds. */
    }

    attribute def Impedance_Ohm :> Real {
        doc /* Electrode-tissue impedance in ohms. */
    }

    attribute def Energy_mWh :> Real {
        doc /* Battery stored energy in milliwatt-hours. */
    }

    attribute def Temperature_C :> Real {
        doc /* Device temperature in degrees Celsius. */
    }

    attribute def Time_s :> Real {
        doc /* Time in seconds. */
    }

    attribute def Percent :> Real {
        doc /* Percentage from 0 to 100. */
    }

    item def ElectricalPower {
        attribute voltage : Voltage_mV;
        attribute current : Current_mA;
    }

    item def StimulationPrescription {
        attribute target : BrainTarget;
        attribute amplitude : Current_mA;
        attribute frequency : Frequency_Hz;
        attribute pulseWidth : PulseWidth_us;
        attribute rampDuration : Time_s;
        attribute maxAllowedAmplitude : Current_mA;
        attribute minAllowedImpedance : Impedance_Ohm;
        attribute maxAllowedImpedance : Impedance_Ohm;
    }

    item def StimulationPulse {
        attribute amplitude : Current_mA;
        attribute pulseWidth : PulseWidth_us;
        attribute interPulseInterval : Time_s;
        attribute activeContact : Integer;
        attribute returnContact : Integer;
    }

    item def NeuralSignalSample {
        attribute localFieldPotential : Voltage_mV;
        attribute dominantFrequency : Frequency_Hz;
        attribute tremorBandPower : Real;
        attribute timestamp : Time_s;
    }

    item def DeviceStatus {
        attribute therapyMode : TherapyMode;
        attribute batteryRemaining : Percent;
        attribute batteryEnergy : Energy_mWh;
        attribute caseTemperature : Temperature_C;
        attribute measuredLeadImpedance : Impedance_Ohm;
        attribute activeFault : FaultKind;
    }

    item def ProgrammingCommand {
        attribute requestedMode : TherapyMode;
        attribute requestedPrescription : StimulationPrescription;
        attribute authenticated : Boolean;
    }

    port def PowerOutputPort {
        out item power : ElectricalPower;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def StimulationOutputPort {
        out item pulse : StimulationPulse;
    }

    port def StimulationInputPort {
        in item pulse : StimulationPulse;
    }

    port def NeuralSensingPort {
        in item sample : NeuralSignalSample;
    }

    port def TelemetryPort {
        in item command : ProgrammingCommand;
        out item status : DeviceStatus;
    }

    port def StatusPort {
        out item status : DeviceStatus;
    }

    part def RechargeableBattery {
        attribute nominalVoltage : Voltage_mV = 3700.0;
        attribute availableEnergy : Energy_mWh = 620.0;
        attribute chargeRemaining : Percent = 100.0;

        port powerOut : PowerOutputPort;

        action provideImplantPower {
            out item suppliedPower : ElectricalPower;
        }
    }

    part def PowerManagementUnit {
        attribute regulatedVoltage : Voltage_mV = 3300.0;
        attribute minimumOperatingEnergy : Energy_mWh = 25.0;

        port batteryPowerIn : PowerInputPort;
        port regulatedPowerOut : PowerOutputPort;
        port statusOut : StatusPort;

        action regulatePower {
            in item rawPower : ElectricalPower;
            out item regulatedPower : ElectricalPower;
        }

        action evaluateBattery {
            out item status : DeviceStatus;
        }
    }

    part def PulseGeneratorElectronics {
        attribute maximumAmplitude : Current_mA = 12.5;
        attribute minimumAmplitude : Current_mA = 0.1;
        attribute maximumFrequency : Frequency_Hz = 250.0;
        attribute minimumFrequency : Frequency_Hz = 2.0;
        attribute maximumPulseWidth : PulseWidth_us = 450.0;
        attribute minimumPulseWidth : PulseWidth_us = 20.0;

        port powerIn : PowerInputPort;
        port prescriptionIn : TelemetryPort;
        port stimOut : StimulationOutputPort;
        port statusOut : StatusPort;

        action synthesizePulseTrain {
            in item prescription : StimulationPrescription;
            out item pulse : StimulationPulse;
        }

        action rampAmplitude {
            in item prescription : StimulationPrescription;
            out item pulse : StimulationPulse;
        }
    }

    part def LeadExtension {
        attribute conductorCount : Integer = 8;
        attribute insulationIntegrity : Percent = 100.0;

        port proximalStimIn : StimulationInputPort;
        port distalStimOut : StimulationOutputPort;
    }

    part def ElectrodeContact {
        attribute contactIndex : Integer;
        attribute polarity : LeadContactPolarity;
        attribute surfaceArea_mm2 : Real;
        attribute measuredImpedance : Impedance_Ohm;

        port stimulationIn : StimulationInputPort;
    }

    part def ImplantedLead {
        attribute implantedTarget : BrainTarget;
        attribute insertionDepth_mm : Real;
        attribute contactSpacing_mm : Real = 1.5;

        port stimulationIn : StimulationInputPort;
        port sensingOut : NeuralSensingPort;

        part contact0 : ElectrodeContact {
            attribute contactIndex = 0;
            attribute polarity = LeadContactPolarity::Cathode;
            attribute surfaceArea_mm2 = 6.0;
            attribute measuredImpedance = 950.0;
        }

        part contact1 : ElectrodeContact {
            attribute contactIndex = 1;
            attribute polarity = LeadContactPolarity::Floating;
            attribute surfaceArea_mm2 = 6.0;
            attribute measuredImpedance = 1020.0;
        }

        part contact2 : ElectrodeContact {
            attribute contactIndex = 2;
            attribute polarity = LeadContactPolarity::Anode;
            attribute surfaceArea_mm2 = 6.0;
            attribute measuredImpedance = 980.0;
        }

        part contact3 : ElectrodeContact {
            attribute contactIndex = 3;
            attribute polarity = LeadContactPolarity::Floating;
            attribute surfaceArea_mm2 = 6.0;
            attribute measuredImpedance = 1015.0;
        }
    }

    part def NeuralTargetTissue {
        attribute target : BrainTarget;
        attribute baselineOscillation : Frequency_Hz;
        attribute stimulationThreshold : Current_mA;
        attribute safeChargeDensityLimit_uC_per_cm2 : Real = 30.0;

        port stimulationIn : StimulationInputPort;
        port neuralSignalOut : NeuralSensingPort;

        action modulateNeuralActivity {
            in item pulse : StimulationPulse;
            out item sample : NeuralSignalSample;
        }
    }

    part def SensingModule {
        attribute samplingRate : Frequency_Hz = 1000.0;
        attribute inputNoise : Voltage_mV = 0.003;
        attribute enabled : Boolean = true;

        port neuralIn : NeuralSensingPort;
        port statusOut : StatusPort;

        action acquireLocalFieldPotential {
            in item rawSample : NeuralSignalSample;
            out item filteredSample : NeuralSignalSample;
        }

        action estimateSymptomBandPower {
            in item filteredSample : NeuralSignalSample;
            out item featureSample : NeuralSignalSample;
        }
    }

    part def TherapyController {
        attribute currentMode : TherapyMode = TherapyMode::Standby;
        attribute activePrescription : StimulationPrescription;
        attribute latestFault : FaultKind = FaultKind::None;
        attribute adaptiveThreshold : Real = 0.65;

        port telemetry : TelemetryPort;
        port sensingIn : NeuralSensingPort;
        port pulseGeneratorCommand : TelemetryPort;
        port statusOut : StatusPort;

        action validatePrescription {
            in item command : ProgrammingCommand;
            out item acceptedPrescription : StimulationPrescription;
        }

        action computeAdaptiveAmplitude {
            in item sample : NeuralSignalSample;
            in item prescription : StimulationPrescription;
            out item adjustedPrescription : StimulationPrescription;
        }

        action enterSafeMode {
            out item status : DeviceStatus;
        }
    }

    part def ClinicianProgrammer {
        attribute sessionAuthenticated : Boolean = false;
        attribute wirelessRange_m : Real = 2.0;

        port telemetry : TelemetryPort;

        action authenticateSession {
            out item command : ProgrammingCommand;
        }

        action transmitPrescription {
            out item command : ProgrammingCommand;
        }

        action requestDeviceStatus {
            in item status : DeviceStatus;
        }
    }

    part def PatientController {
        attribute patientCanPauseTherapy : Boolean = true;
        attribute patientAmplitudeAdjustmentRange : Current_mA = 0.5;

        port telemetry : TelemetryPort;

        action requestStandby {
            out item command : ProgrammingCommand;
        }

        action requestResume {
            out item command : ProgrammingCommand;
        }
    }

    part def ImplantablePulseGenerator {
        attribute enclosureTemperature : Temperature_C = 37.0;
        attribute hermeticSealIntegrity : Percent = 100.0;

        port clinicianTelemetry : TelemetryPort;
        port patientTelemetry : TelemetryPort;
        port stimulationOut : StimulationOutputPort;
        port sensingIn : NeuralSensingPort;
        port statusOut : StatusPort;

        part battery : RechargeableBattery;
        part powerManagement : PowerManagementUnit;
        part pulseElectronics : PulseGeneratorElectronics;
        part sensing : SensingModule;
        part controller : TherapyController;

        connection batteryPower {
            connect battery.powerOut to powerManagement.batteryPowerIn;
        }

        connection regulatedPower {
            connect powerManagement.regulatedPowerOut to pulseElectronics.powerIn;
        }

        connection controllerToPulseGenerator {
            connect controller.pulseGeneratorCommand to pulseElectronics.prescriptionIn;
        }

        connection sensedSignalToController {
            connect sensing.statusOut to controller.statusOut;
        }

        connection telemetryClinician {
            connect clinicianTelemetry to controller.telemetry;
        }

        connection telemetryPatient {
            connect patientTelemetry to controller.telemetry;
        }

        connection generatorOutput {
            connect pulseElectronics.stimOut to stimulationOut;
        }

        connection sensorInput {
            connect sensingIn to sensing.neuralIn;
        }
    }

    part def DeepBrainStimulationSystem {
        attribute intendedPrimaryFunction : String = "Electrical modulation of selected deep brain neural circuits using programmable implanted pulse stimulation.";
        attribute defaultMode : TherapyMode = TherapyMode::ContinuousStimulation;

        part programmer : ClinicianProgrammer;
        part patientController : PatientController;
        part ipg : ImplantablePulseGenerator;
        part extension : LeadExtension;
        part lead : ImplantedLead {
            attribute implantedTarget = BrainTarget::SubthalamicNucleus;
            attribute insertionDepth_mm = 78.0;
        }
        part targetTissue : NeuralTargetTissue {
            attribute target = BrainTarget::SubthalamicNucleus;
            attribute baselineOscillation = 18.0;
            attribute stimulationThreshold = 1.2;
        }

        connection clinicianTelemetryLink {
            connect programmer.telemetry to ipg.clinicianTelemetry;
        }

        connection patientTelemetryLink {
            connect patientController.telemetry to ipg.patientTelemetry;
        }

        connection implantToExtension {
            connect ipg.stimulationOut to extension.proximalStimIn;
        }

        connection extensionToLead {
            connect extension.distalStimOut to lead.stimulationIn;
        }

        connection leadToTissue {
            connect lead.stimulationIn to targetTissue.stimulationIn;
        }

        connection neuralFeedback {
            connect targetTissue.neuralSignalOut to ipg.sensingIn;
        }
    }

    action def DeliverDeepBrainStimulation {
        in item prescription : StimulationPrescription;
        in item neuralFeedback : NeuralSignalSample;
        out item deliveredPulse : StimulationPulse;
        out item deviceStatus : DeviceStatus;

        first start;
        then validateTherapyParameters;
        then selectTherapyMode;
        then generatePulse;
        then deliverPulseToLead;
        then sampleNeuralResponse;
        then publishStatus;
        then done;

        action validateTherapyParameters;
        action selectTherapyMode;
        action generatePulse;
        action deliverPulseToLead;
        action sampleNeuralResponse;
        action publishStatus;
    }

    state def TherapyOperatingStateMachine {
        attribute mode : TherapyMode;
        attribute fault : FaultKind;

        state off;
        state standby;
        state programming;
        state stimulating;
        state adaptiveStimulating;
        state faultSafe;

        entry action initialize {
            mode = TherapyMode::Standby;
            fault = FaultKind::None;
        }

        transition initialTransition first off;
        transition powerOn from off to standby;
        transition beginProgramming from standby to programming;
        transition acceptProgram from programming to stimulating;
        transition enableAdaptiveMode from stimulating to adaptiveStimulating;
        transition disableAdaptiveMode from adaptiveStimulating to stimulating;
        transition pauseTherapy from stimulating to standby;
        transition pauseAdaptiveTherapy from adaptiveStimulating to standby;
        transition faultDetectedFromStandby from standby to faultSafe;
        transition faultDetectedFromProgramming from programming to faultSafe;
        transition faultDetectedFromStimulating from stimulating to faultSafe;
        transition faultDetectedFromAdaptive from adaptiveStimulating to faultSafe;
        transition faultCleared from faultSafe to standby;

        state stimulating {
            entry action startContinuousPulseDelivery;
            do action DeliverDeepBrainStimulation;
            exit action stopPulseDelivery;
        }

        state adaptiveStimulating {
            entry action startClosedLoopSensing;
            do action DeliverDeepBrainStimulation;
            exit action freezeLastSafePrescription;
        }

        state faultSafe {
            entry action disableStimulationOutput;
            do action reportFaultStatus;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : DeepBrainStimulationSystem;

        doc /* The system shall provide programmable electrical stimulation to a selected deep brain target to modulate neural activity at a high level. */

        require constraint {
            system.ipg.controller.currentMode == TherapyMode::ContinuousStimulation or
            system.ipg.controller.currentMode == TherapyMode::AdaptiveStimulation
        }
    }

    requirement def ParameterSafetyRequirement {
        subject prescription : StimulationPrescription;

        doc /* The commanded stimulation parameters shall remain within configured safe operating limits before pulse delivery. */

        require constraint {
            prescription.amplitude >= 0.1 and
            prescription.amplitude <= prescription.maxAllowedAmplitude and
            prescription.frequency >= 2.0 and
            prescription.frequency <= 250.0 and
            prescription.pulseWidth >= 20.0 and
            prescription.pulseWidth <= 450.0
        }
    }

    requirement def LeadImpedanceRequirement {
        subject status : DeviceStatus;
        subject prescription : StimulationPrescription;

        doc /* Therapy shall be inhibited when measured lead impedance is outside the prescription-defined acceptable range. */

        require constraint {
            status.measuredLeadImpedance >= prescription.minAllowedImpedance and
            status.measuredLeadImpedance <= prescription.maxAllowedImpedance
        }
    }

    requirement def FaultSafeRequirement {
        subject controller : TherapyController;

        doc /* The controller shall transition to fault-safe mode and disable stimulation output when a critical device fault is detected. */

        require constraint {
            controller.latestFault == FaultKind::None or
            controller.currentMode == TherapyMode::FaultSafe
        }
    }

    requirement def TelemetryAuthenticationRequirement {
        subject command : ProgrammingCommand;

        doc /* Programming commands that alter therapy shall be accepted only after authenticated telemetry communication. */

        require constraint {
            command.authenticated == true
        }
    }

    requirement def BatterySupportRequirement {
        subject status : DeviceStatus;

        doc /* The implant shall report battery status and shall not initiate stimulation when battery energy is below the minimum operating reserve. */

        require constraint {
            status.batteryRemaining >= 5.0
        }
    }

    part dbsSystem : DeepBrainStimulationSystem;

    item nominalSubthalamicPrescription : StimulationPrescription {
        attribute target = BrainTarget::SubthalamicNucleus;
        attribute amplitude = 2.8;
        attribute frequency = 130.0;
        attribute pulseWidth = 60.0;
        attribute rampDuration = 5.0;
        attribute maxAllowedAmplitude = 5.0;
        attribute minAllowedImpedance = 250.0;
        attribute maxAllowedImpedance = 3000.0;
    }

    satisfy PrimaryFunctionRequirement by dbsSystem;
}