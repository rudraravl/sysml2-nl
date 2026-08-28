package EnvironmentalMonitoringSystem {
    private import ScalarValues::*;

    package Definitions {
        attribute def TemperatureValue :> Real;
        attribute def HumidityValue :> Real;
        attribute def LightLevelValue :> Real;
        attribute def TimestampValue :> Integer;

        item def TempHumidData {
            attribute temperature : TemperatureValue;
            attribute humidity : HumidityValue;
        }

        item def LightData {
            attribute lightLevel : LightLevelValue;
        }

        item def SensorRecord {
            attribute temperature : TemperatureValue;
            attribute humidity : HumidityValue;
            attribute lightLevel : LightLevelValue;
            attribute timestamp : TimestampValue;
        }

        item def DisplayContent {
            attribute line1 : String;
            attribute line2 : String;
        }

        item def AlertEvent;

        attribute def InitComplete;
        attribute def ThresholdExceeded;
        attribute def ThresholdRestored;

        port def I2CBus {
            in ref data : TempHumidData;
        }

        port def AnalogInput {
            in ref data : LightData;
        }

        port def DigitalOutput {
            out ref signal : AlertEvent;
        }

        port def DisplayBus {
            in ref content : DisplayContent;
        }

        port def SerialLink {
            out ref record : SensorRecord;
        }

        action def Initialize;
        action def ReadTempHumid {
            out data : TempHumidData;
        }
        action def ReadLight {
            out data : LightData;
        }
        action def UpdateDisplay {
            in content : DisplayContent;
        }
        action def SoundBuzzer;
        action def IlluminateLED;
        action def BuildRecord {
            in tempData : TempHumidData;
            in lightData : LightData;
            out record : SensorRecord;
        }
        action def TransmitRecord {
            in record : SensorRecord;
        }

        part def TempHumidSensor {
            port i2c : ~I2CBus;
        }

        part def LightSensor {
            port analog : ~AnalogInput;
        }

        part def LCDDisplay {
            port display : DisplayBus;
        }

        part def Buzzer {
            port control : ~DigitalOutput;
        }

        part def StatusLED {
            port control : ~DigitalOutput;
        }

        part def DataLogger {
            port serialInput : ~SerialLink;
        }

        part def ArduinoMicrocontroller {
            port tempHumidPort : I2CBus;
            port lightPort : AnalogInput;
            port displayPort : ~DisplayBus;
            port buzzerPort : DigitalOutput;
            port ledPort : DigitalOutput;
            port serialPort : SerialLink;
            attribute maxTemp : TemperatureValue = 30;
            attribute maxHumid : HumidityValue = 80;

            action initialize : Initialize;
            action readTempHumid : ReadTempHumid;
            action readLight : ReadLight;
            action updateDisplay : UpdateDisplay;
            action soundBuzzer : SoundBuzzer;
            action illuminateLED : IlluminateLED;
            action buildRecord : BuildRecord;
            action transmitRecord : TransmitRecord;

            exhibit state monitorStates {
                entry; then initialization;

                state initialization;
                accept InitComplete
                    then normalMonitoring;

                state normalMonitoring {
                    do readTempHumid;
                    do readLight;
                    do updateDisplay;
                    do buildRecord;
                    do transmitRecord;
                }
                accept ThresholdExceeded
                    then activeAlert;

                state activeAlert {
                    entry soundBuzzer;
                    entry illuminateLED;
                    do readTempHumid;
                    do readLight;
                    do updateDisplay;
                    do buildRecord;
                    do transmitRecord;
                }
                accept ThresholdRestored
                    then normalMonitoring;
            }
        }

        part def EnvironmentalMonitor {
            part arduino : ArduinoMicrocontroller;
            part tempHumidSensor : TempHumidSensor;
            part lightSensor : LightSensor;
            part lcdDisplay : LCDDisplay;
            part buzzer : Buzzer;
            part statusLED : StatusLED;
            part dataLogger : DataLogger;

            connect arduino.tempHumidPort to tempHumidSensor.i2c;
            connect arduino.lightPort to lightSensor.analog;
            connect arduino.displayPort to lcdDisplay.display;
            connect arduino.buzzerPort to buzzer.control;
            connect arduino.ledPort to statusLED.control;
            connect arduino.serialPort to dataLogger.serialInput;

            flow tempHumidFlow of TempHumidData
                from tempHumidSensor.i2c.data to arduino.tempHumidPort.data;
            flow lightFlow of LightData
                from lightSensor.analog.data to arduino.lightPort.data;
            flow displayFlow of DisplayContent
                from arduino.displayPort.content to lcdDisplay.display.content;
            flow buzzerFlow of AlertEvent
                from arduino.buzzerPort.signal to buzzer.control.signal;
            flow ledFlow of AlertEvent
                from arduino.ledPort.signal to statusLED.control.signal;
            flow serialFlow of SensorRecord
                from arduino.serialPort.record to dataLogger.serialInput.record;
        }
    }

    package Usages {
        private import Definitions::*;

        part monitor : EnvironmentalMonitor;

        requirement def EnvironmentalMonitoringRequirement {
            doc "The system shall provide real-time environmental monitoring for indoor spaces to ensure conditions remain within safe and comfortable ranges for sensitive equipment or living spaces.";
        }

        requirement temperatureMeasurement : EnvironmentalMonitoringRequirement {
            doc "The system shall measure temperature using a dedicated temperature and humidity sensor.";
        }

        requirement humidityMeasurement : EnvironmentalMonitoringRequirement {
            doc "The system shall measure humidity using a dedicated temperature and humidity sensor.";
        }

        requirement lightMeasurement : EnvironmentalMonitoringRequirement {
            doc "The system shall measure ambient light levels using a dedicated light sensor.";
        }

        requirement displayVisualization : EnvironmentalMonitoringRequirement {
            doc "The system shall display real-time temperature, humidity, and light level readings on a 16x2 character LCD display.";
        }

        requirement automatedAlert : EnvironmentalMonitoringRequirement {
            doc "When measured temperature or humidity exceeds predefined safe thresholds, the system shall activate both an audible buzzer alarm and a red LED visual indicator immediately.";
        }

        requirement dataLogging : EnvironmentalMonitoringRequirement {
            doc "The system shall transmit sensor data including temperature, humidity, light level, and timestamp via a serial communication port for external data logging.";
        }

        requirement operationalStates : EnvironmentalMonitoringRequirement {
            doc "The system shall operate in a continuous cycle through initialization, normal monitoring, and active alert states, transitioning based on environmental conditions.";
        }
    }
}
