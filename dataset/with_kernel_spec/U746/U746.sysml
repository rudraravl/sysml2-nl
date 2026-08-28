package LevelSensingUnitModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import ISQElectromagnetism::*;
    private import Time::*;

    package Definitions {
        attribute def Trigger;
        attribute def Reset;
        attribute def Calibrate;
        attribute def CalibrationDone;
        attribute def OverRange;
        attribute def PowerOn {
            voltage : ElectricPotentialValue;
        }
        attribute def SensorOutput {
            timeOfFlight : TimeValue;
        }
        attribute def CleanedSignal {
            distance : LengthValue;
        }
        attribute def ProcessedData {
            level : LengthValue;
        }
        attribute def ReadingOutput {
            level : LengthValue;
            timestamp : Time::DateTime;
            validated : Boolean;
        }
        attribute def CalibrationMatrix {
            a : ScalarValues::Real;
            b : ScalarValues::Real;
            c : ScalarValues::Real;
        }

        port def TriggerPort { in trigger : Trigger; }
        port def ResetPort { in reset : Reset; }
        port def CalibratePort { in calibrate : Calibrate; }
        port def SensorOutputPort { out sensorOutput : SensorOutput; }
        port def CleanedSignalPort { out cleanedSignal : CleanedSignal; }
        port def LevelOutputPort { out readingOutput : ReadingOutput; }
        port def TemperaturePort { out temp : TemperatureValue; }
        port def VoltagePort { in voltage : ElectricPotentialValue; }
        port def PowerInPort { in power : PowerOn; }
        port def PowerOutPort { out power : PowerOn; }
        port def OverRangePort { in overRange : OverRange; }

        part def UltrasonicSensor {
            port triggerIn : TriggerPort;
            port sensorOut : SensorOutputPort;
            port powerIn : PowerInPort;
            perform action 'emit pulse and measure' : EmitAndMeasure;
        }

        part def SignalConditioner {
            port signalIn : SensorOutputPort;
            port signalOut : CleanedSignalPort;
            port powerIn : PowerInPort;
            perform action conditionSignal : ConditionSignal;
        }

        part def DataProcessor {
            port dataIn : CleanedSignalPort;
            port levelOut : LevelOutputPort;
            port tempIn : TemperaturePort;
            port powerIn : PowerInPort;
            attribute calibrationMatrix : CalibrationMatrix;
            perform action processData : ProcessData;
        }

        part def TemperatureSensor {
            port tempOut : TemperaturePort;
            port powerIn : PowerInPort;
            perform action senseTemperature : SenseTemperature;
        }

        part def PowerSupply {
            port inputVoltage : VoltagePort;
            port powerOut : PowerOutPort;
            attribute nominalOutput : ElectricPotentialValue;
        }

        part def LevelSensingUnit {
            part sensor : UltrasonicSensor;
            part conditioner : SignalConditioner;
            part processor : DataProcessor;
            part tempSensor : TemperatureSensor;
            part power : PowerSupply;
            port triggerCmd : TriggerPort;
            port resetCmd : ResetPort;
            port calibrateCmd : CalibratePort;
            port levelOutput : LevelOutputPort;
            port mainPower : VoltagePort;
            port overRangeInternal : OverRangePort;
            attribute maxRange : LengthValue;
            attribute calibrated : Boolean = false;
            exhibit state unitStates : UnitStates;
        }

        state def UnitStates;

        action def EmitAndMeasure {
            out sensorOutput : SensorOutput;
        }
        action def ConditionSignal {
            in raw : SensorOutput;
            out cleaned : CleanedSignal;
        }
        action def ProcessData {
            in signal : CleanedSignal;
            in temperature : TemperatureValue;
            in matrix : CalibrationMatrix;
            out result : ProcessedData;
        }
        action def SenseTemperature {
            out temp : TemperatureValue;
        }
        action def PerformSelfTest {
            out success : Boolean;
        }
        action def Initialize;
        action def CalibrateAction;
        action def MeasureLevel {
            out reading : ReadingOutput;
        }

        requirement def MeasurementAccuracy {
            doc "Measurement accuracy shall be within plus or minus 1 mm across the operational range.";
            attribute maxError : LengthValue;
        }
        requirement def MaximumRange {
            doc "The unit shall accurately measure liquid levels up to a maximum range of 10 meters.";
            attribute maxRange : LengthValue;
        }
        requirement def ResponseTime {
            doc "System response time from trigger to valid output shall be less than 1 second.";
            attribute maxResponseTime : TimeValue;
        }
    }

    package Usages {
        private import Definitions::*;

        part levelUnit : LevelSensingUnit {
            connect sensor.sensorOut to conditioner.signalIn;
            connect conditioner.signalOut to processor.dataIn;
            connect tempSensor.tempOut to processor.tempIn;
            connect processor.levelOut to levelOutput;
            connect power.powerOut to sensor.powerIn;
            connect power.powerOut to conditioner.powerIn;
            connect power.powerOut to processor.powerIn;
            connect power.powerOut to tempSensor.powerIn;
            connect mainPower to power.inputVoltage;

            action 'perform self test' : PerformSelfTest;
            action initialize : Initialize;
            action calibrate : CalibrateAction;
            action 'measure level' : MeasureLevel;

            exhibit state unitStates : UnitStates {
                entry; then selfTestInit;

                state selfTestInit {
                    entry 'perform self test';
                }
                transition selfTestInit_to_check first selfTestInit do initialize then calibrationCheck;

                state calibrationCheck;
                transition check_cal_not first calibrationCheck if not calibrated then calibration;
                transition check_cal_yes first calibrationCheck if calibrated then idle;

                state calibration {
                    entry calibrate;
                }
                transition cal_done first calibration accept CalibrationDone then idle;
                transition cal_reset first calibration accept Reset via resetCmd then selfTestInit;

                state idle;
                transition idle_to_meas first idle accept Trigger via triggerCmd do send new Trigger() to sensor.triggerIn then measuring;
                transition idle_to_cal first idle accept Calibrate via calibrateCmd then calibration;
                transition idle_reset first idle accept Reset via resetCmd then selfTestInit;

                state measuring {
                    do 'measure level';
                }
                transition meas_error first measuring accept OverRange via overRangeInternal then error;
                transition meas_reset first measuring accept Reset via resetCmd then selfTestInit;

                state error;
                transition error_reset first error accept Reset via resetCmd then selfTestInit;
            }
        }

        requirement reqAccuracy : MeasurementAccuracy;
        requirement reqRange : MaximumRange;
        requirement reqResponse : ResponseTime;

        satisfy reqAccuracy by levelUnit;
        satisfy reqRange by levelUnit;
        satisfy reqResponse by levelUnit;
    }
}
