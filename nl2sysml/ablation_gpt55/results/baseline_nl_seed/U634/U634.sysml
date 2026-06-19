package ChemicalFieldEffectTransistorSystem {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Voltage :> ISQ::electricPotential {
        unit = SI::V;
    }

    attribute def ElectricCurrent :> ISQ::electricCurrent {
        unit = SI::A;
    }

    attribute def ElectricPowerValue :> ISQ::power {
        unit = SI::W;
    }

    attribute def TimeDuration :> ISQ::time {
        unit = SI::s;
    }

    attribute def SampleTemperature :> ISQ::thermodynamicTemperature {
        unit = SI::K;
    }

    attribute def MolarConcentration :> ISQ::amountOfSubstanceConcentration {
        unit = SI::mol / SI::m^3;
    }

    attribute def VolumeFlowRate :> ScalarValues::Real {
        unit = SI::m^3 / SI::s;
    }

    attribute def PH :> ScalarValues::Real {
        unit = SI::one;
    }

    attribute def GateSensitivity :> ScalarValues::Real {
        unit = SI::V;
    }

    attribute def NoiseDensity :> ScalarValues::Real {
        unit = SI::V;
    }

    enum def AnalyteKind {
        enum hydrogenIon;
        enum sodiumIon;
        enum potassiumIon;
        enum glucoseProxy;
        enum ammonia;
    }

    enum def ReportStatus {
        enum valid;
        enum warming;
        enum calibrating;
        enum outOfRange;
        enum faulted;
    }

    enum def DiagnosticSeverity {
        enum normal;
        enum warning;
        enum critical;
    }

    enum def CommandKind {
        enum powerOn;
        enum powerOff;
        enum startMeasurement;
        enum startCalibration;
        enum flush;
        enum resetFault;
    }

    item def LiquidSample {
        attribute analyte : AnalyteKind = AnalyteKind::hydrogenIon;
        attribute hydrogenIonActivity : MolarConcentration;
        attribute ph : PH;
        attribute temperature : SampleTemperature;
        attribute flowRate : VolumeFlowRate;
    }

    item def ReferenceBuffer {
        attribute certifiedPH : PH;
        attribute temperature : SampleTemperature;
        attribute concentration : MolarConcentration;
    }

    item def ChemicalPotentialSignal {
        attribute gatePotentialShift : Voltage;
        attribute samplePH : PH;
        attribute temperature : SampleTemperature;
    }

    item def ElectricalBias {
        attribute sourceVoltage : Voltage;
        attribute drainVoltage : Voltage;
        attribute gateReferenceVoltage : Voltage;
        attribute drainCurrentSetpoint : ElectricCurrent;
    }

    item def DrainCurrentSignal {
        attribute drainCurrent : ElectricCurrent;
        attribute drainSourceVoltage : Voltage;
        attribute gatePotentialEstimate : Voltage;
        attribute noise : NoiseDensity;
    }

    item def DigitalFrame {
        attribute samplePH : PH;
        attribute compensatedVoltage : Voltage;
        attribute drainCurrent : ElectricCurrent;
        attribute sampleTemperature : SampleTemperature;
        attribute acquisitionTime : TimeDuration;
        attribute status : ReportStatus;
    }

    item def MeasurementReport {
        attribute analyte : AnalyteKind;
        attribute measuredPH : PH;
        attribute estimatedConcentration : MolarConcentration;
        attribute sampleTemperature : SampleTemperature;
        attribute responseTime : TimeDuration;
        attribute status : ReportStatus;
    }

    item def ElectricPower {
        attribute supplyVoltage : Voltage;
        attribute availablePower : ElectricPowerValue;
    }

    item def ControlCommand {
        attribute command : CommandKind;
        attribute requestedBiasVoltage : Voltage;
        attribute requestedMeasurementPeriod : TimeDuration;
    }

    item def DiagnosticMessage {
        attribute severity : DiagnosticSeverity;
        attribute supplyVoltage : Voltage;
        attribute leakageCurrent : ElectricCurrent;
        attribute temperature : SampleTemperature;
    }

    item def CalibrationSet {
        attribute lowReferencePH : PH;
        attribute highReferencePH : PH;
        attribute offsetVoltage : Voltage;
        attribute sensitivity : GateSensitivity;
        attribute validDuration : TimeDuration;
    }

    port def LiquidPort {
        inout item liquid : LiquidSample;
    }

    port def BufferPort {
        inout item buffer : ReferenceBuffer;
    }

    port def ChemicalPotentialPort {
        inout item chemicalSignal : ChemicalPotentialSignal;
    }

    port def BiasPort {
        inout item bias : ElectricalBias;
    }

    port def AnalogSignalPort {
        inout item signal : DrainCurrentSignal;
    }

    port def DigitalDataPort {
        inout item frame : DigitalFrame;
    }

    port def ReportPort {
        inout item report : MeasurementReport;
    }

    port def PowerPort {
        inout item power : ElectricPower;
    }

    port def CommandPort {
        inout item command : ControlCommand;
    }

    port def DiagnosticPort {
        inout item diagnostic : DiagnosticMessage;
    }

    action def ConditionLiquidSample {
        in item rawSample : LiquidSample;
        out item conditionedSample : LiquidSample;
    }

    action def EstablishTransistorBias {
        in item command : ControlCommand;
        out item bias : ElectricalBias;
    }

    action def TransduceGatePotential {
        in item conditionedSample : LiquidSample;
        in item bias : ElectricalBias;
        out item chemicalSignal : ChemicalPotentialSignal;
        out item drainSignal : DrainCurrentSignal;
    }

    action def DigitizeDrainSignal {
        in item drainSignal : DrainCurrentSignal;
        in item chemicalSignal : ChemicalPotentialSignal;
        out item frame : DigitalFrame;
    }

    action def EstimateChemicalActivity {
        in item frame : DigitalFrame;
        in item calibration : CalibrationSet;
        out item report : MeasurementReport;
    }

    action def PublishMeasurementReport {
        in item report : MeasurementReport;
        out item publishedReport : MeasurementReport;
    }

    action def CalibrateChemFET {
        in item lowBuffer : ReferenceBuffer;
        in item highBuffer : ReferenceBuffer;
        out item calibration : CalibrationSet;
    }

    action def SenseChemicalActivity {
        in item sample : LiquidSample;
        in item command : ControlCommand;
        in item calibration : CalibrationSet;
        out item report : MeasurementReport;

        action conditionSample : ConditionLiquidSample;
        action establishBias : EstablishTransistorBias;
        action transduce : TransduceGatePotential;
        action digitize : DigitizeDrainSignal;
        action estimate : EstimateChemicalActivity;
        action publish : PublishMeasurementReport;
    }

    state def ChemFETOperatingStates {
        state off;
        state initializing;
        state conditioning;
        state ready;
        state measuring;
        state calibrating;
        state flushing;
        state fault;

        transition initial then off;
        transition powerOn first off accept ControlCommand then initializing;
        transition initialized first initializing then conditioning;
        transition conditioned first conditioning then ready;
        transition startMeasurement first ready accept ControlCommand then measuring;
        transition measurementComplete first measuring then ready;
        transition startCalibration first ready accept ControlCommand then calibrating;
        transition calibrationComplete first calibrating then ready;
        transition flushRequested first ready accept ControlCommand then flushing;
        transition flushComplete first flushing then conditioning;
        transition detectFault first measuring then fault;
        transition resetFault first fault accept ControlCommand then initializing;
        transition powerOffFromReady first ready accept ControlCommand then off;
        transition powerOffFromFault first fault accept ControlCommand then off;
    }

    part def MicrofluidicFrontEnd {
        port sampleIn : LiquidPort;
        port bufferIn : BufferPort;
        port gateOutlet : LiquidPort;
        port wasteOut : LiquidPort;

        attribute nominalFlowRate : VolumeFlowRate = 1.0e-9 [SI::m^3 / SI::s];
        attribute primingTime : TimeDuration = 2.0 [SI::s];
    }

    part def IonSensitiveGateMembrane {
        port fluidContact : LiquidPort;
        port chemicalPotentialOut : ChemicalPotentialPort;

        attribute nominalSensitivity : GateSensitivity = 0.059 [SI::V];
        attribute referenceOffset : Voltage = 0.0 [SI::V];
        attribute responseTime : TimeDuration = 1.0 [SI::s];
        attribute membraneHydrated : Boolean = true;
    }

    part def SemiconductorChannel {
        port gatePotentialIn : ChemicalPotentialPort;
        port source : BiasPort;
        port drain : BiasPort;
        port drainCurrentOut : AnalogSignalPort;

        attribute thresholdVoltage : Voltage = 0.700 [SI::V];
        attribute nominalDrainCurrent : ElectricCurrent = 10.0e-6 [SI::A];
        attribute maximumLeakageCurrent : ElectricCurrent = 100.0e-9 [SI::A];
    }

    part def ChemicalFETTransducer {
        port fluidGate : LiquidPort;
        port source : BiasPort;
        port drain : BiasPort;
        port analogOut : AnalogSignalPort;

        part gateMembrane : IonSensitiveGateMembrane;
        part channel : SemiconductorChannel;

        connect fluidGate to gateMembrane.fluidContact;
        connect gateMembrane.chemicalPotentialOut to channel.gatePotentialIn;
        connect source to channel.source;
        connect drain to channel.drain;
        connect channel.drainCurrentOut to analogOut;
    }

    part def BiasController {
        port powerIn : PowerPort;
        port commandIn : CommandPort;
        port sourceBias : BiasPort;
        port drainBias : BiasPort;
        port diagnosticOut : DiagnosticPort;

        attribute sourceVoltageNominal : Voltage = 0.0 [SI::V];
        attribute drainVoltageNominal : Voltage = 1.0 [SI::V];
        attribute gateReferenceVoltageNominal : Voltage = 0.0 [SI::V];
        attribute biasSettlingTime : TimeDuration = 0.050 [SI::s];
    }

    part def LowNoiseReadout {
        port analogIn : AnalogSignalPort;
        port digitalOut : DigitalDataPort;
        port powerIn : PowerPort;
        port diagnosticOut : DiagnosticPort;

        attribute inputReferredNoise : NoiseDensity = 5.0e-6 [SI::V];
        attribute conversionTime : TimeDuration = 0.100 [SI::s];
        attribute currentResolution : ElectricCurrent = 1.0e-9 [SI::A];
    }

    part def TemperatureCompensator {
        port frameIn : DigitalDataPort;
        port frameOut : DigitalDataPort;

        attribute referenceTemperature : SampleTemperature = 298.15 [SI::K];
        attribute compensationSettlingTime : TimeDuration = 0.020 [SI::s];
    }

    part def CalibrationManager {
        port lowBufferIn : BufferPort;
        port highBufferIn : BufferPort;
        port commandIn : CommandPort;
        port calibrationOut : DigitalDataPort;

        attribute defaultLowPH : PH = 4.0;
        attribute defaultHighPH : PH = 10.0;
        attribute calibrationDuration : TimeDuration = 15.0 [SI::s];

        perform action calibrationBehavior : CalibrateChemFET;
    }

    part def MeasurementController {
        port commandIn : CommandPort;
        port commandOut : CommandPort;
        port measurementIn : DigitalDataPort;
        port reportOut : ReportPort;
        port diagnosticIn : DiagnosticPort;
        port diagnosticOut : DiagnosticPort;

        attribute measurementPeriod : TimeDuration = 1.0 [SI::s];
        attribute maximumAllowedResponseTime : TimeDuration = 5.0 [SI::s];
        attribute lowerPHLimit : PH = 0.0;
        attribute upperPHLimit : PH = 14.0;

        perform action primaryMeasurementBehavior : SenseChemicalActivity;
        exhibit state operatingState : ChemFETOperatingStates;
    }

    part def PowerRegulator {
        port externalPowerIn : PowerPort;
        port regulatedPowerOut : PowerPort;
        port diagnosticOut : DiagnosticPort;

        attribute inputVoltageNominal : Voltage = 5.0 [SI::V];
        attribute regulatedVoltage : Voltage = 3.3 [SI::V];
        attribute maximumPower : ElectricPowerValue = 1.0 [SI::W];
        attribute startupTime : TimeDuration = 0.500 [SI::s];
    }

    part def ChemicalFETSensorSystem {
        port sampleIn : LiquidPort;
        port lowCalibrationBufferIn : BufferPort;
        port highCalibrationBufferIn : BufferPort;
        port commandIn : CommandPort;
        port powerIn : PowerPort;
        port reportOut : ReportPort;
        port diagnosticOut : DiagnosticPort;
        port wasteOut : LiquidPort;

        attribute measurementRangeLower : PH = 0.0;
        attribute measurementRangeUpper : PH = 14.0;
        attribute maximumResponseTime : TimeDuration = 5.0 [SI::s];
        attribute nominalGateSensitivity : GateSensitivity = 0.059 [SI::V];
        attribute primaryFunctionEnabled : Boolean = true;

        part microfluidics : MicrofluidicFrontEnd;
        part chemFET : ChemicalFETTransducer;
        part biasController : BiasController;
        part readout : LowNoiseReadout;
        part temperatureCompensator : TemperatureCompensator;
        part calibrationManager : CalibrationManager;
        part controller : MeasurementController;
        part powerRegulator : PowerRegulator;

        connect sampleIn to microfluidics.sampleIn;
        connect lowCalibrationBufferIn to microfluidics.bufferIn;
        connect microfluidics.gateOutlet to chemFET.fluidGate;
        connect microfluidics.wasteOut to wasteOut;

        connect commandIn to controller.commandIn;
        connect controller.commandOut to biasController.commandIn;
        connect controller.commandOut to calibrationManager.commandIn;

        connect powerIn to powerRegulator.externalPowerIn;
        connect powerRegulator.regulatedPowerOut to biasController.powerIn;
        connect powerRegulator.regulatedPowerOut to readout.powerIn;

        connect biasController.sourceBias to chemFET.source;
        connect biasController.drainBias to chemFET.drain;
        connect chemFET.analogOut to readout.analogIn;
        connect readout.digitalOut to temperatureCompensator.frameIn;
        connect temperatureCompensator.frameOut to controller.measurementIn;
        connect controller.reportOut to reportOut;

        connect lowCalibrationBufferIn to calibrationManager.lowBufferIn;
        connect highCalibrationBufferIn to calibrationManager.highBufferIn;

        connect biasController.diagnosticOut to controller.diagnosticIn;
        connect readout.diagnosticOut to controller.diagnosticIn;
        connect powerRegulator.diagnosticOut to controller.diagnosticIn;
        connect controller.diagnosticOut to diagnosticOut;

        perform action highLevelPrimaryFunction : SenseChemicalActivity;
        exhibit state systemOperatingState : ChemFETOperatingStates;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The Chemical field-effect transistor system shall accept a liquid sample, expose an ion-sensitive gate to the sample, modulate a semiconductor channel by the chemical potential at the gate, convert drain-current change to digital data, and report analyte activity or concentration. */

        subject system : ChemicalFETSensorSystem;

        require constraint {
            system.primaryFunctionEnabled == true
        }

        require constraint {
            system.measurementRangeLower <= 0.0 and system.measurementRangeUpper >= 14.0
        }

        require constraint {
            system.maximumResponseTime <= 5.0 [SI::s]
        }
    }

    requirement def TransducerSensitivityRequirement {
        subject transducer : ChemicalFETTransducer;

        require constraint {
            transducer.gateMembrane.nominalSensitivity >= 0.050 [SI::V]
        }

        require constraint {
            transducer.gateMembrane.responseTime <= 1.5 [SI::s]
        }
    }

    requirement def ReadoutNoiseRequirement {
        subject readout : LowNoiseReadout;

        require constraint {
            readout.inputReferredNoise <= 10.0e-6 [SI::V]
        }

        require constraint {
            readout.conversionTime <= 0.200 [SI::s]
        }
    }

    requirement def PowerRequirement {
        subject regulator : PowerRegulator;

        require constraint {
            regulator.regulatedVoltage == 3.3 [SI::V]
        }

        require constraint {
            regulator.maximumPower >= 0.500 [SI::W]
        }
    }

    part chemFETSensorSystem : ChemicalFETSensorSystem;

    requirement primaryFunction : PrimaryFunctionRequirement {
        subject system = chemFETSensorSystem;
    }

    requirement transducerPerformance : TransducerSensitivityRequirement {
        subject transducer = chemFETSensorSystem.chemFET;
    }

    requirement readoutPerformance : ReadoutNoiseRequirement {
        subject readout = chemFETSensorSystem.readout;
    }

    requirement powerPerformance : PowerRequirement {
        subject regulator = chemFETSensorSystem.powerRegulator;
    }
}
