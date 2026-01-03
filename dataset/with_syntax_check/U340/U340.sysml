package OsteomedBoneHealingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PatientID;
    attribute def TreatmentProtocol;
    attribute def SessionID;
    
    attribute def BoneDensityValue :> Real;
    attribute def BoneDensityUnit;
    
    item def UltrasoundWaveform {
        attribute frequency : FrequencyValue;
        attribute intensity : PowerValue;
        attribute pulseDuration : TimeValue;
        attribute dutyCycle : Real;
    }
    
    item def BoneTissueState {
        attribute currentDensity : BoneDensityValue;
        attribute healingRate : Real;
        attribute cellularActivity : Real;
    }
    
    item def TreatmentParameters {
        attribute sessionDuration : TimeValue;
        attribute targetFrequency : FrequencyValue;
        attribute targetIntensity : PowerValue;
        attribute numberOfSessions : Integer;
    }
    
    port def UltrasoundOutputPort {
        out waveform : UltrasoundWaveform;
    }
    
    port def TissueContactPort {
        in waveform : UltrasoundWaveform;
        out tissueState : BoneTissueState;
    }
    
    port def ControlInterfacePort {
        in patientID : PatientID;
        in protocol : TreatmentProtocol;
        out sessionID : SessionID;
    }
    
    port def MonitoringPort {
        out boneDensity : BoneDensityValue;
        out healingProgress : Real;
        out systemStatus : Real;
    }
    
    port def PowerSupplyPort {
        out voltage : ISQ::VoltageValue;
        out current : ISQ::ElectricCurrentValue;
    }
    
    part def UltrasoundGeneratorModule {
        port output : UltrasoundOutputPort;
        port powerIn : PowerSupplyPort;
        
        attribute operatingFrequency : FrequencyValue;
        attribute outputIntensity : PowerValue;
        attribute waveformType : Real;
        
        perform action generateWaveform {
            in targetFreq : FrequencyValue;
            in targetIntensity : PowerValue;
            out ultrasoundWave : UltrasoundWaveform;
        }
    }
    
    part def TransducerAssembly {
        port signalInput : UltrasoundOutputPort;
        port tissueContact : TissueContactPort;
        
        attribute transducerCount : Integer;
        attribute beamFocusDepth : LengthValue;
        attribute couplingEfficiency : Real;
        
        perform action transmitToTissue {
            in inputWaveform : UltrasoundWaveform;
            out deliveredWaveform : UltrasoundWaveform;
        }
    }
    
    part def BoneDensitySensor {
        port tissueInterface : TissueContactPort;
        port dataOutput : MonitoringPort;
        
        attribute measurementAccuracy : Real;
        attribute samplingRate : FrequencyValue;
        
        perform action measureBoneDensity {
            in tissueState : BoneTissueState;
            out densityMeasurement : BoneDensityValue;
            out progressMetric : Real;
        }
    }
    
    part def TreatmentControlUnit {
        port userInterface : ControlInterfacePort;
        port monitoring : MonitoringPort;
        port powerOut : PowerSupplyPort;
        
        attribute currentProtocol : TreatmentProtocol;
        attribute sessionCounter : Integer;
        
        perform action executeProtocol;
    }
    
    part def PowerManagementUnit {
        port powerOutput : PowerSupplyPort;
        
        attribute batteryLevel : Real;
        attribute outputVoltage : ISQ::VoltageValue;
        attribute outputCurrent : ISQ::ElectricCurrentValue;
        
        perform action regulatePower {
            in demandedPower : PowerValue;
            out suppliedVoltage : ISQ::VoltageValue;
            out suppliedCurrent : ISQ::ElectricCurrentValue;
        }
    }
    
    action def InitializeSystem {
        out systemReady : Boolean;
        out diagnosticStatus : Real;
    }
    
    action def LoadTreatmentProtocol {
        in patientID : PatientID;
        in protocol : TreatmentProtocol;
        out treatmentParams : TreatmentParameters;
        out sessionPlan : Real;
    }
    
    action def ValidateParameters {
        in params : TreatmentParameters;
        out validationResult : Boolean;
        out adjustedParams : TreatmentParameters;
    }
    
    action def ActivateUltrasound {
        in params : TreatmentParameters;
        out waveformConfig : UltrasoundWaveform;
    }
    
    action def DeliverStimulation {
        in waveform : UltrasoundWaveform;
        in duration : TimeValue;
        out deliveredEnergy : EnergyValue;
    }
    
    action def MonitorTissueResponse {
        in tissueState : BoneTissueState;
        out responseMetrics : Real;
        out safetyCheck : Boolean;
    }
    
    action def AssessProgress {
        in currentDensity : BoneDensityValue;
        in baselineDensity : BoneDensityValue;
        out improvementPercent : Real;
        out continueProtocol : Boolean;
        out protocolComplete : Boolean;
    }
    
    action def RecordSessionData {
        in sessionID : SessionID;
        in densityData : BoneDensityValue;
        in stimulationData : UltrasoundWaveform;
        out dataRecorded : Boolean;
    }
    
    action def GenerateTreatmentReport {
        in patientID : PatientID;
        in sessionHistory : Real[*];
        in finalDensity : BoneDensityValue;
        out reportGenerated : Boolean;
    }
    
    action def PerformBoneHealingTherapy {
        in patientID : PatientID;
        in treatmentProtocol : TreatmentProtocol;
        in baselineDensity : BoneDensityValue;
        in targetImprovement : Real;
        out finalDensity : BoneDensityValue;
        out treatmentOutcome : Real;
        
        first start;
        then action initialize : InitializeSystem {
            out systemReady;
            out diagnosticStatus;
        }
        then action loadProtocol : LoadTreatmentProtocol {
            in patientID = PerformBoneHealingTherapy::patientID;
            in protocol = PerformBoneHealingTherapy::treatmentProtocol;
            out treatmentParams;
            out sessionPlan;
        }
        then action validate : ValidateParameters {
            in params = loadProtocol.treatmentParams;
            out validationResult;
            out adjustedParams;
        }
        then merge treatmentLoop;
        then action activate : ActivateUltrasound {
            in params = validate.adjustedParams;
            out waveformConfig;
        }
        then action deliver : DeliverStimulation {
            in waveform = activate.waveformConfig;
            in duration = validate.adjustedParams.sessionDuration;
            out deliveredEnergy;
        }
        then action monitor : MonitorTissueResponse {
            in tissueState;
            out responseMetrics;
            out safetyCheck;
        }
        then action assess : AssessProgress {
            in currentDensity;
            in baselineDensity = PerformBoneHealingTherapy::baselineDensity;
            out improvementPercent;
            out continueProtocol;
            out protocolComplete;
        }
        then action record : RecordSessionData {
            in sessionID;
            in densityData = assess.currentDensity;
            in stimulationData = activate.waveformConfig;
            out dataRecorded;
        }
        then decide;
            if assess.continueProtocol then treatmentLoop;
            if assess.protocolComplete then generateReport;
        action generateReport : GenerateTreatmentReport {
            in patientID = PerformBoneHealingTherapy::patientID;
            in sessionHistory;
            in finalDensity = assess.currentDensity;
            out reportGenerated;
        }
        then assign finalDensity := assess.currentDensity;
        then assign treatmentOutcome := assess.improvementPercent;
        then done;
    }
    
    part osteomedTherapeuticDevice : OsteomedBoneStimulationSystem {
        doc /*
            Osteomed bone healing stimulation system utilizing low-intensity pulsed 
            ultrasound (LIPUS) technology to accelerate fracture healing and enhance 
            bone regeneration through mechanical stimulation of osteoblasts and 
            promotion of cellular differentiation and matrix synthesis.
        */
        
        part generator : UltrasoundGeneratorModule {
            :>> operatingFrequency = 1.5e6 [SI::Hz];
            :>> outputIntensity = 0.03 [SI::W];
            :>> waveformType = 1.0;
        }
        
        part transducerArray : TransducerAssembly {
            :>> transducerCount = 4;
            :>> beamFocusDepth = 0.02 [SI::m];
            :>> couplingEfficiency = 0.85;
        }
        
        part densitySensor : BoneDensitySensor {
            :>> measurementAccuracy = 0.95;
            :>> samplingRate = 10.0 [SI::Hz];
        }
        
        part controlUnit : TreatmentControlUnit {
            :>> sessionCounter = 0;
        }
        
        part powerUnit : PowerManagementUnit {
            :>> batteryLevel = 1.0;
            :>> outputVoltage = 12.0 [SI::V];
            :>> outputCurrent = 2.5 [SI::A];
        }
        
        connection powerToControl 
            connect powerUnit.powerOutput to controlUnit.powerOut;
        
        connection powerToGenerator 
            connect powerUnit.powerOutput to generator.powerIn;
        
        connection generatorToTransducer 
            connect generator.output to transducerArray.signalInput;
        
        connection transducerToTissue 
            connect transducerArray.tissueContact to densitySensor.tissueInterface;
        
        connection sensorToControl 
            connect densitySensor.dataOutput to controlUnit.monitoring;
        
        perform action therapySession[*] ordered 
            references PerformBoneHealingTherapy {
            in patientID;
            in treatmentProtocol;
            in baselineDensity;
            in targetImprovement = 20.0;
            out finalDensity;
            out treatmentOutcome;
        }
    }
    
    part def OsteomedBoneStimulationSystem {
        doc /*
            Primary Function: Accelerate bone fracture healing and promote bone 
            regeneration by delivering precisely controlled low-intensity pulsed 
            ultrasound stimulation to target tissue sites, thereby enhancing 
            osteoblast activity, increasing bone mineral density, and reducing 
            healing time through non-invasive mechanical stimulation of cellular 
            repair mechanisms and extracellular matrix formation.
        */
    }
    
    requirement def TherapeuticEfficacyRequirement {
        doc /*
            The Osteomed system shall demonstrate clinically significant improvement 
            in bone healing rate and density compared to natural healing processes, 
            achieving measurable increases in bone mineral density and reduction in 
            healing time.
        */
        
        require constraint healingImprovement {
            attribute minDensityIncrease : Real = 15.0;
            attribute minTimeReduction : Real = 25.0;
        }
    }
    
    requirement def StimulationSafetyRequirement {
        doc /*
            The ultrasound stimulation parameters shall remain within established 
            safe limits to prevent thermal damage or adverse tissue effects while 
            maintaining therapeutic effectiveness.
        */
        
        require constraint safetyLimits {
            attribute maxIntensity : PowerValue = 0.1 [SI::W];
            attribute maxTemperatureRise : TemperatureValue = 1.5 [SI::K];
            attribute maxDuration : TimeValue = 1800.0 [SI::s];
        }
    }
    
    requirement def TreatmentConsistencyRequirement {
        doc /*
            The system shall deliver consistent and repeatable stimulation across 
            treatment sessions to ensure reliable therapeutic outcomes and protocol 
            adherence.
        */
        
        require constraint consistency {
            attribute frequencyTolerance : Real = 2.0;
            attribute intensityTolerance : Real = 5.0;
            attribute sessionVariability : Real = 3.0;
        }
    }
    
    requirement def MonitoringAccuracyRequirement {
        doc /*
            The bone density monitoring system shall provide accurate and timely 
            measurements to enable effective treatment adjustment and outcome 
            assessment.
        */
        
        require constraint monitoringPerformance {
            attribute minAccuracy : Real = 0.90;
            attribute maxMeasurementDelay : TimeValue = 2.0 [SI::s];
        }
    }
    
    requirement osteomedSystemRequirements {
        doc /*
            Comprehensive requirements for the Osteomed bone healing stimulation 
            system covering therapeutic efficacy, patient safety, treatment 
            consistency, and monitoring performance.
        */
        
        subject device : OsteomedBoneStimulationSystem;
        
        require efficacy : TherapeuticEfficacyRequirement;
        require safety : StimulationSafetyRequirement;
        require consistency : TreatmentConsistencyRequirement;
        require monitoring : MonitoringAccuracyRequirement;
    }
}
