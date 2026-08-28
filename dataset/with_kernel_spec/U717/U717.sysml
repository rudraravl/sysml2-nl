package DigitalHygrometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import Time::*;

    package Definitions {
        attribute def RelativeHumidityValue :> Real;
        attribute def AnalogVoltageValue :> Real;

        attribute def SensorStatus {
            attribute code : Integer;
            attribute statusText : String;
        }

        attribute def DisplayMode;
        attribute def HumidityOnly :> DisplayMode;
        attribute def TemperatureOnly :> DisplayMode;
        attribute def Combined :> DisplayMode;
        attribute def TrendGraph :> DisplayMode;

        attribute def CalibrationData {
            attribute humidityCorrectionFactor : Real := 1.0;
            attribute humidityOffset : RelativeHumidityValue := 0;
            attribute temperatureOffset : Real := 0;
        }

        item def DataReading {
            attribute humidity : RelativeHumidityValue;
            attribute temperature : TemperatureValue;
            attribute timestamp : DateTime;
            attribute status : SensorStatus;
        }

        attribute def ModeSelectSignal;
        attribute def PowerOnSignal;
        attribute def PowerOffSignal;
        attribute def StartMeasurementSignal;
        attribute def StartCalibrationSignal;
        attribute def CalibrationCompleteSignal;
        attribute def ErrorDetectedSignal;
        attribute def ErrorResolvedSignal;
        attribute def InitComplete;

        action def SenseHumidity {
            out rawVoltage : AnalogVoltageValue;
        }
        action def SenseTemperature {
            out temp : TemperatureValue;
        }
        action def ProcessSignals {
            in rawVoltage : AnalogVoltageValue;
            in temp : TemperatureValue;
            in calibration : CalibrationData;
            out reading : DataReading;
        }
        action def DisplayReading {
            in reading : DataReading;
        }
        action def LogReading {
            in reading : DataReading;
        }
        action def CalibrateSensors {
            out calibration : CalibrationData;
        }

        part def HumiditySensor {
            in powerIn : AnalogVoltageValue;
            out rawHumiditySignal : AnalogVoltageValue;
            perform action sense : SenseHumidity;
            attribute status : SensorStatus;
        }
        part def TemperatureSensor {
            in powerIn : AnalogVoltageValue;
            out tempSignal : TemperatureValue;
            perform action sense : SenseTemperature;
            attribute status : SensorStatus;
        }
        part def SignalProcessor {
            in powerIn : AnalogVoltageValue;
            in rawHumidityIn : AnalogVoltageValue;
            in tempIn : TemperatureValue;
            out readingOut : DataReading;
            attribute calibration : CalibrationData;
            perform action process : ProcessSignals;
            perform action calibrate : CalibrateSensors;
        }
        part def DisplayUnit {
            in powerIn : AnalogVoltageValue;
            in readingIn : DataReading;
            attribute currentMode : DisplayMode := Combined;
            perform action display : DisplayReading;
            exhibit state displayStates {
                entry; then combined;
                state combined;
                accept ModeSelectSignal
                    then humidityOnly;
                state humidityOnly;
                accept ModeSelectSignal
                    then temperatureOnly;
                state temperatureOnly;
                accept ModeSelectSignal
                    then trendGraph;
                state trendGraph;
                accept ModeSelectSignal
                    then combined;
            }
        }
        part def DataLogger {
            in powerIn : AnalogVoltageValue;
            in readingIn : DataReading;
            attribute storage : DataReading[0..*];
            perform action log : LogReading;
        }
        part def PowerSupply {
            out powerOut : AnalogVoltageValue;
            attribute active : Boolean := false;
        }

        part def DigitalHygrometer {
            part humiditySensor : HumiditySensor;
            part temperatureSensor : TemperatureSensor;
            part processor : SignalProcessor;
            part display : DisplayUnit;
            part logger : DataLogger;
            part powerSupply : PowerSupply;

            connect powerSupply.powerOut to humiditySensor.powerIn;
            connect powerSupply.powerOut to temperatureSensor.powerIn;
            connect powerSupply.powerOut to processor.powerIn;
            connect powerSupply.powerOut to display.powerIn;
            connect powerSupply.powerOut to logger.powerIn;

            connect humiditySensor.rawHumiditySignal to processor.rawHumidityIn;
            connect temperatureSensor.tempSignal to processor.tempIn;
            connect processor.readingOut to display.readingIn;
            connect processor.readingOut to logger.readingIn;

            exhibit state systemLifecycle {
                entry; then off;
                state off;
                accept PowerOnSignal
                    do assign powerSupply.active := true
                    then initializing;
                state initializing;
                accept InitComplete
                    then ready;
                accept ErrorDetectedSignal
                    then error;
                state ready;
                accept StartMeasurementSignal
                    then measuring;
                accept StartCalibrationSignal
                    then calibrating;
                accept PowerOffSignal
                    do assign powerSupply.active := false
                    then off;
                accept ErrorDetectedSignal
                    then error;
                state measuring;
                accept PowerOffSignal
                    do assign powerSupply.active := false
                    then off;
                accept ErrorDetectedSignal
                    then error;
                state calibrating;
                accept CalibrationCompleteSignal
                    then ready;
                accept ErrorDetectedSignal
                    then error;
                state error;
                accept ErrorResolvedSignal
                    then ready;
                accept PowerOffSignal
                    do assign powerSupply.active := false
                    then off;
            }
        }
    }

    package Requirements {
        private import Definitions::*;

        part hygrometerInstance : DigitalHygrometer;

        requirement def HumidityMeasurementAccuracy {
            subject hygrometer : DigitalHygrometer;
            text "The system shall measure relative humidity with an accuracy of plus or minus 2 percent over the range 0 to 100 percent RH.";
        }
        requirement def TemperatureCompensationReq {
            subject processor : SignalProcessor;
            text "The processor shall compensate humidity readings using temperature data to correct for temperature-induced drift.";
        }
        requirement def ContinuousLoggingReq {
            subject logger : DataLogger;
            text "The data logger shall record measurements at regular configurable intervals.";
        }
        requirement def DisplayModesReq {
            subject display : DisplayUnit;
            text "The display shall support humidity-only, temperature-only, combined, and trend graph modes.";
        }
        requirement def SystemLifecycleReq {
            subject hygrometer : DigitalHygrometer;
            text "The system shall transition through off, initializing, ready, measuring, calibrating, and error states.";
        }

        requirement humidityAccuracy : HumidityMeasurementAccuracy {
            subject = hygrometerInstance;
        }
        requirement tempCompensation : TemperatureCompensationReq {
            subject = hygrometerInstance.processor;
        }
        requirement logging : ContinuousLoggingReq {
            subject = hygrometerInstance.logger;
        }
        requirement displayReq : DisplayModesReq {
            subject = hygrometerInstance.display;
        }
        requirement lifecycle : SystemLifecycleReq {
            subject = hygrometerInstance;
        }
    }
}
