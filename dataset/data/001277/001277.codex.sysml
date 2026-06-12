package TemperatureGaugeSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Celsius :> Real {
        unit = "degC";
    }

    attribute def Percent :> Real {
        unit = "%";
    }

    attribute def Volt :> Real {
        unit = "V";
    }

    attribute def Milliampere :> Real {
        unit = "mA";
    }

    attribute def Second :> Real {
        unit = "s";
    }

    attribute def Hertz :> Real {
        unit = "Hz";
    }

    attribute def KelvinPerSecond :> Real {
        unit = "K/s";
    }

    enum def GaugeHealth {
        enum nominal;
        enum degraded;
        enum failed;
    }

    enum def AlarmLevel {
        enum normal;
        enum lowWarning;
        enum highWarning;
        enum lowCritical;
        enum highCritical;
        enum sensorFault;
    }

    enum def DisplayMode {
        enum measuredTemperature;
        enum minMax;
        enum diagnostics;
        enum calibration;
    }

    item def ThermalContact {
        attribute temperature : Celsius;
        attribute heatTransferQuality : Percent;
    }

    item def TemperatureSample {
        attribute measuredTemperature : Celsius;
        attribute sampleTime : Second;
        attribute sensorVoltage : Volt;
        attribute valid : Boolean;
    }

    item def FilteredTemperature {
        attribute temperature : Celsius;
        attribute rateOfChange : KelvinPerSecond;
        attribute confidence : Percent;
    }

    item def GaugeReading {
        attribute indicatedTemperature : Celsius;
        attribute alarmLevel : AlarmLevel;
        attribute health : GaugeHealth;
        attribute displayMode : DisplayMode;
        attribute timestamp : Second;
    }

    item def ElectricalPower {
        attribute supplyVoltage : Volt;
        attribute supplyCurrent : Milliampere;
        attribute powerAvailable : Boolean;
    }

    item def UserCommand {
        attribute requestedMode : DisplayMode;
        attribute acknowledgeAlarm : Boolean;
        attribute requestSelfTest : Boolean;
        attribute resetMinMax : Boolean;
    }

    port def ThermalInputPort {
        in item thermalContact : ThermalContact;
    }

    port def SensorSignalPort {
        out item sample : TemperatureSample;
    }

    port def FilteredTemperaturePort {
        out item filteredTemperature : FilteredTemperature;
    }

    port def GaugeReadingPort {
        out item reading : GaugeReading;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def UserCommandPort {
        in item command : UserCommand;
    }

    port def VisualDisplayPort {
        in item reading : GaugeReading;
    }

    port def AlarmOutputPort {
        in item reading : GaugeReading;
    }

    action def SenseTemperature {
        in item thermalContact : ThermalContact;
        out item sample : TemperatureSample;

        attribute nominalSensitivity : Volt = 0.010;
        attribute offsetVoltage : Volt = 0.500;
        attribute minimumValidVoltage : Volt = 0.100;
        attribute maximumValidVoltage : Volt = 2.000;
    }

    action def FilterTemperature {
        in item rawSample : TemperatureSample;
        out item filtered : FilteredTemperature;

        attribute filterTimeConstant : Second = 1.5;
        attribute minimumConfidence : Percent = 85.0;
    }

    action def EvaluateTemperatureLimits {
        in item filtered : FilteredTemperature;
        out attribute alarmLevel : AlarmLevel;

        attribute lowCriticalLimit : Celsius = -20.0;
        attribute lowWarningLimit : Celsius = 0.0;
        attribute highWarningLimit : Celsius = 80.0;
        attribute highCriticalLimit : Celsius = 100.0;
    }

    action def RenderGaugeReading {
        in item filtered : FilteredTemperature;
        in attribute alarmLevel : AlarmLevel;
        in attribute health : GaugeHealth;
        in attribute mode : DisplayMode;
        out item reading : GaugeReading;
    }

    action def PerformSelfTest {
        out attribute healthResult : GaugeHealth;
        attribute maximumSelfTestDuration : Second = 2.0;
    }

    state def GaugeOperatingState {
        entry action initialize {
            then perform PerformSelfTest;
        }

        state off;
        state startup;
        state measuring;
        state warning;
        state criticalAlarm;
        state sensorFault;
        state calibration;
        state shutdown;

        transition first off;

        transition off_to_startup
            first off
            then startup;

        transition startup_to_measuring
            first startup
            if health == GaugeHealth::nominal
            then measuring;

        transition startup_to_fault
            first startup
            if health == GaugeHealth::failed
            then sensorFault;

        transition measuring_to_warning
            first measuring
            if alarmLevel == AlarmLevel::lowWarning or alarmLevel == AlarmLevel::highWarning
            then warning;

        transition warning_to_measuring
            first warning
            if alarmLevel == AlarmLevel::normal
            then measuring;

        transition measuring_to_critical
            first measuring
            if alarmLevel == AlarmLevel::lowCritical or alarmLevel == AlarmLevel::highCritical
            then criticalAlarm;

        transition warning_to_critical
            first warning
            if alarmLevel == AlarmLevel::lowCritical or alarmLevel == AlarmLevel::highCritical
            then criticalAlarm;

        transition critical_to_warning
            first criticalAlarm
            if alarmLevel == AlarmLevel::lowWarning or alarmLevel == AlarmLevel::highWarning
            then warning;

        transition any_to_sensor_fault
            first measuring
            if alarmLevel == AlarmLevel::sensorFault
            then sensorFault;

        transition fault_to_measuring
            first sensorFault
            if health == GaugeHealth::nominal and alarmLevel != AlarmLevel::sensorFault
            then measuring;

        transition measuring_to_calibration
            first measuring
            if displayMode == DisplayMode::calibration
            then calibration;

        transition calibration_to_measuring
            first calibration
            if displayMode == DisplayMode::measuredTemperature
            then measuring;

        transition measuring_to_shutdown
            first measuring
            if powerAvailable == false
            then shutdown;
    }

    part def TemperatureProbe {
        port thermalInput : ThermalInputPort;
        port sensorSignal : SensorSignalPort;

        attribute measurementRangeLow : Celsius = -40.0;
        attribute measurementRangeHigh : Celsius = 125.0;
        attribute accuracy : Celsius = 0.5;
        attribute responseTime : Second = 3.0;
        attribute health : GaugeHealth = GaugeHealth::nominal;

        perform action sense : SenseTemperature {
            in thermalContact = thermalInput.thermalContact;
            out sample = sensorSignal.sample;
        }
    }

    part def SignalConditioner {
        port rawInput : SensorSignalPort;
        port filteredOutput : FilteredTemperaturePort;

        attribute sampleRate : Hertz = 10.0;
        attribute noiseRejection : Percent = 95.0;
        attribute openCircuitDetectionVoltage : Volt = 4.8;
        attribute shortCircuitDetectionVoltage : Volt = 0.05;

        perform action filter : FilterTemperature {
            in rawSample = rawInput.sample;
            out filtered = filteredOutput.filteredTemperature;
        }
    }

    part def GaugeController {
        port filteredInput : FilteredTemperaturePort;
        port commandInput : UserCommandPort;
        port readingOutput : GaugeReadingPort;
        port powerInput : PowerInputPort;

        attribute currentHealth : GaugeHealth = GaugeHealth::nominal;
        attribute currentAlarmLevel : AlarmLevel = AlarmLevel::normal;
        attribute currentDisplayMode : DisplayMode = DisplayMode::measuredTemperature;
        attribute powerAvailable : Boolean = true;
        attribute lowCriticalLimit : Celsius = -20.0;
        attribute lowWarningLimit : Celsius = 0.0;
        attribute highWarningLimit : Celsius = 80.0;
        attribute highCriticalLimit : Celsius = 100.0;
        attribute minimumRecordedTemperature : Celsius = 125.0;
        attribute maximumRecordedTemperature : Celsius = -40.0;

        perform action evaluateLimits : EvaluateTemperatureLimits {
            in filtered = filteredInput.filteredTemperature;
            out alarmLevel = currentAlarmLevel;
        }

        perform action renderReading : RenderGaugeReading {
            in filtered = filteredInput.filteredTemperature;
            in alarmLevel = currentAlarmLevel;
            in health = currentHealth;
            in mode = currentDisplayMode;
            out reading = readingOutput.reading;
        }

        exhibit state operatingState : GaugeOperatingState;
    }

    part def AnalogDialDisplay {
        port readingInput : VisualDisplayPort;

        attribute dialMinimum : Celsius = -40.0;
        attribute dialMaximum : Celsius = 125.0;
        attribute majorTickInterval : Celsius = 20.0;
        attribute pointerPosition : Percent;
        attribute backlightBrightness : Percent = 70.0;
    }

    part def DigitalReadoutDisplay {
        port readingInput : VisualDisplayPort;

        attribute displayedTemperature : Celsius;
        attribute updatePeriod : Second = 0.25;
        attribute decimalPlaces : Integer = 1;
        attribute displayBrightness : Percent = 80.0;
    }

    part def AlarmIndicator {
        port alarmInput : AlarmOutputPort;

        attribute audibleEnabled : Boolean = true;
        attribute visualEnabled : Boolean = true;
        attribute acknowledged : Boolean = false;
        attribute warningFlashRate : Hertz = 1.0;
        attribute criticalFlashRate : Hertz = 4.0;
    }

    part def UserInterface {
        port commandOutput : UserCommandPort;

        attribute selectedMode : DisplayMode = DisplayMode::measuredTemperature;
        attribute alarmAcknowledgePressed : Boolean = false;
        attribute selfTestPressed : Boolean = false;
        attribute resetMinMaxPressed : Boolean = false;
    }

    part def PowerSupply {
        port powerOutput : PowerInputPort;

        attribute nominalVoltage : Volt = 12.0;
        attribute minimumOperatingVoltage : Volt = 9.0;
        attribute maximumOperatingVoltage : Volt = 16.0;
        attribute maximumCurrent : Milliampere = 250.0;
        attribute powerAvailable : Boolean = true;
    }

    part def MeasuredEnvironment {
        port thermalOutput : ThermalInputPort;

        attribute actualTemperature : Celsius;
        attribute maximumTemperatureRate : KelvinPerSecond = 2.0;
    }

    part def TemperatureGaugeSystem {
        part environment : MeasuredEnvironment;
        part probe : TemperatureProbe;
        part conditioner : SignalConditioner;
        part controller : GaugeController;
        part analogDisplay : AnalogDialDisplay;
        part digitalDisplay : DigitalReadoutDisplay;
        part alarm : AlarmIndicator;
        part userInterface : UserInterface;
        part powerSupply : PowerSupply;

        port gaugeReadingOutput : GaugeReadingPort;

        attribute systemMeasurementRangeLow : Celsius = -40.0;
        attribute systemMeasurementRangeHigh : Celsius = 125.0;
        attribute systemAccuracy : Celsius = 1.0;
        attribute normalUpdatePeriod : Second = 0.25;
        attribute highLevelPrimaryFunction : String = "Measure ambient or process temperature, convert it into a stable human-readable indication, and alert the user when the temperature leaves configured safe limits.";

        connect environment.thermalOutput to probe.thermalInput;
        connect probe.sensorSignal to conditioner.rawInput;
        connect conditioner.filteredOutput to controller.filteredInput;
        connect controller.readingOutput to analogDisplay.readingInput;
        connect controller.readingOutput to digitalDisplay.readingInput;
        connect controller.readingOutput to alarm.alarmInput;
        connect controller.readingOutput to gaugeReadingOutput;
        connect userInterface.commandOutput to controller.commandInput;
        connect powerSupply.powerOutput to controller.powerInput;
    }

    requirement def PrimaryTemperatureGaugeFunction {
        doc /* The temperature gauge system shall measure a thermal condition and present a clear temperature indication to the user while identifying abnormal or unsafe temperature conditions. */

        subject gauge : TemperatureGaugeSystem;

        require constraint {
            gauge.systemMeasurementRangeLow <= -40.0 and
            gauge.systemMeasurementRangeHigh >= 125.0;
        }
    }

    requirement def TemperatureMeasurementAccuracy {
        doc /* The gauge shall indicate temperature within 1.0 degC of the measured environment temperature over the supported operating range after signal filtering has settled. */

        subject gauge : TemperatureGaugeSystem;

        require constraint {
            gauge.systemAccuracy <= 1.0;
        }
    }

    requirement def TemperatureRangeCoverage {
        doc /* The gauge shall support indication over at least -40 degC through 125 degC. */

        subject gauge : TemperatureGaugeSystem;

        require constraint {
            gauge.systemMeasurementRangeLow <= -40.0 and
            gauge.systemMeasurementRangeHigh >= 125.0;
        }
    }

    requirement def DisplayUpdateResponsiveness {
        doc /* The displayed reading shall update at least four times per second during normal operation. */

        subject gauge : TemperatureGaugeSystem;

        require constraint {
            gauge.normalUpdatePeriod <= 0.25;
        }
    }

    requirement def WarningAndCriticalAlarmBehavior {
        doc /* The controller shall classify readings below -20 degC or above 100 degC as critical, readings from -20 degC to 0 degC or from 80 degC to 100 degC as warning, and all other valid readings as normal. */

        subject controller : GaugeController;

        require constraint {
            controller.lowCriticalLimit == -20.0 and
            controller.lowWarningLimit == 0.0 and
            controller.highWarningLimit == 80.0 and
            controller.highCriticalLimit == 100.0;
        }
    }

    requirement def SensorFaultDetection {
        doc /* The gauge shall detect invalid sensor samples and report a sensor fault alarm instead of displaying a misleading normal temperature. */

        subject controller : GaugeController;

        require constraint {
            controller.currentAlarmLevel != AlarmLevel::normal or
            controller.currentHealth == GaugeHealth::nominal;
        }
    }

    requirement def PowerOperatingEnvelope {
        doc /* The gauge shall operate from a nominal 12 V supply while tolerating supply voltage from 9 V to 16 V. */

        subject supply : PowerSupply;

        require constraint {
            supply.minimumOperatingVoltage <= 9.0 and
            supply.maximumOperatingVoltage >= 16.0 and
            supply.nominalVoltage == 12.0;
        }
    }

    requirement def AlarmUserAcknowledgement {
        doc /* The audible alarm shall be acknowledgeable by the user while the visual alarm indication remains active until the temperature returns to a non-alarm range. */

        subject alarm : AlarmIndicator;

        require constraint {
            alarm.audibleEnabled == true and
            alarm.visualEnabled == true;
        }
    }

    satisfy PrimaryTemperatureGaugeFunction by TemperatureGaugeSystem;
    satisfy TemperatureMeasurementAccuracy by TemperatureGaugeSystem;
    satisfy TemperatureRangeCoverage by TemperatureGaugeSystem;
    satisfy DisplayUpdateResponsiveness by TemperatureGaugeSystem;
    satisfy WarningAndCriticalAlarmBehavior by GaugeController;
    satisfy SensorFaultDetection by GaugeController;
    satisfy PowerOperatingEnvelope by PowerSupply;
    satisfy AlarmUserAcknowledgement by AlarmIndicator;
}