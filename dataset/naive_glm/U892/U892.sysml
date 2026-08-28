package VehicleSpeedometerSystem {

    import ScalarValues::*;

    package Units {
        unit m;
        unit s;
        unit ms = s / 1000;
        unit Hz = 1 / s;
        unit m_per_s = m / s;
        unit km = 1000 * m;
        unit h = 3600 * s;
        unit km_per_h = km / h;
        unit mi = 1609.344 * m;
        unit mi_per_h = mi / h;
        unit percent = 0.01;
    }

    import Units::*;

    // ---- Value types ----
    value def WheelCircumference :> Real { unit = m; }
    value def WheelRadius :> Real { unit = m; }
    value def RotationalFrequency :> Real { unit = Hz; }
    value def Timestamp :> Real { unit = s; }
    value def LinearSpeed :> Real { unit = m_per_s; }
    value def DisplaySpeed :> Real { unit = km_per_h; }
    value def UpdateRate :> Real { unit = Hz; }
    value def ResponseTime :> Real { unit = ms; }
    value def AccuracyPercent :> Real { unit = percent; }

    // ---- Enumerations ----
    enum def SpeedDisplayUnit {
        kmh;
        mph;
    }

    // ---- Item definitions ----
    item def WheelRotationSignal {
        attribute frequency : RotationalFrequency;
        attribute timestamp : Timestamp;
    }

    item def SpeedCommand {
        attribute speed : LinearSpeed;
        attribute timestamp : Timestamp;
        attribute targetUnit : SpeedDisplayUnit;
    }

    // ---- Port definitions ----
    port def RotationSignalOut {
        out signal : WheelRotationSignal;
    }

    port def RotationSignalIn {
        in signal : WheelRotationSignal;
    }

    port def SpeedCommandOut {
        out command : SpeedCommand;
    }

    port def SpeedCommandIn {
        in command : SpeedCommand;
    }

    // ---- Wheel speed sensor ----
    part def WheelSpeedSensor {
        attribute wheelCircumference : WheelCircumference = 2.0 [m];
        attribute samplingRate : UpdateRate = 100 [Hz];
        port rotationOut : RotationSignalOut;

        action def SenseRotation {
            in circumference : WheelCircumference;
            out signal : WheelRotationSignal;
        }

        perform action sense : SenseRotation {
            in circumference = wheelCircumference;
            out signal to rotationOut.signal;
        }
    }

    // ---- Speed calculation processor ----
    part def SpeedCalculationProcessor {
        attribute wheelRadius : WheelRadius = 0.318 [m];
        attribute processingLatency : ResponseTime = 5 [ms];
        port rotationIn : RotationSignalIn;
        port speedOut : SpeedCommandOut;

        action def CalculateSpeed {
            in signal : WheelRotationSignal;
            in radius : WheelRadius;
            out command : SpeedCommand;
        }

        perform action calculate : CalculateSpeed {
            in signal from rotationIn.signal;
            in radius = wheelRadius;
            out command to speedOut.command;
        }
    }

    // ---- Digital display ----
    part def DigitalDisplay {
        attribute displayUnit : SpeedDisplayUnit = SpeedDisplayUnit::kmh;
        attribute updateRate : UpdateRate = 10 [Hz];
        attribute responseTime : ResponseTime = 100 [ms];
        attribute accuracyError : AccuracyPercent = 0.01 [percent];
        port speedIn : SpeedCommandIn;

        state def DisplayState {
            entry; then off;

            state off {
                entry {
                    // display blank
                }
            }

            state on {
                entry {
                    // show last known speed
                }
            }

            state updating {
                entry {
                    // refresh speed reading
                }
            }

            transition off_to_on
                first off
                accept PowerOn
                then on;

            transition on_to_updating
                first on
                accept SpeedUpdate
                then updating;

            transition updating_to_on
                first updating
                accept UpdateComplete
                then on;

            transition on_to_off
                first on
                accept PowerOff
                then off;

            transition updating_to_off
                first updating
                accept PowerOff
                then off;
        }

        perform state behavior : DisplayState;

        action def RenderSpeed {
            in command : SpeedCommand;
            in unit : SpeedDisplayUnit;
        }

        perform action render : RenderSpeed {
            in command from speedIn.command;
            in unit = displayUnit;
        }
    }

    // ---- System composition ----
    part def SpeedometerSystem {
        attribute responseTime : ResponseTime;
        attribute accuracyError : AccuracyPercent;

        part sensor : WheelSpeedSensor {
            redefines wheelCircumference = 2.0 [m];
        }

        part processor : SpeedCalculationProcessor {
            redefines wheelRadius = 0.318 [m];
        }

        part display : DigitalDisplay {
            redefines displayUnit = SpeedDisplayUnit::kmh;
        }

        connect sensor.rotationOut to processor.rotationIn;
        connect processor.speedOut to display.speedIn;
    }

    // ---- Requirements ----
    requirement def UpdateRateRequirement {
        subject displayUnit : DigitalDisplay;
        attribute minUpdateRate : UpdateRate = 5 [Hz];
        require { displayUnit.updateRate >= minUpdateRate }
    }

    requirement def ResponsivenessRequirement {
        subject system : SpeedometerSystem;
        attribute maxResponseTime : ResponseTime = 150 [ms];
        require { system.responseTime <= maxResponseTime }
    }

    requirement def AccuracyRequirement {
        subject system : SpeedometerSystem;
        attribute maxError : AccuracyPercent = 0.02 [percent];
        require { system.accuracyError <= maxError }
    }

    requirement def DisplayUnitConfigurationRequirement {
        subject displayUnit : DigitalDisplay;
        require { displayUnit.displayUnit == SpeedDisplayUnit::kmh or
                  displayUnit.displayUnit == SpeedDisplayUnit::mph }
    }

    requirement def SensorConfigurationRequirement {
        subject sensorUnit : WheelSpeedSensor;
        require { sensorUnit.wheelCircumference > 0 [m] }
    }

    requirement def ProcessorConfigurationRequirement {
        subject processorUnit : SpeedCalculationProcessor;
        require { processorUnit.wheelRadius > 0 [m] }
    }

    // ---- Requirement satisfaction ----
    part speedometerInstance : SpeedometerSystem {
        redefines responseTime = 120 [ms];
        redefines accuracyError = 0.015 [percent];

        part sensor : WheelSpeedSensor {
            redefines wheelCircumference = 1.995 [m];
        }

        part processor : SpeedCalculationProcessor {
            redefines wheelRadius = 0.3175 [m];
        }

        part display : DigitalDisplay {
            redefines updateRate = 10 [Hz];
            redefinitions responseTime = 80 [ms];
            redefinitions accuracyError = 0.01 [percent];
        }

        satisfy ur : UpdateRateRequirement by display;
        satisfy rr : ResponsivenessRequirement by speedometerInstance;
        satisfy ar : AccuracyRequirement by speedometerInstance;
        satisfy ducr : DisplayUnitConfigurationRequirement by display;
        satisfy scr : SensorConfigurationRequirement by sensor;
        satisfy pcr : ProcessorConfigurationRequirement by processor;
    }

}
