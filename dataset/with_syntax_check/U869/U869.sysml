package 'Semiconductor Detector System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def ParticleType;
    attribute def SignalAmplitude;
    attribute def ThresholdLevel;
    
    item def RadiationEvent {
        attribute particleType : ParticleType;
        attribute depositedEnergy : EnergyValue;
        attribute interactionTime : TimeValue;
        attribute position : LengthValue[3];
    }
    
    item def ElectricPulse {
        attribute amplitude : ElectricPotentialValue;
        attribute riseTime : TimeValue;
        attribute fallTime : TimeValue;
        attribute totalCharge : ElectricChargeValue;
    }
    
    item def DigitalEvent {
        attribute eventID : Integer;
        attribute measuredEnergy : EnergyValue;
        attribute timestamp : TimeValue;
        attribute channelNumber : Integer;
    }
    
    port def RadiationInputPort {
        in radiationEvent : RadiationEvent;
    }
    
    port def AnalogSignalPort {
        out electricPulse : ElectricPulse;
    }
    
    port def DigitalDataPort {
        out digitalEvent : DigitalEvent;
    }
    
    port def BiasVoltagePort {
        in biasVoltage : ElectricPotentialValue;
        out leakageCurrent : ElectricCurrentValue;
    }
    
    port def ControlSignalPort {
        in threshold : ThresholdLevel;
        in gain : Real;
        out status : String;
    }
    
    part def SemiconductorSensor {
        attribute depletionDepth : LengthValue;
        attribute activeVolume : VolumeValue;
        attribute operatingBias : ElectricPotentialValue;
        attribute materialType : String;
        
        port radiationIn : RadiationInputPort;
        port chargeOut : AnalogSignalPort;
        port biasIn : BiasVoltagePort;
        
        action generateCharge {
            in event : RadiationEvent;
            in bias : ElectricPotentialValue;
            out pulse : ElectricPulse;
        }
    }
    
    part def ChargeAmplifier {
        attribute feedbackCapacitance : CapacitanceValue;
        attribute inputImpedance : ElectricResistanceValue;
        attribute amplificationFactor : Real;
        
        port chargeIn : AnalogSignalPort;
        port voltageOut : AnalogSignalPort;
        
        action amplifyCharge {
            in inputPulse : ElectricPulse;
            in gainSetting : Real;
            out amplifiedPulse : ElectricPulse;
        }
    }
    
    part def PulseShapingCircuit {
        attribute shapingTimeConstant : TimeValue;
        attribute filterOrder : Integer;
        
        port pulseIn : AnalogSignalPort;
        port shapedOut : AnalogSignalPort;
        
        action shapePulse {
            in rawPulse : ElectricPulse;
            out shapedPulse : ElectricPulse;
        }
    }
    
    part def PulseHeightAnalyzer {
        attribute adcResolution : Integer;
        attribute conversionTime : TimeValue;
        attribute dynamicRange : ElectricPotentialValue;
        
        port analogIn : AnalogSignalPort;
        port digitalOut : DigitalDataPort;
        port control : ControlSignalPort;
        
        action digitizeSignal {
            in shapedPulse : ElectricPulse;
            in thresholdSetting : ThresholdLevel;
            out event : DigitalEvent;
        }
    }
    
    part def DataAcquisitionUnit {
        attribute bufferCapacity : Integer;
        attribute acquisitionRate : FrequencyValue;
        attribute storageFormat : String;
        
        port eventIn : DigitalDataPort;
        port dataOut : DigitalDataPort;
        
        action collectData {
            in events : DigitalEvent[*];
            out dataset : DigitalEvent[*];
        }
    }
    
    part def HighVoltagePowerSupply {
        attribute outputVoltage : ElectricPotentialValue;
        attribute voltageStability : Real;
        attribute maxOutputCurrent : ElectricCurrentValue;
        attribute rippleNoise : ElectricPotentialValue;
        
        port biasOut : BiasVoltagePort;
        
        action supplyBias {
            out voltage : ElectricPotentialValue;
            out current : ElectricCurrentValue;
        }
    }
    
    part def TemperatureController {
        attribute setpointTemperature : ThermodynamicTemperatureValue;
        attribute coolingPower : PowerValue;
        attribute temperatureStability : ThermodynamicTemperatureValue;
        
        action regulateTemperature {
            in currentTemp : ThermodynamicTemperatureValue;
            in targetTemp : ThermodynamicTemperatureValue;
            out coolingOutput : PowerValue;
        }
    }
    
    action def DetectAndMeasureRadiation {
        in incidentRadiation : RadiationEvent[*];
        in biasVoltage : ElectricPotentialValue;
        in detectionThreshold : ThresholdLevel;
        in amplifierGain : Real;
        out measuredEvents : DigitalEvent[*];
        
        first start;
        then action initialize {
            out systemReady : Boolean;
        }
        then merge detectionLoop;
        
        action processRadiation {
            in radiation : RadiationEvent[*];
            out digitalData : DigitalEvent[*];
            
            action ionizeMedia {
                in radiationEvent : RadiationEvent;
                out chargeCarriers : ElectricChargeValue;
            }
            then action driftCharge {
                in carriers : ElectricChargeValue;
                in electricField : ElectricPotentialValue;
                out inducedPulse : ElectricPulse;
            }
            then action amplifySignal {
                in pulse : ElectricPulse;
                in gain : Real;
                out amplifiedSignal : ElectricPulse;
            }
            then action shapeSignal {
                in signal : ElectricPulse;
                out optimizedPulse : ElectricPulse;
            }
            then action analyzeHeight {
                in optimizedPulse : ElectricPulse;
                in threshold : ThresholdLevel;
                out validEvent : DigitalEvent;
            }
        }
        then detectionLoop;
        
        action aggregateResults {
            in validEvents : DigitalEvent[*];
            out finalDataset : DigitalEvent[*];
        }
        then done;
    }
    
    state def DetectorOperationalStates {
        entry; then standby;
        
        state standby {
            entry assign operatingStatus = "Standby Mode";
        }
        transition standby_to_initialization
            first standby
            accept powerOnCommand
            then initialization;
        
        state initialization {
            entry assign operatingStatus = "Initializing";
            do action rampBiasVoltage;
            do action stabilizeTemperature;
            do action calibrateElectronics;
        }
        transition initialization_to_operational
            first initialization
            if biasStabilized and temperatureStabilized and calibrationComplete
            then operational;
        
        state operational {
            entry assign operatingStatus = "Operational";
            
            state idle {
                entry assign detectionStatus = "Idle";
            }
            transition idle_to_acquiring
                first idle
                accept startAcquisition
                then acquiring;
            
            state acquiring {
                entry assign detectionStatus = "Acquiring Data";
                do action continuousDetection;
                
                state detectingEvents {
                    do action monitorRadiation;
                }
                
                state processingSignals {
                    do action convertAndAnalyze;
                }
                
                state recordingData {
                    do action storeEvents;
                }
            }
            transition acquiring_to_idle
                first acquiring
                accept stopAcquisition
                then idle;
        }
        transition operational_to_maintenance
            first operational
            accept maintenanceRequest
            then maintenance;
        
        state maintenance {
            entry assign operatingStatus = "Maintenance Mode";
            do action performDiagnostics;
            do action adjustCalibration;
        }
        transition maintenance_to_operational
            first maintenance
            accept resumeOperation
            then operational;
        
        transition operational_to_shutdown
            first operational
            accept shutdownCommand
            then shutdown;
        
        state shutdown {
            entry assign operatingStatus = "Shutting Down";
            do action rampDownBias;
            do action disableCooling;
            do action saveConfiguration;
        }
        then done;
        
        attribute operatingStatus : String;
        attribute detectionStatus : String;
        attribute biasStabilized : Boolean;
        attribute temperatureStabilized : Boolean;
        attribute calibrationComplete : Boolean;
    }
    
    part def SemiconductorDetectorSystem;
    
    part semiconductorDetectorSystem : SemiconductorDetectorSystem {
        attribute systemIdentifier : String;
        attribute detectorConfiguration : String = "High Purity Germanium Detector";
        attribute operatingMode : String;
        
        part sensor : SemiconductorSensor {
            attribute depletionDepth = 15.0 [SI::mm];
            attribute activeVolume = 100.0 [SI::cm3];
            attribute operatingBias = 3000.0 [SI::V];
            attribute materialType = "HPGe";
        }
        
        part preAmplifier : ChargeAmplifier {
            attribute feedbackCapacitance = 1.0 [SI::pF];
            attribute inputImpedance = 1.0e12 [SI::'Ω'];
            attribute amplificationFactor = 50.0;
        }
        
        part shaper : PulseShapingCircuit {
            attribute shapingTimeConstant = 2.0e-6 [SI::s];
            attribute filterOrder = 4;
        }
        
        part analyzer : PulseHeightAnalyzer {
            attribute adcResolution = 16;
            attribute conversionTime = 10.0e-6 [SI::s];
            attribute dynamicRange = 10.0 [SI::V];
        }
        
        part dataSystem : DataAcquisitionUnit {
            attribute bufferCapacity = 8192;
            attribute acquisitionRate = 100000.0 [SI::Hz];
            attribute storageFormat = "List Mode";
        }
        
        part hvSupply : HighVoltagePowerSupply {
            attribute outputVoltage = 3000.0 [SI::V];
            attribute voltageStability = 0.01;
            attribute maxOutputCurrent = 5.0 [SI::mA];
            attribute rippleNoise = 0.1 [SI::V];
        }
        
        part cooler : TemperatureController {
            attribute setpointTemperature = 77.0 [SI::K];
            attribute coolingPower = 100.0 [SI::W];
            attribute temperatureStability = 0.5 [SI::K];
        }
        
        connect hvSupply.biasOut to sensor.biasIn;
        connect sensor.chargeOut to preAmplifier.chargeIn;
        connect preAmplifier.voltageOut to shaper.pulseIn;
        connect shaper.shapedOut to analyzer.analogIn;
        connect analyzer.digitalOut to dataSystem.eventIn;
        
        perform action detectMeasure : DetectAndMeasureRadiation {
            in incidentRadiation[*];
            in biasVoltage = hvSupply.outputVoltage;
            in detectionThreshold;
            in amplifierGain = preAmplifier.amplificationFactor;
            out measuredEvents[*];
        }
        
        exhibit state systemState : DetectorOperationalStates;
    }
    
    requirement def EnergyResolutionRequirement {
        doc /* The detector system shall provide sufficient energy resolution to 
               distinguish between radiation sources with closely spaced energy peaks. */
        
        attribute fwhmAtReference : EnergyValue;
        attribute referenceEnergy : EnergyValue;
        attribute resolutionPercentage : Real;
        
        require constraint resolutionLimit {
            resolutionPercentage <= 0.2
        }
    }
    
    requirement def DetectionEfficiencyRequirement {
        doc /* The detector system shall achieve minimum detection efficiency 
               across the specified energy range for target radiation types. */
        
        attribute minimumEfficiency : Real;
        attribute energyRangeLow : EnergyValue;
        attribute energyRangeHigh : EnergyValue;
        
        require constraint efficiencyThreshold {
            minimumEfficiency >= 0.90
        }
    }
    
    requirement def CountRateCapabilityRequirement {
        doc /* The detector system shall process radiation events at rates 
               sufficient for the intended measurement applications. */
        
        attribute maxCountRate : FrequencyValue;
        attribute deadTime : TimeValue;
        attribute pileupRejection : Real;
        
        require constraint throughputCapability {
            maxCountRate >= 50000.0 [SI::Hz]
        }
    }
    
    requirement def OperationalStabilityRequirement {
        doc /* The detector system shall maintain stable operating conditions 
               including temperature, bias voltage, and electronic gain. */
        
        attribute temperatureVariation : ThermodynamicTemperatureValue;
        attribute biasStability : Real;
        attribute gainDrift : Real;
        
        require constraint stabilityLimits {
            temperatureVariation <= 1.0 [SI::K] and
            biasStability <= 0.01 and
            gainDrift <= 0.005
        }
    }
    
    requirement <'DET-SYS-001'> primaryDetectionFunction {
        doc /* The semiconductor detector system shall detect ionizing radiation particles 
               and photons, convert their deposited energy into measurable electrical signals, 
               and process these signals to produce precise digital measurements of radiation 
               energy, intensity, and temporal distribution for spectroscopic analysis and 
               radiation monitoring applications. */
        
        subject system : SemiconductorDetectorSystem;
        
        assume constraint radiationInteraction {
            doc /* Incident radiation interacts with semiconductor crystal lattice creating 
                   electron-hole pairs proportional to deposited energy. */
        }
        
        assume constraint chargeCollection {
            doc /* Applied electric field causes charge carrier drift and collection 
                   at detector electrodes within microsecond timescales. */
        }
        
        require energyResolution : EnergyResolutionRequirement {
            fwhmAtReference = 2.0 [SI::keV];
            referenceEnergy = 1332.0 [SI::keV];
            resolutionPercentage = 0.15;
        }
        
        require detectionEfficiency : DetectionEfficiencyRequirement {
            minimumEfficiency = 0.90;
            energyRangeLow = 50.0 [SI::keV];
            energyRangeHigh = 3000.0 [SI::keV];
        }
        
        require countRateCapability : CountRateCapabilityRequirement {
            maxCountRate = 100000.0 [SI::Hz];
            deadTime = 5.0e-6 [SI::s];
            pileupRejection = 0.95;
        }
        
        require operationalStability : OperationalStabilityRequirement {
            temperatureVariation = 0.5 [SI::K];
            biasStability = 0.005;
            gainDrift = 0.002;
        }
    }
}
