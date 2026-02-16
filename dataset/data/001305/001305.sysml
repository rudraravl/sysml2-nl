package VariometerSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def VerticalSpeedValue :> ISQ::SpeedValue;
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def AltitudeValue :> ISQ::LengthValue;
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def FrequencyValue :> ISQ::FrequencyValue;
    attribute def TimeValue :> ISQ::TimeValue;

    attribute def PowerCommand;
    attribute def CalibrationCommand;

    item def PressureReading {
        attribute staticPressure : PressureValue;
        attribute dynamicPressure : PressureValue;
        attribute timestamp : TimeValue;
    }

    item def VerticalSpeedData {
        attribute rawVerticalSpeed : VerticalSpeedValue;
        attribute compensatedVerticalSpeed : VerticalSpeedValue;
        attribute altitude : AltitudeValue;
    }

    item def AudioToneSignal {
        attribute frequency : FrequencyValue;
        attribute enabled : Boolean;
    }

    port def PressureInputPort {
        in staticP : PressureValue;
        in dynamicP : PressureValue;
    }

    port def PressureDataPort {
        out reading : PressureReading;
    }

    port def VerticalSpeedPort {
        out vsData : VerticalSpeedData;
    }

    port def DisplayPort {
        in vsData : VerticalSpeedData;
    }

    port def AudioPort {
        in toneSignal : AudioToneSignal;
    }

    part def PressureSensor {
        doc /* Measures static and dynamic atmospheric pressure. */
        
        port pressureInput : PressureInputPort;
        port dataOutput : PressureDataPort;
        
        attribute sampleRate : Real := 10.0;
        attribute accuracy : PressureValue;
    }

    part def ComputationUnit {
        doc /* Processes pressure data to calculate vertical speed with Total Energy compensation. */
        
        port pressureInput {
            in reading : PressureReading;
        }
        port vsOutput : VerticalSpeedPort;
        
        attribute previousAltitude : AltitudeValue := 0.0[m];
        attribute filterCoefficient : Real := 0.85;
        attribute teCompensationFactor : Real := 0.05;
    }

    part def VisualDisplay {
        doc /* Displays vertical speed and altitude information to the pilot. */
        
        port displayInput : DisplayPort;
        
        attribute updateRate : Real := 5.0;
        attribute displayRange : VerticalSpeedValue := 10.0[m/s];
    }

    part def AudioIndicator {
        doc /* Provides audible feedback for climb and sink rates. */
        
        port audioInput : AudioPort;
        port vsInput {
            in vsData : VerticalSpeedData;
        }
        
        attribute climbThreshold : VerticalSpeedValue := 0.5[m/s];
        attribute sinkThreshold : VerticalSpeedValue := -1.0[m/s];
    }

    action def MeasurePressure {
        in staticPressure : PressureValue;
        in dynamicPressure : PressureValue;
        out reading : PressureReading;
    }

    action def CalculateAltitude {
        in pressure : PressureValue;
        in temperature : TemperatureValue;
        out altitude : AltitudeValue;
    }

    action def ComputeVerticalSpeed {
        in currentAltitude : AltitudeValue;
        in previousAltitude : AltitudeValue;
        in deltaTime : TimeValue;
        in airspeed : ISQ::SpeedValue;
        in teCompensation : Real;
        out rawVS : VerticalSpeedValue;
        out compensatedVS : VerticalSpeedValue;
    }

    action def GenerateAudioTone {
        in verticalSpeed : VerticalSpeedValue;
        out toneSignal : AudioToneSignal;
    }

    action def VariometerOperation {
        doc /* Main operational cycle of the variometer system. */
        
        in attribute staticPressure : PressureValue;
        in attribute dynamicPressure : PressureValue;
        in attribute sampleInterval : TimeValue := 0.1[s];
        out attribute vsHistory : VerticalSpeedData[*] := ();
        
        attribute currentAltitude : AltitudeValue := 0.0[m];
        attribute previousAltitude : AltitudeValue := 0.0[m];
        attribute standardTemperature : TemperatureValue := 288.15[K];
        
        first start;
        then merge continueMeasurement;
        
        then action measure : MeasurePressure {
            in staticPressure = VariometerOperation::staticPressure;
            in dynamicPressure = VariometerOperation::dynamicPressure;
            out pressureReading : PressureReading;
        }
        
        then action calculateAlt : CalculateAltitude {
            in pressure = measure.pressureReading.staticPressure;
            in temperature = standardTemperature;
            out calculatedAltitude : AltitudeValue;
        }
        
        then assign currentAltitude := calculateAlt.calculatedAltitude;
        
        then action computeVS : ComputeVerticalSpeed {
            in currentAltitude = VariometerOperation::currentAltitude;
            in previousAltitude = VariometerOperation::previousAltitude;
            in deltaTime = sampleInterval;
            in airspeed = 25.0[m/s];
            in teCompensation = 0.05;
            out rawVerticalSpeed : VerticalSpeedValue;
            out compensatedVerticalSpeed : VerticalSpeedValue;
        }
        
        then action generateTone : GenerateAudioTone {
            in verticalSpeed = computeVS.compensatedVerticalSpeed;
            out audioSignal : AudioToneSignal;
        }
        
        then assign previousAltitude := currentAltitude;
        
        then continueMeasurement;
    }

    state def VariometerStates {
        entry; then off;
        
        state off {
            doc /* System is powered down. */
        }
        
        transition off_to_initializing
            first off
            accept powerOn : PowerCommand
            then initializing;
        
        state initializing {
            doc /* System performs self-test and sensor calibration. */
            entry action calibrateSensors;
        }
        
        transition initializing_to_operational
            first initializing
            accept calibrationComplete : CalibrationCommand
            then operational;
        
        state operational {
            doc /* System continuously measures and displays vertical speed. */
            
            state measuring {
                entry action startMeasurement;
            }
            
            state climbing {
                doc /* Aircraft is gaining altitude. */
            }
            
            state descending {
                doc /* Aircraft is losing altitude. */
            }
            
            state level {
                doc /* Aircraft is maintaining altitude. */
            }
            
            transition measuring_to_climbing
                first measuring
                accept when verticalSpeed > 0.5
                then climbing;
            
            transition measuring_to_descending
                first measuring
                accept when verticalSpeed < -0.5
                then descending;
            
            transition measuring_to_level
                first measuring
                accept when verticalSpeed >= -0.5 and verticalSpeed <= 0.5
                then level;
            
            transition climbing_to_level
                first climbing
                accept when verticalSpeed >= -0.5 and verticalSpeed <= 0.5
                then level;
            
            transition descending_to_level
                first descending
                accept when verticalSpeed >= -0.5 and verticalSpeed <= 0.5
                then level;
            
            transition level_to_climbing
                first level
                accept when verticalSpeed > 0.5
                then climbing;
            
            transition level_to_descending
                first level
                accept when verticalSpeed < -0.5
                then descending;
        }
        
        transition operational_to_off
            first operational
            accept powerOff : PowerCommand
            then off;
    }

    part def Variometer {
        doc /* 
            A variometer is an aviation instrument that measures and displays 
            the rate of climb or descent of an aircraft by detecting changes 
            in atmospheric pressure. The system provides both visual and 
            audible feedback to assist pilots in maintaining optimal flight 
            performance, particularly in soaring and gliding applications.
            
            Primary Function: Continuously monitor atmospheric pressure changes,
            calculate Total Energy compensated vertical speed, and provide 
            real-time climb/sink rate information through visual display and 
            audio feedback to enable efficient thermal soaring and altitude 
            management.
        */
        
        attribute maxVerticalSpeed : VerticalSpeedValue := 15.0[m/s];
        attribute minVerticalSpeed : VerticalSpeedValue := -15.0[m/s];
        attribute responseTime : TimeValue := 1.0[s];
        attribute operatingAltitudeRange : AltitudeValue := 6000.0[m];
        
        port ambientPressure : PressureInputPort;
        port vsDataOutput : VerticalSpeedPort;
        
        part sensor : PressureSensor {
            attribute :>> sampleRate = 10.0;
            attribute :>> accuracy = 1.0[Pa];
        }
        
        part computer : ComputationUnit {
            attribute :>> filterCoefficient = 0.85;
            attribute :>> teCompensationFactor = 0.05;
        }
        
        part display : VisualDisplay {
            attribute :>> updateRate = 5.0;
            attribute :>> displayRange = 10.0[m/s];
        }
        
        part audio : AudioIndicator {
            attribute :>> climbThreshold = 0.5[m/s];
            attribute :>> sinkThreshold = -1.0[m/s];
        }
        
        connection : FlowConnection connect 
            ambientPressure.staticP to sensor.pressureInput.staticP;
        
        connection : FlowConnection connect 
            ambientPressure.dynamicP to sensor.pressureInput.dynamicP;
        
        connection : FlowConnection connect 
            sensor.dataOutput.reading to computer.pressureInput.reading;
        
        connection : FlowConnection connect 
            computer.vsOutput.vsData to display.displayInput.vsData;
        
        connection : FlowConnection connect 
            computer.vsOutput.vsData to audio.vsInput.vsData;
        
        connection : FlowConnection connect 
            computer.vsOutput.vsData to vsDataOutput.vsData;
        
        perform action operation : VariometerOperation;
        
        exhibit state systemStates : VariometerStates;
    }

    requirement def AccuracyRequirement {
        doc /* The variometer shall measure vertical speed with specified accuracy across operational range. */
        
        subject variometer : Variometer;
        
        require constraint {
            variometer.sensor.accuracy <= 2.0[Pa]
        }
    }

    requirement def ResponseRequirement {
        doc /* The variometer shall respond to altitude changes within specified time. */
        
        subject variometer : Variometer;
        
        require constraint {
            variometer.responseTime <= 2.0[s]
        }
    }

    requirement def MeasurementRangeRequirement {
        doc /* The variometer shall measure vertical speeds within operational range. */
        
        subject variometer : Variometer;
        
        require constraint {
            variometer.minVerticalSpeed >= -20.0[m/s] and
            variometer.maxVerticalSpeed <= 20.0[m/s]
        }
    }

    requirement def TECompensationRequirement {
        doc /* The variometer shall provide Total Energy compensated vertical speed. */
        
        subject variometer : Variometer;
        
        require constraint {
            variometer.computer.teCompensationFactor > 0.0 and
            variometer.computer.teCompensationFactor < 0.1
        }
    }

    requirement <'VAR-SYS-001'> variometerSystemRequirements {
        doc /* 
            The variometer system shall accurately measure, compute, and display 
            vertical speed information to support safe and efficient flight operations.
        */
        
        require accuracyReq : AccuracyRequirement;
        require responseReq : ResponseRequirement;
        require rangeReq : MeasurementRangeRequirement;
        require teCompReq : TECompensationRequirement;
    }

    part variometerSystem : Variometer {
        doc /* 
            Complete variometer system instance for aircraft installation.
            Provides continuous vertical speed monitoring with Total Energy 
            compensation for optimal soaring performance.
        */
        
        attribute :>> maxVerticalSpeed = 15.0[m/s];
        attribute :>> minVerticalSpeed = -15.0[m/s];
        attribute :>> responseTime = 1.5[s];
        attribute :>> operatingAltitudeRange = 6000.0[m];
        
        satisfy variometerSystemRequirements;
    }
}
