package GasDetectorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    package Definitions {
        attribute def GasConcentration :> Real;
        attribute def Voltage :> Real;

        enum def AlarmLevel {
            none;
            warning;
            danger;
            critical;
        }

        item def RawSensorReading {
            attribute concentration : GasConcentration;
            attribute timestamp : Time::DateTime;
        }
        item def ProcessedReading {
            attribute concentration : GasConcentration;
            attribute timestamp : Time::DateTime;
            attribute isValid : Boolean;
        }
        item def AlarmEvent {
            attribute level : AlarmLevel;
            attribute concentration : GasConcentration;
            attribute timestamp : Time::DateTime;
        }
        item def LogEntry {
            attribute reading : ProcessedReading;
            attribute alarmEvent : AlarmEvent[0..1];
            attribute timestamp : Time::DateTime;
        }
        item def PowerOn;
        item def FaultDetected;
        item def FaultCleared;
        item def SelfTestComplete;
        item def SelfTestFailed;

        port def RawDataPort {
            out reading : RawSensorReading;
        }
        port def ProcessedDataPort {
            out reading : ProcessedReading;
        }
        port def AlarmPort {
            out alarmEvent : AlarmEvent;
        }
        port def LogPort {
            out logEntry : LogEntry;
        }
        port def PowerPort {
            in inputVoltage : Voltage;
            out outputVoltage : Voltage;
        }
        port def GasInputPort {
            in ambientConcentration : GasConcentration;
        }

        action def SenseGas {
            in ambientConcentration : GasConcentration;
            out reading : RawSensorReading;
        }
        action def ValidateReading {
            in reading : RawSensorReading;
            out isValid : Boolean;
        }
        action def FilterNoise {
            in reading : RawSensorReading;
            out filtered : RawSensorReading;
        }
        action def ApplyCalibration {
            in reading : RawSensorReading;
            out processed : ProcessedReading;
        }
        action def EvaluateThresholds {
            in reading : ProcessedReading;
            out alarmLevel : AlarmLevel;
        }
        action def ActivateVisualAlert;
        action def ActivateAudibleAlert;
        action def DeactivateAlerts;
        action def RecordEntry {
            in logEntry : LogEntry;
        }
        action def CheckCapacity {
            out hasCapacity : Boolean;
        }
        action def ConvertPower {
            in inputVoltage : Voltage;
            out outputVoltage : Voltage;
        }
        action def RunSelfTest {
            out passed : Boolean;
        }

        state def DetectorStates;

        part def ElectrochemicalSensor {
            attribute minRange : GasConcentration = 0.0;
            attribute maxRange : GasConcentration = 500.0;
            attribute responseTime : Real = 30.0;
            port gasInput : GasInputPort;
            port rawDataOut : RawDataPort;
            port powerIn : PowerPort;
            perform senseGas : SenseGas;
        }
        part def SignalProcessor {
            attribute plausibleMin : GasConcentration = 0.0;
            attribute plausibleMax : GasConcentration = 500.0;
            attribute noiseFilterThreshold : GasConcentration = 2.0;
            attribute calibrationOffset : GasConcentration = 0.0;
            port rawDataIn : RawDataPort;
            port processedDataOut : ProcessedDataPort;
            port powerIn : PowerPort;
            perform validateReading : ValidateReading;
            perform filterNoise : FilterNoise;
            perform applyCalibration : ApplyCalibration;
        }
        part def AlarmUnit {
            attribute warningThreshold : GasConcentration = 50.0;
            attribute dangerThreshold : GasConcentration = 100.0;
            attribute criticalThreshold : GasConcentration = 200.0;
            attribute clearThreshold : GasConcentration = 45.0;
            attribute visualAlertActive : Boolean = false;
            attribute audibleAlertActive : Boolean = false;
            attribute currentAlarmLevel : AlarmLevel = AlarmLevel::none;
            port processedDataIn : ProcessedDataPort;
            port alarmOut : AlarmPort;
            port logOut : LogPort;
            port powerIn : PowerPort;
            perform evaluateThresholds : EvaluateThresholds;
            perform activateVisualAlert : ActivateVisualAlert;
            perform activateAudibleAlert : ActivateAudibleAlert;
            perform deactivateAlerts : DeactivateAlerts;
        }
        part def DataLogger {
            attribute maxEntries : Integer = 10000;
            attribute logInterval : Real = 60.0;
            attribute entryCount : Integer = 0;
            port logIn : LogPort;
            port powerIn : PowerPort;
            perform recordEntry : RecordEntry;
            perform checkCapacity : CheckCapacity;
        }
        part def PowerSupply {
            attribute inputVoltageMin : Voltage = 120.0;
            attribute inputVoltageMax : Voltage = 240.0;
            attribute outputVoltage : Voltage = 12.0;
            attribute outputCurrentMax : Real = 5.0;
            port powerIn : PowerPort;
            port powerOut : PowerPort;
            perform convertPower : ConvertPower;
        }
        part def GasDetector {
            attribute warningThreshold : GasConcentration = 50.0;
            attribute dangerThreshold : GasConcentration = 100.0;
            attribute criticalThreshold : GasConcentration = 200.0;
            attribute clearThreshold : GasConcentration = 45.0;
            attribute currentConcentration : GasConcentration = 0.0;
            attribute faultCondition : Boolean = false;
            port powerInput : PowerPort;
            port gasInput : GasInputPort;
            part sensor : ElectrochemicalSensor;
            part processor : SignalProcessor;
            part alarmUnit : AlarmUnit;
            part logger : DataLogger;
            part powerSupply : PowerSupply;
            perform runSelfTest : RunSelfTest;
            exhibit state detectorStates : DetectorStates;
        }

        requirement def SensorRangeRequirement {
            subject sensor : ElectrochemicalSensor;
            doc /* The sensor shall detect gas concentrations from 0 to 500 ppm. */
            assume constraint {
                sensor.minRange == 0.0 and sensor.maxRange == 500.0
            }
        }
        requirement def SensorResponseTimeRequirement {
            subject sensor : ElectrochemicalSensor;
            doc /* The sensor shall respond to concentration changes within 30 seconds. */
            assume constraint {
                sensor.responseTime <= 30.0
            }
        }
        requirement def WarningThresholdRequirement {
            subject alarmUnit : AlarmUnit;
            doc /* A warning shall be triggered at 50 ppm with a visual alert. */
            assume constraint {
                alarmUnit.warningThreshold == 50.0
            }
        }
        requirement def DangerThresholdRequirement {
            subject alarmUnit : AlarmUnit;
            doc /* A danger alarm shall be triggered at 100 ppm with audible and visual alerts. */
            assume constraint {
                alarmUnit.dangerThreshold == 100.0
            }
        }
        requirement def CriticalThresholdRequirement {
            subject alarmUnit : AlarmUnit;
            doc /* A critical alarm shall be triggered at 200 ppm with audible and visual alerts. */
            assume constraint {
                alarmUnit.criticalThreshold == 200.0
            }
        }
        requirement def LoggerCapacityRequirement {
            subject logger : DataLogger;
            doc /* The data logger shall record up to 10,000 readings and alarm events. */
            assume constraint {
                logger.maxEntries == 10000
            }
        }
        requirement def LoggerIntervalRequirement {
            subject logger : DataLogger;
            doc /* The data logger shall record at one-minute intervals. */
            assume constraint {
                logger.logInterval == 60.0
            }
        }
        requirement def PowerSupplyRequirement {
            subject powerSupply : PowerSupply;
            doc /* The power supply shall convert higher input voltage to stable lower output voltage. */
            assume constraint {
                powerSupply.outputVoltage == 12.0 and
                powerSupply.inputVoltageMin >= 120.0
            }
        }
        requirement def StateLifecycleRequirement {
            subject detector : GasDetector;
            doc /* The system shall initialize, monitor, alarm, and enter fault states appropriately. */
        }
    }

    package Usages {
        private import Definitions::*;

        part gasDetector : GasDetector {
            part powerSupply : PowerSupply {
                perform convertPower : ConvertPower;
            }
            part sensor : ElectrochemicalSensor {
                perform senseGas : SenseGas;
            }
            part processor : SignalProcessor {
                perform validateReading : ValidateReading;
                perform filterNoise : FilterNoise;
                perform applyCalibration : ApplyCalibration;
            }
            part alarmUnit : AlarmUnit {
                perform evaluateThresholds : EvaluateThresholds;
                perform activateVisualAlert : ActivateVisualAlert;
                perform activateAudibleAlert : ActivateAudibleAlert;
                perform deactivateAlerts : DeactivateAlerts;
            }
            part logger : DataLogger {
                perform recordEntry : RecordEntry;
                perform checkCapacity : CheckCapacity;
            }

            connect powerSupply.powerOut to sensor.powerIn;
            connect powerSupply.powerOut to processor.powerIn;
            connect powerSupply.powerOut to alarmUnit.powerIn;
            connect powerSupply.powerOut to logger.powerIn;

            connect sensor.rawDataOut to processor.rawDataIn;
            connect processor.processedDataOut to alarmUnit.processedDataIn;
            connect alarmUnit.logOut to logger.logIn;

            connect gasInput to sensor.gasInput;

            state detectorStates : DetectorStates {
                entry; then initializing;

                state initializing {
                    do runSelfTest;
                }
                accept SelfTestComplete
                    then monitoring;
                accept SelfTestFailed
                    then fault;

                state monitoring {
                    do sensor.senseGas;
                    do processor.validateReading;
                    do processor.filterNoise;
                    do processor.applyCalibration;
                    do alarmUnit.evaluateThresholds;
                    do logger.recordEntry;
                }
                accept when currentConcentration > warningThreshold
                    then alarming;
                accept FaultDetected
                    then fault;

                state alarming {
                    entry alarmUnit.activateVisualAlert;
                    do alarmUnit.evaluateThresholds;
                    do logger.recordEntry;
                }
                accept when currentConcentration > dangerThreshold
                    then dangerAlarm;
                accept when currentConcentration < clearThreshold
                    then monitoring;
                accept FaultDetected
                    then fault;

                state dangerAlarm {
                    entry alarmUnit.activateAudibleAlert;
                    do alarmUnit.evaluateThresholds;
                    do logger.recordEntry;
                }
                accept when currentConcentration > criticalThreshold
                    then criticalAlarm;
                accept when currentConcentration < warningThreshold
                    then alarming;
                accept when currentConcentration < clearThreshold
                    then monitoring;
                accept FaultDetected
                    then fault;

                state criticalAlarm {
                    entry alarmUnit.activateAudibleAlert;
                    do alarmUnit.evaluateThresholds;
                    do logger.recordEntry;
                }
                accept when currentConcentration < dangerThreshold
                    then dangerAlarm;
                accept when currentConcentration < clearThreshold
                    then monitoring;
                accept FaultDetected
                    then fault;

                state fault {
                    entry assign faultCondition := true;
                }
                accept FaultCleared
                    do assign faultCondition := false
                    then initializing;
            }
        }

        verify sensorRangeReq : SensorRangeRequirement by gasDetector.sensor;
        verify sensorResponseReq : SensorResponseTimeRequirement by gasDetector.sensor;
        verify warningReq : WarningThresholdRequirement by gasDetector.alarmUnit;
        verify dangerReq : DangerThresholdRequirement by gasDetector.alarmUnit;
        verify criticalReq : CriticalThresholdRequirement by gasDetector.alarmUnit;
        verify loggerCapacityReq : LoggerCapacityRequirement by gasDetector.logger;
        verify loggerIntervalReq : LoggerIntervalRequirement by gasDetector.logger;
        verify powerSupplyReq : PowerSupplyRequirement by gasDetector.powerSupply;
        verify stateLifecycleReq : StateLifecycleRequirement by gasDetector;
    }
}
