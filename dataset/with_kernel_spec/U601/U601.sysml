package AtomicGravitationalWaveInterferometricSensor {
    attribute def TemperatureValue :> ScalarValues::Real;
    attribute def FrequencyValue :> ScalarValues::Real;
    attribute def StrainValue :> ScalarValues::Real;
    attribute def AmplitudeValue :> ScalarValues::Real;
    attribute def PhaseShiftValue :> ScalarValues::Real;
    attribute def TimeValue :> ScalarValues::Real;
    attribute def PressureValue :> ScalarValues::Real;
    attribute def MagneticFluxDensityValue :> ScalarValues::Real;
    attribute def SpeedValue :> ScalarValues::Real;
    
    item def Rubidium87Atom;
    
    item def AtomCloud {
        item atoms : Rubidium87Atom [*];
        attribute temperature : TemperatureValue;
        attribute velocity : SpeedValue;
    }
    
    item def LaserPulse {
        attribute duration : TimeValue;
        attribute timing : TimeValue;
    }
    
    item def InterferencePattern {
        attribute phaseShift : PhaseShiftValue;
        attribute fringeContrast : ScalarValues::Real;
    }
    
    item def GravitationalWaveSignal {
        attribute strain : StrainValue;
        attribute frequency : FrequencyValue;
        attribute amplitude : AmplitudeValue;
    }
    
    part def VacuumChamber {
        attribute material : ScalarValues::String = "Stainless Steel";
        attribute pressure : PressureValue;
    }
    
    part def AtomicSource {
        out item releasedAtoms : Rubidium87Atom [*];
    }
    
    part def MagnetoOpticalTrap {
        in item atoms : Rubidium87Atom [*];
        out item cooledCloud : AtomCloud;
        attribute magneticFieldStrength : MagneticFluxDensityValue;
    }
    
    part def LaserSystem {
        out item laserPulses : LaserPulse [*];
    }
    
    part def StateDetector {
        in item cloud : AtomCloud;
        out item interferencePattern : InterferencePattern;
    }
    
    part def SignalProcessingUnit {
        in item rawPattern : InterferencePattern;
        out item gwSignal : GravitationalWaveSignal;
    }
    
    part def ControlSystem {
        out attribute triggerLaser : ScalarValues::Boolean;
        out attribute triggerMOT : ScalarValues::Boolean;
        out attribute triggerSource : ScalarValues::Boolean;
    }
    
    part def SensorSystem {
        part chamber : VacuumChamber;
        part source : AtomicSource;
        part mot : MagnetoOpticalTrap;
        part laser : LaserSystem;
        part detector : StateDetector;
        part spu : SignalProcessingUnit;
        part controller : ControlSystem;
        
        flow from source.releasedAtoms to mot.atoms;
        flow from mot.cooledCloud to detector.cloud;
        flow from detector.interferencePattern to spu.rawPattern;
    }
    
    action def MeasurementSequence {
        in item cloud : AtomCloud;
        out item pattern : InterferencePattern;
        
        action launch {
            in item cloud : AtomCloud;
            out item launchedCloud : AtomCloud;
        }
        then split;
        action split {
            in item launchedCloud : AtomCloud;
            out item splitCloud : AtomCloud;
        }
        then mirror;
        action mirror {
            in item splitCloud : AtomCloud;
            out item mirroredCloud : AtomCloud;
        }
        then recombine;
        action recombine {
            in item mirroredCloud : AtomCloud;
            out item recombinedCloud : AtomCloud;
        }
        then detect;
        action detect {
            in item recombinedCloud : AtomCloud;
            out item pattern : InterferencePattern;
        }
    }
    
    state def SensorStateMachine {
        entry; then Initialization;
        state Initialization;
        transition init_to_loading
            first Initialization
            then AtomLoadingCooling;
            
        state AtomLoadingCooling;
        transition loading_to_measurement
            first AtomLoadingCooling
            then ActiveMeasurement;
            
        state ActiveMeasurement;
        transition measurement_to_processing
            first ActiveMeasurement
            then DataProcessing;
            
        state DataProcessing;
        transition processing_to_ready
            first DataProcessing
            then Ready;
            
        state Ready;
        transition ready_to_loading
            first Ready
            then AtomLoadingCooling;
    }
    
    requirement def UltraHighVacuumRequirement {
        doc /* The vacuum chamber shall maintain an ultra-high vacuum below 1e-9 Pa. */
    }
    
    requirement def LowFrequencySensitivityRequirement {
        doc /* The sensor shall be sensitive to gravitational wave strain in the low-frequency band below 10 Hz. */
    }
    
    part sensor : SensorSystem {
        satisfy UltraHighVacuumRequirement by chamber;
        satisfy LowFrequencySensitivityRequirement by spu;
    }
}
