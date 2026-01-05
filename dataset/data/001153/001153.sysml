package NanosensorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SequenceFunctions::*;
    
    attribute def ConcentrationValue :> Real;
    attribute def SignalIntensityValue :> Real;
    
    attribute def StartCommand;
    attribute def StopCommand;
    attribute def CalibrationCommand;
    
    item def TargetMolecule {
        attribute molecularWeight : MassValue;
        attribute concentration : ConcentrationValue;
        attribute bindingAffinity : Real;
    }
    
    item def OpticalSignal {
        attribute wavelength : LengthValue;
        attribute intensity : SignalIntensityValue;
        attribute timestamp : TimeValue;
    }
    
    port def SensingInterface {
        in item sampleInput : TargetMolecule;
        out attribute detectedConcentration : ConcentrationValue;
    }
    
    port def OpticalOutputInterface {
        out item signalOutput : OpticalSignal;
    }
    
    port def ControlInterface {
        in attribute startCmd : StartCommand;
        in attribute stopCmd : StopCommand;
        in attribute calibrationCmd : CalibrationCommand;
        out attribute operationalStatus : Real;
    }
    
    part def NanoparticleSurface {
        attribute surfaceArea : AreaValue;
        attribute bindingSites : Integer;
        attribute functionalizedCoating : String;
        
        action bindMolecule {
            in targetMolecule : TargetMolecule;
            out bindingOccurred : Boolean;
            out boundConcentration : ConcentrationValue;
        }
    }
    
    part def OpticalTransducer {
        attribute excitationWavelength : LengthValue;
        attribute emissionWavelength : LengthValue;
        attribute quantumEfficiency : Real;
        
        action generateOpticalSignal {
            in molecularBinding : ConcentrationValue;
            out opticalOutput : OpticalSignal;
        }
    }
    
    part def SignalAmplifier {
        attribute gainFactor : Real;
        attribute noiseFloor : SignalIntensityValue;
        
        action amplifySignal {
            in rawSignal : OpticalSignal;
            out amplifiedSignal : OpticalSignal;
        }
    }
    
    part def DataProcessor {
        attribute calibrationFactor : Real;
        attribute detectionThreshold : ConcentrationValue;
        
        action processData {
            in amplifiedSignal : OpticalSignal;
            out quantifiedConcentration : ConcentrationValue;
        }
        
        action calibrate {
            in referenceConcentration : ConcentrationValue;
            in measuredSignal : OpticalSignal;
            out newCalibrationFactor : Real;
        }
    }
    
    part def Nanosensor {
        attribute sensorIdentifier : String;
        attribute minimumDetectionLimit : ConcentrationValue;
        attribute responseTime : TimeValue;
        attribute operatingTemperatureRange : TemperatureValue[2];
        
        port sensingPort : SensingInterface;
        port opticalPort : OpticalOutputInterface;
        port controlPort : ControlInterface;
        
        part nanoSurface : NanoparticleSurface {
            attribute :>> surfaceArea = 1.0e-14 [SI::m^2];
            attribute :>> bindingSites = 1000;
            attribute :>> functionalizedCoating = "Gold-Antibody";
        }
        
        part transducer : OpticalTransducer {
            attribute :>> excitationWavelength = 532.0e-9 [SI::m];
            attribute :>> emissionWavelength = 580.0e-9 [SI::m];
            attribute :>> quantumEfficiency = 0.85;
        }
        
        part amplifier : SignalAmplifier {
            attribute :>> gainFactor = 1000.0;
            attribute :>> noiseFloor = 0.01;
        }
        
        part processor : DataProcessor {
            attribute :>> calibrationFactor = 1.0;
            attribute :>> detectionThreshold = 1.0e-12;
        }
        
        connection surfaceToTransducer
            connect nanoSurface.bindMolecule.boundConcentration
            to transducer.generateOpticalSignal.molecularBinding;
        
        connection transducerToAmplifier
            connect transducer.generateOpticalSignal.opticalOutput
            to amplifier.amplifySignal.rawSignal;
        
        connection amplifierToProcessor
            connect amplifier.amplifySignal.amplifiedSignal
            to processor.processData.amplifiedSignal;
        
        connection processorToOutput
            connect processor.processData.quantifiedConcentration
            to sensingPort.detectedConcentration;
    }
    
    action def PerformMolecularDetection {
        in sampleMolecule : TargetMolecule;
        in detectionLimit : ConcentrationValue;
        out measuredConcentration : ConcentrationValue;
        out opticalResponse : OpticalSignal;
    }
    
    action def ContinuousSensing {
        in monitoringPeriod : TimeValue;
        in samplingInterval : TimeValue;
        out concentrationTimeSeries : ConcentrationValue[*];
        
        private attribute elapsedTime := 0.0 [SI::s];
        private attribute measurements : ConcentrationValue[*] := ();
        
        first start;
        then merge continueLoop;
        loop {
            action detectSample : PerformMolecularDetection {
                in sampleMolecule : TargetMolecule;
                in detectionLimit : ConcentrationValue;
                out measuredConcentration : ConcentrationValue;
                out opticalResponse : OpticalSignal;
            }
            then assign measurements := measurements->including(detectSample.measuredConcentration);
            then assign elapsedTime := elapsedTime + samplingInterval;
            if elapsedTime < monitoringPeriod then continueLoop;
        }
        then assign concentrationTimeSeries := measurements;
        then done;
    }
    
    state def NanosensorOperationalStates {
        entry; then idle;
        
        state idle {
            entry assign operationalStatus := 0.0;
        }
        
        state calibrating {
            entry assign operationalStatus := 1.0;
            do action runCalibration {
                in referenceValue : ConcentrationValue;
                out calibrationSuccess : Boolean;
            }
        }
        
        state sensing {
            entry assign operationalStatus := 2.0;
            do action activeSensing {
                in moleculeStream : TargetMolecule;
                out continuousSignal : OpticalSignal;
            }
        }
        
        state analyzing {
            entry assign operationalStatus := 3.0;
            do action dataAnalysis {
                in signalData : OpticalSignal[*];
                out finalConcentration : ConcentrationValue;
            }
        }
        
        state standby {
            entry assign operationalStatus := 4.0;
        }
        
        transition idle_to_calibrating
            first idle
            accept calibrationCmd : CalibrationCommand
            then calibrating;
        
        transition calibrating_to_idle
            first calibrating
            if runCalibration.calibrationSuccess
            then idle;
        
        transition idle_to_sensing
            first idle
            accept startCmd : StartCommand
            then sensing;
        
        transition sensing_to_analyzing
            first sensing
            if activeSensing.continuousSignal.intensity > 0.1
            then analyzing;
        
        transition analyzing_to_sensing
            first analyzing
            then sensing;
        
        transition sensing_to_standby
            first sensing
            accept stopCmd : StopCommand
            then standby;
        
        transition analyzing_to_standby
            first analyzing
            accept stopCmd : StopCommand
            then standby;
        
        transition standby_to_idle
            first standby
            accept startCmd : StartCommand
            then idle;
    }
    
    part nanosensorDevice : Nanosensor {
        attribute :>> sensorIdentifier = "NS-BIO-001";
        attribute :>> minimumDetectionLimit = 1.0e-15;
        attribute :>> responseTime = 0.1 [SI::s];
        attribute :>> operatingTemperatureRange = (273.15 [SI::K], 310.15 [SI::K]);
        
        perform action continuousMonitoring : ContinuousSensing {
            in monitoringPeriod = 7200.0 [SI::s];
            in samplingInterval = 0.1 [SI::s];
            out concentrationTimeSeries : ConcentrationValue[*];
        }
        
        state behavior : NanosensorOperationalStates;
    }
    
    requirement def SensitivityRequirement {
        doc /* The nanosensor shall detect target molecules at ultra-low concentrations with high sensitivity. */
        
        subject sensor : Nanosensor;
        
        require constraint detectionLimitConstraint {
            sensor.minimumDetectionLimit <= 1.0e-12
        }
        
        require constraint responseTimeConstraint {
            sensor.responseTime <= 1.0 [SI::s]
        }
    }
    
    requirement def SignalFidelityRequirement {
        doc /* The optical signal shall maintain high fidelity throughout amplification and processing. */
        
        subject amplifier : SignalAmplifier;
        
        require constraint gainConstraint {
            amplifier.gainFactor >= 100.0
        }
        
        require constraint noiseConstraint {
            amplifier.noiseFloor <= 0.05
        }
    }
    
    requirement <'NS-REQ-001'> sensitivitySpec : SensitivityRequirement {
        subject testSensor = nanosensorDevice;
    }
    
    requirement <'NS-REQ-002'> signalQualitySpec : SignalFidelityRequirement {
        subject testAmplifier = nanosensorDevice.amplifier;
    }
    
    requirement <'NS-MISSION-001'> primaryMissionRequirement {
        doc /* The nanosensor system shall detect and quantify specific target molecules in complex 
                biological or chemical environments by converting molecular binding events at the 
                nanoscale surface into measurable optical signals, enabling real-time monitoring for 
                applications in medical diagnostics, environmental sensing, and biochemical research. */
        
        assume constraint targetMoleculePresence {
            doc /* Target molecules are present in the sample environment at detectable concentrations. */
        }
        
        assume constraint environmentalConditions {
            doc /* Operating temperature and pH are within specified ranges for sensor functionality. */
        }
        
        require sensitivitySpec;
        require signalQualitySpec;
        
        require constraint continuousOperationConstraint {
            nanosensorDevice.continuousMonitoring.monitoringPeriod >= 3600.0 [SI::s]
        }
        
        require constraint samplingIntervalConstraint {
            nanosensorDevice.continuousMonitoring.samplingInterval <= 1.0 [SI::s]
        }
    }
}
