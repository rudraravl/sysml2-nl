package AcousticRadiometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def AcousticIntensity :> ISQ::PowerValue;
    
    attribute def RadiationPressure :> ISQ::PressureValue;
    
    attribute def AcousticPower :> ISQ::PowerValue;
    
    item def AcousticWaveField {
        attribute frequency : ISQ::FrequencyValue;
        attribute intensity : AcousticIntensity;
        attribute pressure : RadiationPressure;
    }
    
    item def ForceReading {
        attribute radiationForce : ISQ::ForceValue;
        attribute timestamp : ISQ::TimeValue;
    }
    
    item def PowerMeasurement {
        attribute acousticPower : AcousticPower;
        attribute confidence : Real;
    }
    
    port def AcousticInputPort {
        in item waveField : AcousticWaveField;
    }
    
    port def ForceOutputPort {
        out item forceData : ForceReading;
    }
    
    port def DataOutputPort {
        out item measurement : PowerMeasurement;
    }
    
    part def AbsorbingTarget {
        attribute absorptionCoefficient : Real;
        attribute surfaceArea : ISQ::AreaValue;
        attribute mass : ISQ::MassValue;
        
        port acousticPort : AcousticInputPort;
        port forcePort : ForceOutputPort;
        
        perform action absorbAcousticWave {
            in waveField : AcousticWaveField;
            out radiationForce : ISQ::ForceValue;
        }
    }
    
    part def ForceSensor {
        attribute sensitivity : Real;
        attribute range : ISQ::ForceValue;
        
        port forceInput : ForceOutputPort;
        port signalOutput;
        
        perform action measureForce {
            in appliedForce : ISQ::ForceValue;
            out forceReading : ForceReading;
        }
    }
    
    part def SignalConditioner {
        attribute gain : Real;
        attribute bandwidth : ISQ::FrequencyValue;
        
        port signalInput;
        port conditionedOutput;
        
        perform action conditionSignal {
            in rawSignal : ForceReading;
            out conditionedSignal : ForceReading;
        }
    }
    
    part def ComputationUnit {
        attribute calibrationFactor : Real;
        attribute mediumDensity : ISQ::DensityValue;
        attribute soundSpeed : ISQ::SpeedValue;
        
        port dataInput;
        port powerOutput : DataOutputPort;
        
        perform action computeAcousticPower {
            in forceData : ForceReading;
            out powerMeasurement : PowerMeasurement;
        }
    }
    
    part def DisplayUnit {
        port dataInput : DataOutputPort;
        
        perform action displayMeasurement {
            in measurement : PowerMeasurement;
        }
    }
    
    action def AbsorbWave {
        in waveField : AcousticWaveField;
        in absorptionCoeff : Real;
        in targetArea : ISQ::AreaValue;
        out radiationForce : ISQ::ForceValue;
    }
    
    action def SenseForce {
        in radiationForce : ISQ::ForceValue;
        in sensorSensitivity : Real;
        out forceReading : ForceReading;
    }
    
    action def ConditionData {
        in rawReading : ForceReading;
        in signalGain : Real;
        out conditionedReading : ForceReading;
    }
    
    action def CalculatePower {
        in forceReading : ForceReading;
        in density : ISQ::DensityValue;
        in speedOfSound : ISQ::SpeedValue;
        in calibration : Real;
        out acousticPower : PowerMeasurement;
    }
    
    action def PresentResults {
        in powerData : PowerMeasurement;
    }
    
    part def AcousticRadiometer {
        attribute operatingFrequency : ISQ::FrequencyValue;
        attribute accuracy : Real;
        
        port acousticInput : AcousticInputPort;
        port measurementOutput : DataOutputPort;
        
        part target : AbsorbingTarget;
        part sensor : ForceSensor;
        part conditioner : SignalConditioner;
        part processor : ComputationUnit;
        part display : DisplayUnit;
    }
    
    part acousticRadiometer : AcousticRadiometer {
        attribute :>> operatingFrequency = 1000.0 [SI::Hz];
        attribute :>> accuracy = 0.03;
        
        part :>> target {
            attribute :>> absorptionCoefficient = 0.95;
            attribute :>> surfaceArea = 0.001 [SI::m^2];
            attribute :>> mass = 0.005 [SI::kg];
        }
        
        part :>> sensor {
            attribute :>> sensitivity = 1000.0;
            attribute :>> range = 0.01 [SI::N];
        }
        
        part :>> conditioner {
            attribute :>> gain = 100.0;
            attribute :>> bandwidth = 10000.0 [SI::Hz];
        }
        
        part :>> processor {
            attribute :>> calibrationFactor = 1.0;
            attribute :>> mediumDensity = 1000.0 [SI::kg/SI::m^3];
            attribute :>> soundSpeed = 1500.0 [SI::m/SI::s];
        }
        
        connect acousticInput to target.acousticPort;
        connect target.forcePort to sensor.forceInput;
        connect sensor.signalOutput to conditioner.signalInput;
        connect conditioner.conditionedOutput to processor.dataInput;
        connect processor.powerOutput to display.dataInput;
        connect processor.powerOutput to measurementOutput;
        
        perform action measureAcousticRadiation {
            first start;
            then action absorb : AbsorbWave {
                in waveField;
                in absorptionCoeff = target.absorptionCoefficient;
                in targetArea = target.surfaceArea;
                out radiationForce;
            }
            then action sense : SenseForce {
                in radiationForce = absorb.radiationForce;
                in sensorSensitivity = sensor.sensitivity;
                out forceReading;
            }
            then action condition : ConditionData {
                in rawReading = sense.forceReading;
                in signalGain = conditioner.gain;
                out conditionedReading;
            }
            then action calculate : CalculatePower {
                in forceReading = condition.conditionedReading;
                in density = processor.mediumDensity;
                in speedOfSound = processor.soundSpeed;
                in calibration = processor.calibrationFactor;
                out acousticPower;
            }
            then action present : PresentResults {
                in powerData = calculate.acousticPower;
            }
            then done;
        }
        
        state operationalMode {
            entry; then idle;
            
            state idle;
            state calibrating;
            state measuring;
            state processing;
            state displaying;
            
            transition idle_to_calibrating
                first idle
                accept calibrationRequest
                then calibrating;
            
            transition calibrating_to_measuring
                first calibrating
                accept calibrationComplete
                then measuring;
            
            transition measuring_to_processing
                first measuring
                accept dataAcquired
                then processing;
            
            transition processing_to_displaying
                first processing
                accept computationComplete
                then displaying;
            
            transition displaying_to_measuring
                first displaying
                accept displayComplete
                then measuring;
            
            transition any_to_idle
                first calibrating
                accept shutdownRequest
                then idle;
        }
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def AccuracyRequirement;
    
    requirement <'AR-REQ-001'> primaryFunction : FunctionalRequirement {
        doc /* 
        The acoustic radiometer shall measure the total time-averaged acoustic 
        power of an incident sound field by detecting the acoustic radiation 
        force exerted on an absorbing target and converting this force 
        measurement into an acoustic power value.
        */
        subject radiometerSystem : AcousticRadiometer;
    }
    
    requirement <'AR-REQ-002'> measurementAccuracy : AccuracyRequirement {
        doc /* 
        The acoustic radiometer shall measure acoustic power with an accuracy 
        of ±3% of the reading over the specified operating range.
        */
        subject radiometerSystem : AcousticRadiometer;
        
        require constraint accuracyConstraint {
            radiometerSystem.accuracy <= 0.03
        }
    }
    
    requirement <'AR-REQ-003'> continuousOperation : PerformanceRequirement {
        doc /* 
        The acoustic radiometer shall perform continuous measurement cycles 
        and provide updated power readings at intervals not exceeding 100 milliseconds.
        */
        subject radiometerSystem : AcousticRadiometer;
    }
    
    requirement <'AR-REQ-004'> frequencyRange : PerformanceRequirement {
        doc /* 
        The acoustic radiometer shall operate over a frequency range from 
        20 Hz to 20 kHz with uniform sensitivity.
        */
        subject radiometerSystem : AcousticRadiometer;
    }
    
    satisfy primaryFunction by acousticRadiometer.measureAcousticRadiation;
    satisfy measurementAccuracy by acousticRadiometer.processor.computeAcousticPower;
    satisfy continuousOperation by acousticRadiometer.operationalMode;
}
