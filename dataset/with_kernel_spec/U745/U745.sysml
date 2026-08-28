package LeafMoistureSensingUnit {
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def CapacitanceValue :> ScalarValues::Real;
    attribute def TemperatureValue :> ScalarValues::Real;
    attribute def VoltageValue :> ScalarValues::Real;
    attribute def DurationValue :> ScalarValues::Real;
    attribute def MoistureValue :> ScalarValues::Real;
    attribute def QualityValue :> ScalarValues::Real;

    item def RawSensorData {
        attribute capacitance : CapacitanceValue;
        attribute temperature : TemperatureValue;
    }
    item def ConditionedData {
        attribute capacitance : CapacitanceValue;
        attribute temperature : TemperatureValue;
    }
    item def MoistureReading {
        attribute moisturePercent : MoistureValue;
        attribute quality : QualityValue;
    }
    item def CalibrationParameters {
        attribute dryReference : CapacitanceValue;
        attribute wetReference : CapacitanceValue;
        attribute temperatureCoefficient : ScalarValues::Real;
    }
    item def JsonMessage {
        attribute payload : ScalarValues::String;
    }

    attribute def MeasureCommand;
    attribute def MeasurementComplete;
    attribute def CalibrateCommand;
    attribute def CalibrationComplete;
    attribute def FaultDetected;
    attribute def ResetCommand;

    port def RawDataPort {
        out item rawSensorData : RawSensorData;
    }
    port def ConditionedDataPort {
        out item conditionedData : ConditionedData;
    }
    port def MoistureDataPort {
        out item moistureReading : MoistureReading;
    }
    port def CalibrationPort {
        out item calibrationParameters : CalibrationParameters;
    }
    port def OutputDataPort {
        out item jsonMessage : JsonMessage;
    }
    port def PowerPort {
        attribute supplyVoltage : VoltageValue;
    }
    port def ControlPort {
        attribute command : ScalarValues::String;
        attribute status : ScalarValues::String;
    }

    action def MeasureRawData {
        out item rawSensorData : RawSensorData;
    }
    action def ConditionSignal {
        in item rawSensorData : RawSensorData;
        out item conditionedData : ConditionedData;
    }
    action def ProcessMoisture {
        in item conditionedData : ConditionedData;
        in item calibrationParameters : CalibrationParameters;
        out item moistureReading : MoistureReading;
    }
    action def FormatOutput {
        in item moistureReading : MoistureReading;
        out item jsonMessage : JsonMessage;
    }
    action def PerformRecalibration {
        in item oldParameters : CalibrationParameters;
        out item newParameters : CalibrationParameters;
    }
    action def Initialize;
    action def RunDiagnostics;
    action def PerformMeasurementSequence {
        in item rawSensorData : RawSensorData;
        in item calibrationParameters : CalibrationParameters;
        out item jsonMessage : JsonMessage;
        action measureRawData : MeasureRawData;
        action conditionSignal : ConditionSignal;
        action processMoisture : ProcessMoisture;
        action formatOutput : FormatOutput;
        flow measureRawData.rawSensorData to conditionSignal.rawSensorData;
        flow conditionSignal.conditionedData to processMoisture.conditionedData;
        flow processMoisture.moistureReading to formatOutput.moistureReading;
    }

    state def SensingUnitStates {
        entry; then Initialization;
        state Initialization;
        transition init_to_ready
            first Initialization
            then Ready;
        state Ready;
        transition ready_to_measuring
            first Ready
            accept MeasureCommand
            then ActiveMeasuring;
        state ActiveMeasuring {
            do action performMeasurement : PerformMeasurementSequence;
        }
        transition measuring_to_ready
            first ActiveMeasuring
            accept MeasurementComplete
            then Ready;
        transition ready_to_calibrating
            first Ready
            accept CalibrateCommand
            then CalibrationMode;
        state CalibrationMode {
            do action performRecalibration : PerformRecalibration;
        }
        transition calibrating_to_ready
            first CalibrationMode
            accept CalibrationComplete
            then Ready;
        transition ready_to_error
            first Ready
            accept FaultDetected
            then ErrorState;
        transition measuring_to_error
            first ActiveMeasuring
            accept FaultDetected
            then ErrorState;
        state ErrorState;
        transition error_to_ready
            first ErrorState
            accept ResetCommand
            then Ready;
    }

    part def LeafSensor {
        port rawOut : RawDataPort;
        port powerIn : PowerPort;
        perform action measureRawData : MeasureRawData;
    }
    part def SignalConditioner {
        port rawIn : ~RawDataPort;
        port conditionedOut : ConditionedDataPort;
        port powerIn : PowerPort;
        perform action conditionSignal : ConditionSignal;
    }
    part def DataProcessor {
        port conditionedIn : ~ConditionedDataPort;
        port moistureOut : MoistureDataPort;
        port calibrationIn : ~CalibrationPort;
        port powerIn : PowerPort;
        ref item storedCalibration : CalibrationParameters;
        perform action processMoisture : ProcessMoisture;
    }
    part def CalibrationManager {
        port calibrationOut : CalibrationPort;
        port powerIn : PowerPort;
        ref item storedParameters : CalibrationParameters;
        attribute daysSinceLastCalibration : ScalarValues::Integer;
        attribute supportsFieldRecalibration : ScalarValues::Boolean = true;
        perform action performRecalibration : PerformRecalibration;
    }
    part def OutputInterface {
        port moistureIn : ~MoistureDataPort;
        port outputOut : OutputDataPort;
        port powerIn : PowerPort;
        perform action formatOutput : FormatOutput;
    }
    part def SensingUnit {
        attribute operatingTemperature : TemperatureValue;
        attribute supplyVoltage : VoltageValue;
        attribute responseTime : DurationValue;
        attribute measuredMoisture : MoistureValue;
        attribute actualMoisture : MoistureValue;

        port powerIn : PowerPort;
        port controlPort : ControlPort;
        port outputPort : ~OutputDataPort;

        exhibit state unitStates : SensingUnitStates;
        perform action initialize : Initialize;
        perform action runDiagnostics : RunDiagnostics;

        part leafSensor : LeafSensor;
        part signalConditioner : SignalConditioner;
        part dataProcessor : DataProcessor;
        part calibrationManager : CalibrationManager;
        part outputInterface : OutputInterface;

        connect leafSensor.rawOut to signalConditioner.rawIn;
        connect signalConditioner.conditionedOut to dataProcessor.conditionedIn;
        connect dataProcessor.moistureOut to outputInterface.moistureIn;
        connect outputInterface.outputOut to outputPort;
        connect calibrationManager.calibrationOut to dataProcessor.calibrationIn;
        connect powerIn to leafSensor.powerIn;
        connect powerIn to signalConditioner.powerIn;
        connect powerIn to dataProcessor.powerIn;
        connect powerIn to calibrationManager.powerIn;
        connect powerIn to outputInterface.powerIn;
    }

    requirement def AccuracyRequirement {
        attribute maxError : MoistureValue = 2.0;
        subject sensingUnit : SensingUnit;
        constraint {
            sensingUnit.measuredMoisture - sensingUnit.actualMoisture <= maxError and
            sensingUnit.actualMoisture - sensingUnit.measuredMoisture <= maxError
        }
    }
    requirement def ResponseTimeRequirement {
        attribute maxResponseTime : DurationValue = 500;
        subject sensingUnit : SensingUnit;
        constraint {
            sensingUnit.responseTime <= maxResponseTime
        }
    }
    requirement def OperatingTemperatureRequirement {
        attribute minTemp : TemperatureValue = -20;
        attribute maxTemp : TemperatureValue = 85;
        subject sensingUnit : SensingUnit;
        constraint {
            sensingUnit.operatingTemperature >= minTemp and
            sensingUnit.operatingTemperature <= maxTemp
        }
    }
    requirement def PowerSupplyRequirement {
        attribute minVoltage : VoltageValue = 3.3;
        attribute maxVoltage : VoltageValue = 5.0;
        subject sensingUnit : SensingUnit;
        constraint {
            sensingUnit.supplyVoltage >= minVoltage and
            sensingUnit.supplyVoltage <= maxVoltage
        }
    }
    requirement def CalibrationRetentionRequirement {
        attribute maxRetentionDays : ScalarValues::Integer = 30;
        subject sensingUnit : SensingUnit;
        constraint {
            sensingUnit.calibrationManager.daysSinceLastCalibration <= maxRetentionDays
        }
    }
    requirement def FieldRecalibrationRequirement {
        subject sensingUnit : SensingUnit;
        constraint {
            sensingUnit.calibrationManager.supportsFieldRecalibration == true
        }
    }

    part sensingUnit : SensingUnit;

    requirement accuracyReq : AccuracyRequirement;
    requirement responseTimeReq : ResponseTimeRequirement;
    requirement operatingTempReq : OperatingTemperatureRequirement;
    requirement powerSupplyReq : PowerSupplyRequirement;
    requirement calibrationRetentionReq : CalibrationRetentionRequirement;
    requirement fieldRecalibrationReq : FieldRecalibrationRequirement;

    satisfy accuracyReq by sensingUnit;
    satisfy responseTimeReq by sensingUnit;
    satisfy operatingTempReq by sensingUnit;
    satisfy powerSupplyReq by sensingUnit;
    satisfy calibrationRetentionReq by sensingUnit;
    satisfy fieldRecalibrationReq by sensingUnit;
}
