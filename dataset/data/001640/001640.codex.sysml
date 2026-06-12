package ArduinoEnvironmentalMonitor {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Voltage :> Real {
        unit = "V";
    }

    attribute def Current :> Real {
        unit = "mA";
    }

    attribute def Power :> Real {
        unit = "W";
    }

    attribute def Temperature :> Real {
        unit = "degC";
    }

    attribute def RelativeHumidity :> Real {
        unit = "%";
    }

    attribute def Illuminance :> Real {
        unit = "lx";
    }

    attribute def TimeInterval :> Real {
        unit = "s";
    }

    attribute def DataRate :> Real {
        unit = "bit/s";
    }

    attribute def DigitalLevel :> Boolean;

    attribute def AnalogReading :> Integer {
        range = 0..1023;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def I2CFrame {
        attribute address : Integer;
        attribute register : Integer;
        attribute payloadBytes : Integer;
    }

    item def UARTFrame {
        attribute baudRate : DataRate;
        attribute payloadBytes : Integer;
    }

    item def SensorSample {
        attribute temperature : Temperature;
        attribute humidity : RelativeHumidity;
        attribute lightLevel : Illuminance;
        attribute sampleAge : TimeInterval;
    }

    item def DisplayMessage {
        attribute line1 : String;
        attribute line2 : String;
    }

    item def AlertSignal {
        attribute overTemperature : Boolean;
        attribute lowLight : Boolean;
        attribute sensorFault : Boolean;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def PowerOutputPort {
        out item power : ElectricalPower;
    }

    port def I2CPort {
        out item txFrame : I2CFrame;
        in item rxFrame : I2CFrame;
    }

    port def UARTPort {
        out item txFrame : UARTFrame;
        in item rxFrame : UARTFrame;
    }

    port def AnalogInputPort {
        in attribute reading : AnalogReading;
    }

    port def DigitalOutputPort {
        out attribute level : DigitalLevel;
    }

    port def SampleOutputPort {
        out item sample : SensorSample;
    }

    port def AlertOutputPort {
        out item alert : AlertSignal;
    }

    part def UsbPowerSource {
        attribute nominalVoltage : Voltage = 5.0;
        attribute maxCurrent : Current = 500.0;
        port powerOut : PowerOutputPort;
    }

    part def ArduinoUnoController {
        attribute supplyVoltage : Voltage = 5.0;
        attribute clockFrequencyMHz : Real = 16.0;
        attribute samplePeriod : TimeInterval = 2.0;
        attribute overTemperatureThreshold : Temperature = 35.0;
        attribute lowLightThreshold : Illuminance = 50.0;

        port powerIn : PowerInputPort;
        port i2cBus : I2CPort;
        port serialTelemetry : UARTPort;
        port analogLightInput : AnalogInputPort;
        port buzzerDrive : DigitalOutputPort;
        port statusLedDrive : DigitalOutputPort;
        port sampleOut : SampleOutputPort;
        port alertOut : AlertOutputPort;

        action acquireEnvironmentSample {
            in item humidityFrame : I2CFrame;
            in attribute lightReading : AnalogReading;
            out item sample : SensorSample;

            first start;
            then readTemperatureHumidity;
            then convertLightReading;
            then assembleSample;
            then done;

            action readTemperatureHumidity;
            action convertLightReading;
            action assembleSample;
        }

        action evaluateAlert {
            in item sample : SensorSample;
            out item alert : AlertSignal;

            first start;
            then compareThresholds;
            then publishAlert;
            then done;

            action compareThresholds;
            action publishAlert;
        }

        action transmitTelemetry {
            in item sample : SensorSample;
            in item alert : AlertSignal;
            out item telemetryFrame : UARTFrame;

            first start;
            then formatFrame;
            then sendFrame;
            then done;

            action formatFrame;
            action sendFrame;
        }

        state machine controllerLifecycle {
            state booting;
            state initializingSensors;
            state monitoring;
            state alerting;
            state degraded;
            state idle;

            initial then booting;

            transition booting_to_initializing
                first booting
                accept after 1.0 [s]
                then initializingSensors;

            transition initializing_to_monitoring
                first initializingSensors
                accept when sensorsReady
                then monitoring;

            transition monitoring_to_alerting
                first monitoring
                accept when alertOut.alert.overTemperature or alertOut.alert.lowLight
                then alerting;

            transition alerting_to_monitoring
                first alerting
                accept when not alertOut.alert.overTemperature and not alertOut.alert.lowLight
                then monitoring;

            transition monitoring_to_degraded
                first monitoring
                accept when alertOut.alert.sensorFault
                then degraded;

            transition degraded_to_initializing
                first degraded
                accept after 10.0 [s]
                then initializingSensors;

            transition monitoring_to_idle
                first monitoring
                accept when powerIn.power.voltage < 4.5
                then idle;
        }
    }

    part def TemperatureHumiditySensor {
        attribute operatingVoltage : Voltage = 5.0;
        attribute measurementPeriod : TimeInterval = 2.0;
        attribute temperatureAccuracy : Temperature = 0.5;
        attribute humidityAccuracy : RelativeHumidity = 2.0;

        port powerIn : PowerInputPort;
        port i2cBus : I2CPort;
        port sampleOut : SampleOutputPort;
    }

    part def LightSensor {
        attribute operatingVoltage : Voltage = 5.0;
        attribute minIlluminance : Illuminance = 0.0;
        attribute maxIlluminance : Illuminance = 10000.0;

        port powerIn : PowerInputPort;
        port analogOut : AnalogInputPort;
    }

    part def LcdDisplay {
        attribute operatingVoltage : Voltage = 5.0;
        attribute columns : Integer = 16;
        attribute rows : Integer = 2;

        port powerIn : PowerInputPort;
        port i2cBus : I2CPort;

        action showEnvironmentStatus {
            in item message : DisplayMessage;
            first clear;
            then writeLine1;
            then writeLine2;
            then done;

            action clear;
            action writeLine1;
            action writeLine2;
        }
    }

    part def StatusLed {
        attribute forwardVoltage : Voltage = 2.1;
        attribute nominalCurrent : Current = 10.0;
        port driveIn : DigitalOutputPort;
    }

    part def PiezoBuzzer {
        attribute operatingVoltage : Voltage = 5.0;
        attribute nominalCurrent : Current = 25.0;
        port driveIn : DigitalOutputPort;
    }

    part def HostComputer {
        attribute serialBaudRate : DataRate = 9600.0;
        port serialPort : UARTPort;

        action logTelemetry {
            in item frame : UARTFrame;
            first receive;
            then timestamp;
            then persist;
            then done;

            action receive;
            action timestamp;
            action persist;
        }
    }

    part def ArduinoBasedEnvironmentalMonitoringSystem {
        attribute primaryFunction : String =
            "Measure ambient temperature, humidity, and light level using Arduino-connected sensors, evaluate threshold conditions, display local status, and transmit telemetry to a host computer.";

        part usbPower : UsbPowerSource;
        part controller : ArduinoUnoController;
        part tempHumiditySensor : TemperatureHumiditySensor;
        part lightSensor : LightSensor;
        part lcd : LcdDisplay;
        part led : StatusLed;
        part buzzer : PiezoBuzzer;
        part host : HostComputer;

        port systemPowerIn : PowerInputPort;
        port telemetryOut : UARTPort;
        port environmentSampleOut : SampleOutputPort;
        port alertOut : AlertOutputPort;

        connect usbPower.powerOut to controller.powerIn;
        connect usbPower.powerOut to tempHumiditySensor.powerIn;
        connect usbPower.powerOut to lightSensor.powerIn;
        connect usbPower.powerOut to lcd.powerIn;

        connect controller.i2cBus to tempHumiditySensor.i2cBus;
        connect controller.i2cBus to lcd.i2cBus;
        connect lightSensor.analogOut to controller.analogLightInput;

        connect controller.statusLedDrive to led.driveIn;
        connect controller.buzzerDrive to buzzer.driveIn;

        connect controller.serialTelemetry to host.serialPort;
        connect controller.serialTelemetry to telemetryOut;

        connect controller.sampleOut to environmentSampleOut;
        connect controller.alertOut to alertOut;

        action performPrimaryFunction {
            first powerOn;
            then initializeController;
            then initializeSensors;
            then cyclicMonitoring;

            action powerOn;
            action initializeController;
            action initializeSensors;

            action cyclicMonitoring {
                first waitForSamplePeriod;
                then acquire;
                then evaluate;
                then updateDisplay;
                then updateIndicators;
                then sendTelemetry;
                then waitForSamplePeriod;

                action waitForSamplePeriod;
                action acquire : controller.acquireEnvironmentSample;
                action evaluate : controller.evaluateAlert;
                action updateDisplay : lcd.showEnvironmentStatus;
                action updateIndicators;
                action sendTelemetry : controller.transmitTelemetry;
            }
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : ArduinoBasedEnvironmentalMonitoringSystem;

        require constraint {
            system.primaryFunction ==
            "Measure ambient temperature, humidity, and light level using Arduino-connected sensors, evaluate threshold conditions, display local status, and transmit telemetry to a host computer."
        }
    }

    requirement def SamplingRequirement {
        subject controller : ArduinoUnoController;

        require constraint {
            controller.samplePeriod <= 2.0
        }
    }

    requirement def PowerRequirement {
        subject system : ArduinoBasedEnvironmentalMonitoringSystem;

        require constraint {
            system.usbPower.nominalVoltage == 5.0 and
            system.usbPower.maxCurrent >= 250.0
        }
    }

    requirement def AlertRequirement {
        subject controller : ArduinoUnoController;

        require constraint {
            controller.overTemperatureThreshold == 35.0 and
            controller.lowLightThreshold == 50.0
        }
    }

    requirement def TelemetryRequirement {
        subject host : HostComputer;

        require constraint {
            host.serialBaudRate >= 9600.0
        }
    }

    requirement def DisplayRequirement {
        subject display : LcdDisplay;

        require constraint {
            display.columns >= 16 and display.rows >= 2
        }
    }

    requirement def SensorAccuracyRequirement {
        subject sensor : TemperatureHumiditySensor;

        require constraint {
            sensor.temperatureAccuracy <= 0.5 and
            sensor.humidityAccuracy <= 2.0
        }
    }

    satisfy PrimaryFunctionRequirement by ArduinoBasedEnvironmentalMonitoringSystem;
    satisfy SamplingRequirement by ArduinoUnoController;
    satisfy PowerRequirement by ArduinoBasedEnvironmentalMonitoringSystem;
    satisfy AlertRequirement by ArduinoUnoController;
    satisfy TelemetryRequirement by HostComputer;
    satisfy DisplayRequirement by LcdDisplay;
    satisfy SensorAccuracyRequirement by TemperatureHumiditySensor;

}