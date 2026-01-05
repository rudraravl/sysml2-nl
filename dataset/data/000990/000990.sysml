package BiochipSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def SampleID;
    attribute def AnalyteConcentration;
    attribute def DetectionThreshold;
    
    attribute def FluidVolume {
        attribute volumeAmount : VolumeValue;
    }
    
    attribute def OpticalSignal {
        attribute intensity : PowerValue;
    }
    
    attribute def FlowRate {
        attribute rate : VolumeFlowRateValue;
    }
    
    item def BiologicalSample {
        attribute sampleID : SampleID;
        attribute volume : FluidVolume;
        attribute analytePresent : Boolean;
    }
    
    item def ReagentMixture {
        attribute reagentType : String;
        attribute volume : FluidVolume;
    }
    
    item def AssayResult {
        attribute sampleID : SampleID;
        attribute detectedConcentration : AnalyteConcentration;
        attribute isPositive : Boolean;
        attribute signalStrength : OpticalSignal;
    }
    
    port def FluidInputPort {
        in item sample : BiologicalSample;
    }
    
    port def FluidOutputPort {
        out item waste : BiologicalSample;
    }
    
    port def ReagentPort {
        in item reagent : ReagentMixture;
    }
    
    port def DataOutputPort {
        out item result : AssayResult;
    }
    
    part def MicrofluidicChannel {
        port inlet : FluidInputPort;
        port outlet : FluidOutputPort;
        attribute channelWidth : LengthValue;
        attribute channelDepth : LengthValue;
    }
    
    part def ReactionChamber {
        port sampleInput : FluidInputPort;
        port reagentInput : ReagentPort;
        port chamberOutput : FluidOutputPort;
        attribute chamberVolume : FluidVolume;
        attribute reactionTemperature : TemperatureValue;
    }
    
    part def OpticalDetector {
        port detectionInput : FluidInputPort;
        port signalOutput : DataOutputPort;
        attribute wavelength : LengthValue;
        attribute sensitivity : DetectionThreshold;
    }
    
    part def FluidPump {
        attribute pumpRate : FlowRate;
        attribute maxPressure : PressureValue;
    }
    
    part def TemperatureController {
        attribute targetTemperature : TemperatureValue;
        attribute heatingPower : PowerValue;
    }
    
    action def LoadSample {
        in sampleIn : BiologicalSample;
        in targetVolume : FluidVolume;
        out loadedSample : BiologicalSample;
    }
    
    action def IntroduceReagent {
        in reagent : ReagentMixture;
        in sample : BiologicalSample;
        out mixture : BiologicalSample;
    }
    
    action def IncubateMixture {
        in mixture : BiologicalSample;
        in incubationTime : TimeValue;
        in temperature : TemperatureValue;
        out incubatedSample : BiologicalSample;
    }
    
    action def DetectAnalyte {
        in incubatedSample : BiologicalSample;
        in detectionThreshold : DetectionThreshold;
        out signal : OpticalSignal;
        out concentration : AnalyteConcentration;
    }
    
    action def GenerateResult {
        in signal : OpticalSignal;
        in concentration : AnalyteConcentration;
        in sampleID : SampleID;
        out assayResult : AssayResult;
    }
    
    action def PerformAssay {
        in inputSample : BiologicalSample;
        in reagentInput : ReagentMixture;
        in incubationDuration : TimeValue;
        in incubationTemp : TemperatureValue;
        in threshold : DetectionThreshold;
        out finalResult : AssayResult;
        
        first start;
        then action load : LoadSample {
            in sampleIn = inputSample;
            in targetVolume;
            out loadedSample;
        }
        then action mix : IntroduceReagent {
            in reagent = reagentInput;
            in sample = load.loadedSample;
            out mixture;
        }
        then action incubate : IncubateMixture {
            in mixture = mix.mixture;
            in incubationTime = incubationDuration;
            in temperature = incubationTemp;
            out incubatedSample;
        }
        then action detect : DetectAnalyte {
            in incubatedSample = incubate.incubatedSample;
            in detectionThreshold = threshold;
            out signal;
            out concentration;
        }
        then action generate : GenerateResult {
            in signal = detect.signal;
            in concentration = detect.concentration;
            in sampleID = inputSample.sampleID;
            out assayResult;
        }
        then assign finalResult := generate.assayResult;
        then done;
    }
    
    state def BiochipStateMachine {
        entry; then idle;
        
        state idle;
        
        state ready {
            entry action prepareSystem;
        }
        
        state processing {
            entry action beginAssay;
            do action runAssay : PerformAssay;
        }
        
        state analyzing {
            entry action processSignal;
        }
        
        state complete {
            entry action outputResult;
        }
        
        transition idle_to_ready
            first idle
            then ready;
        
        transition ready_to_processing
            first ready
            accept sampleReceived
            then processing;
        
        transition processing_to_analyzing
            first processing
            then analyzing;
        
        transition analyzing_to_complete
            first analyzing
            then complete;
        
        transition complete_to_idle
            first complete
            then idle;
    }
    
    part def Biochip {
        port samplePort : FluidInputPort;
        port reagentPort : ReagentPort;
        port wastePort : FluidOutputPort;
        port resultPort : DataOutputPort;
        
        part channel : MicrofluidicChannel {
            attribute channelWidth = 100.0;
            attribute channelDepth = 50.0;
        }
        
        part chamber : ReactionChamber {
            attribute chamberVolume;
            attribute reactionTemperature = 310.0;
        }
        
        part detector : OpticalDetector {
            attribute wavelength = 650.0;
            attribute sensitivity;
        }
        
        part pump : FluidPump {
            attribute pumpRate;
            attribute maxPressure = 200.0;
        }
        
        part tempController : TemperatureController {
            attribute targetTemperature = 310.0;
            attribute heatingPower = 5.0;
        }
        
        connect samplePort to channel.inlet;
        connect channel.outlet to chamber.sampleInput;
        connect reagentPort to chamber.reagentInput;
        connect chamber.chamberOutput to detector.detectionInput;
        connect detector.signalOutput to resultPort;
        connect detector.detectionInput to wastePort;
        
        exhibit state biochipBehavior : BiochipStateMachine;
        perform action assay : PerformAssay;
    }
    
    part def BiochipAnalysisSystem {
        part biochip : Biochip;
        
        port systemSampleInput :> biochip.samplePort;
        port systemReagentInput :> biochip.reagentPort;
        port systemWasteOutput :> biochip.wastePort;
        port systemResultOutput :> biochip.resultPort;
    }
    
    requirement def SystemFunctionRequirement {
        doc /* The biochip system shall perform automated biochemical analysis of biological samples. */
        subject system : BiochipAnalysisSystem;
    }
    
    requirement def DetectionSensitivityRequirement {
        doc /* The biochip shall detect target analytes at concentrations down to the specified threshold. */
        subject detector : OpticalDetector;
        require constraint {
            detector.sensitivity <= 0.001
        }
    }
    
    requirement def ProcessingTimeRequirement {
        doc /* The biochip shall complete sample analysis within 15 minutes from sample introduction. */
        subject system : BiochipAnalysisSystem;
    }
    
    requirement def ThroughputRequirement {
        doc /* The biochip system shall process at least 96 samples per hour. */
        subject system : BiochipAnalysisSystem;
    }
    
    requirement <'SYS-001'> primaryFunction : SystemFunctionRequirement {
        doc /* The biochip-based system shall automatically analyze biological samples by mixing them with reagents, 
             incubating under controlled conditions, detecting optical signals from biochemical reactions, 
             and generating quantitative assay results indicating the presence and concentration of target analytes. */
        
        subject biochipSystem : BiochipAnalysisSystem;
        
        require detectionSensitivity : DetectionSensitivityRequirement;
        require processingTime : ProcessingTimeRequirement;
        require throughput : ThroughputRequirement;
    }
    
    part biochipSystem : BiochipAnalysisSystem {
        satisfy primaryFunction;
    }
}
