package DigitalScoliometer {
    private import ScalarValues::*;
    private import ISQ::AngleValue;
    private import ISQ::VoltageValue;
    private import ISQ::EnergyValue;
    private import SI::*;
    private import Time::TimeInstantValue;

    package Definitions {
        enum def SeverityLevel {
            normal;
            monitor;
            refer;
        }

        enum def PatientPosition {
            standing;
            forwardBend;
            seated;
        }

        enum def VertebralLevel {
            C7;
            T1;
            T3;
            T5;
            T7;
            T9;
            T11;
            T12;
            L1;
            L3;
            L5;
        }

        item def RawAngleSignal {
            attribute angle : AngleValue;
        }

        item def ProcessedATRData {
            attribute atr : AngleValue;
            attribute severity : SeverityLevel;
        }

        item def MeasurementRecord {
            attribute atr : AngleValue;
            attribute timestamp : TimeInstantValue;
            attribute vertebralLevel : VertebralLevel;
            attribute patientPosition : PatientPosition;
            attribute severity : SeverityLevel;
        }

        item def PowerSignal {
            attribute voltage : VoltageValue;
        }

        attribute def PowerOnSignal;
        attribute def StartMeasurementSignal;
        attribute def AcknowledgeResultSignal;
        attribute def ShutdownSignal;

        action def InitializeSystem;

        action def MeasureAngle {
            out rawAngle : AngleValue;
        }

        action def ProcessData {
            in rawAngle : AngleValue;
            in calibrationOffset : AngleValue;
            out atr : AngleValue;
        }

        action def ClassifySeverity {
            in atr : AngleValue;
            in normalThreshold : AngleValue;
            in monitorThreshold : AngleValue;
            out severity : SeverityLevel;
        }

        action def DisplayResult {
            in atr : AngleValue;
            in severity : SeverityLevel;
        }

        action def LogMeasurement {
            in record : MeasurementRecord;
        }

        part def InclinometerSensor {
            port out rawAngleOut : RawAngleSignal;
            port in powerIn : PowerSignal;
            perform action measure : MeasureAngle;
        }

        part def SignalProcessor {
            attribute calibrationOffset : AngleValue := 0.0 [deg];
            attribute normalThreshold : AngleValue := 5.0 [deg];
            attribute monitorThreshold : AngleValue := 7.0 [deg];
            port in rawAngleIn : RawAngleSignal;
            port out atrOut : ProcessedATRData;
            port out recordOut : MeasurementRecord;
            port in powerIn : PowerSignal;
            perform action process : ProcessData;
            perform action classify : ClassifySeverity;
        }

        part def DigitalDisplay {
            port in dataIn : ProcessedATRData;
            port in powerIn : PowerSignal;
            perform action update : DisplayResult;
        }

        part def DataLogger {
            attribute history : MeasurementRecord[*];
            port in recordIn : MeasurementRecord;
            port in powerIn : PowerSignal;
            perform action log : LogMeasurement;
        }

        part def Battery {
            attribute chargeLevel : Real := 1.0;
            attribute capacity : EnergyValue := 10 [Wh];
            port out sensorPowerOut : PowerSignal;
            port out processorPowerOut : PowerSignal;
            port out displayPowerOut : PowerSignal;
            port out loggerPowerOut : PowerSignal;
        }

        part def ScoliometerDevice {
            part inclinometer : InclinometerSensor;
            part processor : SignalProcessor;
            part display : DigitalDisplay;
            part logger : DataLogger;
            part battery : Battery;

            connect inclinometer.rawAngleOut to processor.rawAngleIn;
            connect processor.atrOut to display.dataIn;
            connect processor.recordOut to logger.recordIn;
            connect battery.sensorPowerOut to inclinometer.powerIn;
            connect battery.processorPowerOut to processor.powerIn;
            connect battery.displayPowerOut to display.powerIn;
            connect battery.loggerPowerOut to logger.powerIn;

            attribute currentVertebralLevel : VertebralLevel := VertebralLevel::T7;
            attribute currentPatientPosition : PatientPosition := PatientPosition::forwardBend;
            attribute currentTimestamp : TimeInstantValue;
            attribute currentATR : AngleValue;
            attribute currentSeverity : SeverityLevel;
            attribute currentRawAngle : AngleValue;

            perform action 'initialize system' : InitializeSystem;
            exhibit state 'device states' : 'Device States';
        }

        state def 'Device States';
    }

    package Usages {
        private import Definitions::*;

        action 'initialize system' : InitializeSystem;
        action 'measure angle' : MeasureAngle;
        action 'process data' : ProcessData;
        action 'classify severity' : ClassifySeverity;
        action 'display result' : DisplayResult;
        action 'log measurement' : LogMeasurement;

        part device : ScoliometerDevice;

        state 'device states' : 'Device States' {
            entry; then off;

            state off;
            accept PowerOnSignal
                then initializing;

            state initializing {
                do 'initialize system';
            }
            then ready;

            state ready;
            accept StartMeasurementSignal
                then measuring;
            accept ShutdownSignal
                then off;

            state measuring {
                do 'measure angle';
            }
            then processing;

            state processing {
                do 'process data';
                do 'classify severity';
                do 'log measurement';
            }
            then displaying;

            state displaying {
                do 'display result';
            }
            accept AcknowledgeResultSignal
                then ready;
            accept ShutdownSignal
                then off;
        }

        requirement def 'Measurement Accuracy Requirement' {
            doc /* The digital scoliometer shall measure the Angle of Trunk Rotation (ATR) with an accuracy of at least +/- 1 degree during a forward bend test. */
            subject device : ScoliometerDevice;
        }

        requirement def 'Severity Classification Requirement' {
            doc /* The device shall classify ATR measurements as normal (below 5 deg), monitor (5-7 deg), or refer (above 7 deg) based on predefined clinical thresholds. */
            subject processor : SignalProcessor;
        }

        requirement def 'Data Logging Requirement' {
            doc /* The data logger shall store each measurement record including ATR, timestamp, vertebral level, patient position, and severity classification. */
            subject logger : DataLogger;
        }

        requirement def 'Portability Requirement' {
            doc /* The device shall be powered by an internal battery suitable for portable clinical use with a minimum capacity of 10 watt-hours. */
            subject battery : Battery;
        }

        requirement def 'Workflow Requirement' {
            doc /* The device shall follow a workflow from ready through measuring, processing, and displaying, returning to ready after result acknowledgement. */
            subject device : ScoliometerDevice;
        }

        requirement 'Measurement Accuracy Req' : 'Measurement Accuracy Requirement' {
            subject device = Usages::device;
        }

        requirement 'Severity Classification Req' : 'Severity Classification Requirement' {
            subject processor = Usages::device.processor;
        }

        requirement 'Data Logging Req' : 'Data Logging Requirement' {
            subject logger = Usages::device.logger;
        }

        requirement 'Portability Req' : 'Portability Requirement' {
            subject battery = Usages::device.battery;
        }

        requirement 'Workflow Req' : 'Workflow Requirement' {
            subject device = Usages::device;
        }
    }
}
