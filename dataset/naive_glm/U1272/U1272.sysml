package EnvironmentalMonitoringSystem {

    import ScalarValues::*;

    // ========== Units ==========

    unit Celsius { 
        /* degrees Celsius */
    }

    unit PercentRelativeHumidity {
        /* percentage, 0-100 */
    }

    unit Lux {
        /* illuminance */
    }

    unit Hertz {
        /* frequency */
    }

    unit Millisecond {
        /* time */
    }

    // ========== Value Types ==========

    value type Temperature :> Real {
        :>> unit = Celsius;
        attribute minSafe : Temperature = 10 [Celsius];
        attribute maxSafe : Temperature = 35 [Celsius];
    }

    value type Humidity :> Real {
        :>> unit = PercentRelativeHumidity;
        attribute minSafe : Humidity = 20 [PercentRelativeHumidity];
        attribute maxSafe : Humidity = 70 [PercentRelativeHumidity];
    }

    value type Illuminance :> Real {
        :>> unit = Lux;
        attribute comfortableMin : Illuminance = 50 [Lux];
        attribute comfortableMax : Illuminance = 1000 [Lux];
    }

    // ========== Item Types ==========

    item def SensorReading {
        attribute temperature : Temperature;
        attribute humidity : Humidity;
        attribute lightLevel : Illuminance;
        attribute timestamp : String;
    }

    item def AlertEvent {
        attribute triggeredBy : String;
        attribute measuredTemperature : Temperature;
        attribute measuredHumidity : Humidity;
        attribute timestamp : String;
    }

    item def SerialPacket {
        attribute payload : String;
        attribute timestamp : String;
        attribute checksum : Integer;
    }

    // ========== Port Definitions ==========

    port def TempHumDataPort {
        out reading : SensorReading;
    }

    port def LightDataPort {
        out illuminance : Illuminance;
    }

    port def DisplayCommandPort {
        in line1 : String;
        in line2 : String;
    }

    port def AudioOutputPort {
        out toneActive : Boolean;
    }

    port def LEDOutputPort {
        out illuminated : Boolean;
    }

    port def SerialDataPort {
        out transmitted : SerialPacket;
        in received : SerialPacket;
    }

    // ========== Component Part Definitions ==========

    part def TempHumiditySensor {
        attribute samplePeriod : Integer = 2000 [Millisecond];
        attribute accuracy : Real = 0.5 [Celsius];
        attribute humidityAccuracy : Real = 2.0 [PercentRelativeHumidity];
        port tempHumOut : TempHumDataPort;
        exhibit action sampleSensor {
            /* Reads temperature and humidity from physical sensor elements */
        }
        perform sampleSensor;
    }

    part def AmbientLightSensor {
        attribute samplePeriod : Integer = 1000 [Millisecond];
        attribute maxRange : Illuminance = 6000 [Lux];
        port lightOut : LightDataPort;
        exhibit action readLight {
            /* Performs analog-to-digital conversion of photodiode output */
        }
        perform readLight;
    }

    part def CharacterLCD16x2 {
        attribute cols : Integer = 16;
        attribute rows : Integer = 2;
        attribute backlit : Boolean = true;
        port displayIn : DisplayCommandPort;
        exhibit action renderText {
            /* Renders two 16-character lines to the LCD panel */
        }
        perform renderText;
    }

    part def PiezoBuzzer {
        attribute resonantFrequency : Real = 4000.0 [Hertz];
        attribute soundPressureLevel : Real = 85.0 [dB];
        port buzzerIn : AudioOutputPort;
        exhibit action emitTone {
            /* Generates audible alert tone */
        }
        perform emitTone;
    }

    part def RedIndicatorLED {
        attribute forwardVoltage : Real = 2.0 [V];
        attribute luminousIntensity : Real = 800.0 [mcd];
        port ledIn : LEDOutputPort;
        exhibit action illuminate {
            /* Drives LED ON when over-threshold alert is active */
        }
        perform illuminate;
    }

    part def ArduinoMicrocontroller {
        attribute clockFrequency : Real = 16.0e6 [Hertz];
        attribute memoryFlashKB : Integer = 32;
        attribute memorySRAMKB : Integer = 2;
        attribute analogInputPins : Integer = 6;
        attribute digitalPins : Integer = 14;
        attribute temperatureThreshold : Temperature = 35 [Celsius];
        attribute humidityThreshold : Humidity = 70 [PercentRelativeHumidity];

        port tempHumIn : TempHumDataPort;
        port lightIn : LightDataPort;
        port displayOut : DisplayCommandPort;
        port buzzerOut : AudioOutputPort;
        port ledOut : LEDOutputPort;
        port serialIO : SerialDataPort;

        exhibit stateMachine MonitoringController {

            state Initialization {
                entry action initSequence {
                    /* Power-up self-test, configure peripherals, set I/O modes */
                }
                do action bootWait {
                    /* Wait for sensors to stabilize */
                }
            }

            state NormalMonitoring {
                entry action enterMonitoring {
                    /* Clear any alert, dim indicators */
                }
                do action continuousSampling {
                    /* Acquire sensor samples at scheduled intervals */
                }
                do action refreshDisplay {
                    /* Update LCD with current readings */
                }
                do action transmitSerial {
                    /* Send timestamped sensor packet over serial port */
                }
            }

            state AlertActive {
                entry action raiseAlert {
                    /* Activate buzzer and red LED */
                }
                do action emitAudio {
                    /* Maintain audible alarm */
                }
                do action maintainVisualIndicator {
                    /* Maintain red LED lit */
                }
                do action persistAlertDisplay {
                    /* Show alert message on LCD */
                }
                exit action clearAlert {
                    /* De-activate buzzer and red LED */
                }
            }

            transition t_init_to_monitor
                first Initialization then NormalMonitoring
                if true;

            transition t_monitor_to_alert
                from NormalMonitoring to AlertActive
                if (tempHumIn.reading.temperature > temperatureThreshold) or
                   (tempHumIn.reading.humidity > humidityThreshold);

            transition t_alert_to_monitor
                from AlertActive to NormalMonitoring
                if (tempHumIn.reading.temperature <= temperatureThreshold) and
                   (tempHumIn.reading.humidity <= humidityThreshold);
        }

        perform MonitoringController;
    }

    // ========== Top-Level System Assembly ==========

    part EnvironmentalMonitor {
        part mcu : ArduinoMicrocontroller;
        part tempHumSensor : TempHumiditySensor;
        part lightSensor : AmbientLightSensor;
        part display : CharacterLCD16x2;
        port alertBuzzer : PiezoBuzzer;
        port alertLED : RedIndicatorLED;

        // Internal connections
        connection tempHumBus connect
            tempHumSensor.tempHumOut to mcu.tempHumIn;

        connection lightSensorWire connect
            lightSensor.lightOut to mcu.lightIn;

        connection displayDriver connect
            mcu.displayOut to display.displayIn;

        connection buzzerDrive connect
            mcu.buzzerOut to alertBuzzer.buzzerIn;

        connection ledDrive connect
            mcu.ledOut to alertLED.ledIn;

        // External serial port exposed to user
        port externalSerial : SerialDataPort;
        connection serialLink connect
            mcu.serialIO to externalSerial;
    }

    // ========== Requirements ==========

    requirement def EnvironmentalMonitoringSystemRequirement {
        doc
            /* Arduino-based real-time indoor environmental monitoring
               system for temperature, humidity, and ambient light. */
        subject : EnvironmentalMonitor;
        objective
            /* Ensure environmental parameters remain within safe range
               for sensitive equipment or living spaces. */
    }

    requirement def ContinuousSensingRequirement {
        doc
            /* The system shall continuously monitor temperature, humidity,
               and ambient light levels in real time. */
        subject : EnvironmentalMonitor;
        satisfy by mcu;
    }

    requirement def DisplayReadingsRequirement {
        doc
            /* The system shall display current temperature, humidity,
               and light readings on a 16x2 character LCD display. */
        subject : display;
        satisfy by display;
    }

    requirement def ThresholdAlertRequirement {
        doc
            /* When measured temperature or humidity exceeds predefined safe
               thresholds, the system shall activate both an audible buzzer
               and a visual red LED indicator. */
        subject : EnvironmentalMonitor;
        satisfy by alertBuzzer;
        satisfy by alertLED;
        attribute temperatureLimit : Temperature = 35 [Celsius];
        attribute humidityLimit : Humidity = 70 [PercentRelativeHumidity];
    }

    requirement def SerialTransmissionRequirement {
        doc
            /* The system shall transmit sensor data with timestamps via a
               serial communication port for external logging. */
        subject : externalSerial;
        satisfy by externalSerial;
    }

    requirement def StateMachineBehaviorRequirement {
        doc
            /* The system shall cycle through initialization, normal
               monitoring, and alert states based on sensor conditions. */
        subject : mcu;
        satisfy by mcu::MonitoringController;
    }

    requirement EnvironmentalMonitoringReq : EnvironmentalMonitoringSystemRequirement;
    requirement ContinuousSensingReq : ContinuousSensingRequirement;
    requirement DisplayReadingsReq : DisplayReadingsRequirement;
    requirement ThresholdAlertReq : ThresholdAlertRequirement;
    requirement SerialTransmissionReq : SerialTransmissionRequirement;
    requirement StateMachineBehaviorReq : StateMachineBehaviorRequirement;

    // ========== Requirement Satisfaction ==========

    satisfaction ContinuousSensingReq satisfy mcu;
    satisfaction DisplayReadingsReq satisfy display;
    satisfaction ThresholdAlertReq satisfy alertBuzzer;
    satisfaction ThresholdAlertReq satisfy alertLED;
    satisfaction SerialTransmissionReq satisfy externalSerial;
    satisfaction StateMachineBehaviorReq satisfy mcu::MonitoringController;

}
