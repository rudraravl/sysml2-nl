package GravimeterSystem {

    import ScalarValues::*;
    import SI::*;

    value type Time_s :> Real {
        unit = "s";
        quantityKind = "time";
    }

    value type Frequency_Hz :> Real {
        unit = "Hz";
        quantityKind = "frequency";
    }

    value type Voltage_V :> Real {
        unit = "V";
        quantityKind = "electric potential";
    }

    value type Current_A :> Real {
        unit = "A";
        quantityKind = "electric current";
    }

    value type Power_W :> Real {
        unit = "W";
        quantityKind = "power";
    }

    value type Temperature_degC :> Real {
        unit = "degC";
        quantityKind = "thermodynamic temperature";
    }

    value type Acceleration_mps2 :> Real {
        unit = "m/s^2";
        quantityKind = "acceleration";
    }

    value type GravityGradient_E :> Real {
        unit = "E";
        quantityKind = "gravity gradient";
    }

    value type Length_m :> Real {
        unit = "m";
        quantityKind = "length";
    }

    value type Angle_rad :> Real {
        unit = "rad";
        quantityKind = "plane angle";
    }

    value type NoiseDensity_ugPerSqrtHz :> Real {
        unit = "ug/sqrt(Hz)";
        quantityKind = "acceleration noise density";
    }

    value type DataRate_bps :> Real {
        unit = "bit/s";
        quantityKind = "data rate";
    }

    value type Capacity_Wh :> Real {
        unit = "W*h";
        quantityKind = "energy capacity";
    }

    value type Percent :> Real {
        unit = "%";
        quantityKind = "ratio";
    }

    enum def GravimeterMode {
        enum off;
        enum standby;
        enum warmup;
        enum selfTest;
        enum leveling;
        enum calibrating;
        enum measuring;
        enum reporting;
        enum fault;
    }

    enum def HealthStatus {
        enum nominal;
        enum degraded;
        enum maintenanceRequired;
        enum failed;
    }

    enum def MeasurementQuality {
        enum invalid;
        enum low;
        enum medium;
        enum high;
        enum surveyGrade;
    }

    item def ElectricalPower {
        attribute voltage : Voltage_V;
        attribute current : Current_A;
        attribute power : Power_W;
    }

    item def PowerCommand {
        attribute requestedOn : Boolean;
        attribute requestedStandby : Boolean;
    }

    item def GravitySample {
        attribute timestamp : Time_s;
        attribute rawAcceleration : Acceleration_mps2;
        attribute sensorTemperature : Temperature_degC;
        attribute verticalTiltX : Angle_rad;
        attribute verticalTiltY : Angle_rad;
    }

    item def CorrectedGravitySample {
        attribute timestamp : Time_s;
        attribute localGravity : Acceleration_mps2;
        attribute estimatedBias : Acceleration_mps2;
        attribute correctionApplied : Acceleration_mps2;
        attribute uncertaintyOneSigma : Acceleration_mps2;
        attribute quality : MeasurementQuality;
    }

    item def GravityReport {
        attribute reportTime : Time_s;
        attribute averageGravity : Acceleration_mps2;
        attribute standardDeviation : Acceleration_mps2;
        attribute sampleCount : Integer;
        attribute averagingPeriod : Time_s;
        attribute quality : MeasurementQuality;
        attribute health : HealthStatus;
    }

    item def EnvironmentalData {
        attribute ambientTemperature : Temperature_degC;
        attribute enclosureTemperature : Temperature_degC;
        attribute vibrationAccelerationRms : Acceleration_mps2;
        attribute barometricCorrection : Acceleration_mps2;
    }

    item def AttitudeData {
        attribute roll : Angle_rad;
        attribute pitch : Angle_rad;
        attribute yaw : Angle_rad;
        attribute verticalityError : Angle_rad;
    }

    item def ControlCommand {
        attribute commandedMode : GravimeterMode;
        attribute integrationTime : Time_s;
        attribute startMeasurement : Boolean;
        attribute stopMeasurement : Boolean;
        attribute requestSelfTest : Boolean;
        attribute requestCalibration : Boolean;
    }

    item def HealthTelemetry {
        attribute mode : GravimeterMode;
        attribute status : HealthStatus;
        attribute batteryStateOfCharge : Percent;
        attribute enclosureTemperature : Temperature_degC;
        attribute sensorTemperature : Temperature_degC;
        attribute lastFaultCode : Integer;
    }

    item def TimeReference {
        attribute epochTime : Time_s;
        attribute clockDrift : Time_s;
        attribute synchronizationValid : Boolean;
    }

    port def PowerInputPort {
        in item electricalPower : ElectricalPower;
        in item powerCommand : PowerCommand;
    }

    port def RegulatedPowerPort {
        out item regulatedPower : ElectricalPower;
    }

    port def SensorSamplePort {
        out item gravitySample : GravitySample;
    }

    port def CorrectedSamplePort {
        out item correctedSample : CorrectedGravitySample;
    }

    port def GravityReportPort {
        out item gravityReport : GravityReport;
    }

    port def EnvironmentPort {
        out item environmentalData : EnvironmentalData;
    }

    port def AttitudePort {
        out item attitudeData : AttitudeData;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def TelemetryPort {
        out item telemetry : HealthTelemetry;
    }

    port def TimePort {
        in item timeReference : TimeReference;
    }

    port def OperatorInterfacePort {
        in item operatorCommand : ControlCommand;
        out item displayedReport : GravityReport;
        out item displayedHealth : HealthTelemetry;
    }

    part def Gravimeter {
        attribute primaryFunction : String = "Estimate and report local gravitational acceleration by sensing inertial acceleration, rejecting environmental disturbances, applying calibration and compensation corrections, and delivering a qualified gravity measurement to an operator or host system.";
        attribute mode : GravimeterMode = GravimeterMode::off;
        attribute health : HealthStatus = HealthStatus::nominal;
        attribute measurementRate : Frequency_Hz = 1.0;
        attribute nominalGravityRangeMin : Acceleration_mps2 = 9.70;
        attribute nominalGravityRangeMax : Acceleration_mps2 = 9.90;
        attribute targetResolution : Acceleration_mps2 = 0.000001;
        attribute targetAccuracy : Acceleration_mps2 = 0.000010;
        attribute warmupDuration : Time_s = 600.0;
        attribute operatingTemperatureMin : Temperature_degC = -10.0;
        attribute operatingTemperatureMax : Temperature_degC = 45.0;

        port powerIn : PowerInputPort;
        port commandIn : CommandPort;
        port timeIn : TimePort;
        port reportOut : GravityReportPort;
        port telemetryOut : TelemetryPort;
        port operatorInterface : OperatorInterfacePort;

        part powerSubsystem : PowerSubsystem;
        part sensorHead : SensorHead;
        part thermalControl : ThermalControlUnit;
        part levelingSubsystem : LevelingSubsystem;
        part signalProcessor : SignalProcessor;
        part calibrationManager : CalibrationManager;
        part dataLogger : DataLogger;
        part userInterface : UserInterface;
        part communicationsAdapter : CommunicationsAdapter;

        connection externalPowerToPowerSubsystem connect powerIn to powerSubsystem.powerIn;
        connection regulatedPowerToSensorHead connect powerSubsystem.regulatedPowerOut to sensorHead.powerIn;
        connection regulatedPowerToThermalControl connect powerSubsystem.regulatedPowerOut to thermalControl.powerIn;
        connection regulatedPowerToLeveling connect powerSubsystem.regulatedPowerOut to levelingSubsystem.powerIn;
        connection regulatedPowerToProcessor connect powerSubsystem.regulatedPowerOut to signalProcessor.powerIn;
        connection regulatedPowerToCalibration connect powerSubsystem.regulatedPowerOut to calibrationManager.powerIn;
        connection regulatedPowerToLogger connect powerSubsystem.regulatedPowerOut to dataLogger.powerIn;
        connection regulatedPowerToInterface connect powerSubsystem.regulatedPowerOut to userInterface.powerIn;
        connection regulatedPowerToComms connect powerSubsystem.regulatedPowerOut to communicationsAdapter.powerIn;

        connection timeToProcessor connect timeIn to signalProcessor.timeIn;
        connection operatorCommandsToInterface connect operatorInterface to userInterface.operatorInterface;
        connection userCommandsToProcessor connect userInterface.commandOut to signalProcessor.commandIn;
        connection externalCommandsToProcessor connect commandIn to signalProcessor.commandIn;

        connection thermalEnvironmentToProcessor connect thermalControl.environmentOut to signalProcessor.environmentIn;
        connection levelAttitudeToProcessor connect levelingSubsystem.attitudeOut to signalProcessor.attitudeIn;
        connection rawSamplesToProcessor connect sensorHead.sampleOut to signalProcessor.sampleIn;
        connection correctedSamplesToCalibration connect signalProcessor.correctedSampleOut to calibrationManager.correctedSampleIn;
        connection calibrationToProcessor connect calibrationManager.calibrationOut to signalProcessor.calibrationIn;
        connection processorReportsToLogger connect signalProcessor.reportOut to dataLogger.reportIn;
        connection processorTelemetryToLogger connect signalProcessor.telemetryOut to dataLogger.telemetryIn;
        connection processorReportsToComms connect signalProcessor.reportOut to communicationsAdapter.reportIn;
        connection processorTelemetryToComms connect signalProcessor.telemetryOut to communicationsAdapter.telemetryIn;
        connection processorReportsToSystem connect signalProcessor.reportOut to reportOut;
        connection processorTelemetryToSystem connect signalProcessor.telemetryOut to telemetryOut;
        connection processorReportsToInterface connect signalProcessor.reportOut to userInterface.reportIn;
        connection processorTelemetryToInterface connect signalProcessor.telemetryOut to userInterface.telemetryIn;
    }

    part def PowerSubsystem {
        attribute inputVoltageMin : Voltage_V = 10.0;
        attribute inputVoltageMax : Voltage_V = 32.0;
        attribute regulatedVoltage : Voltage_V = 12.0;
        attribute maximumOutputPower : Power_W = 80.0;
        attribute batteryCapacity : Capacity_Wh = 160.0;
        attribute stateOfCharge : Percent = 100.0;

        port powerIn : PowerInputPort;
        port regulatedPowerOut : RegulatedPowerPort;

        part battery : BatteryPack;
        part powerConditioner : PowerConditioner;
        part protectionSwitch : ProtectionSwitch;
    }

    part def BatteryPack {
        attribute nominalVoltage : Voltage_V = 14.4;
        attribute capacity : Capacity_Wh = 160.0;
        attribute minimumSafeStateOfCharge : Percent = 10.0;
        attribute stateOfCharge : Percent = 100.0;
    }

    part def PowerConditioner {
        attribute outputVoltage : Voltage_V = 12.0;
        attribute outputRippleRms : Voltage_V = 0.005;
        attribute efficiency : Percent = 92.0;
    }

    part def ProtectionSwitch {
        attribute overCurrentTrip : Current_A = 8.0;
        attribute underVoltageTrip : Voltage_V = 9.5;
        attribute overTemperatureTrip : Temperature_degC = 70.0;
    }

    part def SensorHead {
        attribute sensorType : String = "spring-mass inertial gravimeter with precision displacement readout";
        attribute proofMassTravel : Length_m = 0.002;
        attribute rawNoiseDensity : NoiseDensity_ugPerSqrtHz = 5.0;
        attribute sampleRate : Frequency_Hz = 200.0;
        attribute scaleFactor : Real = 1.0;
        attribute biasStability : Acceleration_mps2 = 0.000005;
        attribute allowableTilt : Angle_rad = 0.002;

        port powerIn : RegulatedPowerPort;
        port sampleOut : SensorSamplePort;

        part proofMassAssembly : ProofMassAssembly;
        part displacementReadout : DisplacementReadout;
        part analogFrontEnd : AnalogFrontEnd;
        part digitizer : Digitizer;
    }

    part def ProofMassAssembly {
        attribute proofMass : Real = 0.05;
        attribute springConstant : Real = 12.0;
        attribute mechanicalResonance : Frequency_Hz = 7.5;
        attribute dampingRatio : Real = 0.7;
    }

    part def DisplacementReadout {
        attribute readoutResolution : Length_m = 0.000000001;
        attribute readoutBandwidth : Frequency_Hz = 50.0;
        attribute linearityError : Percent = 0.01;
    }

    part def AnalogFrontEnd {
        attribute gain : Real = 1000.0;
        attribute bandwidth : Frequency_Hz = 100.0;
        attribute inputReferredNoise : Voltage_V = 0.000001;
    }

    part def Digitizer {
        attribute resolutionBits : Integer = 24;
        attribute samplingFrequency : Frequency_Hz = 200.0;
        attribute referenceVoltage : Voltage_V = 2.5;
    }

    part def ThermalControlUnit {
        attribute setPoint : Temperature_degC = 35.0;
        attribute stability : Temperature_degC = 0.02;
        attribute heaterPower : Power_W = 15.0;
        attribute enclosureTemperature : Temperature_degC = 35.0;

        port powerIn : RegulatedPowerPort;
        port environmentOut : EnvironmentPort;

        part temperatureSensor : TemperatureSensor;
        part heater : Heater;
        part insulation : ThermalInsulation;
    }

    part def TemperatureSensor {
        attribute accuracy : Temperature_degC = 0.05;
        attribute responseTime : Time_s = 2.0;
    }

    part def Heater {
        attribute maximumPower : Power_W = 15.0;
        attribute controlResolution : Percent = 1.0;
    }

    part def ThermalInsulation {
        attribute thermalResistance : Real = 8.0;
        attribute warmupTimeConstant : Time_s = 300.0;
    }

    part def LevelingSubsystem {
        attribute levelingAccuracy : Angle_rad = 0.00005;
        attribute maximumCorrectionAngle : Angle_rad = 0.05;
        attribute settlingTime : Time_s = 20.0;

        port powerIn : RegulatedPowerPort;
        port attitudeOut : AttitudePort;

        part tiltSensor : TiltSensor;
        part motorizedLevelingFeet : MotorizedLevelingFeet;
    }

    part def TiltSensor {
        attribute resolution : Angle_rad = 0.00001;
        attribute bandwidth : Frequency_Hz = 5.0;
        attribute biasError : Angle_rad = 0.00002;
    }

    part def MotorizedLevelingFeet {
        attribute actuatorCount : Integer = 3;
        attribute stepSize : Length_m = 0.000001;
        attribute maximumLoad : Real = 20.0;
    }

    part def SignalProcessor {
        attribute processorClock : Frequency_Hz = 200000000.0;
        attribute decimationRatio : Integer = 200;
        attribute integrationTimeDefault : Time_s = 60.0;
        attribute filterCutoff : Frequency_Hz = 0.5;
        attribute lastComputedGravity : Acceleration_mps2 = 9.80665;
        attribute lastUncertainty : Acceleration_mps2 = 0.000010;

        port powerIn : RegulatedPowerPort;
        port commandIn : CommandPort;
        port timeIn : TimePort;
        port sampleIn : SensorSamplePort;
        port environmentIn : EnvironmentPort;
        port attitudeIn : AttitudePort;
        port calibrationIn : CalibrationPort;
        port correctedSampleOut : CorrectedSamplePort;
        port reportOut : GravityReportPort;
        port telemetryOut : TelemetryPort;

        part acquisition : AcquisitionFunction;
        part compensation : CompensationFunction;
        part estimator : GravityEstimator;
        part qualityMonitor : QualityMonitor;
    }

    port def CalibrationPort {
        in item calibration : CalibrationData;
        out item calibration : CalibrationData;
    }

    item def CalibrationData {
        attribute scaleFactor : Real;
        attribute bias : Acceleration_mps2;
        attribute temperatureCoefficient : Acceleration_mps2;
        attribute tiltCoefficient : Acceleration_mps2;
        attribute calibrationTime : Time_s;
        attribute valid : Boolean;
    }

    part def AcquisitionFunction {
        attribute inputSampleRate : Frequency_Hz = 200.0;
        attribute outputSampleRate : Frequency_Hz = 1.0;
        attribute antiAliasCutoff : Frequency_Hz = 50.0;
    }

    part def CompensationFunction {
        attribute appliesTemperatureCorrection : Boolean = true;
        attribute appliesTiltCorrection : Boolean = true;
        attribute appliesBarometricCorrection : Boolean = true;
        attribute appliesBiasCorrection : Boolean = true;
    }

    part def GravityEstimator {
        attribute estimatorType : String = "averaged compensated acceleration with uncertainty propagation";
        attribute nominalIntegrationTime : Time_s = 60.0;
        attribute minimumSamplesForReport : Integer = 30;
    }

    part def QualityMonitor {
        attribute maximumVibrationRms : Acceleration_mps2 = 0.0005;
        attribute maximumVerticalityError : Angle_rad = 0.0002;
        attribute maximumTemperatureDeviation : Temperature_degC = 0.1;
    }

    part def CalibrationManager {
        attribute calibrationInterval : Time_s = 2592000.0;
        attribute currentScaleFactor : Real = 1.0;
        attribute currentBias : Acceleration_mps2 = 0.0;
        attribute currentTemperatureCoefficient : Acceleration_mps2 = 0.000001;
        attribute currentTiltCoefficient : Acceleration_mps2 = 9.80665;

        port powerIn : RegulatedPowerPort;
        port correctedSampleIn : CorrectedSamplePort;
        port calibrationOut : CalibrationPort;
    }

    part def DataLogger {
        attribute storageCapacity : Real = 32000000000.0;
        attribute retainedReports : Integer = 1000000;
        attribute loggingEnabled : Boolean = true;

        port powerIn : RegulatedPowerPort;
        port reportIn : GravityReportPort;
        port telemetryIn : TelemetryPort;
    }

    part def UserInterface {
        attribute displayRefreshRate : Frequency_Hz = 2.0;
        attribute audibleAlarmEnabled : Boolean = true;

        port powerIn : RegulatedPowerPort;
        port operatorInterface : OperatorInterfacePort;
        port commandOut : CommandPort;
        port reportIn : GravityReportPort;
        port telemetryIn : TelemetryPort;
    }

    part def CommunicationsAdapter {
        attribute protocol : String = "USB-C and Ethernet gravimetry telemetry service";
        attribute maximumDataRate : DataRate_bps = 100000000.0;

        port powerIn : RegulatedPowerPort;
        port reportIn : GravityReportPort;
        port telemetryIn : TelemetryPort;
    }

    action def AcquireRawGravitySample {
        in item timeReference : TimeReference;
        in item environmentalData : EnvironmentalData;
        in item attitudeData : AttitudeData;
        out item gravitySample : GravitySample;

        first start;
        then readProofMassDisplacement;
        then convertDisplacementToAcceleration;
        then attachTemperatureAndTilt;
        then publishRawSample;
    }

    action def CompensateGravitySample {
        in item rawSample : GravitySample;
        in item environmentalData : EnvironmentalData;
        in item attitudeData : AttitudeData;
        in item calibration : CalibrationData;
        out item correctedSample : CorrectedGravitySample;

        first receiveSample;
        then removeSensorBias;
        then applyScaleFactor;
        then applyTemperatureCorrection;
        then applyTiltCorrection;
        then applyBarometricCorrection;
        then estimateSampleUncertainty;
        then publishCorrectedSample;
    }

    action def EstimateLocalGravity {
        in item correctedSample : CorrectedGravitySample;
        in item command : ControlCommand;
        out item gravityReport : GravityReport;

        first initializeAccumulator;
        then collectCorrectedSamples;
        then rejectOutliers;
        then computeAverageGravity;
        then computeStandardDeviation;
        then assignMeasurementQuality;
        then publishGravityReport;
    }

    action def PerformSelfTest {
        in item command : ControlCommand;
        out item telemetry : HealthTelemetry;

        first verifyPowerRails;
        then verifySensorReadout;
        then verifyTemperatureControl;
        then verifyLevelingActuators;
        then verifyMemoryAndCommunications;
        then publishHealthStatus;
    }

    action def LevelInstrument {
        in item attitudeData : AttitudeData;
        out item leveledAttitude : AttitudeData;

        first readTilt;
        then computeFootCorrections;
        then moveLevelingFeet;
        then waitForSettling;
        then confirmVerticality;
    }

    action def HighLevelGravimeterFunction {
        in item operatorCommand : ControlCommand;
        in item electricalPower : ElectricalPower;
        out item gravityReport : GravityReport;
        out item telemetry : HealthTelemetry;

        first powerAndWarmElectronics;
        then stabilizeSensorTemperature;
        then levelMeasurementAxis;
        then acquireInertialSamples;
        then compensateSamplesForBiasTiltTemperatureAndEnvironment;
        then estimateAverageLocalGravity;
        then reportQualifiedGravityValue;
    }

    state def GravimeterOperationalStateMachine {
        attribute currentMode : GravimeterMode;

        entry action initializeTelemetry;

        state Off {
            entry action disableSensorAndHeaters;
        }

        state Standby {
            entry action energizeControllerOnly;
            do action monitorCommands;
        }

        state Warmup {
            entry action enableThermalControl;
            do action stabilizeSensorHeadTemperature;
            exit action confirmThermalStability;
        }

        state SelfTest {
            do action PerformSelfTest;
        }

        state Leveling {
            do action LevelInstrument;
        }

        state Calibrating {
            do action updateBiasAndScaleFactor;
        }

        state Measuring {
            entry action resetGravityAccumulator;
            do action HighLevelGravimeterFunction;
            exit action freezeLastMeasurement;
        }

        state Reporting {
            do action transmitGravityReport;
        }

        state Fault {
            entry action setHealthFailed;
            do action preserveFaultLog;
        }

        transition initialToOff first Off;
        transition powerApplied Off to Standby;
        transition warmupRequested Standby to Warmup;
        transition selfTestRequested Standby to SelfTest;
        transition selfTestPassed SelfTest to Leveling;
        transition warmupComplete Warmup to Leveling;
        transition levelingComplete Leveling to Measuring;
        transition calibrationRequested Standby to Calibrating;
        transition calibrationComplete Calibrating to Standby;
        transition measurementComplete Measuring to Reporting;
        transition reportDelivered Reporting to Measuring;
        transition stopRequested Measuring to Standby;
        transition standbyRequested Reporting to Standby;
        transition recoverableFault Fault to Standby;
        transition unrecoverableFault Off to Fault;
        transition faultDuringWarmup Warmup to Fault;
        transition faultDuringLeveling Leveling to Fault;
        transition faultDuringMeasurement Measuring to Fault;
    }

    requirement def PrimaryFunctionRequirement {
        subject gravimeter : Gravimeter;

        doc /* The gravimeter shall provide the high-level primary function of measuring local gravitational acceleration at its installation point and reporting a qualified gravity value to the operator or host system. */

        require constraint {
            gravimeter.primaryFunction == "Estimate and report local gravitational acceleration by sensing inertial acceleration, rejecting environmental disturbances, applying calibration and compensation corrections, and delivering a qualified gravity measurement to an operator or host system."
        }
    }

    requirement def MeasurementRangeRequirement {
        subject gravimeter : Gravimeter;

        doc /* The gravimeter shall measure local gravitational acceleration over the expected terrestrial operating range. */

        require constraint {
            gravimeter.nominalGravityRangeMin <= 9.70 and gravimeter.nominalGravityRangeMax >= 9.90
        }
    }

    requirement def AccuracyRequirement {
        subject gravimeter : Gravimeter;

        doc /* The gravimeter shall provide survey-grade gravity reports with one-sigma uncertainty no greater than 10 micro meters per second squared after the commanded integration interval under nominal environmental conditions. */

        require constraint {
            gravimeter.targetAccuracy <= 0.000010
        }
    }

    requirement def ResolutionRequirement {
        subject gravimeter : Gravimeter;

        doc /* The gravimeter shall resolve changes in local gravitational acceleration of at least 1 micro meter per second squared. */

        require constraint {
            gravimeter.targetResolution <= 0.000001
        }
    }

    requirement def ThermalStabilityRequirement {
        subject gravimeter : Gravimeter;

        doc /* The gravimeter shall stabilize the sensor head temperature before issuing high-quality gravity reports. */

        require constraint {
            gravimeter.thermalControl.stability <= 0.02
        }
    }

    requirement def LevelingRequirement {
        subject gravimeter : Gravimeter;

        doc /* The gravimeter shall align its sensitive measurement axis with the local vertical to limit tilt-induced gravity error. */

        require constraint {
            gravimeter.levelingSubsystem.levelingAccuracy <= 0.00005
        }
    }

    requirement def DataReportingRequirement {
        subject gravimeter : Gravimeter;

        doc /* The gravimeter shall output each gravity report with average gravity, uncertainty, sample count, averaging period, quality, and health status. */

        require constraint {
            gravimeter.signalProcessor.estimator.minimumSamplesForReport >= 30
        }
    }

    requirement def PowerRequirement {
        subject gravimeter : Gravimeter;

        doc /* The gravimeter shall operate from a portable low-voltage electrical source and internally condition power for all measurement functions. */

        require constraint {
            gravimeter.powerSubsystem.inputVoltageMin <= 12.0 and gravimeter.powerSubsystem.inputVoltageMax >= 24.0 and gravimeter.powerSubsystem.maximumOutputPower >= 60.0
        }
    }

    requirement def EnvironmentalOperatingRequirement {
        subject gravimeter : Gravimeter;

        doc /* The gravimeter shall operate within the specified ambient temperature range while maintaining measurement performance after warmup. */

        require constraint {
            gravimeter.operatingTemperatureMin <= -10.0 and gravimeter.operatingTemperatureMax >= 45.0
        }
    }

    satisfy PrimaryFunctionRequirement by Gravimeter;
    satisfy MeasurementRangeRequirement by Gravimeter;
    satisfy AccuracyRequirement by Gravimeter;
    satisfy ResolutionRequirement by Gravimeter;
    satisfy ThermalStabilityRequirement by ThermalControlUnit;
    satisfy LevelingRequirement by LevelingSubsystem;
    satisfy DataReportingRequirement by SignalProcessor;
    satisfy PowerRequirement by PowerSubsystem;
    satisfy EnvironmentalOperatingRequirement by Gravimeter;

    part gravimeterSystem : Gravimeter {
        attribute primaryFunction = "Estimate and report local gravitational acceleration by sensing inertial acceleration, rejecting environmental disturbances, applying calibration and compensation corrections, and delivering a qualified gravity measurement to an operator or host system.";
        attribute measurementRate = 1.0;
        attribute targetResolution = 0.000001;
        attribute targetAccuracy = 0.000010;
    }

}
