package ElectronicTongueSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    enum def TasteCategory {
        sweet;
        sour;
        salty;
        bitter;
        umami;
    }

    enum def AnalysisStatus {
        idle;
        sampling;
        measuring;
        processing;
        complete;
        error;
    }

    attribute def ConcentrationValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def ResistanceValue :> Real;
    attribute def CapacitanceValue :> Real;

    value type TasteIntensity {
        attribute category : TasteCategory;
        attribute intensity : Real;
        attribute confidence : Real;
    }

    value type TasteProfile {
        attribute intensities : TasteIntensity[5];
        attribute timestamp : TimeValue;
        attribute overallQuality : Real;
    }

    item def LiquidSample {
        attribute volume : VolumeValue;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute pH : Real;
    }

    item def WasteSample :> LiquidSample;

    port def FluidPort {
        in item sampleIn : LiquidSample;
        out item wasteOut : WasteSample;
    }

    port def ElectricalPort {
        out voltage : VoltageValue;
        out resistance : ResistanceValue;
        out capacitance : CapacitanceValue;
    }

    port def DataPort {
        out profile : TasteProfile;
        in command : String;
    }

    part def ChemicalSensor {
        attribute sensorType : TasteCategory;
        attribute sensitivity : Real;
        attribute responseTime : DurationValue;

        port fluidInterface : FluidPort;
        port electricalOutput : ElectricalPort;

        action def MeasureResponse {
            in sample : LiquidSample;
            out voltage : VoltageValue;
            out resistance : ResistanceValue;
        }
    }

    part def SensorArray {
        port sampleIntake : FluidPort;
        port sensorOutputs[5] : ElectricalPort;

        part sweetSensor : ChemicalSensor {
            attribute :>> sensorType = TasteCategory::sweet;
            attribute :>> sensitivity = 0.92;
            attribute :>> responseTime = 2.0 [s];
        }

        part sourSensor : ChemicalSensor {
            attribute :>> sensorType = TasteCategory::sour;
            attribute :>> sensitivity = 0.89;
            attribute :>> responseTime = 2.5 [s];
        }

        part saltySensor : ChemicalSensor {
            attribute :>> sensorType = TasteCategory::salty;
            attribute :>> sensitivity = 0.91;
            attribute :>> responseTime = 2.2 [s];
        }

        part bitterSensor : ChemicalSensor {
            attribute :>> sensorType = TasteCategory::bitter;
            attribute :>> sensitivity = 0.87;
            attribute :>> responseTime = 3.0 [s];
        }

        part umamiSensor : ChemicalSensor {
            attribute :>> sensorType = TasteCategory::umami;
            attribute :>> sensitivity = 0.85;
            attribute :>> responseTime = 3.5 [s];
        }

        action def AcquireAllSensorData {
            in sample : LiquidSample;
            out voltages : VoltageValue[5];
            out resistances : ResistanceValue[5];
        }
    }

    part def FluidDeliverySystem {
        attribute chamberVolume : VolumeValue;
        attribute flowRate : VolumeValue;

        port inlet : FluidPort;
        port outlet : FluidPort;
        port toSensors : FluidPort;

        part pump {
            attribute pumpRate : VolumeValue;
        }

        part measurementChamber {
            attribute volume : VolumeValue;
        }

        part cleaningUnit {
            action def RinseChamber {
                in rinseVolume : VolumeValue;
            }
        }

        action def DeliverSample {
            in sample : LiquidSample;
            out deliveredSample : LiquidSample;
        }

        action def EvacuateWaste {
            in usedSample : LiquidSample;
            out waste : WasteSample;
        }
    }

    part def SignalProcessor {
        attribute amplificationGain : Real;
        attribute filterCutoff : Real;

        port rawSignalInput[5] : ElectricalPort;
        port processedSignalOutput : DataPort;

        action def AmplifySignals {
            in rawVoltages : VoltageValue[5];
            out amplifiedVoltages : VoltageValue[5];
        }

        action def FilterNoise {
            in noisySignals : VoltageValue[5];
            out cleanSignals : VoltageValue[5];
        }

        action def NormalizeData {
            in signals : VoltageValue[5];
            out normalized : Real[5];
        }
    }

    part def PatternAnalyzer {
        attribute neuralNetworkLayers : Integer;
        attribute trainingAccuracy : Real;

        port dataInput : DataPort;
        port analysisOutput : DataPort;

        action def ClassifyTaste {
            in sensorData : Real[5];
            out profile : TasteProfile;
        }

        action def CalculateIntensities {
            in normalizedData : Real[5];
            out intensities : TasteIntensity[5];
        }
    }

    part def ControlUnit {
        attribute operatingMode : AnalysisStatus;

        port commandInterface : DataPort;
        port statusOutput : DataPort;

        state def OperationStateMachine {
            entry; then idle;

            state idle;

            transition idle_to_sampling
                first idle
                accept startAnalysis
                then sampling;

            state sampling;

            transition sampling_to_measuring
                first sampling
                if sampleReady
                then measuring;

            state measuring;

            transition measuring_to_processing
                first measuring
                if dataAcquired
                then processing;

            state processing;

            transition processing_to_complete
                first processing
                if analysisComplete
                then complete;

            state complete;

            transition complete_to_idle
                first complete
                accept resultsRetrieved
                then idle;

            transition any_to_error
                first idle, sampling, measuring, processing, complete
                accept systemFault
                then error;

            state error;

            transition error_to_idle
                first error
                accept errorCleared
                then idle;
        }
    }

    part def DisplayInterface {
        attribute displayResolution : String;

        port resultsInput : DataPort;
        port userCommands : DataPort;

        action def ShowTasteProfile {
            in profile : TasteProfile;
        }

        action def DisplayStatus {
            in status : AnalysisStatus;
        }
    }

    part def ElectronicTongue {
        attribute systemID : String;
        attribute calibrationDate : TimeValue;
        attribute overallAccuracy : Real;

        port sampleInput : FluidPort;
        port wasteOutput : FluidPort;
        port userInterface : DataPort;

        part fluidSystem : FluidDeliverySystem {
            attribute :>> chamberVolume = 10.0 [mL];
            attribute :>> flowRate = 5.0 [mL/s];
        }

        part sensorArray : SensorArray;

        part signalProcessor : SignalProcessor {
            attribute :>> amplificationGain = 100.0;
            attribute :>> filterCutoff = 1000.0;
        }

        part analyzer : PatternAnalyzer {
            attribute :>> neuralNetworkLayers = 5;
            attribute :>> trainingAccuracy = 0.93;
        }

        part controller : ControlUnit;

        part display : DisplayInterface {
            attribute :>> displayResolution = "1920x1080";
        }

        connection fluidToSensors
            connect fluidSystem.toSensors to sensorArray.sampleIntake;

        connection sensorsToProcessor
            connect sensorArray.sensorOutputs to signalProcessor.rawSignalInput;

        connection processorToAnalyzer
            connect signalProcessor.processedSignalOutput to analyzer.dataInput;

        connection analyzerToController
            connect analyzer.analysisOutput to controller.statusOutput;

        connection controllerToDisplay
            connect controller.commandInterface to display.userCommands;

        connection displayToUser
            connect display.resultsInput to userInterface;

        perform action completeTasteAnalysis : AnalyzeLiquidSample;
        exhibit state systemOperation : controller.OperationStateMachine;
    }

    action def IntroduceSample {
        in sample : LiquidSample;
        out deliveredSample : LiquidSample;
    }

    action def AcquireSensorReadings {
        in sample : LiquidSample;
        out rawData : VoltageValue[5];
    }

    action def ProcessSignalData {
        in rawData : VoltageValue[5];
        out processedData : Real[5];
    }

    action def AnalyzeTastePattern {
        in processedData : Real[5];
        out tasteProfile : TasteProfile;
    }

    action def PresentResults {
        in tasteProfile : TasteProfile;
    }

    action def CleanSystem {
        in rinseVolume : VolumeValue;
    }

    action def AnalyzeLiquidSample {
        first start;
        then action introduce : IntroduceSample {
            in sample : LiquidSample;
            out deliveredSample : LiquidSample;
        }
        then action acquire : AcquireSensorReadings {
            in sample = introduce.deliveredSample;
            out rawData : VoltageValue[5];
        }
        then action process : ProcessSignalData {
            in rawData = acquire.rawData;
            out processedData : Real[5];
        }
        then action analyze : AnalyzeTastePattern {
            in processedData = process.processedData;
            out tasteProfile : TasteProfile;
        }
        then action present : PresentResults {
            in tasteProfile = analyze.tasteProfile;
        }
        then action clean : CleanSystem {
            in rinseVolume = 20.0 [mL];
        }
        then done;
    }

    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def AccuracyRequirement;

    requirement <'REQ-ET-F001'> primaryFunction : FunctionalRequirement {
        doc /* The electronic tongue system shall analyze liquid samples to 
             * identify and quantify taste profiles across five basic taste 
             * categories (sweet, sour, salty, bitter, umami) using an array 
             * of chemical sensors and pattern recognition algorithms.
             */
        subject system : ElectronicTongue;
    }

    requirement <'REQ-ET-P001'> analysisTime : PerformanceRequirement {
        doc /* The system shall complete a full taste analysis from sample 
             * introduction to results display within 30 seconds.
             */
        subject system : ElectronicTongue;
    }

    requirement <'REQ-ET-A001'> classificationAccuracy : AccuracyRequirement {
        doc /* The system shall achieve a minimum overall classification 
             * accuracy of 90% for taste identification.
             */
        subject system : ElectronicTongue;
        assert constraint {
            system.overallAccuracy >= 0.90
        }
    }

    requirement <'REQ-ET-P002'> sampleVolume : PerformanceRequirement {
        doc /* The system shall require no more than 10 mL of liquid sample 
             * for a complete analysis.
             */
        subject fluidSys : FluidDeliverySystem;
        assert constraint {
            fluidSys.chamberVolume <= 10.0 [mL]
        }
    }

    requirement <'REQ-ET-A002'> sensorSensitivity : AccuracyRequirement {
        doc /* Each chemical sensor in the array shall maintain a minimum 
             * sensitivity of 0.85 for its target taste category.
             */
        subject sensors : SensorArray;
    }

    part electronicTongueSystem : ElectronicTongue {
        attribute :>> systemID = "ET-SYS-2024-001";
        attribute :>> overallAccuracy = 0.93;
    }

    satisfy primaryFunction by electronicTongueSystem;
    satisfy analysisTime by electronicTongueSystem;
    satisfy classificationAccuracy by electronicTongueSystem;
    satisfy sampleVolume by electronicTongueSystem.fluidSystem;
    satisfy sensorSensitivity by electronicTongueSystem.sensorArray;
}
