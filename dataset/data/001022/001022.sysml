package DepthGaugeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def DepthValue :> LengthValue;
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def TemperatureValue :> ThermodynamicTemperatureValue;
    attribute def DensityValue :> ISQ::DensityValue;
    
    enum def OperatingMode {
        off;
        initializing;
        measuring;
        calibrating;
        alarm;
    }
    
    enum def AlarmState {
        normal;
        warning;
        critical;
    }
    
    item def WaterMedium {
        attribute density : DensityValue;
        attribute temperature : TemperatureValue;
    }
    
    port def PressureSensorPort {
        out pressure : PressureValue;
        out temperature : TemperatureValue;
    }
    
    port def DisplayPort {
        in depth : DepthValue;
        in mode : OperatingMode;
        in alarm : AlarmState;
    }
    
    port def ControlPort {
        in command : String;
        out status : String;
    }
    
    constraint def DepthCalculation {
        in pressure : PressureValue;
        in atmosphericPressure : PressureValue;
        in waterDensity : DensityValue;
        in gravity : AccelerationValue;
        out depth : DepthValue;
        depth == (pressure - atmosphericPressure) / (waterDensity * gravity)
    }
    
    action def MeasurePressure {
        out pressure : PressureValue;
        out temperature : TemperatureValue;
    }
    
    action def CalculateDepth {
        in pressure : PressureValue;
        in temperature : TemperatureValue;
        out depth : DepthValue;
    }
    
    action def UpdateDisplay {
        in depth : DepthValue;
        in mode : OperatingMode;
        in alarm : AlarmState;
    }
    
    action def CheckAlarms {
        in depth : DepthValue;
        out alarmState : AlarmState;
    }
    
    action def DepthMonitoringCycle {
        first start;
        then merge continueMonitoring;
        
        then action measure : MeasurePressure {
            out measuredPressure : PressureValue;
            out measuredTemp : TemperatureValue;
        }
        
        then action calculate : CalculateDepth {
            in pressure = measure.measuredPressure;
            in temperature = measure.measuredTemp;
            out calculatedDepth : DepthValue;
        }
        
        then action checkAlarm : CheckAlarms {
            in depth = calculate.calculatedDepth;
            out alarm : AlarmState;
        }
        
        then action display : UpdateDisplay {
            in depth = calculate.calculatedDepth;
            in mode = OperatingMode::measuring;
            in alarm = checkAlarm.alarm;
        }
        
        then decide;
            if checkAlarm.alarm == AlarmState::critical then handleCriticalAlarm;
            if checkAlarm.alarm != AlarmState::critical then continueMonitoring;
        
        action handleCriticalAlarm;
        then continueMonitoring;
    }
    
    state def DepthGaugeStateMachine {
        entry; then off;
        
        state off;
        
        transition powerOn
            first off
            accept PowerOnEvent
            then initializing;
        
        state initializing {
            entry; then selfTest;
            state selfTest;
            then calibration;
            state calibration;
        }
        
        transition initComplete
            first initializing
            accept InitCompleteEvent
            then measuring;
        
        state measuring {
            entry; then normalOperation;
            
            state normalOperation;
            
            transition depthExceeded
                first normalOperation
                accept DepthExceededEvent
                then alarm;
        }
        
        state alarm {
            entry; then alerting;
            state alerting;
        }
        
        transition alarmCleared
            first alarm
            accept AlarmClearedEvent
            then measuring;
        
        transition powerOff
            first measuring
            accept PowerOffEvent
            then off;
        
        transition emergencyShutdown
            first alarm
            accept EmergencyShutdownEvent
            then off;
    }
    
    part def PressureSensor {
        attribute accuracy : Real;
        attribute maxPressure : PressureValue;
        attribute responseTime : Real;
        
        port sensorOutput : PressureSensorPort;
        
        perform action sense : MeasurePressure;
    }
    
    part def ProcessingUnit {
        attribute atmosphericPressure : PressureValue;
        attribute waterDensity : DensityValue;
        attribute gravity : AccelerationValue;
        attribute currentDepth : DepthValue;
        attribute warningDepth : DepthValue;
        attribute criticalDepth : DepthValue;
        
        port sensorInput : ~PressureSensorPort;
        port displayOutput : DisplayPort;
        port control : ControlPort;
        
        assert constraint depthCalc : DepthCalculation {
            in pressure = sensorInput.pressure;
            in atmosphericPressure = atmosphericPressure;
            in waterDensity = waterDensity;
            in gravity = gravity;
            out depth = currentDepth;
        }
        
        perform action compute : CalculateDepth;
        perform action evaluate : CheckAlarms;
        
        state operatingState : DepthGaugeStateMachine;
    }
    
    part def DisplayUnit {
        attribute brightness : Real;
        attribute refreshRate : Real;
        attribute resolution : String;
        
        port input : ~DisplayPort;
        
        perform action show : UpdateDisplay;
    }
    
    part def PowerSupply {
        attribute voltage : Real;
        attribute capacity : Real;
        attribute batteryLevel : Real;
    }
    
    part def WaterproofHousing {
        attribute maxDepthRating : DepthValue;
        attribute material : String;
        attribute sealIntegrity : Real;
    }
    
    part def DepthGauge {
        doc /*
         * A depth gauge system that measures underwater depth by sensing ambient
         * water pressure and converting it to depth readings. The system continuously
         * monitors depth, displays real-time information to the user, and provides
         * alarm notifications when depth exceeds safe operating limits.
         */
        
        attribute operatingRange : DepthValue;
        attribute measurementAccuracy : Real;
        attribute updateFrequency : Real;
        
        part sensor : PressureSensor {
            attribute :>> accuracy = 0.005;
            attribute :>> maxPressure = 2000000.0 [Pa];
            attribute :>> responseTime = 0.1;
        }
        
        part processor : ProcessingUnit {
            attribute :>> atmosphericPressure = 101325.0 [Pa];
            attribute :>> waterDensity = 1025.0 [kg/m^3];
            attribute :>> gravity = 9.81 [m/s^2];
            attribute :>> warningDepth = 80.0 [m];
            attribute :>> criticalDepth = 95.0 [m];
        }
        
        part display : DisplayUnit {
            attribute :>> brightness = 100.0;
            attribute :>> refreshRate = 2.0;
            attribute :>> resolution = "320x240";
        }
        
        part power : PowerSupply {
            attribute :>> voltage = 3.7;
            attribute :>> capacity = 3000.0;
            attribute :>> batteryLevel = 100.0;
        }
        
        part housing : WaterproofHousing {
            attribute :>> maxDepthRating = 150.0 [m];
            attribute :>> material = "Titanium";
            attribute :>> sealIntegrity = 100.0;
        }
        
        connection sensorToProcessor connect sensor.sensorOutput to processor.sensorInput;
        connection processorToDisplay connect processor.displayOutput to display.input;
        
        perform action monitorDepth : DepthMonitoringCycle {
            action measure : MeasurePressure;
            action calculate : CalculateDepth {
                in pressure = measure.pressure;
                in temperature = measure.temperature;
                out depth = processor.currentDepth;
            }
            action checkAlarm : CheckAlarms {
                in depth = calculate.depth;
                out alarmState;
            }
            action display : UpdateDisplay {
                in depth = calculate.depth;
                in mode = OperatingMode::measuring;
                in alarm = checkAlarm.alarmState;
            }
        }
    }
    
    requirement <'REQ-DG-100'> primaryFunction {
        doc /*
         * The depth gauge system shall measure and display underwater depth by
         * continuously sensing ambient water pressure, converting pressure readings
         * to depth values, and presenting real-time depth information to the user
         * with alarm notifications for depth limit violations.
         */
        subject gauge : DepthGauge;
        
        require <'REQ-DG-101'> pressureSensing {
            doc /*
             * The system shall continuously sense ambient water pressure with
             * high accuracy and minimal response time.
             */
        }
        
        require <'REQ-DG-102'> depthConversion {
            doc /*
             * The system shall convert pressure readings to depth values using
             * the hydrostatic pressure equation accounting for water density
             * and gravitational acceleration.
             */
        }
        
        require <'REQ-DG-103'> displayUpdate {
            doc /*
             * The system shall update the displayed depth information at least
             * twice per second during normal operation.
             */
        }
        
        require <'REQ-DG-104'> alarmMonitoring {
            doc /*
             * The system shall monitor depth against configured warning and
             * critical thresholds and activate appropriate alarms.
             */
        }
    }
    
    requirement <'REQ-DG-200'> accuracyRequirement {
        doc /*
         * The depth gauge shall maintain measurement accuracy within 0.5% of
         * actual depth across the entire operating range.
         */
        subject sensor :>> DepthGauge::sensor;
        
        assert constraint {
            sensor.accuracy <= 0.005
        }
    }
    
    requirement <'REQ-DG-201'> operatingRangeRequirement {
        doc /*
         * The depth gauge shall accurately measure depth from 0 to 100 meters
         * in saltwater conditions.
         */
        subject gauge :>> DepthGauge::depthGauge;
        
        assert constraint {
            gauge.operatingRange >= 100.0 [m]
        }
    }
    
    requirement <'REQ-DG-202'> housingIntegrityRequirement {
        doc /*
         * The housing shall maintain waterproof integrity to a depth rating
         * of at least 150 meters, providing 50% safety margin beyond the
         * operating range.
         */
        subject housing :>> DepthGauge::housing;
        
        assert constraint {
            housing.maxDepthRating >= 150.0 [m]
        }
    }
    
    requirement <'REQ-DG-203'> responseTimeRequirement {
        doc /*
         * The pressure sensor shall respond to pressure changes within
         * 100 milliseconds to enable real-time depth tracking.
         */
        subject sensor :>> DepthGauge::sensor;
        
        assert constraint {
            sensor.responseTime <= 0.1
        }
    }
    
    part depthGauge : DepthGauge {
        attribute :>> operatingRange = 100.0 [m];
        attribute :>> measurementAccuracy = 0.005;
        attribute :>> updateFrequency = 2.0;
    }
    
    satisfy primaryFunction by depthGauge;
    satisfy accuracyRequirement by depthGauge.sensor;
    satisfy operatingRangeRequirement by depthGauge;
    satisfy housingIntegrityRequirement by depthGauge.housing;
    satisfy responseTimeRequirement by depthGauge.sensor;
}
