package ElectronicTongueSystem {
    package Definitions {
        unit def Volt;
        unit def Ohm;
        unit def Percent;
        unit def Second;
        unit def Pixel;
        unit def Decibel;
        
        attribute def Voltage :> Real { unit Volt; }
        attribute def Resistance :> Real { unit Ohm; }
        attribute def TasteIntensity :> Real { unit Percent; }
        attribute def ConfidenceLevel :> Real { unit Percent; }
        attribute def QualityScore :> Real;
        attribute def Resolution :> Integer { unit Pixel; }
        attribute def CycleTime :> Real { unit Second; }
        attribute def SignalToNoiseRatio :> Real { unit Decibel; }
        attribute def ContaminationLevel :> Real { unit Percent; }
        
        item def LiquidSample;
        item def Waste;
        item def CleaningSolution;
        
        item def SensorData {
            attribute voltage : Voltage;
            attribute resistance : Resistance;
        }
        item def ProcessedData {
            attribute normalizedVoltage : Voltage;
            attribute normalizedResistance : Resistance;
        }
        item def TasteProfile {
            attribute sweet : TasteIntensity;
            attribute sour : TasteIntensity;
            attribute salty : TasteIntensity;
            attribute bitter : TasteIntensity;
            attribute umami : TasteIntensity;
            attribute confidence : ConfidenceLevel;
            attribute qualityScore : QualityScore;
        }
        item def Command;
        item def Status;
        
        port def FluidPort {
            in item sample : LiquidSample;
            out item waste : Waste;
            in item cleaner : CleaningSolution;
        }
        port def SensorSignalPort {
            out item data : SensorData;
        }
        port def ProcessedDataPort {
            out item data : ProcessedData;
        }
        port def ProfilePort {
            out item profile : TasteProfile;
        }
        port def ControlPort {
            in item cmd : Command;
            out item status : Status;
        }
        
        part def FluidDeliverySystem {
            port fluidOut : ~FluidPort;
            port ctrl : ControlPort;
        }
        part def ChemicalSensor {
            port signalOut : SensorSignalPort;
        }
        part def SensorArray {
            port fluidIn : FluidPort;
            port ctrl : ControlPort;
            part sweetSensor : ChemicalSensor;
            part sourSensor : ChemicalSensor;
            part saltySensor : ChemicalSensor;
            part bitterSensor : ChemicalSensor;
            part umamiSensor : ChemicalSensor;
        }
        part def SignalProcessor {
            port sweetIn : ~SensorSignalPort;
            port sourIn : ~SensorSignalPort;
            port saltyIn : ~SensorSignalPort;
            port bitterIn : ~SensorSignalPort;
            port umamiIn : ~SensorSignalPort;
            port dataOut : ProcessedDataPort;
            port ctrl : ControlPort;
        }
        part def PatternAnalyzer {
            port dataIn : ~ProcessedDataPort;
            port profileOut : ProfilePort;
            port ctrl : ControlPort;
        }
        part def ControlUnit {
            port userCmd : ControlPort;
            port fluidCtrl : ~ControlPort;
            port sensorCtrl : ~ControlPort;
            port procCtrl : ~ControlPort;
            port analyzerCtrl : ~ControlPort;
            port displayCtrl : ~ControlPort;
        }
        part def DisplayInterface {
            port uiPort : ~ControlPort;
            port ctrl : ControlPort;
            port profileIn : ~ProfilePort;
        }
        part def ElectronicTongue;
        
        action def DrawSample { out sample : LiquidSample; }
        action def PumpToChamber { in sample : LiquidSample; }
        action def MeasureTastes {
            in sample : LiquidSample;
            out sweetData : SensorData;
            out sourData : SensorData;
            out saltyData : SensorData;
            out bitterData : SensorData;
            out umamiData : SensorData;
        }
        action def ProcessSignals {
            in sweetData : SensorData;
            in sourData : SensorData;
            in saltyData : SensorData;
            in bitterData : SensorData;
            in umamiData : SensorData;
            out processedData : ProcessedData;
        }
        action def AnalyzePatterns {
            in processedData : ProcessedData;
            out profile : TasteProfile;
        }
        action def DisposeWaste { in waste : Waste; }
        action def CleanChamber { in cleaner : CleaningSolution; }
        
        state def SystemStates {
            entry; then idle;
            state idle;
            state sampling;
            state measuring;
            state processing;
            state finished;
            transition idle_to_sampling from idle to sampling;
            transition sampling_to_measuring from sampling to measuring;
            transition measuring_to_processing from measuring to processing;
            transition processing_to_finished from processing to finished;
            transition finished_to_idle from finished to idle;
        }
        
        requirement def TasteIdentificationReq {
            doc /* The system shall identify and quantify the five basic tastes: sweet, sour, salty, bitter, and umami. */
            attribute profile : TasteProfile;
            require constraint { profile.confidence >= 0 }
        }
        requirement def CrossContaminationReq {
            doc /* The cleaning unit shall rinse the measurement chamber to prevent cross-contamination between samples. */
            attribute contaminationLevel : ContaminationLevel;
            attribute maxContamination : ContaminationLevel;
            require constraint { contaminationLevel <= maxContamination }
        }
        requirement def SignalProcessingReq {
            doc /* The Signal Processor shall amplify, filter, and normalize raw electrical signals from the Sensor Array. */
            attribute signalToNoiseRatio : SignalToNoiseRatio;
            attribute minSignalToNoiseRatio : SignalToNoiseRatio;
            require constraint { signalToNoiseRatio >= minSignalToNoiseRatio }
        }
        requirement def PatternAnalysisReq {
            doc /* The Pattern Analyzer shall classify tastes and calculate intensities, confidence levels, and quality score. */
            attribute profile : TasteProfile;
            require constraint { profile.qualityScore >= 0 }
        }
        requirement def ResponseTimeReq {
            doc /* The system shall complete the full analysis cycle within 60 seconds. */
            attribute cycleTime : CycleTime;
            attribute maxCycleTime : CycleTime;
            require constraint { cycleTime <= maxCycleTime }
        }
        requirement def DisplayResolutionReq {
            doc /* The Display Interface shall provide a high-resolution screen for viewing results. */
            attribute displayResolution : Resolution;
            attribute minDisplayResolution : Resolution;
            require constraint { displayResolution >= minDisplayResolution }
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part electronicTongue : ElectronicTongue {
            part fluidDelivery : FluidDeliverySystem;
            part sensorArray : SensorArray;
            part signalProcessor : SignalProcessor;
            part patternAnalyzer : PatternAnalyzer;
            part controlUnit : ControlUnit;
            part displayInterface : DisplayInterface;
            
            connect fluidDelivery.fluidOut to sensorArray.fluidIn;
            connect sensorArray.sweetSensor.signalOut to signalProcessor.sweetIn;
            connect sensorArray.sourSensor.signalOut to signalProcessor.sourIn;
            connect sensorArray.saltySensor.signalOut to signalProcessor.saltyIn;
            connect sensorArray.bitterSensor.signalOut to signalProcessor.bitterIn;
            connect sensorArray.umamiSensor.signalOut to signalProcessor.umamiIn;
            connect signalProcessor.dataOut to patternAnalyzer.dataIn;
            connect patternAnalyzer.profileOut to displayInterface.profileIn;
            
            connect controlUnit.fluidCtrl to fluidDelivery.ctrl;
            connect controlUnit.sensorCtrl to sensorArray.ctrl;
            connect controlUnit.procCtrl to signalProcessor.ctrl;
            connect controlUnit.analyzerCtrl to patternAnalyzer.ctrl;
            connect controlUnit.displayCtrl to displayInterface.ctrl;
            connect displayInterface.uiPort to controlUnit.userCmd;
            
            exhibit systemStates : SystemStates { }
            
            satisfy TasteIdentificationReq by patternAnalyzer;
            satisfy CrossContaminationReq by fluidDelivery;
            satisfy SignalProcessingReq by signalProcessor;
            satisfy PatternAnalysisReq by patternAnalyzer;
            satisfy ResponseTimeReq by electronicTongue;
            satisfy DisplayResolutionReq by displayInterface;
        }
        
        action 'analyze sample' {
            action 'draw sample': DrawSample {
                out sample: LiquidSample;
            }
            flow 'draw sample'.sample to 'pump to chamber'.sample;
            action 'pump to chamber': PumpToChamber {
                in sample: LiquidSample;
            }
            flow 'pump to chamber'.sample to 'measure tastes'.sample;
            action 'measure tastes': MeasureTastes {
                in sample: LiquidSample;
                out sweetData: SensorData;
                out sourData: SensorData;
                out saltyData: SensorData;
                out bitterData: SensorData;
                out umamiData: SensorData;
            }
            flow 'measure tastes'.sweetData to 'process signals'.sweetData;
            flow 'measure tastes'.sourData to 'process signals'.sourData;
            flow 'measure tastes'.saltyData to 'process signals'.saltyData;
            flow 'measure tastes'.bitterData to 'process signals'.bitterData;
            flow 'measure tastes'.umamiData to 'process signals'.umamiData;
            action 'process signals': ProcessSignals {
                in sweetData: SensorData;
                in sourData: SensorData;
                in saltyData: SensorData;
                in bitterData: SensorData;
                in umamiData: SensorData;
                out processedData: ProcessedData;
            }
            flow 'process signals'.processedData to 'analyze patterns'.processedData;
            action 'analyze patterns': AnalyzePatterns {
                in processedData: ProcessedData;
                out profile: TasteProfile;
            }
            action 'dispose waste': DisposeWaste {
                in waste: Waste;
            }
            then action 'clean chamber': CleanChamber {
                in cleaner: CleaningSolution;
            }
        }
    }
}
