package 'Thermopile Laser Sensing System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    item def InfraredRadiation {
        attribute intensity : Real;
        attribute wavelength : LengthValue;
    }
    
    item def TemperatureMeasurement {
        attribute value : TemperatureValue;
        attribute timestamp : TimeValue;
        attribute accuracy : TemperatureValue;
        attribute valid : Boolean;
    }
    
    item def LaserBeam {
        attribute wavelength : LengthValue;
        attribute power : PowerValue;
        attribute enabled : Boolean;
    }
    
    port def PowerPort {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }
    
    port def ThermalInputPort {
        in item radiation : InfraredRadiation;
    }
    
    port def DataOutputPort {
        out item measurement : TemperatureMeasurement;
    }
    
    port def LaserOutputPort {
        out item beam : LaserBeam;
    }
    
    port def ConfigurationPort {
        in attribute emissivity : Real;
        in attribute ambientTemp : TemperatureValue;
    }
    
    action def DetectInfraredRadiation {
        in item radiation : InfraredRadiation;
        out attribute voltage : ElectricPotentialValue;
    }
    
    action def ConditionSignal {
        in attribute rawVoltage : ElectricPotentialValue;
        out attribute conditionedVoltage : ElectricPotentialValue;
    }
    
    action def CalculateTemperature {
        in attribute voltage : ElectricPotentialValue;
        in attribute emissivity : Real;
        in attribute ambient : TemperatureValue;
        out item temperature : TemperatureMeasurement;
    }
    
    action def EmitAimingLaser {
        out item beam : LaserBeam;
    }
    
    action def MeasurementCycle {
        in item targetRadiation : InfraredRadiation;
        in attribute emissivity : Real;
        in attribute ambient : TemperatureValue;
        out item finalMeasurement : TemperatureMeasurement;
        
        action emitLaser : EmitAimingLaser {
            out beam;
        }
        then detectIR;
        
        action detectIR : DetectInfraredRadiation {
            in radiation;
            out voltage;
        }
        then succession flow from detectIR.voltage to condition.rawVoltage;
        
        action condition : ConditionSignal {
            in rawVoltage;
            out conditionedVoltage;
        }
        then succession flow from condition.conditionedVoltage to calculate.voltage;
        
        action calculate : CalculateTemperature {
            in voltage;
            in emissivity;
            in ambient;
            out temperature;
        }
        
        bind calculate.temperature = finalMeasurement;
    }
    
    state def SensorOperationStates {
        entry; then idle;
        
        state idle;
        transition powerOn first idle then standby;
        
        state standby;
        transition beginMeasure first standby then active;
        
        state active {
            entry; then aiming;
            state aiming;
            transition aimed first aiming then measuring;
            state measuring;
            transition complete first measuring then reporting;
            state reporting;
        }
        
        transition finished first active then standby;
        transition fault first standby then error;
        transition fault first active then error;
        
        state error;
        transition reset first error then idle;
    }
    
    part def OpticalSystem {
        attribute apertureDiameter : LengthValue;
        attribute focusDistance : LengthValue;
        attribute transmittance : Real;
        port thermalIn : ThermalInputPort;
    }
    
    part def ThermopileDetector {
        attribute junctionCount : Integer;
        attribute sensitivity : Real;
        attribute responseTime : TimeValue;
        attribute spectralRangeMin : LengthValue;
        attribute spectralRangeMax : LengthValue;
        port thermalInput : ThermalInputPort;
        port power : PowerPort;
    }
    
    part def LaserAiming {
        attribute wavelength : LengthValue;
        attribute opticalPower : PowerValue;
        attribute beamDivergence : Real;
        port laserOut : LaserOutputPort;
        port power : PowerPort;
    }
    
    part def SignalConditioner {
        attribute gain : Real;
        attribute filterCutoff : FrequencyValue;
        attribute offsetCorrection : ElectricPotentialValue;
        port power : PowerPort;
    }
    
    part def TemperatureProcessor {
        attribute samplingRate : FrequencyValue;
        attribute resolutionBits : Integer;
        attribute calibrationFactor : Real;
        port config : ConfigurationPort;
        port power : PowerPort;
    }
    
    part def PowerSupply {
        attribute inputVoltage : ElectricPotentialValue;
        attribute outputVoltage : ElectricPotentialValue;
        attribute efficiency : Real;
        port input : PowerPort;
    }
    
    part def ThermopileLaserSensor {
        attribute operatingTempMin : TemperatureValue;
        attribute operatingTempMax : TemperatureValue;
        attribute measurementAccuracy : TemperatureValue;
        attribute responseTime : TimeValue;
        attribute measurementRangeMin : TemperatureValue;
        attribute measurementRangeMax : TemperatureValue;
        
        port powerInput : PowerPort;
        port thermalPort : ThermalInputPort;
        port dataOutput : DataOutputPort;
        port laserOutput : LaserOutputPort;
        port configuration : ConfigurationPort;
        
        part optics : OpticalSystem {
            attribute :>> apertureDiameter = 12.0[mm];
            attribute :>> focusDistance = 100.0[mm];
            attribute :>> transmittance = 0.93;
        }
        
        part thermopile : ThermopileDetector {
            attribute :>> junctionCount = 120;
            attribute :>> sensitivity = 100.0;
            attribute :>> responseTime = 0.15[s];
            attribute :>> spectralRangeMin = 8000.0[nm];
            attribute :>> spectralRangeMax = 14000.0[nm];
        }
        
        part laser : LaserAiming {
            attribute :>> wavelength = 650.0[nm];
            attribute :>> opticalPower = 0.001[W];
            attribute :>> beamDivergence = 0.002;
        }
        
        part conditioner : SignalConditioner {
            attribute :>> gain = 100.0;
            attribute :>> filterCutoff = 10.0[Hz];
            attribute :>> offsetCorrection = 0.0[V];
        }
        
        part processor : TemperatureProcessor {
            attribute :>> samplingRate = 10.0[Hz];
            attribute :>> resolutionBits = 16;
            attribute :>> calibrationFactor = 1.0;
        }
        
        part supply : PowerSupply {
            attribute :>> inputVoltage = 24.0[V];
            attribute :>> outputVoltage = 5.0[V];
            attribute :>> efficiency = 0.85;
        }
        
        connect powerInput to supply.input;
        connect thermalPort to optics.thermalIn;
        connect optics.thermalIn to thermopile.thermalInput;
        connect laser.laserOut to laserOutput;
        connect configuration to processor.config;
        
        perform action measurementBehavior : MeasurementCycle;
        exhibit state operationState : SensorOperationStates;
    }
    
    requirement def MeasurementAccuracyRequirement {
        subject sensor : ThermopileLaserSensor;
        doc /* The sensor shall measure temperature with accuracy better than 2 Kelvin across the operating range. */
        require constraint {
            sensor.measurementAccuracy.num <= 2.0
        }
    }
    
    requirement def OperatingRangeRequirement {
        subject sensor : ThermopileLaserSensor;
        doc /* The sensor shall operate across a temperature measurement range from -50 to 1000 degrees Celsius. */
        require constraint {
            sensor.measurementRangeMin.num >= -50.0 and sensor.measurementRangeMax.num <= 1000.0
        }
    }
    
    requirement def ResponseTimeRequirement {
        subject sensor : ThermopileLaserSensor;
        doc /* The sensor shall provide temperature measurements within 500 milliseconds. */
        require constraint {
            sensor.responseTime.num <= 0.5
        }
    }
    
    requirement def SpectralRangeRequirement {
        subject sensor : ThermopileLaserSensor;
        doc /* The thermopile detector shall operate in the infrared spectral range from 8 to 14 micrometers. */
        require constraint {
            sensor.thermopile.spectralRangeMin.num >= 8000.0 and 
            sensor.thermopile.spectralRangeMax.num <= 14000.0
        }
    }
    
    part sensingUnit {
        part sensor : ThermopileLaserSensor {
            attribute :>> operatingTempMin = 223.15[K];
            attribute :>> operatingTempMax = 1273.15[K];
            attribute :>> measurementAccuracy = 1.5[K];
            attribute :>> responseTime = 0.3[s];
            attribute :>> measurementRangeMin = 223.15[K];
            attribute :>> measurementRangeMax = 1273.15[K];
        }
        
        part powerSource {
            port output : PowerPort {
                attribute :>> voltage = 24.0[V];
                attribute :>> current = 0.2[A];
            }
        }
        
        part dataAcquisition {
            port input : DataOutputPort;
        }
        
        connect powerSource.output to sensor.powerInput;
        connect sensor.dataOutput to dataAcquisition.input;
        
        requirement accuracyReq : MeasurementAccuracyRequirement;
        requirement rangeReq : OperatingRangeRequirement;
        requirement responseReq : ResponseTimeRequirement;
        requirement spectralReq : SpectralRangeRequirement;
        
        satisfy accuracyReq by sensor;
        satisfy rangeReq by sensor;
        satisfy responseReq by sensor;
        satisfy spectralReq by sensor;
    }
}
