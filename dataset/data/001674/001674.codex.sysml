package NodeMCU_IoT_Environment_Monitor {

    import ScalarValues::*;
    import SI::*;

    attribute def Celsius : Real {
        unit = "degC";
    }

    attribute def PercentRH : Real {
        unit = "%";
    }

    attribute def Lux : Real {
        unit = "lx";
    }

    attribute def Volt : Real {
        unit = "V";
    }

    attribute def Milliampere : Real {
        unit = "mA";
    }

    attribute def Millisecond : Real {
        unit = "ms";
    }

    attribute def Second : Real {
        unit = "s";
    }

    attribute def ByteCount : Integer {
        unit = "byte";
    }

    enum def WifiConnectionState {
        enum disconnected;
        enum scanning;
        enum authenticating;
        enum connected;
        enum degraded;
    }

    enum def TelemetryQuality {
        enum valid;
        enum stale;
        enum invalid;
    }

    item def TemperatureSample {
        attribute value : Celsius;
        attribute sampleAge : Millisecond;
        attribute quality : TelemetryQuality;
    }

    item def HumiditySample {
        attribute value : PercentRH;
        attribute sampleAge : Millisecond;
        attribute quality : TelemetryQuality;
    }

    item def IlluminanceSample {
        attribute value : Lux;
        attribute sampleAge : Millisecond;
        attribute quality : TelemetryQuality;
    }

    item def TelemetryPacket {
        attribute deviceId : String;
        attribute sequenceNumber : Integer;
        attribute timestamp : String;
        attribute temperature : Celsius;
        attribute humidity : PercentRH;
        attribute illuminance : Lux;
        attribute supplyVoltage : Volt;
        attribute payloadSize : ByteCount;
        attribute quality : TelemetryQuality;
    }

    item def CommandMessage {
        attribute commandId : String;
        attribute requestedSamplePeriod : Second;
        attribute ledEnabled : Boolean;
        attribute rebootRequested : Boolean;
    }

    port def PowerInputPort {
        in item voltage : Volt;
        in item currentLimit : Milliampere;
    }

    port def I2CPort {
        out item scl : Boolean;
        inout item sda : Boolean;
    }

    port def DigitalPort {
        out item logicLevel : Boolean;
    }

    port def AnalogPort {
        in item analogVoltage : Volt;
    }

    port def WifiPort {
        out item telemetry : TelemetryPacket;
        in item command : CommandMessage;
    }

    port def SensorDataPort {
        out item temperature : TemperatureSample;
        out item humidity : HumiditySample;
        out item illuminance : IlluminanceSample;
    }

    part def NodeMCU_ESP8266_Controller {
        attribute clockFrequency : Real = 80.0;
        attribute supplyVoltageNominal : Volt = 3.3;
        attribute activeCurrent : Milliampere = 85.0;
        attribute deepSleepCurrent : Milliampere = 0.08;
        attribute wifiState : WifiConnectionState = WifiConnectionState::disconnected;
        attribute firmwareVersion : String = "1.0.0";

        port vin : PowerInputPort;
        port i2c : I2CPort;
        port statusLed : DigitalPort;
        port batterySense : AnalogPort;
        port wifi : WifiPort;
        port sensorData : SensorDataPort;

        action def ReadSensors {
            in item temperatureIn : TemperatureSample;
            in item humidityIn : HumiditySample;
            in item illuminanceIn : IlluminanceSample;
            out item packetDraft : TelemetryPacket;
        }

        action def ConnectWifi {
            out attribute result : WifiConnectionState;
        }

        action def PublishTelemetry {
            in item packet : TelemetryPacket;
            out attribute acknowledged : Boolean;
        }

        action def ApplyCommand {
            in item command : CommandMessage;
            out attribute samplePeriod : Second;
            out attribute statusLedEnabled : Boolean;
        }

        state def ControllerLifecycle {
            entry action initializeFirmware;
            state booting;
            state acquiringSensorData;
            state connectingWifi;
            state publishingTelemetry;
            state processingCommand;
            state sleeping;
            state fault;

            transition first booting;
            transition booting then acquiringSensorData;
            transition acquiringSensorData then connectingWifi;
            transition connectingWifi then publishingTelemetry
                if wifiState == WifiConnectionState::connected;
            transition connectingWifi then fault
                if wifiState == WifiConnectionState::disconnected;
            transition publishingTelemetry then processingCommand;
            transition processingCommand then sleeping;
            transition sleeping then acquiringSensorData;
            transition fault then booting;
        }
    }

    part def TemperatureHumiditySensor {
        attribute temperatureAccuracy : Celsius = 0.5;
        attribute humidityAccuracy : PercentRH = 2.0;
        attribute operatingVoltage : Volt = 3.3;

        port power : PowerInputPort;
        port i2c : I2CPort;
        port samples : SensorDataPort;
    }

    part def LightSensor {
        attribute minimumIlluminance : Lux = 1.0;
        attribute maximumIlluminance : Lux = 65535.0;
        attribute operatingVoltage : Volt = 3.3;

        port power : PowerInputPort;
        port i2c : I2CPort;
        port samples : SensorDataPort;
    }

    part def VoltageRegulator {
        attribute inputVoltageMin : Volt = 4.5;
        attribute inputVoltageMax : Volt = 12.0;
        attribute outputVoltage : Volt = 3.3;
        attribute outputCurrentMax : Milliampere = 500.0;

        port inputPower : PowerInputPort;
        port regulatedPower : PowerInputPort;
    }

    part def StatusIndicator {
        attribute forwardVoltage : Volt = 2.0;
        attribute operatingCurrent : Milliampere = 8.0;

        port drive : DigitalPort;

        state def IndicatorBehavior {
            state off;
            state bootBlink;
            state connectedPulse;
            state faultBlink;

            transition first off;
            transition off then bootBlink;
            transition bootBlink then connectedPulse;
            transition connectedPulse then faultBlink;
            transition faultBlink then bootBlink;
        }
    }

    part def CloudTelemetryEndpoint {
        attribute brokerUri : String = "mqtts://telemetry.example.net";
        attribute topic : String = "devices/nodemcu/environment";
        attribute maximumPayloadSize : ByteCount = 1024;

        port wifi : WifiPort;

        action def StoreTelemetry {
            in item packet : TelemetryPacket;
            out attribute stored : Boolean;
        }

        action def IssueCommand {
            out item command : CommandMessage;
        }
    }

    part def NodeMCU_Environment_Monitor {
        doc /* Primary function: periodically measure local temperature, humidity, and ambient light using a NodeMCU-based embedded controller, package the measurements with device health data, and transmit telemetry over Wi-Fi to a cloud endpoint while accepting remote configuration commands. */

        attribute deviceId : String = "NODEMCU-ENV-001";
        attribute nominalSamplePeriod : Second = 60.0;
        attribute maximumWakeDuration : Second = 10.0;
        attribute batteryVoltageWarning : Volt = 3.5;
        attribute telemetryRetryLimit : Integer = 3;

        part regulator : VoltageRegulator;
        part controller : NodeMCU_ESP8266_Controller;
        part tempHumiditySensor : TemperatureHumiditySensor;
        part lightSensor : LightSensor;
        part indicator : StatusIndicator;
        part cloud : CloudTelemetryEndpoint;

        port externalPower : PowerInputPort;

        connect externalPower to regulator.inputPower;
        connect regulator.regulatedPower to controller.vin;
        connect regulator.regulatedPower to tempHumiditySensor.power;
        connect regulator.regulatedPower to lightSensor.power;
        connect controller.i2c to tempHumiditySensor.i2c;
        connect controller.i2c to lightSensor.i2c;
        connect tempHumiditySensor.samples to controller.sensorData;
        connect lightSensor.samples to controller.sensorData;
        connect controller.statusLed to indicator.drive;
        connect controller.wifi to cloud.wifi;

        action def MonitorEnvironmentCycle {
            first start;
            then readSensorValues;
            then validateMeasurements;
            then buildTelemetryPacket;
            then connectNetwork;
            then publishPacket;
            then receiveRemoteCommand;
            then updateConfiguration;
            then enterLowPowerSleep;

            action readSensorValues {
                out item temperature : TemperatureSample;
                out item humidity : HumiditySample;
                out item illuminance : IlluminanceSample;
            }

            action validateMeasurements {
                in item temperature : TemperatureSample;
                in item humidity : HumiditySample;
                in item illuminance : IlluminanceSample;
                out attribute valid : Boolean;
            }

            action buildTelemetryPacket {
                in item temperature : TemperatureSample;
                in item humidity : HumiditySample;
                in item illuminance : IlluminanceSample;
                out item packet : TelemetryPacket;
            }

            action connectNetwork {
                out attribute wifiState : WifiConnectionState;
            }

            action publishPacket {
                in item packet : TelemetryPacket;
                out attribute delivered : Boolean;
            }

            action receiveRemoteCommand {
                out item command : CommandMessage;
            }

            action updateConfiguration {
                in item command : CommandMessage;
                out attribute newSamplePeriod : Second;
            }

            action enterLowPowerSleep {
                in attribute sleepDuration : Second;
            }
        }

        state def SystemOperationalState {
            state poweredOff;
            state boot;
            state measure;
            state networkJoin;
            state transmit;
            state commandUpdate;
            state lowPowerWait;
            state degradedOperation;
            state serviceRequired;

            transition first poweredOff;
            transition poweredOff then boot;
            transition boot then measure;
            transition measure then networkJoin;
            transition networkJoin then transmit
                if controller.wifiState == WifiConnectionState::connected;
            transition networkJoin then degradedOperation
                if controller.wifiState == WifiConnectionState::degraded;
            transition transmit then commandUpdate;
            transition commandUpdate then lowPowerWait;
            transition lowPowerWait then measure;
            transition degradedOperation then lowPowerWait;
            transition degradedOperation then serviceRequired
                if telemetryRetryLimit <= 0;
            transition serviceRequired then boot;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : NodeMCU_Environment_Monitor;
        require constraint {
            system.nominalSamplePeriod <= 300.0
        }
        doc /* The system shall use a NodeMCU controller to periodically collect environmental measurements and transmit them through Wi-Fi as telemetry. */
    }

    requirement def TelemetryContentRequirement {
        subject packet : TelemetryPacket;
        require constraint {
            packet.payloadSize <= 1024
        }
        doc /* Each telemetry packet shall include device identity, sequence number, timestamp, temperature, humidity, illuminance, supply voltage, and quality status. */
    }

    requirement def SensorAccuracyRequirement {
        subject system : NodeMCU_Environment_Monitor;
        require constraint {
            system.tempHumiditySensor.temperatureAccuracy <= 0.5 and
            system.tempHumiditySensor.humidityAccuracy <= 2.0
        }
        doc /* The environmental sensing subsystem shall meet the required temperature and humidity accuracy for room monitoring. */
    }

    requirement def PowerRequirement {
        subject system : NodeMCU_Environment_Monitor;
        require constraint {
            system.regulator.outputVoltage == 3.3 and
            system.regulator.outputCurrentMax >= 300.0
        }
        doc /* The regulated supply shall provide 3.3 V power with sufficient current for Wi-Fi transmission peaks and connected sensors. */
    }

    requirement def LowPowerRequirement {
        subject controller : NodeMCU_ESP8266_Controller;
        require constraint {
            controller.deepSleepCurrent <= 0.1
        }
        doc /* The controller shall enter low-power sleep between measurement cycles to reduce average current draw. */
    }

    requirement def NetworkRequirement {
        subject controller : NodeMCU_ESP8266_Controller;
        require constraint {
            controller.wifiState == WifiConnectionState::connected or
            controller.wifiState == WifiConnectionState::degraded or
            controller.wifiState == WifiConnectionState::disconnected
        }
        doc /* The controller shall manage Wi-Fi connection state and support retry or degraded operation when the cloud endpoint is unavailable. */
    }

    satisfy PrimaryFunctionRequirement by NodeMCU_Environment_Monitor;
    satisfy SensorAccuracyRequirement by TemperatureHumiditySensor;
    satisfy PowerRequirement by VoltageRegulator;
    satisfy LowPowerRequirement by NodeMCU_ESP8266_Controller;
    satisfy NetworkRequirement by NodeMCU_ESP8266_Controller;
    satisfy TelemetryContentRequirement by TelemetryPacket;
}