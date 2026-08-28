package BiochipAnalysisSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import SequenceFunctions::*;

    package Definitions {
        item def Fluid;
        item def BiologicalSample :> Fluid {
            attribute sampleId : String;
            attribute sampleType : SampleType;
        }
        enum def SampleType {
            blood;
            saliva;
            urine;
        }
        item def Reagent :> Fluid {
            attribute reagentId : String;
            attribute targetAnalyte : String;
        }
        item def Mixture :> Fluid {
            attribute sampleId : String;
            attribute reagentId : String;
        }
        item def WasteFluid :> Fluid;
        item def AssayResult {
            attribute sampleId : String;
            attribute concentration : Real;
            attribute signalStrength : Real;
            attribute determination : Determination;
        }
        enum def Determination {
            positive;
            negative;
        }
        item def StartSignal;
        item def SampleReceivedSignal;
        item def ReactionCompleteSignal;
        item def DetectionCompleteSignal;
        item def AnalysisCompleteSignal;
        item def ResetSignal;

        port def FluidPort {
            interface FluidInterface {
                end fluidItem : Fluid;
            }
        }
        port def ThermalPort {
            interface ThermalInterface {
                end temperature :> ISQ::temperature;
            }
        }
        port def AssayResultPort {
            interface AssayResultInterface {
                end resultItem : AssayResult;
            }
        }

        part def FluidPump {
            attribute flowRate :> ISQ::volumeFlowRate;
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
        }
        part def MicrofluidicChannel {
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
        }
        part def ReactionChamber {
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
            port reagentIn : FluidPort;
            port thermalPort : ThermalPort;
            attribute volume :> ISQ::volume;
            attribute currentTemp :> ISQ::temperature;
        }
        part def TemperatureController {
            attribute setTemp :> ISQ::temperature;
            attribute tolerance :> ISQ::temperature;
            port thermalLink : ThermalPort;
        }
        part def OpticalDetector {
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
            attribute wavelength :> ISQ::length;
            attribute measuredSignal : Real;
            attribute sensitivityThreshold : Real;
        }
        part def WastePort {
            port fluidIn : FluidPort;
        }

        part def Biochip {
            part pump : FluidPump {
                attribute :>> flowRate = 0.01 [L/s];
            }
            part sampleChannel : MicrofluidicChannel;
            part reagentChannel : MicrofluidicChannel;
            part chamber : ReactionChamber {
                attribute :>> volume = 0.05 [L];
                attribute :>> currentTemp = 310 [K];
            }
            part tempController : TemperatureController {
                attribute :>> setTemp = 310 [K];
                attribute :>> tolerance = 0.5 [K];
            }
            part detector : OpticalDetector {
                attribute :>> wavelength = 480e-9 [m];
                attribute :>> sensitivityThreshold = 0.001;
            }
            part waste : WastePort;
            port sampleInput : FluidPort;
            port reagentInput : FluidPort;
            port resultOutput : AssayResultPort;
            connection sampleFlow connect sampleInput to sampleChannel.fluidIn;
            connection sampleToPump connect sampleChannel.fluidOut to pump.fluidIn;
            connection pumpToChamber connect pump.fluidOut to chamber.fluidIn;
            connection reagentFlow connect reagentInput to reagentChannel.fluidIn;
            connection reagentToChamber connect reagentChannel.fluidOut to chamber.reagentIn;
            connection chamberToDetector connect chamber.fluidOut to detector.fluidIn;
            connection detectorToWaste connect detector.fluidOut to waste.fluidIn;
            connection thermalControl connect tempController.thermalLink to chamber.thermalPort;
        }

        action def MixReagent {
            in item sample : BiologicalSample;
            in item reagent : Reagent;
            out item mixture : Mixture;
        }
        action def Incubate {
            in item mixture : Mixture;
            in attribute temp :> ISQ::temperature;
            in attribute duration :> ISQ::time;
            out item incubatedMixture : Mixture;
        }
        action def Detect {
            in item mixture : Mixture;
            out attribute signalStrength : Real;
            out item waste : WasteFluid;
        }
        action def Analyze {
            in attribute signalStrength : Real;
            in attribute sampleId : String;
            out item result : AssayResult;
        }
        action def PerformAssay {
            in item sample : BiologicalSample;
            in item reagent : Reagent;
            out item result : AssayResult;
            out item waste : WasteFluid;
            action mix : MixReagent {
                in item sample = PerformAssay::sample;
                in item reagent = PerformAssay::reagent;
                out item mixture;
            }
            action incubate : Incubate {
                in item mixture = mix.mixture;
                in attribute temp = 310 [K];
                in attribute duration = 300 [s];
                out item incubatedMixture;
            }
            action detect : Detect {
                in item mixture = incubate.incubatedMixture;
                out attribute signalStrength;
                out item waste;
            }
            action analyze : Analyze {
                in attribute signalStrength = detect.signalStrength;
                in attribute sampleId = PerformAssay::sample.sampleId;
                out item result;
            }
            flow mix.mixture to incubate.mixture;
            flow incubate.incubatedMixture to detect.mixture;
            flow detect.waste to PerformAssay.waste;
            flow analyze.result to PerformAssay.result;
        }

        state def BiochipStates;
        state biochipStates : BiochipStates {
            in biochip : Biochip;
            in sample : BiologicalSample;
            in reagent : Reagent;
            out result : AssayResult;
            entry; then idle;
            state idle;
            accept StartSignal then ready;
            state ready;
            accept SampleReceivedSignal then processing;
            state processing {
                entry action performAssay : PerformAssay {
                    in item sample = biochipStates::sample;
                    in item reagent = biochipStates::reagent;
                    out item result;
                }
                do action controlTemperature { /* maintain chamber temperature */ }
            }
            accept ReactionCompleteSignal then analyzing;
            state analyzing {
                entry action interpretSignal { /* interpret raw signal */ }
            }
            accept DetectionCompleteSignal then complete;
            state complete {
                entry action outputResult { /* output assay result */ }
                do action flushWaste { /* direct used fluids to waste port */ }
            }
            accept AnalysisCompleteSignal then idle;
            accept ResetSignal then idle;
        }

        requirement def AnalysisTimeRequirement {
            subject biochip : Biochip;
            attribute maxDuration :> ISQ::time = 900 [s];
            doc /* The entire analysis process must complete in under 15 minutes. */
            constraint { biochip.analysisDuration <= maxDuration }
        }
        requirement def DetectionSensitivityRequirement {
            subject detector : OpticalDetector;
            attribute minConcentration : Real = 0.000001;
            doc /* The detector must identify very low concentrations of analyte. */
            constraint { detector.sensitivityThreshold <= 0.001 }
        }
        requirement def TemperatureStabilityRequirement {
            subject controller : TemperatureController;
            attribute maxDeviation :> ISQ::temperature = 0.5 [K];
            doc /* The temperature controller must maintain the chamber at a precise, stable temperature. */
            constraint { controller.tolerance <= maxDeviation }
        }
    }

    package Usages {
        private import Definitions::*;

        part biochipSystem : Biochip {
            attribute analysisDuration :> ISQ::time;
            state states : BiochipStates {
                in biochip = biochipSystem;
                in sample = currentSample;
                in reagent = currentReagent;
                out result = currentResult;
            }
            part currentSample : BiologicalSample {
                attribute :>> sampleId = "S001";
                attribute :>> sampleType = SampleType::blood;
            }
            part currentReagent : Reagent {
                attribute :>> reagentId = "R001";
                attribute :>> targetAnalyte = "Glucose";
            }
            part currentResult : AssayResult;
            satisfy AnalysisTimeRequirement {
                subject biochip = biochipSystem;
            }
            satisfy DetectionSensitivityRequirement {
                subject detector = biochipSystem.detector;
            }
            satisfy TemperatureStabilityRequirement {
                subject controller = biochipSystem.tempController;
            }
        }
    }
}
