package GravimeterSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Acceleration {
        :> scalar;
        unit = "m/s^2";
    }

    attribute def MicroGal {
        :> scalar;
        unit = "um/s^2";
    }

    attribute def Length {
        :> scalar;
        unit = "m";
    }

    attribute def TimeDuration {
        :> scalar;
        unit = "s";
    }

    attribute def Temperature {
        :> scalar;
        unit = "K";
    }

    attribute def Voltage {
        :> scalar;
        unit = "V";
    }

    attribute def Current {
        :> scalar;
        unit = "A";
    }

    attribute def Frequency {
        :> scalar;
        unit = "Hz";
    }

    attribute def Angle {
        :> scalar;
        unit = "rad";
    }

    attribute def Mass {
        :> scalar;
        unit = "kg";
    }

    item def PowerEnergy {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def RawSensorSignal {
        attribute proofMassDisplacement : Length;
        attribute pickoffVoltage : Voltage;
        attribute sampleTime : TimeDuration;
        attribute sensorTemperature : Temperature;
    }

    item def GravityMeasurement {
        attribute localGravity : Acceleration;
        attribute uncertainty : MicroGal;
        attribute integrationTime : TimeDuration;
        attribute latitudeCorrectionApplied : Boolean;
        attribute terrainCorrectionApplied : Boolean;
        attribute timestamp : TimeDuration;
    }

    item def EnvironmentalData {
        attribute temperature : Temperature;
        attribute tiltX : Angle;
        attribute tiltY : Angle;
        attribute vibrationRms : Acceleration;
        attribute pressureCompensationFactor : Real;
    }

    item def CalibrationData {
        attribute scaleFactor : Real;
        attribute biasOffset : Acceleration;
        attribute temperatureCoefficient : Real;
        attribute lastCalibrationAge : TimeDuration;
    }

    item def OperatorCommand {
        attribute startMeasurement : Boolean;
        attribute stopMeasurement : Boolean;
        attribute calibrate : Boolean;
        attribute integrationTimeCommand : TimeDuration;
    }

    item def MeasurementReport {
        attribute gravity : Acceleration;
        attribute expandedUncertainty : MicroGal;
        attribute qualityIndex : Real;
        attribute statusText : String;
    }

    port def PowerPort {
        in item powerIn : PowerEnergy;
    }

    port def SignalPort {
        out item rawSignal : RawSensorSignal;
    }

    port def EnvironmentPort {
        out item environment : EnvironmentalData;
    }

    port def CalibrationPort {
        out item calibration : CalibrationData;
    }

    port def CommandPort {
        in item command : OperatorCommand;
    }

    port def MeasurementPort {
        out item measurement : GravityMeasurement;
    }

    port def ReportPort {
        out item report : MeasurementReport;
    }

    part def Gravimeter {
        attribute measurementRangeMin : Acceleration = 9.70;
        attribute measurementRangeMax : Acceleration = 9.90;
        attribute resolution : MicroGal = 1.0;
        attribute warmupTime : TimeDuration = 600.0;
        attribute nominalPowerVoltage : Voltage = 24.0;

        port powerPort : PowerPort;
        port commandPort : CommandPort;
        port reportPort : ReportPort;

        part sensorHead : GravimetricSensorHead;
        part thermalControl : ThermalControlUnit;
        part isolationStage : VibrationIsolationStage;
        part tiltSubsystem : TiltCompensationSubsystem;
        part acquisitionElectronics : DataAcquisitionElectronics;
        part processingUnit : GravityProcessingUnit;
        part calibrationUnit : CalibrationUnit;
        part userInterface : OperatorInterface;
        part powerConditioner : PowerConditioningUnit;

        connect powerPort.powerIn to powerConditioner.inputPower;
        connect powerConditioner.conditionedPower to sensorHead.powerPort.powerIn;
        connect powerConditioner.conditionedPower to thermalControl.powerPort.powerIn;
        connect powerConditioner.conditionedPower to acquisitionElectronics.powerPort.powerIn;
        connect powerConditioner.conditionedPower to processingUnit.powerPort.powerIn;
        connect powerConditioner.conditionedPower to userInterface.powerPort.powerIn;

        connect sensorHead.signalPort.rawSignal to acquisitionElectronics.sensorInput;
        connect thermalControl.environmentPort.environment to processingUnit.environmentInput;
        connect tiltSubsystem.environmentPort.environment to processingUnit.tiltInput;
        connect isolationStage.environmentPort.environment to processingUnit.vibrationInput;
        connect acquisitionElectronics.digitizedSignal to processingUnit.rawInput;
        connect calibrationUnit.calibrationPort.calibration to processingUnit.calibrationInput;
        connect commandPort.command to userInterface.commandInput;
        connect userInterface.operatorCommand to processingUnit.commandInput;
        connect processingUnit.measurementPort.measurement to userInterface.measurementInput;
        connect userInterface.reportPort.report to reportPort.report;

        perform action MeasureLocalGravity;
    }

    part def GravimetricSensorHead {
        attribute proofMass : Mass = 0.025;
        attribute springConstant : Real = 0.48;
        attribute naturalFrequency : Frequency = 8.0;
        attribute pickoffGain : Real = 1200.0;

        port powerPort : PowerPort;
        port signalPort : SignalPort;

        part proofMassAssembly : ProofMassAssembly;
        part suspension : ElasticSuspension;
        part positionPickoff : CapacitivePickoff;
        part referenceFrame : RigidReferenceFrame;

        connect proofMassAssembly.motionOutput to positionPickoff.displacementInput;
        connect suspension.supportOutput to proofMassAssembly.supportInput;
        connect positionPickoff.signalPort.rawSignal to signalPort.rawSignal;
    }

    part def ProofMassAssembly {
        attribute mass : Mass = 0.025;
        attribute displacementLimit : Length = 0.0005;
        port motionOutput : SignalPort;
        port supportInput : SignalPort;
    }

    part def ElasticSuspension {
        attribute stiffness : Real = 0.48;
        attribute dampingCoefficient : Real = 0.025;
        port supportOutput : SignalPort;
    }

    part def CapacitivePickoff {
        attribute excitationFrequency : Frequency = 10000.0;
        attribute nominalGap : Length = 0.0002;
        attribute gain : Real = 1200.0;
        port displacementInput : SignalPort;
        port signalPort : SignalPort;
    }

    part def RigidReferenceFrame {
        attribute frameStability : Length = 0.00000001;
        attribute thermalExpansionCoefficient : Real = 0.0000005;
    }

    part def ThermalControlUnit {
        attribute setPoint : Temperature = 308.15;
        attribute allowableDrift : Temperature = 0.005;

        port powerPort : PowerPort;
        port environmentPort : EnvironmentPort;

        part heater : PrecisionHeater;
        part temperatureSensor : TemperatureSensor;
        part controller : TemperatureController;

        connect temperatureSensor.environmentPort.environment to controller.temperatureFeedback;
        connect controller.heaterCommand to heater.powerPort.powerIn;
    }

    part def PrecisionHeater {
        attribute maximumPower : Real = 5.0;
        port powerPort : PowerPort;
    }

    part def TemperatureSensor {
        attribute accuracy : Temperature = 0.002;
        port environmentPort : EnvironmentPort;
    }

    part def TemperatureController {
        attribute proportionalGain : Real = 2.5;
        attribute integralGain : Real = 0.05;
        port temperatureFeedback : EnvironmentPort;
        port heaterCommand : PowerPort;
    }

    part def VibrationIsolationStage {
        attribute attenuationAtTenHz : Real = 40.0;
        attribute resonanceFrequency : Frequency = 1.2;

        port environmentPort : EnvironmentPort;

        part passiveIsolator : PassiveSpringDamper;
        part vibrationMonitor : AccelerometerMonitor;

        connect vibrationMonitor.environmentPort.environment to environmentPort.environment;
    }

    part def PassiveSpringDamper {
        attribute verticalStiffness : Real = 120.0;
        attribute dampingRatio : Real = 0.7;
    }

    part def AccelerometerMonitor {
        attribute noiseDensity : Real = 0.000001;
        port environmentPort : EnvironmentPort;
    }

    part def TiltCompensationSubsystem {
        attribute maximumCompensatedTilt : Angle = 0.0873;
        attribute tiltAccuracy : Angle = 0.000017;

        port environmentPort : EnvironmentPort;

        part tiltMeterX : TiltMeter;
        part tiltMeterY : TiltMeter;
    }

    part def TiltMeter {
        attribute range : Angle = 0.0873;
        attribute accuracy : Angle = 0.000017;
        port environmentPort : EnvironmentPort;
    }

    part def DataAcquisitionElectronics {
        attribute adcResolutionBits : Integer = 24;
        attribute samplingFrequency : Frequency = 100.0;
        attribute inputNoise : Voltage = 0.0000001;

        port powerPort : PowerPort;
        port sensorInput : SignalPort;
        port digitizedSignal : SignalPort;

        part antiAliasFilter : AntiAliasFilter;
        part analogToDigitalConverter : AnalogToDigitalConverter;
        part timingReference : TimingReference;

        connect sensorInput.rawSignal to antiAliasFilter.inputSignal;
        connect antiAliasFilter.filteredSignal to analogToDigitalConverter.inputSignal;
        connect analogToDigitalConverter.outputSignal to digitizedSignal.rawSignal;
    }

    part def AntiAliasFilter {
        attribute cutoffFrequency : Frequency = 20.0;
        attribute order : Integer = 4;
        port inputSignal : SignalPort;
        port filteredSignal : SignalPort;
    }

    part def AnalogToDigitalConverter {
        attribute bits : Integer = 24;
        attribute referenceVoltage : Voltage = 5.0;
        port inputSignal : SignalPort;
        port outputSignal : SignalPort;
    }

    part def TimingReference {
        attribute oscillatorStability : Real = 0.00000001;
        attribute frequency : Frequency = 10000000.0;
    }

    part def CalibrationUnit {
        attribute defaultScaleFactor : Real = 1.0;
        attribute defaultBiasOffset : Acceleration = 0.0;

        port calibrationPort : CalibrationPort;

        part referenceWeightActuator : ReferenceForceActuator;
        part calibrationMemory : CalibrationMemory;
    }

    part def ReferenceForceActuator {
        attribute referenceForceEquivalentGravity : Acceleration = 0.00001;
        attribute repeatability : MicroGal = 0.2;
    }

    part def CalibrationMemory {
        attribute storedScaleFactor : Real = 1.000004;
        attribute storedBiasOffset : Acceleration = 0.0000003;
        attribute storedTemperatureCoefficient : Real = 0.0000002;
    }

    part def GravityProcessingUnit {
        attribute minimumIntegrationTime : TimeDuration = 10.0;
        attribute defaultIntegrationTime : TimeDuration = 60.0;
        attribute maximumIntegrationTime : TimeDuration = 3600.0;

        port powerPort : PowerPort;
        port rawInput : SignalPort;
        port environmentInput : EnvironmentPort;
        port tiltInput : EnvironmentPort;
        port vibrationInput : EnvironmentPort;
        port calibrationInput : CalibrationPort;
        port commandInput : CommandPort;
        port measurementPort : MeasurementPort;

        perform action EstimateGravity;
    }

    part def OperatorInterface {
        attribute displayRefreshRate : Frequency = 1.0;

        port powerPort : PowerPort;
        port commandInput : CommandPort;
        port operatorCommand : CommandPort;
        port measurementInput : MeasurementPort;
        port reportPort : ReportPort;
    }

    part def PowerConditioningUnit {
        attribute inputVoltageMin : Voltage = 18.0;
        attribute inputVoltageMax : Voltage = 32.0;
        attribute outputVoltage : Voltage = 24.0;
        attribute rippleVoltage : Voltage = 0.001;

        in item inputPower : PowerEnergy;
        out item conditionedPower : PowerEnergy;
    }

    action def MeasureLocalGravity {
        in item command : OperatorCommand;
        out item report : MeasurementReport;

        first start;
        then warmUp;
        then stabilizeSensor;
        then acquireRawSignal;
        then compensateEnvironment;
        then estimateGravity;
        then publishReport;
        then done;

        action warmUp {
            out attribute elapsed : TimeDuration = 600.0;
        }

        action stabilizeSensor {
            out attribute sensorStable : Boolean = true;
        }

        action acquireRawSignal {
            in item rawSignal : RawSensorSignal;
            out item averagedSignal : RawSensorSignal;
        }

        action compensateEnvironment {
            in item averagedSignal : RawSensorSignal;
            in item environment : EnvironmentalData;
            out item compensatedSignal : RawSensorSignal;
        }

        action estimateGravity {
            in item compensatedSignal : RawSensorSignal;
            in item calibration : CalibrationData;
            out item measurement : GravityMeasurement;
        }

        action publishReport {
            in item measurement : GravityMeasurement;
            out item report : MeasurementReport;
        }
    }

    action def EstimateGravity {
        in item rawSignal : RawSensorSignal;
        in item environment : EnvironmentalData;
        in item calibration : CalibrationData;
        out item measurement : GravityMeasurement;

        attribute correctedDisplacement : Length;
        attribute scaleCorrectedGravity : Acceleration;
        attribute tiltCorrectedGravity : Acceleration;
        attribute temperatureCorrectedGravity : Acceleration;
    }

    state def GravimeterOperationalStates {
        entry action InitializeHardware;

        state Off;
        state PowerUp;
        state WarmUp;
        state Standby;
        state Measuring;
        state Calibrating;
        state Fault;
        state Shutdown;

        transition initial then Off;
        transition Off_to_PowerUp first Off then PowerUp
            accept OperatorCommand
            if command.startMeasurement == true;

        transition PowerUp_to_WarmUp first PowerUp then WarmUp;
        transition WarmUp_to_Standby first WarmUp then Standby
            if elapsedWarmup >= 600.0;

        transition Standby_to_Measuring first Standby then Measuring
            accept OperatorCommand
            if command.startMeasurement == true;

        transition Measuring_to_Standby first Measuring then Standby
            accept OperatorCommand
            if command.stopMeasurement == true;

        transition Standby_to_Calibrating first Standby then Calibrating
            accept OperatorCommand
            if command.calibrate == true;

        transition Calibrating_to_Standby first Calibrating then Standby
            if calibrationComplete == true;

        transition Measuring_to_Fault first Measuring then Fault
            if vibrationLimitExceeded == true or thermalLimitExceeded == true;

        transition WarmUp_to_Fault first WarmUp then Fault
            if thermalLimitExceeded == true;

        transition Fault_to_Shutdown first Fault then Shutdown
            if unrecoverableFault == true;

        attribute elapsedWarmup : TimeDuration;
        attribute calibrationComplete : Boolean;
        attribute vibrationLimitExceeded : Boolean;
        attribute thermalLimitExceeded : Boolean;
        attribute unrecoverableFault : Boolean;
    }

    action def InitializeHardware {
        out attribute initialized : Boolean = true;
    }

    requirement def GravimeterPrimaryFunctionRequirement {
        doc /* The gravimeter shall determine local gravitational acceleration by sensing the displacement of a proof mass relative to a stable reference frame, compensating for temperature, tilt, vibration, and calibration bias, and reporting a gravity measurement with quantified uncertainty. */

        subject gravimeter : Gravimeter;

        require constraint {
            gravimeter.processingUnit.defaultIntegrationTime >= 10.0 and
            gravimeter.resolution <= 1.0
        }
    }

    requirement def MeasurementRangeRequirement {
        doc /* The gravimeter shall measure local gravity over the terrestrial operating range expected for field and laboratory use. */

        subject gravimeter : Gravimeter;

        require constraint {
            gravimeter.measurementRangeMin <= 9.70 and
            gravimeter.measurementRangeMax >= 9.90
        }
    }

    requirement def ThermalStabilityRequirement {
        doc /* The sensor thermal environment shall remain sufficiently stable to prevent temperature drift from dominating gravity uncertainty. */

        subject gravimeter : Gravimeter;

        require constraint {
            gravimeter.thermalControl.allowableDrift <= 0.005
        }
    }

    requirement def VibrationRejectionRequirement {
        doc /* The gravimeter shall monitor vibration and reject or flag measurements when vibration exceeds the processing quality threshold. */

        subject gravimeter : Gravimeter;

        require constraint {
            gravimeter.isolationStage.attenuationAtTenHz >= 40.0
        }
    }

    requirement def CalibrationRequirement {
        doc /* The gravimeter shall apply stored calibration scale factor, bias offset, and temperature coefficient to each reported gravity estimate. */

        subject gravimeter : Gravimeter;

        require constraint {
            gravimeter.calibrationUnit.calibrationMemory.storedScaleFactor > 0.99 and
            gravimeter.calibrationUnit.calibrationMemory.storedScaleFactor < 1.01
        }
    }

    requirement def ReportRequirement {
        doc /* The gravimeter shall output a measurement report containing corrected gravity, expanded uncertainty, quality index, and operating status. */

        subject gravimeter : Gravimeter;

        require constraint {
            gravimeter.processingUnit.defaultIntegrationTime <= gravimeter.processingUnit.maximumIntegrationTime
        }
    }

    satisfy GravimeterPrimaryFunctionRequirement by Gravimeter;
    satisfy MeasurementRangeRequirement by Gravimeter;
    satisfy ThermalStabilityRequirement by ThermalControlUnit;
    satisfy VibrationRejectionRequirement by VibrationIsolationStage;
    satisfy CalibrationRequirement by CalibrationUnit;
    satisfy ReportRequirement by OperatorInterface;

    part fieldGravimeter : Gravimeter {
        attribute measurementRangeMin = 9.70;
        attribute measurementRangeMax = 9.90;
        attribute resolution = 1.0;
        attribute warmupTime = 600.0;
    }

}