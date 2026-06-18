package ArduinoBasedEnvironmentalMonitor {

    import ScalarValues::*;
    import SI::*;

    doc
    /*
     * High-Level Primary Function:
     * The Arduino Based Environmental Monitor samples ambient temperature,
     * relative humidity, and illumination using attached sensors, evaluates
     * the measurements against configured limits, indicates local status using
     * LEDs and a buzzer, and publishes periodic measurements over a USB serial
     * interface for external logging or display.
     */

    attribute def Voltage_V :> Real {
        doc /* Electrical potential in volts. */
    }

    attribute def Current_mA :> Real {
        doc /* Electrical current in milliamperes. */
    }

    attribute def Power_W :> Real {
        doc /* Electrical power in watts. */
    }

    attribute def Temperature_C :> Real {
        doc /* Temperature in degrees Celsius. */
    }

    attribute def RelativeHumidity_pct :> Real {
        doc /* Relative humidity as a percentage from 0 to 100. */
    }

    attribute def Illuminance_lux :> Real {
        doc /* Visible light intensity in lux. */
    }

    attribute def Time_s :> Real {
        doc /* Time duration in seconds. */
    }

    attribute def Frequency_Hz :> Real {
        doc /* Frequency in hertz. */
    }

    attribute def DigitalLevel :> Boolean {
        doc /* Digital electrical logic level. */
    }

    enum def AlertSeverity {
        enum normal;
        enum warning;
        enum critical;
    }

    enum def OperatingMode {
        enum booting;
        enum monitoring;
        enum alerting;
        enum fault;
        enum lowPower;
    }

    enum def LedColor {
        enum green;
        enum yellow;
        enum red;
        enum blue;
    }

    item def RegulatedDcPower {
        attribute voltage : Voltage_V;
        attribute maxCurrent : Current_mA;
    }

    item def RawDcPower {
        attribute voltage : Voltage_V;
        attribute availableCurrent : Current_mA;
    }

    item def GroundReference {
        attribute potential : Voltage_V = 0.0;
    }

    item def I2CFrame {
        attribute address : Integer;
        attribute payloadBytes : Integer;
        attribute bitRate : Frequency_Hz;
    }

    item def AnalogVoltageSample {
        attribute voltage : Voltage_V;
        attribute sampledAt : Time_s;
    }

    item def DigitalCommand {
        attribute level : DigitalLevel;
        attribute issuedAt : Time_s;
    }

    item def PwmCommand {
        attribute dutyCyclePercent : Real;
        attribute frequency : Frequency_Hz;
    }

    item def EnvironmentReading {
        attribute temperature : Temperature_C;
        attribute humidity : RelativeHumidity_pct;
        attribute illuminance : Illuminance_lux;
        attribute sampleTime : Time_s;
    }

    item def ThresholdConfiguration {
        attribute highTemperatureWarning : Temperature_C = 30.0;
        attribute highTemperatureCritical : Temperature_C = 40.0;
        attribute lowHumidityWarning : RelativeHumidity_pct = 25.0;
        attribute lowLightWarning : Illuminance_lux = 50.0;
    }

    item def AlertCommand {
        attribute severity : AlertSeverity;
        attribute messageCode : Integer;
        attribute commandedAt : Time_s;
    }

    item def SerialTelemetryFrame {
        attribute sequenceNumber : Integer;
        attribute temperature : Temperature_C;
        attribute humidity : RelativeHumidity_pct;
        attribute illuminance : Illuminance_lux;
        attribute severity : AlertSeverity;
        attribute frameTime : Time_s;
    }

    port def DcPowerInPort {
        in item power : RawDcPower;
        in item ground : GroundReference;
    }

    port def RegulatedPowerOutPort {
        out item power : RegulatedDcPower;
        out item ground : GroundReference;
    }

    port def RegulatedPowerInPort {
        in item power : RegulatedDcPower;
        in item ground : GroundReference;
    }

    port def I2CPort {
        out item request : I2CFrame;
        in item response : I2CFrame;
    }

    port def AnalogInputPort {
        in item sample : AnalogVoltageSample;
    }

    port def DigitalOutputPort {
        out item command : DigitalCommand;
    }

    port def PwmOutputPort {
        out item command : PwmCommand;
    }

    port def UsbSerialPort {
        out item telemetry : SerialTelemetryFrame;
        in item configuration : ThresholdConfiguration;
    }

    port def HumanVisibleIndicatorPort {
        out item command : DigitalCommand;
    }

    port def AudibleIndicatorPort {
        out item command : PwmCommand;
    }

    part def UsbPowerSource {
        attribute nominalVoltage : Voltage_V = 5.0;
        attribute maximumCurrent : Current_mA = 500.0;

        port dcOut : DcPowerInPort;
    }

    part def ArduinoUnoCompatibleBoard {
        doc /* Arduino-compatible microcontroller board used as the central controller. */

        attribute supplyVoltage : Voltage_V = 5.0;
        attribute clockFrequency : Frequency_Hz = 16000000.0;
        attribute adcResolutionBits : Integer = 10;
        attribute programMemoryBytes : Integer = 32768;
        attribute sramBytes : Integer = 2048;
        attribute nominalSamplePeriod : Time_s = 1.0;
        attribute currentMode : OperatingMode = OperatingMode::booting;

        port powerIn : DcPowerInPort;
        port fiveVoltOut : RegulatedPowerOutPort;
        port i2cBus : I2CPort;
        port analogA0 : AnalogInputPort;
        port digitalD8 : DigitalOutputPort;
        port digitalD9Pwm : PwmOutputPort;
        port digitalD10 : DigitalOutputPort;
        port usbSerial : UsbSerialPort;

        state controllerStateMachine {
            entry action initializeHardware;

            state Booting;
            state Monitoring;
            state Alerting;
            state Fault;
            state LowPower;

            transition initial_to_booting
                first Booting;

            transition boot_complete
                first Booting
                then Monitoring
                accept after 2.0;

            transition warning_or_critical_alert
                first Monitoring
                then Alerting
                accept AlertCommand
                if severity != AlertSeverity::normal;

            transition alert_cleared
                first Alerting
                then Monitoring
                accept AlertCommand
                if severity == AlertSeverity::normal;

            transition sensor_fault_detected
                first Monitoring
                then Fault
                accept FaultDetected;

            transition alert_sensor_fault_detected
                first Alerting
                then Fault
                accept FaultDetected;

            transition fault_recovered
                first Fault
                then Monitoring
                accept FaultCleared;

            transition idle_timeout_to_low_power
                first Monitoring
                then LowPower
                accept after 300.0;

            transition wake_for_sample
                first LowPower
                then Monitoring
                accept after 1.0;
        }
    }

    part def TemperatureHumiditySensor {
        doc /* Digital I2C sensor providing temperature and relative humidity. */

        attribute supplyVoltage : Voltage_V = 5.0;
        attribute temperatureAccuracy : Temperature_C = 0.5;
        attribute humidityAccuracy : RelativeHumidity_pct = 2.0;
        attribute maximumCurrent : Current_mA = 2.5;
        attribute i2cAddress : Integer = 64;

        port powerIn : RegulatedPowerInPort;
        port i2c : I2CPort;
    }

    part def LightSensor {
        doc /* Analog photoresistor divider producing a voltage proportional to light level. */

        attribute supplyVoltage : Voltage_V = 5.0;
        attribute darkOutputVoltage : Voltage_V = 4.5;
        attribute brightOutputVoltage : Voltage_V = 0.5;
        attribute maximumCurrent : Current_mA = 1.0;

        port powerIn : RegulatedPowerInPort;
        port analogOut : AnalogInputPort;
    }

    part def StatusLed {
        attribute color : LedColor;
        attribute forwardVoltage : Voltage_V = 2.0;
        attribute nominalCurrent : Current_mA = 10.0;

        port powerIn : RegulatedPowerInPort;
        port drive : HumanVisibleIndicatorPort;
    }

    part def PiezoBuzzer {
        attribute nominalVoltage : Voltage_V = 5.0;
        attribute nominalCurrent : Current_mA = 30.0;
        attribute alertToneFrequency : Frequency_Hz = 2000.0;

        port powerIn : RegulatedPowerInPort;
        port drive : AudibleIndicatorPort;
    }

    part def UsbSerialHost {
        doc /* External computer or logger receiving serial telemetry and optionally sending limits. */

        attribute baudRate : Frequency_Hz = 9600.0;

        port serial : UsbSerialPort;
    }

    action def InitializeHardware {
        out item ready : DigitalLevel;

        action configureClock;
        action configureAdc;
        action configureI2CBus;
        action configureDigitalOutputs;
        action loadDefaultThresholds;

        flow configureClock then configureAdc;
        flow configureAdc then configureI2CBus;
        flow configureI2CBus then configureDigitalOutputs;
        flow configureDigitalOutputs then loadDefaultThresholds;
    }

    action def SampleEnvironment {
        in item temperatureHumidityFrame : I2CFrame;
        in item lightVoltage : AnalogVoltageSample;
        out item reading : EnvironmentReading;

        attribute adcReferenceVoltage : Voltage_V = 5.0;
        attribute adcResolutionBits : Integer = 10;
        attribute sampleDuration : Time_s = 0.05;

        action requestTemperatureHumidity;
        action convertI2CResponse;
        action readLightAnalogVoltage;
        action convertLightVoltageToLux;
        action assembleReading;

        flow requestTemperatureHumidity then convertI2CResponse;
        flow readLightAnalogVoltage then convertLightVoltageToLux;
        flow convertI2CResponse then assembleReading;
        flow convertLightVoltageToLux then assembleReading;
    }

    action def EvaluateEnvironment {
        in item reading : EnvironmentReading;
        in item thresholds : ThresholdConfiguration;
        out item alert : AlertCommand;

        action compareTemperature;
        action compareHumidity;
        action compareIlluminance;
        action selectHighestSeverity;

        flow compareTemperature then selectHighestSeverity;
        flow compareHumidity then selectHighestSeverity;
        flow compareIlluminance then selectHighestSeverity;
    }

    action def IndicateStatus {
        in item alert : AlertCommand;
        out item greenLedCommand : DigitalCommand;
        out item redLedCommand : DigitalCommand;
        out item buzzerCommand : PwmCommand;

        action commandNormalIndication;
        action commandWarningIndication;
        action commandCriticalIndication;

        decision selectIndication;
        first selectIndication;

        transition normalPath
            first selectIndication
            then commandNormalIndication
            if alert.severity == AlertSeverity::normal;

        transition warningPath
            first selectIndication
            then commandWarningIndication
            if alert.severity == AlertSeverity::warning;

        transition criticalPath
            first selectIndication
            then commandCriticalIndication
            if alert.severity == AlertSeverity::critical;
    }

    action def PublishTelemetry {
        in item reading : EnvironmentReading;
        in item alert : AlertCommand;
        out item frame : SerialTelemetryFrame;

        attribute baudRate : Frequency_Hz = 9600.0;
        attribute maximumFramePeriod : Time_s = 1.0;

        action encodeCsvFrame;
        action transmitUsbSerialFrame;

        flow encodeCsvFrame then transmitUsbSerialFrame;
    }

    action def EnvironmentalMonitoringLoop {
        in item thresholds : ThresholdConfiguration;
        out item telemetry : SerialTelemetryFrame;
        out item alert : AlertCommand;

        action initialize : InitializeHardware;
        action sample : SampleEnvironment;
        action evaluate : EvaluateEnvironment;
        action indicate : IndicateStatus;
        action publish : PublishTelemetry;
        action waitUntilNextSample;

        flow initialize.ready to sample;
        flow sample.reading to evaluate.reading;
        flow thresholds to evaluate.thresholds;
        flow evaluate.alert to indicate.alert;
        flow sample.reading to publish.reading;
        flow evaluate.alert to publish.alert;
        flow publish.frame to telemetry;
        flow publish then waitUntilNextSample;
        flow waitUntilNextSample then sample;
    }

    constraint def TotalCurrentWithinUsbLimit {
        in controllerCurrent : Current_mA;
        in sensorCurrent : Current_mA;
        in ledCurrent : Current_mA;
        in buzzerCurrent : Current_mA;
        in usbLimit : Current_mA;

        controllerCurrent + sensorCurrent + ledCurrent + buzzerCurrent <= usbLimit;
    }

    constraint def TemperatureWarningRule {
        in measuredTemperature : Temperature_C;
        in warningThreshold : Temperature_C;

        measuredTemperature >= warningThreshold;
    }

    constraint def TemperatureCriticalRule {
        in measuredTemperature : Temperature_C;
        in criticalThreshold : Temperature_C;

        measuredTemperature >= criticalThreshold;
    }

    constraint def HumidityWarningRule {
        in measuredHumidity : RelativeHumidity_pct;
        in lowHumidityThreshold : RelativeHumidity_pct;

        measuredHumidity <= lowHumidityThreshold;
    }

    constraint def LightWarningRule {
        in measuredIlluminance : Illuminance_lux;
        in lowLightThreshold : Illuminance_lux;

        measuredIlluminance <= lowLightThreshold;
    }

    part def ArduinoEnvironmentalMonitorSystem {
        doc
        /*
         * System context:
         * A USB-powered Arduino-compatible embedded system that monitors
         * ambient environmental conditions and provides local and serial
         * status output.
         */

        attribute primaryFunction : String =
            "Monitor ambient temperature, humidity, and light, then report measurements and alert when configured environmental limits are exceeded.";

        attribute nominalInputVoltage : Voltage_V = 5.0;
        attribute maximumSystemCurrent : Current_mA = 500.0;
        attribute nominalSamplePeriod : Time_s = 1.0;
        attribute telemetryPeriod : Time_s = 1.0;
        attribute operatingMode : OperatingMode = OperatingMode::monitoring;

        port usbPowerInput : DcPowerInPort;
        port telemetryPort : UsbSerialPort;

        part usbSource : UsbPowerSource {
            attribute nominalVoltage = 5.0;
            attribute maximumCurrent = 500.0;
        }

        part controller : ArduinoUnoCompatibleBoard {
            attribute nominalSamplePeriod = 1.0;
        }

        part temperatureHumiditySensor : TemperatureHumiditySensor {
            attribute i2cAddress = 64;
            attribute maximumCurrent = 2.5;
        }

        part lightSensor : LightSensor {
            attribute maximumCurrent = 1.0;
        }

        part greenStatusLed : StatusLed {
            attribute color = LedColor::green;
            attribute nominalCurrent = 10.0;
        }

        part redAlertLed : StatusLed {
            attribute color = LedColor::red;
            attribute nominalCurrent = 10.0;
        }

        part buzzer : PiezoBuzzer {
            attribute nominalCurrent = 30.0;
            attribute alertToneFrequency = 2000.0;
        }

        part hostComputer : UsbSerialHost {
            attribute baudRate = 9600.0;
        }

        item defaultThresholds : ThresholdConfiguration {
            attribute highTemperatureWarning = 30.0;
            attribute highTemperatureCritical = 40.0;
            attribute lowHumidityWarning = 25.0;
            attribute lowLightWarning = 50.0;
        }

        perform monitoringLoop : EnvironmentalMonitoringLoop;

        connect usbSource.dcOut to controller.powerIn;
        connect controller.fiveVoltOut to temperatureHumiditySensor.powerIn;
        connect controller.fiveVoltOut to lightSensor.powerIn;
        connect controller.fiveVoltOut to greenStatusLed.powerIn;
        connect controller.fiveVoltOut to redAlertLed.powerIn;
        connect controller.fiveVoltOut to buzzer.powerIn;

        connect controller.i2cBus to temperatureHumiditySensor.i2c;
        connect lightSensor.analogOut to controller.analogA0;

        connect controller.digitalD8 to greenStatusLed.drive;
        connect controller.digitalD10 to redAlertLed.drive;
        connect controller.digitalD9Pwm to buzzer.drive;

        connect controller.usbSerial to hostComputer.serial;
        connect telemetryPort to controller.usbSerial;
        connect usbPowerInput to controller.powerIn;

        bind monitoringLoop.thresholds = defaultThresholds;
        bind monitoringLoop.telemetry = controller.usbSerial.telemetry;

        constraint totalCurrentBudget : TotalCurrentWithinUsbLimit {
            in controllerCurrent = 75.0;
            in sensorCurrent = 3.5;
            in ledCurrent = 20.0;
            in buzzerCurrent = 30.0;
            in usbLimit = 500.0;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /*
         * The system shall use an Arduino-compatible controller to periodically
         * acquire environmental measurements and provide local and serial
         * indication of environmental status.
         */

        subject system : ArduinoEnvironmentalMonitorSystem;

        require constraint {
            system.nominalSamplePeriod <= 1.0
        }
    }

    requirement def PowerRequirement {
        doc
        /*
         * The system shall operate from a 5 V USB source without exceeding
         * the standard 500 mA USB current budget.
         */

        subject system : ArduinoEnvironmentalMonitorSystem;

        require constraint {
            system.nominalInputVoltage == 5.0 and system.maximumSystemCurrent <= 500.0
        }
    }

    requirement def TemperatureAlertRequirement {
        doc
        /*
         * The system shall command a critical alert when measured temperature
         * is greater than or equal to 40 degrees Celsius.
         */

        subject system : ArduinoEnvironmentalMonitorSystem;

        require constraint {
            system.defaultThresholds.highTemperatureCritical == 40.0
        }
    }

    requirement def TelemetryRequirement {
        doc
        /*
         * The system shall publish telemetry at least once per second during
         * normal monitoring operation.
         */

        subject system : ArduinoEnvironmentalMonitorSystem;

        require constraint {
            system.telemetryPeriod <= 1.0
        }
    }

    requirement def LocalIndicationRequirement {
        doc
        /*
         * The system shall provide visible normal indication using a green LED
         * and visible/audible alert indication using a red LED and buzzer.
         */

        subject system : ArduinoEnvironmentalMonitorSystem;

        require constraint {
            system.greenStatusLed.nominalCurrent > 0.0 and
            system.redAlertLed.nominalCurrent > 0.0 and
            system.buzzer.nominalCurrent > 0.0
        }
    }

    requirement def SensorInterfaceRequirement {
        doc
        /*
         * The Arduino controller shall interface with the temperature/humidity
         * sensor using I2C and the light sensor using one analog input channel.
         */

        subject system : ArduinoEnvironmentalMonitorSystem;

        require constraint {
            system.temperatureHumiditySensor.i2cAddress == 64 and
            system.controller.adcResolutionBits >= 10
        }
    }

    satisfy PrimaryFunctionRequirement by ArduinoEnvironmentalMonitorSystem;
    satisfy PowerRequirement by ArduinoEnvironmentalMonitorSystem;
    satisfy TemperatureAlertRequirement by ArduinoEnvironmentalMonitorSystem;
    satisfy TelemetryRequirement by ArduinoEnvironmentalMonitorSystem;
    satisfy LocalIndicationRequirement by ArduinoEnvironmentalMonitorSystem;
    satisfy SensorInterfaceRequirement by ArduinoEnvironmentalMonitorSystem;

    exhibit state controllerBehavior by ArduinoUnoCompatibleBoard::controllerStateMachine;

}
