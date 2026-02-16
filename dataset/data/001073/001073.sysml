package GravimeterSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def GravityAcceleration :> ISQ::AccelerationValue {
        doc /* Measured local gravitational acceleration */
    }
    
    attribute def SensorVoltage :> ISQ::VoltageValue {
        doc /* Voltage signal from proof mass displacement */
    }
    
    attribute def CalibrationCoefficient :> Real {
        doc /* Conversion factor from sensor output to acceleration */
    }
    
    item def GravityReading {
        attribute timestamp : ISQ::TimeValue;
        attribute acceleration : GravityAcceleration;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute quality : Real;
    }
    
    port def SensorOutputPort {
        out voltage : SensorVoltage;
        out temperature : ISQ::ThermodynamicTemperatureValue;
    }
    
    port def DataOutputPort {
        out reading : GravityReading;
    }
    
    port def PowerInputPort {
        in voltage : ISQ::VoltageValue;
        in current : ISQ::ElectricCurrentValue;
    }
    
    port def ControlPort {
        in command : String;
        out status : String;
    }
    
    part def ProofMass {
        doc /* Suspended mass that responds to gravitational field variations */
        attribute mass : ISQ::MassValue;
        attribute displacement : ISQ::LengthValue;
    }
    
    part def SpringSystem {
        doc /* Provides restoring force for proof mass */
        attribute springConstant : Real;
        attribute naturalFrequency : ISQ::FrequencyValue;
    }
    
    part def DisplacementSensor {
        doc /* Measures proof mass displacement and converts to electrical signal */
        attribute sensitivity : Real;
        port output : SensorOutputPort;
        
        action measureDisplacement {
            in displacement : ISQ::LengthValue;
            out voltage : SensorVoltage;
        }
    }
    
    part def SignalConditioner {
        doc /* Amplifies and filters raw sensor signals */
        attribute gain : Real;
        attribute filterCutoff : ISQ::FrequencyValue;
        
        action conditionSignal {
            in rawVoltage : SensorVoltage;
            out conditionedVoltage : SensorVoltage;
        }
    }
    
    part def AnalogToDigitalConverter {
        doc /* Converts analog sensor signals to digital values */
        attribute resolution : Integer;
        attribute samplingRate : ISQ::FrequencyValue;
        
        action convertSignal {
            in analogVoltage : SensorVoltage;
            out digitalValue : Real;
        }
    }
    
    part def DataProcessor {
        doc /* Applies calibration and temperature compensation to measurements */
        attribute calibrationData : CalibrationCoefficient;
        
        action processData {
            in digitalValue : Real;
            in temperature : ISQ::ThermodynamicTemperatureValue;
            out acceleration : GravityAcceleration;
        }
        
        action applyTemperatureCompensation {
            in rawAcceleration : GravityAcceleration;
            in temperature : ISQ::ThermodynamicTemperatureValue;
            out compensatedAcceleration : GravityAcceleration;
        }
    }
    
    part def DataLogger {
        doc /* Stores and outputs gravity measurements */
        attribute bufferSize : Integer;
        port dataOut : DataOutputPort;
        
        action logReading {
            in acceleration : GravityAcceleration;
            in timestamp : ISQ::TimeValue;
            in temperature : ISQ::ThermodynamicTemperatureValue;
            out reading : GravityReading;
        }
    }
    
    part def PowerSupply {
        doc /* Provides regulated power to all subsystems */
        attribute outputVoltage : ISQ::VoltageValue;
        attribute outputCurrent : ISQ::ElectricCurrentValue;
        port powerOut : PowerInputPort;
    }
    
    part def ControlUnit {
        doc /* Manages gravimeter operation modes and system health */
        port control : ControlPort;
        
        action manageOperation {
            in command : String;
            out status : String;
        }
    }
    
    part def Gravimeter {
        doc /* 
            High-precision instrument for measuring local gravitational acceleration.
            Primary function: Continuously measure variations in Earth's gravitational field
            for applications in geophysics, geodesy, resource exploration, and navigation.
        */
        
        attribute operatingRange : GravityAcceleration[2];
        attribute resolution : GravityAcceleration;
        attribute accuracy : GravityAcceleration;
        attribute operatingTemperatureRange : ISQ::ThermodynamicTemperatureValue[2];
        
        part proofMass : ProofMass {
            :>> mass = 0.1[SI::kg];
        }
        
        part spring : SpringSystem {
            :>> springConstant = 10.0;
            :>> naturalFrequency = 1.0[SI::Hz];
        }
        
        part sensor : DisplacementSensor {
            :>> sensitivity = 1000.0;
        }
        
        part conditioner : SignalConditioner {
            :>> gain = 100.0;
            :>> filterCutoff = 10.0[SI::Hz];
        }
        
        part adc : AnalogToDigitalConverter {
            :>> resolution = 24;
            :>> samplingRate = 100.0[SI::Hz];
        }
        
        part processor : DataProcessor {
            :>> calibrationData = 9.80665;
        }
        
        part logger : DataLogger {
            :>> bufferSize = 1000;
        }
        
        part power : PowerSupply {
            :>> outputVoltage = 12.0[SI::V];
            :>> outputCurrent = 0.5[SI::A];
        }
        
        part controller : ControlUnit;
        
        connection sensorToConditioner connect sensor.output to conditioner;
        connection conditionerToADC connect conditioner to adc;
        connection adcToProcessor connect adc to processor;
        connection processorToLogger connect processor to logger;
        
        connection powerToSensor connect power.powerOut to sensor;
        connection powerToConditioner connect power.powerOut to conditioner;
        connection powerToADC connect power.powerOut to adc;
        connection powerToProcessor connect power.powerOut to processor;
        connection powerToLogger connect power.powerOut to logger;
        connection powerToController connect power.powerOut to controller;
        
        perform action measureGravity;
    }
    
    action def MeasureGravity {
        doc /* Primary gravimeter function: continuous gravity field measurement */
        in operatingMode : String;
        out measurements : GravityReading[*];
    }
    
    action measureGravity : MeasureGravity {
        in operatingMode : String;
        out measurements : GravityReading[*] := ( );
        
        first start;
        then merge continueMeasurement;
        
        then action initialize {
            doc /* System initialization and self-test */
        }
        
        then action calibrate {
            doc /* Apply calibration coefficients and verify accuracy */
        }
        
        then action acquireMeasurement {
            action detectDisplacement {
                doc /* Proof mass responds to gravity field */
                out displacement : ISQ::LengthValue;
            }
            
            flow detectDisplacement.displacement to convertToVoltage.displacement;
            
            action convertToVoltage {
                in displacement : ISQ::LengthValue;
                out voltage : SensorVoltage;
            }
            
            flow convertToVoltage.voltage to amplifySignal.rawVoltage;
            
            action amplifySignal {
                in rawVoltage : SensorVoltage;
                out amplifiedVoltage : SensorVoltage;
            }
            
            flow amplifySignal.amplifiedVoltage to digitize.analogVoltage;
            
            action digitize {
                in analogVoltage : SensorVoltage;
                out digitalValue : Real;
            }
            
            flow digitize.digitalValue to calculateAcceleration.digitalValue;
            
            action calculateAcceleration {
                in digitalValue : Real;
                out acceleration : GravityAcceleration;
            }
            
            flow calculateAcceleration.acceleration to compensate.rawAcceleration;
            
            action compensate {
                in rawAcceleration : GravityAcceleration;
                in temperature : ISQ::ThermodynamicTemperatureValue;
                out compensatedAcceleration : GravityAcceleration;
            }
            
            flow compensate.compensatedAcceleration to recordReading.acceleration;
            
            action recordReading {
                in acceleration : GravityAcceleration;
                out reading : GravityReading;
            }
            
            then assign measurements := SequenceFunctions::including(measurements, recordReading.reading);
        }
        
        then decide;
            if operatingMode == "continuous" then continueMeasurement;
            if operatingMode == "single" then shutdown;
        
        action shutdown {
            doc /* Safe system shutdown */
        }
        
        then done;
    }
    
    requirement def AccuracyRequirement {
        doc /* Defines required measurement accuracy */
        subject gravimeter : Gravimeter;
        
        require constraint {
            gravimeter.accuracy <= 1.0e-5 * 9.81[SI::m/SI::s^2]
        }
    }
    
    requirement def ResolutionRequirement {
        doc /* Defines required measurement resolution */
        subject gravimeter : Gravimeter;
        
        require constraint {
            gravimeter.resolution <= 1.0e-8 * 9.81[SI::m/SI::s^2]
        }
    }
    
    requirement def OperatingRangeRequirement {
        doc /* Defines measurement range for gravitational acceleration */
        subject gravimeter : Gravimeter;
        
        require constraint {
            gravimeter.operatingRange[1] >= 9.75[SI::m/SI::s^2] and
            gravimeter.operatingRange[2] <= 9.85[SI::m/SI::s^2]
        }
    }
    
    requirement def TemperatureStabilityRequirement {
        doc /* Defines acceptable operating temperature range */
        subject gravimeter : Gravimeter;
        
        require constraint {
            gravimeter.operatingTemperatureRange[1] >= 263.15[SI::K] and
            gravimeter.operatingTemperatureRange[2] <= 313.15[SI::K]
        }
    }
    
    requirement <'GRV-SYS-001'> gravimeterSystemRequirement {
        doc /* 
            The gravimeter system shall continuously measure local gravitational 
            acceleration with high precision and stability for geophysical surveying,
            resource exploration, and geodetic applications.
        */
        
        subject gravimeterSystem : Gravimeter;
        
        assume constraint environmentalConditions {
            doc /* System operates in controlled environmental conditions with minimal vibration */
        }
        
        require accuracy : AccuracyRequirement {
            subject gravimeter = gravimeterSystem;
        }
        
        require resolution : ResolutionRequirement {
            subject gravimeter = gravimeterSystem;
        }
        
        require range : OperatingRangeRequirement {
            subject gravimeter = gravimeterSystem;
        }
        
        require temperatureStability : TemperatureStabilityRequirement {
            subject gravimeter = gravimeterSystem;
        }
    }
    
    part gravimeterInstance : Gravimeter {
        :>> operatingRange = (9.78[SI::m/SI::s^2], 9.83[SI::m/SI::s^2]);
        :>> resolution = 1.0e-9 * 9.81[SI::m/SI::s^2];
        :>> accuracy = 5.0e-6 * 9.81[SI::m/SI::s^2];
        :>> operatingTemperatureRange = (273.15[SI::K], 303.15[SI::K]);
        
        perform action measureGravity {
            in operatingMode = "continuous";
        }
    }
}
