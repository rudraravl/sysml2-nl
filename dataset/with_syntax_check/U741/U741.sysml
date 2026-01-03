package LabOnAChipSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def SampleIdentifier {
        attribute id : String;
        attribute timestamp : TimeValue;
    }
    
    enum def BiomarkerType {
        glucose;
        cholesterol;
        protein;
        dna;
    }
    
    enum def AssayStatus {
        idle;
        loading;
        mixing;
        incubating;
        detecting;
        analyzing;
        complete;
        error;
    }
    
    attribute def FluidVolume :> VolumeValue {
        attribute :>> num : Real;
    }
    
    attribute def FlowRate :> VolumeFlowRateValue {
        attribute :>> num : Real;
    }
    
    attribute def ReactionTemperature :> ThermodynamicTemperatureValue {
        attribute :>> num : Real;
    }
    
    attribute def Concentration :> DimensionOneValue {
        attribute :>> num : Real;
    }
    
    attribute def OpticalIntensity :> DimensionOneValue {
        attribute :>> num : Real;
    }
    
    item def BiologicalSample {
        attribute sampleId : SampleIdentifier;
        attribute volume : FluidVolume;
        attribute temperature : ReactionTemperature;
        attribute biomarker : BiomarkerType;
    }
    
    item def ChemicalReagent {
        attribute reagentType : String;
        attribute volume : FluidVolume;
        attribute concentration : Concentration;
    }
    
    item def AnalysisResult {
        attribute sampleId : SampleIdentifier;
        attribute biomarkerConcentration : Concentration;
        attribute detectionSignal : OpticalIntensity;
        attribute status : AssayStatus;
        attribute processingTime : TimeValue;
    }
    
    port def FluidInputPort {
        in item fluid : BiologicalSample;
        attribute flowRate : FlowRate;
    }
    
    port def ReagentInputPort {
        in item reagent : ChemicalReagent;
        attribute flowRate : FlowRate;
    }
    
    port def FluidOutputPort {
        out item fluid : BiologicalSample;
        attribute flowRate : FlowRate;
    }
    
    port def OpticalDetectionPort {
        out attribute signal : OpticalIntensity;
        attribute wavelength : LengthValue;
    }
    
    port def ControlSignalPort {
        in attribute command : String;
        out attribute status : AssayStatus;
    }
    
    port def DataOutputPort {
        out item result : AnalysisResult;
    }
    
    part def SampleReservoir {
        port sampleOut : FluidOutputPort;
        attribute capacity : FluidVolume;
        attribute currentLevel : FluidVolume;
    }
    
    part def ReagentReservoir {
        port reagentOut : ReagentInputPort;
        attribute capacity : FluidVolume;
        attribute currentLevel : FluidVolume;
        attribute reagentType : String;
    }
    
    part def MicrofluidicPump {
        port fluidIn : FluidInputPort;
        port fluidOut : FluidOutputPort;
        port control : ControlSignalPort;
        attribute pumpRate : FlowRate;
        attribute maxFlowRate : FlowRate;
    }
    
    part def MicrofluidicChannel {
        port inlet : FluidInputPort;
        port outlet : FluidOutputPort;
        attribute channelWidth : LengthValue;
        attribute channelDepth : LengthValue;
        attribute channelLength : LengthValue;
    }
    
    part def MixingChamber {
        port sampleIn : FluidInputPort;
        port reagentIn : ReagentInputPort;
        port mixedOut : FluidOutputPort;
        attribute chamberVolume : FluidVolume;
        attribute mixingEfficiency : Real;
        attribute mixingTime : TimeValue;
    }
    
    part def IncubationChamber {
        port fluidIn : FluidInputPort;
        port fluidOut : FluidOutputPort;
        port control : ControlSignalPort;
        attribute chamberVolume : FluidVolume;
        attribute targetTemperature : ReactionTemperature;
        attribute currentTemperature : ReactionTemperature;
        attribute incubationTime : TimeValue;
    }
    
    part def OpticalDetector {
        port detectionWindow : FluidInputPort;
        port signalOut : OpticalDetectionPort;
        port control : ControlSignalPort;
        attribute sensitivity : Real;
        attribute excitationWavelength : LengthValue;
        attribute emissionWavelength : LengthValue;
    }
    
    part def WasteReservoir {
        port wasteIn : FluidInputPort;
        attribute capacity : FluidVolume;
        attribute currentLevel : FluidVolume;
    }
    
    part def MicrocontrollerUnit {
        port pumpControl : ControlSignalPort;
        port incubatorControl : ControlSignalPort;
        port detectorControl : ControlSignalPort;
        port dataOut : DataOutputPort;
        attribute processingPower : PowerValue;
    }
    
    action def LoadSample {
        in sampleInput : BiologicalSample;
        in loadVolume : FluidVolume;
        out loadedSample : BiologicalSample;
    }
    
    action def DispenseReagent {
        in reagentInput : ChemicalReagent;
        in dispenseVolume : FluidVolume;
        out dispensedReagent : ChemicalReagent;
    }
    
    action def MixFluids {
        in sample : BiologicalSample;
        in reagent : ChemicalReagent;
        in mixDuration : TimeValue;
        out mixture : BiologicalSample;
    }
    
    action def IncubateMixture {
        in mixture : BiologicalSample;
        in targetTemp : ReactionTemperature;
        in incubationDuration : TimeValue;
        out incubatedMixture : BiologicalSample;
    }
    
    action def PerformOpticalDetection {
        in sample : BiologicalSample;
        out detectionSignal : OpticalIntensity;
    }
    
    action def AnalyzeDetectionSignal {
        in signal : OpticalIntensity;
        in sampleId : SampleIdentifier;
        out analysisResult : AnalysisResult;
    }
    
    action def FlushWaste {
        in wasteFluid : BiologicalSample;
    }
    
    attribute def AssayParameters {
        attribute sampleVolume : FluidVolume;
        attribute reagentVolume : FluidVolume;
        attribute mixingTime : TimeValue;
        attribute incubationTemperature : ReactionTemperature;
        attribute incubationTime : TimeValue;
    }
    
    action def ExecuteBioassay {
        in inputSample : BiologicalSample;
        in inputReagent : ChemicalReagent;
        in assayParameters : AssayParameters;
        out finalResult : AnalysisResult;
        
        first start;
        
        then action loadSample : LoadSample {
            in sampleInput = inputSample;
            in loadVolume = assayParameters.sampleVolume;
            out loadedSample;
        }
        
        then action dispenseReagent : DispenseReagent {
            in reagentInput = inputReagent;
            in dispenseVolume = assayParameters.reagentVolume;
            out dispensedReagent;
        }
        
        then action mixFluids : MixFluids {
            in sample = loadSample.loadedSample;
            in reagent = dispenseReagent.dispensedReagent;
            in mixDuration = assayParameters.mixingTime;
            out mixture;
        }
        
        then action incubateMixture : IncubateMixture {
            in mixture = mixFluids.mixture;
            in targetTemp = assayParameters.incubationTemperature;
            in incubationDuration = assayParameters.incubationTime;
            out incubatedMixture;
        }
        
        then action performDetection : PerformOpticalDetection {
            in sample = incubateMixture.incubatedMixture;
            out detectionSignal;
        }
        
        then action analyzeSignal : AnalyzeDetectionSignal {
            in signal = performDetection.detectionSignal;
            in sampleId = inputSample.sampleId;
            out analysisResult;
        }
        
        then assign finalResult := analyzeSignal.analysisResult;
        
        then action flushWaste : FlushWaste {
            in wasteFluid = incubateMixture.incubatedMixture;
        }
        
        then done;
    }
    
    part def LabOnAChipDevice {
        doc /* 
            Integrated microfluidic lab-on-a-chip system for automated biochemical analysis.
            Performs complete bioassay workflow from sample loading through detection and analysis.
        */
        
        attribute deviceId : String;
        attribute operationalStatus : AssayStatus;
        
        part sampleReservoir : SampleReservoir {
            attribute :>> capacity : FluidVolume;
            attribute :>> currentLevel : FluidVolume;
        }
        
        part reagentReservoir1 : ReagentReservoir {
            attribute :>> capacity : FluidVolume;
            attribute :>> currentLevel : FluidVolume;
            attribute :>> reagentType = "Detection Antibody";
        }
        
        part reagentReservoir2 : ReagentReservoir {
            attribute :>> capacity : FluidVolume;
            attribute :>> currentLevel : FluidVolume;
            attribute :>> reagentType = "Substrate Solution";
        }
        
        part samplePump : MicrofluidicPump {
            attribute :>> pumpRate : FlowRate;
            attribute :>> maxFlowRate : FlowRate;
        }
        
        part reagentPump1 : MicrofluidicPump {
            attribute :>> pumpRate : FlowRate;
            attribute :>> maxFlowRate : FlowRate;
        }
        
        part reagentPump2 : MicrofluidicPump {
            attribute :>> pumpRate : FlowRate;
            attribute :>> maxFlowRate : FlowRate;
        }
        
        part sampleChannel : MicrofluidicChannel {
            attribute :>> channelWidth : LengthValue;
            attribute :>> channelDepth : LengthValue;
            attribute :>> channelLength : LengthValue;
        }
        
        part reagentChannel1 : MicrofluidicChannel {
            attribute :>> channelWidth : LengthValue;
            attribute :>> channelDepth : LengthValue;
            attribute :>> channelLength : LengthValue;
        }
        
        part reagentChannel2 : MicrofluidicChannel {
            attribute :>> channelWidth : LengthValue;
            attribute :>> channelDepth : LengthValue;
            attribute :>> channelLength : LengthValue;
        }
        
        part mixer : MixingChamber {
            attribute :>> chamberVolume : FluidVolume;
            attribute :>> mixingEfficiency = 0.95;
            attribute :>> mixingTime : TimeValue;
        }
        
        part incubator : IncubationChamber {
            attribute :>> chamberVolume : FluidVolume;
            attribute :>> targetTemperature : ReactionTemperature;
            attribute :>> currentTemperature : ReactionTemperature;
            attribute :>> incubationTime : TimeValue;
        }
        
        part detector : OpticalDetector {
            attribute :>> sensitivity = 0.001;
            attribute :>> excitationWavelength : LengthValue;
            attribute :>> emissionWavelength : LengthValue;
        }
        
        part waste : WasteReservoir {
            attribute :>> capacity : FluidVolume;
            attribute :>> currentLevel : FluidVolume;
        }
        
        part controller : MicrocontrollerUnit {
            attribute :>> processingPower : PowerValue;
        }
        
        connection sampleFlow connect sampleReservoir.sampleOut to samplePump.fluidIn;
        connection samplePumpToChannel connect samplePump.fluidOut to sampleChannel.inlet;
        connection sampleToMixer connect sampleChannel.outlet to mixer.sampleIn;
        
        connection reagent1Flow connect reagentReservoir1.reagentOut to reagentPump1.fluidIn;
        connection reagent1PumpToChannel connect reagentPump1.fluidOut to reagentChannel1.inlet;
        connection reagent1ToMixer connect reagentChannel1.outlet to mixer.reagentIn;
        
        connection reagent2Flow connect reagentReservoir2.reagentOut to reagentPump2.fluidIn;
        connection reagent2PumpToChannel connect reagentPump2.fluidOut to reagentChannel2.inlet;
        
        connection mixerToIncubator connect mixer.mixedOut to incubator.fluidIn;
        connection incubatorToDetector connect incubator.fluidOut to detector.detectionWindow;
        connection detectorToWaste connect detector.detectionWindow to waste.wasteIn;
        
        connection controllerToPumps connect controller.pumpControl to samplePump.control;
        connection controllerToIncubator connect controller.incubatorControl to incubator.control;
        connection controllerToDetector connect controller.detectorControl to detector.control;
        connection detectorToController connect detector.signalOut to controller.dataOut;
        
        perform action bioassayExecution : ExecuteBioassay;
    }
    
    requirement def SystemFunctionalRequirement {
        doc /* The lab-on-a-chip system shall perform automated biochemical assays. */
    }
    
    requirement def FluidHandlingRequirement {
        doc /* The system shall accurately control fluid volumes and flow rates. */
    }
    
    requirement def TemperatureControlRequirement {
        doc /* The system shall maintain precise temperature control during incubation. */
    }
    
    requirement def DetectionSensitivityRequirement {
        doc /* The optical detector shall achieve minimum detection sensitivity. */
    }
    
    requirement def AssayThroughputRequirement {
        doc /* The system shall complete a single assay within specified time. */
    }
    
    requirement def WasteManagementRequirement {
        doc /* The waste reservoir shall have sufficient capacity for multiple assays. */
    }
    
    requirement <'LOC-SYS-001'> primarySystemRequirement {
        doc /* 
            The lab-on-a-chip system shall perform automated biochemical analysis
            by integrating sample handling, reagent mixing, controlled incubation,
            and optical detection on a single microfluidic platform to determine
            biomarker concentrations in biological samples.
        */
        
        subject labOnChipSystem : LabOnAChipDevice;
        
        require systemFunction : SystemFunctionalRequirement;
        require fluidHandling : FluidHandlingRequirement;
        require temperatureControl : TemperatureControlRequirement;
        require detectionSensitivity : DetectionSensitivityRequirement;
        require assayThroughput : AssayThroughputRequirement;
        require wasteManagement : WasteManagementRequirement;
    }
    
    part labOnChipSystem : LabOnAChipDevice {
        attribute :>> deviceId = "LOC-PROTO-001";
    }
}
