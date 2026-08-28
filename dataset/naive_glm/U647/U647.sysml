package UnderwaterDepthGauge {

    import ScalarValues::*;
    import ISQ::*;

    // ---------- Value types with units ----------
    value def PressureValue :> Real {
        unit mbar;
    }

    value def TemperatureValue :> Real {
        unit '°C';
    }

    value def DepthValue :> Real {
        unit m;
    }

    value def DensityValue :> Real {
        unit 'kg/m^3';
    }

    value def VoltageValue :> Real {
        unit V;
    }

    value def BatteryLevel :> Real {
        unit '%';
    }

    // ---------- Item definitions ----------
    item def PressureReading {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
    }

    item def DepthResult {
        attribute depth : DepthValue;
        attribute mode : String;
        attribute alert : String;
    }

    item def DisplayCommand {
        attribute depth : DepthValue;
        attribute mode : String;
        attribute alert : String;
    }

    // ---------- Requirements ----------
    requirement def HousingRequirement {
        subject housing : Housing;
        requirement
            housing.material == "Titanium" and
            housing.ratedDepth >= 200 [m];
    }

    requirement def OperatingRangeRequirement {
        subject gauge : DepthGauge;
        requirement
            gauge.operatingDepthMax == 100 [m] and
            gauge.warningDepth == 40 [m] and
            gauge.criticalDepth == 70 [m];
    }

    requirement def MeasurementAccuracyRequirement {
        subject gauge : DepthGauge;
        requirement
            gauge.measurementAccuracy <= 0.1 [m];
    }

    requirement def PowerRequirement {
        subject battery : Battery;
        requirement
            battery.nominalVoltage == 3.6 [V] and
            battery.capacity >= 1500 [mAh];
    }

    // ---------- Parts ----------

    part def Housing {
        attribute material : String = "Titanium";
        attribute ratedDepth : DepthValue = 200 [m];
        attribute waterproof : Boolean = true;
    }

    part def Battery {
        attribute nominalVoltage : VoltageValue = 3.6 [V];
        attribute capacity : Integer = 1800; // mAh
        attribute level : BatteryLevel = 100 [%];
        port powerOut : 'PowerOut';
    }

    part def PressureSensor {
        attribute precision : PressureValue = 0.5 [mbar];
        port pressureIn : 'PressureIn';
        port dataOut : 'SensorDataOut';
        port powerIn : 'PowerIn';

        action def sense : PressureReading {
            in p : PressureValue;
            in t : TemperatureValue;
        }
    }

    part def Processor {
        attribute atmosphericPressure : PressureValue = 1013.25 [mbar];
        attribute waterDensity : DensityValue = 1025 ['kg/m^3'];
        attribute warningDepth : DepthValue = 40 [m];
        attribute criticalDepth : DepthValue = 70 [m];
        attribute operatingDepthMax : DepthValue = 100 [m];
        attribute measurementAccuracy : DepthValue = 0.1 [m];

        port sensorDataIn : 'SensorDataIn';
        port displayOut : 'DisplayOut';
        port powerIn : 'PowerIn';

        action def calculateDepth : DepthValue {
            in reading : PressureReading;
            return depth : DepthValue = (reading.pressure - atmosphericPressure) * 100 / (waterDensity * 9.81);
        }

        action def checkLimits : String {
            in depth : DepthValue;
            return alert : String =
                depth >= criticalDepth ? "CRITICAL" :
                depth >= warningDepth ? "WARNING" : "NONE";
        }

        state machine def ProcessorStates {
            state initializing {
                entry action selfTest;
                do action calibrate;
            }
            state measuring {
                do action senseCalculateDisplay;
            }
            state alarm {
                entry action triggerAlert;
                do action senseCalculateDisplay;
            }
            transition initializing_to_measuring
                from initializing to measuring
                when selfTestComplete;
            transition measuring_to_alarm
                from measuring to alarm
                when currentDepth >= warningDepth;
            transition alarm_to_measuring
                from alarm to measuring
                when currentDepth < warningDepth and alarmCleared;
        }
    }

    part def DisplayUnit {
        port displayIn : 'DisplayIn';
        port powerIn : 'PowerIn';

        action def render {
            in command : DisplayCommand;
        }
    }

    // ---------- Port definitions ----------
    port def 'PowerOut' {
        out voltage : VoltageValue;
    }

    port def 'PowerIn' {
        in voltage : VoltageValue;
    }

    port def 'PressureIn' {
        in pressure : PressureValue;
        in temperature : TemperatureValue;
    }

    port def 'SensorDataOut' {
        out reading : PressureReading;
    }

    port def 'SensorDataIn' {
        in reading : PressureReading;
    }

    port def 'DisplayOut' {
        out command : DisplayCommand;
    }

    port def 'DisplayIn' {
        in command : DisplayCommand;
    }

    // ---------- Top-level part ----------
    part def DepthGauge {

        attribute operatingDepthMax : DepthValue = 100 [m];
        attribute warningDepth : DepthValue = 40 [m];
        attribute criticalDepth : DepthValue = 70 [m];
        attribute measurementAccuracy : DepthValue = 0.1 [m];

        part housing : Housing {
            satisfy HousingRequirement;
        }

        part battery : Battery {
            satisfy PowerRequirement;
        }

        part pressureSensor : PressureSensor {
            port powerIn : 'PowerIn';
            port dataOut : 'SensorDataOut';
            port pressureIn : 'PressureIn';
        }

        part processor : Processor {
            port sensorDataIn : 'SensorDataIn';
            port displayOut : 'DisplayOut';
            port powerIn : 'PowerIn';
        }

        part display : DisplayUnit {
            port displayIn : 'DisplayIn';
            port powerIn : 'PowerIn';
        }

        // Power distribution
        connection battery.powerOut to pressureSensor.powerIn;
        connection battery.powerOut to processor.powerIn;
        connection battery.powerOut to display.powerIn;

        // Data flow
        connection pressureSensor.dataOut to processor.sensorDataIn;
        connection processor.displayOut to display.displayIn;

        // Environmental pressure input to sensor
        flow ambientPressure : PressureValue to pressureSensor.pressureIn.pressure;
        flow ambientTemperature : TemperatureValue to pressureSensor.pressureIn.temperature;

        // Behavioral state machine for the overall device
        state machine def DepthGaugeStates {

            attribute currentDepth : DepthValue = 0 [m];
            attribute currentMode : String = "OFF";
            attribute currentAlert : String = "NONE";
            attribute selfTestComplete : Boolean = false;
            attribute alarmCleared : Boolean = false;

            state off {
                entry action currentMode = "OFF";
            }

            state initializing {
                entry action currentMode = "INIT";
                do action performSelfTest;
                do action performCalibration;
            }

            state measuring {
                entry action currentMode = "MEASURE";
                do action senseCalculateDisplay;
            }

            state alarm {
                entry action currentMode = "ALARM";
                do action triggerAlert;
                do action senseCalculateDisplay;
            }

            transition off_to_initializing
                from off to initializing
                when powerOn;

            transition initializing_to_measuring
                from initializing to measuring
                when selfTestComplete;

            transition measuring_to_alarm
                from measuring to alarm
                when currentDepth >= warningDepth;

            transition alarm_to_measuring
                from alarm to measuring
                when currentDepth < warningDepth and alarmCleared;

            action performSelfTest {
                // Run internal diagnostics
            }

            action performCalibration {
                // Calibrate pressure sensor against atmospheric pressure
            }

            action senseCalculateDisplay {
                // Read sensor, compute depth, check limits, update display
            }

            action triggerAlert {
                // Activate audible/visual alarm
            }
        }

        satisfy OperatingRangeRequirement;
        satisfy MeasurementAccuracyRequirement;
    }

}
