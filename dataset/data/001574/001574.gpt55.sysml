package SiliceneBasedSystemModel {

    import ScalarValues::*;

    attribute def ElectricPotential :> Real {
        doc /* Electrical potential in volts. */
        attribute unit : String = "V";
    }

    attribute def ElectricCurrent :> Real {
        doc /* Electrical current in amperes. */
        attribute unit : String = "A";
    }

    attribute def ElectricalResistance :> Real {
        doc /* Electrical resistance in ohms. */
        attribute unit : String = "ohm";
    }

    attribute def ElectricalConductance :> Real {
        doc /* Electrical conductance in siemens. */
        attribute unit : String = "S";
    }

    attribute def Temperature :> Real {
        doc /* Temperature in kelvin. */
        attribute unit : String = "K";
    }

    attribute def Length :> Real {
        doc /* Length in meters. */
        attribute unit : String = "m";
    }

    attribute def Area :> Real {
        doc /* Area in square meters. */
        attribute unit : String = "m^2";
    }

    attribute def TimeDuration :> Real {
        doc /* Time duration in seconds. */
        attribute unit : String = "s";
    }

    attribute def Concentration :> Real {
        doc /* Molecular concentration in moles per cubic meter. */
        attribute unit : String = "mol/m^3";
    }

    attribute def Frequency :> Real {
        doc /* Sampling frequency in hertz. */
        attribute unit : String = "Hz";
    }

    attribute def Power :> Real {
        doc /* Electrical power in watts. */
        attribute unit : String = "W";
    }

    attribute def Fraction :> Real {
        doc /* Dimensionless fraction. */
        attribute unit : String = "1";
    }

    enum def OperatingMode {
        enum idle;
        enum calibrating;
        enum sensing;
        enum processing;
        enum reporting;
        enum fault;
    }

    enum def SurfaceCondition {
        enum clean;
        enum functionalized;
        enum contaminated;
        enum regenerated;
    }

    enum def AnalyteClass {
        enum gasMolecule;
        enum biomolecule;
        enum ion;
        enum volatileOrganicCompound;
    }

    item def ElectricalEnergy {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
        attribute power : Power;
    }

    item def GateBias {
        attribute gateVoltage : ElectricPotential;
        attribute leakageCurrent : ElectricCurrent;
    }

    item def DrainSourceSignal {
        attribute drainSourceVoltage : ElectricPotential;
        attribute drainCurrent : ElectricCurrent;
        attribute channelConductance : ElectricalConductance;
    }

    item def AnalyteSample {
        attribute class : AnalyteClass;
        attribute concentration : Concentration;
        attribute sampleTemperature : Temperature;
    }

    item def SurfaceAdsorptionEvent {
        attribute fractionalCoverage : Fraction;
        attribute adsorptionTime : TimeDuration;
        attribute inducedChargeDensity : Real;
    }

    item def CalibratedMeasurement {
        attribute estimatedConcentration : Concentration;
        attribute confidence : Fraction;
        attribute measurementLatency : TimeDuration;
    }

    item def DigitalTelemetry {
        attribute payloadSizeBytes : Integer;
        attribute sampleRate : Frequency;
    }

    item def ThermalCondition {
        attribute sensorTemperature : Temperature;
        attribute temperatureStability : Temperature;
    }

    item def ControlCommand {
        attribute requestedMode : OperatingMode;
        attribute commandId : Integer;
    }

    port def PowerInputPort {
        in item electricalPower : ElectricalEnergy;
    }

    port def BiasPort {
        out item appliedBias : GateBias;
    }

    port def ChannelMeasurementPort {
        in item rawSignal : DrainSourceSignal;
    }

    port def SampleInletPort {
        in item sample : AnalyteSample;
    }

    port def AdsorptionPort {
        out item adsorption : SurfaceAdsorptionEvent;
    }

    port def ThermalPort {
        inout item thermalCondition : ThermalCondition;
    }

    port def DataOutPort {
        out item telemetry : DigitalTelemetry;
        out item measurement : CalibratedMeasurement;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def InternalSignalPort {
        inout item signal : DrainSourceSignal;
    }

    action def ApplyBias {
        in item biasCommand : GateBias;
        out item biasedChannel : DrainSourceSignal;
        attribute targetGateVoltage : ElectricPotential;
        attribute maximumLeakage : ElectricCurrent;
    }

    action def ExposeSiliceneSurface {
        in item sample : AnalyteSample;
        out item adsorption : SurfaceAdsorptionEvent;
        attribute exposureDuration : TimeDuration;
    }

    action def MeasureConductanceShift {
        in item baseline : DrainSourceSignal;
        in item sensed : DrainSourceSignal;
        out item conductanceShift : ElectricalConductance;
        attribute integrationTime : TimeDuration;
    }

    action def EstimateAnalyteConcentration {
        in item conductanceShift : ElectricalConductance;
        out item measurement : CalibratedMeasurement;
        attribute calibrationSlope : Real;
        attribute calibrationOffset : Real;
    }

    action def ReportMeasurement {
        in item measurement : CalibratedMeasurement;
        out item telemetry : DigitalTelemetry;
        attribute reportingRate : Frequency;
    }

    state def SensorLifecycle {
        entry action initialize {
            doc /* Initialize controller memory, bias supply, baseline conductance estimate, and thermal control. */
        }

        state Off;
        state Idle;
        state Calibrating;
        state SurfaceReady;
        state Sensing;
        state SignalProcessing;
        state Reporting;
        state Regenerating;
        state Fault;

        transition first Off then Idle;

        transition Idle_to_Calibrating
            first Idle
            accept ControlCommand
            if command.requestedMode == OperatingMode::calibrating
            then Calibrating;

        transition Calibrating_to_SurfaceReady
            first Calibrating
            then SurfaceReady;

        transition SurfaceReady_to_Sensing
            first SurfaceReady
            accept AnalyteSample
            then Sensing;

        transition Sensing_to_Processing
            first Sensing
            then SignalProcessing;

        transition Processing_to_Reporting
            first SignalProcessing
            then Reporting;

        transition Reporting_to_SurfaceReady
            first Reporting
            then SurfaceReady;

        transition SurfaceReady_to_Regenerating
            first SurfaceReady
            if surfaceStatus == SurfaceCondition::contaminated
            then Regenerating;

        transition Regenerating_to_SurfaceReady
            first Regenerating
            then SurfaceReady;

        transition Any_to_Fault
            first Idle
            then Fault;

        attribute surfaceStatus : SurfaceCondition;
    }

    part def SiliceneMonolayer {
        doc /* Atomically thin buckled silicon honeycomb sheet used as the active transduction material. */

        attribute layerThickness : Length = 4.5e-10;
        attribute activeArea : Area = 2.5e-8;
        attribute carrierMobility : Real = 0.12;
        attribute bandGapUnderGateBias : ElectricPotential = 0.18;
        attribute surfaceCondition : SurfaceCondition = SurfaceCondition::functionalized;
        attribute operatingTemperature : Temperature = 300.0;

        port sampleInterface : SampleInletPort;
        port adsorptionInterface : AdsorptionPort;
        port electricalChannel : InternalSignalPort;
        port thermalInterface : ThermalPort;

        perform action expose : ExposeSiliceneSurface {
            exposureDuration = 2.0;
        }
    }

    part def FunctionalizationLayer {
        doc /* Selective receptor layer bonded to silicene to improve analyte specificity while preserving charge transfer. */

        attribute receptorCoverage : Fraction = 0.82;
        attribute selectivityFactor : Fraction = 0.91;
        attribute regenerationEfficiency : Fraction = 0.95;
        attribute maximumOperatingTemperature : Temperature = 330.0;

        port sampleInterface : SampleInletPort;
        port adsorptionOutput : AdsorptionPort;
    }

    part def SourceDrainElectrodes {
        doc /* Metal contacts that inject and collect carriers through the silicene channel. */

        attribute contactResistance : ElectricalResistance = 45.0;
        attribute drainSourceVoltage : ElectricPotential = 0.1;
        attribute maximumCurrent : ElectricCurrent = 0.005;

        port channelPort : InternalSignalPort;
        port measurementPort : ChannelMeasurementPort;
    }

    part def GateDielectricAndBackGate {
        doc /* Gate stack that electrostatically tunes the silicene band structure and operating point. */

        attribute dielectricThickness : Length = 1.0e-8;
        attribute relativePermittivity : Real = 20.0;
        attribute gateVoltageRangeLow : ElectricPotential = -1.5;
        attribute gateVoltageRangeHigh : ElectricPotential = 1.5;
        attribute nominalGateVoltage : ElectricPotential = 0.45;
        attribute leakageLimit : ElectricCurrent = 1.0e-9;

        port biasOutput : BiasPort;

        perform action biasAction : ApplyBias {
            targetGateVoltage = 0.45;
            maximumLeakage = 1.0e-9;
        }
    }

    part def LowNoiseReadoutCircuit {
        doc /* Analog front end that measures drain current and computes conductance of the silicene channel. */

        attribute inputCurrentNoise : ElectricCurrent = 2.0e-12;
        attribute samplingFrequency : Frequency = 1000.0;
        attribute transimpedanceGain : ElectricalResistance = 1000000.0;
        attribute maximumInputCurrent : ElectricCurrent = 0.002;

        port rawInput : ChannelMeasurementPort;
        port processedSignal : InternalSignalPort;

        perform action measureShift : MeasureConductanceShift {
            integrationTime = 0.05;
        }
    }

    part def MicroController {
        doc /* Digital controller executing calibration, signal processing, concentration estimation, and reporting. */

        attribute clockFrequency : Frequency = 48000000.0;
        attribute processingLatency : TimeDuration = 0.02;
        attribute calibrationSlope : Real = 4.2e4;
        attribute calibrationOffset : Real = 0.0;
        attribute currentMode : OperatingMode = OperatingMode::idle;

        port signalInput : InternalSignalPort;
        port commandInput : CommandPort;
        port dataOutput : DataOutPort;

        perform action estimate : EstimateAnalyteConcentration {
            calibrationSlope = 4.2e4;
            calibrationOffset = 0.0;
        }

        perform action report : ReportMeasurement {
            reportingRate = 10.0;
        }

        exhibit state lifecycle : SensorLifecycle;
    }

    part def ThermalStabilizer {
        doc /* Maintains silicene and receptor layer temperature to reduce drift and preserve sensitivity. */

        attribute setPoint : Temperature = 300.0;
        attribute stabilityBand : Temperature = 0.2;
        attribute heaterPowerLimit : Power = 0.35;

        port thermalInterface : ThermalPort;
        port powerInput : PowerInputPort;
    }

    part def PowerManagementUnit {
        doc /* Converts external supply to regulated rails for gate bias, readout electronics, controller, and heater. */

        attribute inputVoltage : ElectricPotential = 5.0;
        attribute regulatedAnalogVoltage : ElectricPotential = 1.8;
        attribute regulatedDigitalVoltage : ElectricPotential = 3.3;
        attribute peakPower : Power = 0.6;

        port externalPower : PowerInputPort;
        port heaterPower : PowerInputPort;
        port controllerPower : PowerInputPort;
    }

    part def SiliceneAnalyteSensorSystem {
        doc /* High-level system based on silicene. Its primary function is to detect target analyte molecules by using adsorption-induced changes in a silicene field-effect channel and to output a calibrated concentration estimate. */

        attribute nominalLimitOfDetection : Concentration = 1.0e-9;
        attribute responseTime : TimeDuration = 3.0;
        attribute nominalOperatingTemperature : Temperature = 300.0;
        attribute standbyPower : Power = 0.08;
        attribute activePower : Power = 0.42;

        port powerIn : PowerInputPort;
        port sampleIn : SampleInletPort;
        port commandIn : CommandPort;
        port dataOut : DataOutPort;
        port ambientThermal : ThermalPort;

        part silicene : SiliceneMonolayer;
        part receptors : FunctionalizationLayer;
        part electrodes : SourceDrainElectrodes;
        part gate : GateDielectricAndBackGate;
        part readout : LowNoiseReadoutCircuit;
        part controller : MicroController;
        part thermal : ThermalStabilizer;
        part power : PowerManagementUnit;

        connection powerFeed connect powerIn to power.externalPower;
        connection controllerPowerFeed connect power.controllerPower to controller.commandInput;
        connection heaterPowerFeed connect power.heaterPower to thermal.powerInput;

        connection sampleToReceptors connect sampleIn to receptors.sampleInterface;
        connection receptorsToSilicene connect receptors.adsorptionOutput to silicene.adsorptionInterface;
        connection sampleToSilicene connect sampleIn to silicene.sampleInterface;

        connection gateBiasToSilicene connect gate.biasOutput to silicene.electricalChannel;
        connection siliceneToElectrodes connect silicene.electricalChannel to electrodes.channelPort;
        connection electrodesToReadout connect electrodes.measurementPort to readout.rawInput;
        connection readoutToController connect readout.processedSignal to controller.signalInput;

        connection commandToController connect commandIn to controller.commandInput;
        connection controllerToExternalData connect controller.dataOutput to dataOut;

        connection ambientToThermalControl connect ambientThermal to thermal.thermalInterface;
        connection thermalToSilicene connect thermal.thermalInterface to silicene.thermalInterface;

        perform action systemExposure : ExposeSiliceneSurface {
            exposureDuration = 2.0;
        }

        perform action systemMeasurement : MeasureConductanceShift {
            integrationTime = 0.05;
        }

        perform action systemEstimation : EstimateAnalyteConcentration {
            calibrationSlope = 4.2e4;
            calibrationOffset = 0.0;
        }
    }

    requirement def HighLevelPrimaryFunctionRequirement {
        doc /* The system shall use a silicene monolayer as the active sensing channel to convert adsorption of target analyte molecules into an electrical signal and provide a calibrated concentration estimate to an external user or host system. */

        subject system : SiliceneAnalyteSensorSystem;

        require constraint {
            system.nominalLimitOfDetection <= 1.0e-9
        }

        require constraint {
            system.responseTime <= 5.0
        }
    }

    requirement def SiliceneMaterialRequirement {
        doc /* The active transduction element shall be an atomically thin silicene monolayer with an electrically tunable channel. */

        subject layer : SiliceneMonolayer;

        require constraint {
            layer.layerThickness <= 1.0e-9
        }

        require constraint {
            layer.surfaceCondition == SurfaceCondition::functionalized
        }
    }

    requirement def ElectricalReadoutRequirement {
        doc /* The readout chain shall measure changes in drain-source current caused by analyte adsorption on silicene with low noise and sufficient sampling rate. */

        subject readoutCircuit : LowNoiseReadoutCircuit;

        require constraint {
            readoutCircuit.inputCurrentNoise <= 5.0e-12
        }

        require constraint {
            readoutCircuit.samplingFrequency >= 100.0
        }
    }

    requirement def GateControlRequirement {
        doc /* The gate stack shall bias the silicene channel within a safe voltage range while limiting leakage current. */

        subject gateStack : GateDielectricAndBackGate;

        require constraint {
            gateStack.nominalGateVoltage >= gateStack.gateVoltageRangeLow
        }

        require constraint {
            gateStack.nominalGateVoltage <= gateStack.gateVoltageRangeHigh
        }

        require constraint {
            gateStack.leakageLimit <= 1.0e-8
        }
    }

    requirement def ThermalStabilityRequirement {
        doc /* The system shall stabilize the silicene sensing surface near room temperature to reduce conductance drift. */

        subject thermalControl : ThermalStabilizer;

        require constraint {
            thermalControl.setPoint >= 295.0
        }

        require constraint {
            thermalControl.setPoint <= 305.0
        }

        require constraint {
            thermalControl.stabilityBand <= 0.5
        }
    }

    requirement def ReportingRequirement {
        doc /* The controller shall report concentration estimates and digital telemetry at a rate useful for high-level monitoring. */

        subject controller : MicroController;

        require constraint {
            controller.processingLatency <= 0.1
        }
    }

    part siliceneSensorSystem : SiliceneAnalyteSensorSystem;

    requirement primaryFunctionReq : HighLevelPrimaryFunctionRequirement {
        subject system = siliceneSensorSystem;
    }

    requirement materialReq : SiliceneMaterialRequirement {
        subject layer = siliceneSensorSystem.silicene;
    }

    requirement readoutReq : ElectricalReadoutRequirement {
        subject readoutCircuit = siliceneSensorSystem.readout;
    }

    requirement gateReq : GateControlRequirement {
        subject gateStack = siliceneSensorSystem.gate;
    }

    requirement thermalReq : ThermalStabilityRequirement {
        subject thermalControl = siliceneSensorSystem.thermal;
    }

    requirement reportReq : ReportingRequirement {
        subject controller = siliceneSensorSystem.controller;
    }

    satisfy primaryFunctionSatisfaction by siliceneSensorSystem;
    satisfy materialSatisfaction by siliceneSensorSystem.silicene;
    satisfy readoutSatisfaction by siliceneSensorSystem.readout;
    satisfy gateSatisfaction by siliceneSensorSystem.gate;
    satisfy thermalSatisfaction by siliceneSensorSystem.thermal;
    satisfy reportingSatisfaction by siliceneSensorSystem.controller;
}
