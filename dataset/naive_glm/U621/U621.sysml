package BreathalyzerModel {
    import ScalarValues::*;

    // ===== Enumerations =====
    enum def AlarmStatus {
        safe;
        warning;
        violation;
    }

    enum def DeviceState {
        idle;
        ready;
        sampling;
        analyzing;
        complete;
    }

    enum def PowerState {
        poweredOn;
        poweredOff;
        lowBattery;
    }

    // ===== Value Types =====
    value type BACValue :> Real {
        unit 'g/dL';
    }

    value type BreathAlcoholConcentration :> Real {
        unit 'mg/L';
    }

    value type ConversionFactor :> Real {
        unit 'g/dL/(mg/L)';
    }

    value type Sensitivity :> Real {
        unit 'mg/L';
    }

    value type CalibrationValue :> Real {
        unit 'mg/L';
    }

    value type Voltage :> Real {
        unit 'V';
    }

    value type BatteryLevel :> Real {
        unit '%';
    }

    value type TimeDuration :> Real {
        unit 's';
    }

    value type Temperature :> Real {
        unit 'degC';
    }

    value type BreathVolume :> Real {
        unit 'L';
    }

    value type BreathFlowRate :> Real {
        unit 'L/s';
    }

    value type Mass :> Real {
        unit 'g';
    }

    // ===== Item Definitions =====
    item def BreathSample {
        attribute breathAlcoholConcentration : BreathAlcoholConcentration;
        attribute volume : BreathVolume;
        attribute temperature : Temperature;
        attribute timestamp : TimeDuration;
        attribute isValid : Boolean;
    }

    item def AnalysisResult {
        attribute bacValue : BACValue;
        attribute alarmStatus : AlarmStatus;
        attribute legalLimit : BACValue;
        attribute warningThreshold : BACValue;
        attribute timestamp : TimeDuration;
        attribute confidenceLevel : Real;
    }

    item def DisplayMessage {
        attribute bacValue : BACValue;
        attribute alarmStatus : AlarmStatus;
        attribute messageText : String;
        attribute colorCode : String;
        attribute timestamp : TimeDuration;
    }

    item def PowerSignal {
        attribute voltage : Voltage;
        attribute batteryLevel : BatteryLevel;
        attribute powerState : PowerState;
    }

    item def ControlCommand {
        attribute commandType : String;
        attribute timestamp : TimeDuration;
        attribute parameterValue : Real;
    }

    item def SensorReading {
        attribute rawValue : Real;
        attribute calibratedValue : BreathAlcoholConcentration;
        attribute sensorTemperature : Temperature;
        attribute timestamp : TimeDuration;
    }

    // ===== Port Definitions =====
    port def BreathSampleOutPort {
        out breathSample : BreathSample;
    }

    port def BreathSampleInPort {
        in breathSample : BreathSample;
    }

    port def AnalysisResultOutPort {
        out analysisResult : AnalysisResult;
    }

    port def AnalysisResultInPort {
        in analysisResult : AnalysisResult;
    }

    port def ControlOutPort {
        out command : ControlCommand;
    }

    port def ControlInPort {
        in command : ControlCommand;
    }

    port def PowerOutPort {
        out power : PowerSignal;
    }

    port def PowerInPort {
        in power : PowerSignal;
    }

    port def SensorReadingOutPort {
        out sensorReading : SensorReading;
    }

    port def SensorReadingInPort {
        in sensorReading : SensorReading;
    }

    // ===== Part Definitions =====

    part def BreathSensor {
        attribute sensitivity : Sensitivity = 0.01;
        attribute calibration : CalibrationValue = 0.0;
        attribute isCalibrated : Boolean = true;
        attribute warmupTime : TimeDuration = 2.0;
        attribute operatingTemperature : Temperature = 25.0;
        attribute minDetectableLevel : BreathAlcoholConcentration = 0.02;
        attribute maxDetectableLevel : BreathAlcoholConcentration = 5.0;

        port breathOutput : BreathSampleOutPort;
        port sensorReadingOutput : SensorReadingOutPort;
        port powerInput : PowerInPort;
        port controlInput : ControlInPort;

        action def CaptureBreathSample {
            in breathFlowRate : BreathFlowRate;
            in ambientTemp : Temperature;
            in calibrationSetting : CalibrationValue;
            in sensitivitySetting : Sensitivity;
            out sample : BreathSample;
            out reading : SensorReading;

            action measureRawValue {
                out rawValue : Real;
            }

            action applyCalibration {
                in rawValue : Real;
                in calibrationSetting : CalibrationValue;
                out calibratedValue : BreathAlcoholConcentration;
            }

            action validateSample {
                in calibratedValue : BreathAlcoholConcentration;
                in volume : BreathVolume;
                out isValid : Boolean;
            }

            succession from measureRawValue to applyCalibration;
            succession from applyCalibration to validateSample;
        }

        action def CalibrateSensor {
            in referenceValue : BreathAlcoholConcentration;
            in measuredValue : BreathAlcoholConcentration;
            out newCalibration : CalibrationValue;
        }

        action def WarmupSensor {
            in warmupDuration : TimeDuration;
            out isReady : Boolean;
        }

        action capture : CaptureBreathSample;
        action calibrate : CalibrateSensor;
        action warmup : WarmupSensor;
    }

    part def AnalysisModule {
        attribute conversionFactor : ConversionFactor = 0.21;
        attribute legalLimit : BACValue = 0.08;
        attribute warningThreshold : BACValue = 0.05;
        attribute processingTime : TimeDuration = 3.0;
        attribute confidenceThreshold : Real = 0.95;

        port sampleInput : BreathSampleInPort;
        port resultOutput : AnalysisResultOutPort;
        port powerInput : PowerInPort;
        port controlInput : ControlInPort;

        action def ConvertBreathToBAC {
            in breathAlcohol : BreathAlcoholConcentration;
            in factor : ConversionFactor;
            out bac : BACValue;
        }

        action def EvaluateAlarmStatus {
            in bac : BACValue;
            in limit : BACValue;
            in warningLevel : BACValue;
            out status : AlarmStatus;
        }

        action def CalculateConfidence {
            in sample : BreathSample;
            out confidence : Real;
        }

        action def PerformFullAnalysis {
            in sample : BreathSample;
            in factor : ConversionFactor;
            in limit : BACValue;
            in warningLevel : BACValue;
            out result : AnalysisResult;

            action convert : ConvertBreathToBAC;
            action evaluate : EvaluateAlarmStatus;
            action calculateConfidence : CalculateConfidence;

            succession from convert to evaluate;
            succession from evaluate to calculateConfidence;
        }

        action analyze : PerformFullAnalysis;
    }

    part def DisplayUnit {
        attribute backlightEnabled : Boolean = true;
        attribute displayWidth : Integer = 128;
        attribute displayHeight : Integer = 64;
        attribute buzzerEnabled : Boolean = true;
        attribute buzzerFrequency : Integer = 3000;
        attribute safeColor : String = "green";
        attribute warningColor : String = "yellow";
        attribute violationColor : String = "red";

        port displayInput : AnalysisResultInPort;
        port powerInput : PowerInPort;
        port controlInput : ControlInPort;

        action def DisplayResult {
            in result : AnalysisResult;
            out message : DisplayMessage;
        }

        action def GenerateVisualAlarm {
            in status : AlarmStatus;
            out colorCode : String;
            out backlightOn : Boolean;
        }

        action def GenerateAudibleAlarm {
            in status : AlarmStatus;
            out buzzerActive : Boolean;
            out frequency : Integer;
        }

        action def ClearDisplay {
            out isCleared : Boolean;
        }

        action showResult : DisplayResult;
        action generateVisualAlarm : GenerateVisualAlarm;
        action generateAudibleAlarm : GenerateAudibleAlarm;
        action clearDisplay : ClearDisplay;
    }

    part def PowerSupply {
        attribute nominalVoltage : Voltage = 3.7;
        attribute maxCapacity : BatteryLevel = 100.0;
        attribute currentLevel : BatteryLevel = 100.0;
        attribute isRechargeable : Boolean = true;
        attribute estimatedRemainingTime : TimeDuration = 7200.0;
        attribute lowBatteryThreshold : BatteryLevel = 15.0;
        attribute criticalBatteryThreshold : BatteryLevel = 5.0;

        port powerOutput : PowerOutPort;

        action def SupplyPower {
            out power : PowerSignal;
        }

        action def CheckBatteryLevel {
            out level : BatteryLevel;
            out state : PowerState;
        }

        action def Recharge {
            in chargeVoltage : Voltage;
            out isCharging : Boolean;
        }

        action def MonitorPower {
            out powerState : PowerState;
            out shouldShutdown : Boolean;
        }

        action supply : SupplyPower;
        action checkBattery : CheckBatteryLevel;
        action recharge : Recharge;
        action monitor : MonitorPower;
    }

    // ===== State Machine Definition =====
    state machine def DeviceStateMachine {
        event startTest;
        event breathDetected;
        event sampleComplete;
        event analysisComplete;
        event reset;
        event timeout;
        event lowBattery;
        event powerOff;

        state idle {
            entry {
                /* Device in idle state, waiting for user input */
            }
            do {
                /* Monitor battery level and wait for start command */
            }
        }

        state ready {
            entry {
                /* Sensor warmup initiated, device prepared for sampling */
            }
            do {
                /* Wait for breath detection from sensor */
            }
        }

        state sampling {
            entry {
                /* Breath sample being captured by sensor */
            }
            do {
                /* Monitor breath flow and capture sample data */
            }
        }

        state analyzing {
            entry {
                /* Analysis module processing breath sample */
            }
            do {
                /* Convert breath alcohol to BAC and evaluate alarm status */
            }
        }

        state complete {
            entry {
                /* Result displayed to user */
            }
            do {
                /* Hold result display for 5 seconds before auto-reset */
            }
        }

        state lowPower {
            entry {
                /* Device in low power mode due to low battery */
            }
        }

        transition from idle to ready when startTest;
        transition from ready to sampling when breathDetected;
        transition from sampling to analyzing when sampleComplete;
        transition from analyzing to complete when analysisComplete;
        transition from complete to idle when reset;
        transition from ready to idle when timeout;
        transition from sampling to idle when timeout;
        transition from analyzing to idle when timeout;
        transition from idle to lowPower when lowBattery;
        transition from lowPower to idle when startTest;
        transition from idle to idle when powerOff;
    }

    part def ControlUnit {
        attribute testTimeout : TimeDuration = 10.0;
        attribute analysisTimeout : TimeDuration = 5.0;
        attribute displayHoldTime : TimeDuration = 5.0;
        attribute firmwareVersion : String = "1.0.0";
        attribute currentState : DeviceState = DeviceState::idle;

        port controlOutput : ControlOutPort;
        port powerInput : PowerInPort;

        state machine deviceState : DeviceStateMachine;

        action def StartTest {
            out command : ControlCommand;
        }

        action def TriggerSampling {
            out command : ControlCommand;
        }

        action def TriggerAnalysis {
            out command : ControlCommand;
        }

        action def TriggerDisplay {
            out command : ControlCommand;
        }

        action def ResetDevice {
            out command : ControlCommand;
        }

        action def HandleTimeout {
            out command : ControlCommand;
        }

        action def HandleLowBattery {
            out command : ControlCommand;
        }

        action startTest : StartTest;
        action triggerSampling : TriggerSampling;
        action triggerAnalysis : TriggerAnalysis;
        action triggerDisplay : TriggerDisplay;
        action resetDevice : ResetDevice;
        action handleTimeout : HandleTimeout;
        action handleLowBattery : HandleLowBattery;

        succession from startTest to triggerSampling;
        succession from triggerSampling to triggerAnalysis;
        succession from triggerAnalysis to triggerDisplay;
        succession from triggerDisplay to resetDevice;
    }

    // ===== Top-level System =====
    part def BreathalyzerSystem {
        attribute deviceName : String = "Portable Digital Breathalyzer";
        attribute manufacturer : String = "SafeDrive Inc.";
        attribute modelNumber : String = "BAC-1000";
        attribute serialNumber : String = "SN-00001";
        attribute legalLimit : BACValue = 0.08;
        attribute warningThreshold : BACValue = 0.05;
        attribute deviceWeight : Mass = 250.0;
        attribute deviceLength : Real = 150.0;
        attribute deviceWidth : Real = 70.0;
        attribute deviceHeight : Real = 30.0;

        part breathSensor : BreathSensor {
            attribute sensitivity : Sensitivity = 0.01;
            attribute calibration : CalibrationValue = 0.0;
            attribute warmupTime : TimeDuration = 2.0;
        }

        part analysisModule : AnalysisModule {
            attribute conversionFactor : ConversionFactor = 0.21;
            attribute legalLimit : BACValue = 0.08;
            attribute warningThreshold : BACValue = 0.05;
            attribute processingTime : TimeDuration = 3.0;
        }

        part displayUnit : DisplayUnit {
            attribute backlightEnabled : Boolean = true;
            attribute buzzerEnabled : Boolean = true;
        }

        part controlUnit : ControlUnit {
            attribute testTimeout : TimeDuration = 10.0;
            attribute firmwareVersion : String = "1.0.0";
        }

        part powerSupply : PowerSupply {
            attribute nominalVoltage : Voltage = 3.7;
            attribute currentLevel : BatteryLevel = 100.0;
            attribute maxCapacity : BatteryLevel = 100.0;
        }

        // Connections
        connection breathDataFlow connect breathSensor.breathOutput to analysisModule.sampleInput;
        connection analysisDataFlow connect analysisModule.resultOutput to displayUnit.displayInput;
        connection sensorReadingFlow connect breathSensor.sensorReadingOutput to controlUnit.powerInput;

        connection powerToSensor connect powerSupply.powerOutput to breathSensor.powerInput;
        connection powerToAnalysis connect powerSupply.powerOutput to analysisModule.powerInput;
        connection powerToDisplay connect powerSupply.powerOutput to displayUnit.powerInput;
        connection powerToControl connect powerSupply.powerOutput to controlUnit.powerInput;

        connection controlToSensor connect controlUnit.controlOutput to breathSensor.controlInput;
        connection controlToAnalysis connect controlUnit.controlOutput to analysisModule.controlInput;
        connection controlToDisplay connect controlUnit.controlOutput to displayUnit.controlInput;

        // Item flows
        flow of BreathSample from breathSensor.breathOutput to analysisModule.sampleInput;
        flow of AnalysisResult from analysisModule.resultOutput to displayUnit.displayInput;
        flow of PowerSignal from powerSupply.powerOutput to breathSensor.powerInput;
        flow of PowerSignal from powerSupply.powerOutput to analysisModule.powerInput;
        flow of PowerSignal from powerSupply.powerOutput to displayUnit.powerInput;
        flow of PowerSignal from powerSupply.powerOutput to controlUnit.powerInput;
        flow of ControlCommand from controlUnit.controlOutput to breathSensor.controlInput;
        flow of ControlCommand from controlUnit.controlOutput to analysisModule.controlInput;
        flow of ControlCommand from controlUnit.controlOutput to displayUnit.controlInput;
    }

    // ===== Requirements =====
    requirement def MeasurementAccuracyRequirement {
        attribute requiredAccuracy : BACValue = 0.005;
        attribute measurementRangeMin : BACValue = 0.0;
        attribute measurementRangeMax : BACValue = 0.4;
        doc "The breathalyzer shall measure BAC within +/- 0.005 g/dL accuracy across the full measurement range of 0.0 to 0.4 g/dL.";
    }

    requirement def ResponseTimeRequirement {
        attribute maxResponseTime : TimeDuration = 5.0;
        doc "The device shall display results within 5 seconds of breath sample collection.";
    }

    requirement def LegalLimitRequirement {
        attribute legalLimit : BACValue = 0.08;
        attribute warningThreshold : BACValue = 0.05;
        doc "The device shall compare BAC against a configurable legal limit of 0.08 g/dL and provide a warning at 0.05 g/dL.";
    }

    requirement def AlarmIndicationRequirement {
        attribute safeColor : String = "green";
        attribute warningColor : String = "yellow";
        attribute violationColor : String = "red";
        doc "The device shall provide a color-coded alarm status: safe (green), warning (yellow), or violation (red), accompanied by an audible alarm for violation status.";
    }

    requirement def BatteryLifeRequirement {
        attribute minBatteryLife : TimeDuration = 7200.0;
        attribute lowBatteryThreshold : BatteryLevel = 15.0;
        doc "The device shall operate for at least 2 hours of continuous use on a full battery charge and alert the user when battery falls below 15%.";
    }

    requirement def CalibrationRequirement {
        attribute calibrationInterval : TimeDuration = 2592000.0;
        attribute maxCalibrationDrift : BreathAlcoholConcentration = 0.05;
        doc "The breath sensor shall be calibrated at least every 30 days to maintain measurement accuracy within specified drift limits.";
    }

    requirement def PortabilityRequirement {
        attribute maxWeight : Mass = 300.0;
        attribute maxLength : Real = 150.0;
        attribute maxWidth : Real = 70.0;
        attribute maxHeight : Real = 30.0;
        doc "The device shall be portable, weighing no more than 300g and fitting within 150mm x 70mm x 30mm.";
    }

    requirement def WarmupRequirement {
        attribute maxWarmupTime : TimeDuration = 2.0;
        doc "The breath sensor shall complete warmup within 2 seconds of power-on.";
    }

    requirement def StateTransitionRequirement {
        attribute idleToReadyMaxTime : TimeDuration = 3.0;
        attribute samplingTimeout : TimeDuration = 10.0;
        attribute analyzingTimeout : TimeDuration = 5.0;
        doc "The control unit shall transition through states idle, ready, sampling, analyzing, and complete with specified timeout constraints.";
    }

    requirement def ConversionFactorRequirement {
        attribute standardConversionFactor : ConversionFactor = 0.21;
        attribute maxConversionError : Real = 0.01;
        doc "The analysis module shall use a standard conversion factor of 0.21 g/dL per (mg/L) to convert breath alcohol concentration to BAC.";
    }

    // ===== Requirement Usages and Satisfaction =====
    requirement measurementAccuracyReq : MeasurementAccuracyRequirement;
    requirement responseTimeReq : ResponseTimeRequirement;
    requirement legalLimitReq : LegalLimitRequirement;
    requirement alarmIndicationReq : AlarmIndicationRequirement;
    requirement batteryLifeReq : BatteryLifeRequirement;
    requirement calibrationReq : CalibrationRequirement;
    requirement portabilityReq : PortabilityRequirement;
    requirement warmupReq : WarmupRequirement;
    requirement stateTransitionReq : StateTransitionRequirement;
    requirement conversionFactorReq : ConversionFactorRequirement;

    satisfy measurementAccuracyReq by BreathSensor;
    satisfy responseTimeReq by ControlUnit;
    satisfy legalLimitReq by AnalysisModule;
    satisfy alarmIndicationReq by DisplayUnit;
    satisfy batteryLifeReq by PowerSupply;
    satisfy calibrationReq by BreathSensor;
    satisfy portabilityReq by BreathalyzerSystem;
    satisfy warmupReq by BreathSensor;
    satisfy stateTransitionReq by ControlUnit;
    satisfy conversionFactorReq by AnalysisModule;

    // ===== Use Case =====
    action def PerformBreathTest {
        in user : String;
        out result : AnalysisResult;
        out displayMsg : DisplayMessage;

        action startTest {
            doc "User presses the start button to initiate a breath test.";
        }

        action prepareDevice {
            doc "Control unit transitions from idle to ready state and warms up the sensor.";
        }

        action waitForBreath {
            doc "Device waits for user to blow into the sensor mouthpiece.";
        }

        action blowIntoSensor {
            doc "User blows into the breath sensor mouthpiece providing a breath sample.";
        }

        action captureSample {
            doc "Breath sensor captures the breath sample and measures breath alcohol concentration.";
        }

        action analyzeSample {
            doc "Analysis module converts breath alcohol to BAC using conversion factor and evaluates against legal limit.";
        }

        action determineAlarmStatus {
            doc "Analysis module determines if BAC is safe, warning, or violation based on legal limit and warning threshold.";
        }

        action displayResult {
            doc "Display unit shows BAC value and color-coded alarm status with optional audible alarm.";
        }

        action holdResult {
            doc "Device holds the result display for 5 seconds.";
        }

        action resetDevice {
            doc "Device resets to idle state for next use.";
        }

        succession from startTest to prepareDevice;
        succession from prepareDevice to waitForBreath;
        succession from waitForBreath to blowIntoSensor;
        succession from blowIntoSensor to captureSample;
        succession from captureSample to analyzeSample;
        succession from analyzeSample to determineAlarmStatus;
        succession from determineAlarmStatus to displayResult;
        succession from displayResult to holdResult;
        succession from holdResult to resetDevice;
    }

    // ===== Verification Actions =====
    action def VerifyMeasurementAccuracy {
        in sensor : BreathSensor;
        in referenceSample : BreathSample;
        attribute tolerance : BACValue = 0.005;
        out isAccurate : Boolean;
    }

    action def VerifyResponseTime {
        in controlUnit : ControlUnit;
        attribute maxTime : TimeDuration = 5.0;
        out measuredTime : TimeDuration;
        out isWithinLimit : Boolean;
    }

    action def VerifyAlarmIndication {
        in displayUnit : DisplayUnit;
        in testStatus : AlarmStatus;
        out correctColor : Boolean;
        out buzzerActivated : Boolean;
    }

    action def VerifyBatteryLife {
        in powerSupply : PowerSupply;
        attribute minLife : TimeDuration = 7200.0;
        out measuredLife : TimeDuration;
        out isSufficient : Boolean;
    }
}
