package MeasurementUnits {
    unit Celsius { symbol = "°C"; }
    unit MilliLiter { symbol = "mL"; }
    unit MilliVolt { symbol = "mV"; }
    unit KiloOhm { symbol = "kΩ"; }
    unit Percent { symbol = "%"; }
    unit Points { symbol = "pts"; }
    unit Hertz { symbol = "Hz"; }
    unit MilliAmpere { symbol = "mA"; }
    unit Liter { symbol = "L"; }
}

package TasteDomain {
    import MeasurementUnits::*;

    enum def TasteCategory {
        SWEET;
        SOUR;
        SALTY;
        BITTER;
        UMAMI;
    }

    value type TemperatureValue :> Real { unit Celsius; }
    value type VolumeValue :> Real { unit MilliLiter; }
    value type VoltageValue :> Real { unit MilliVolt; }
    value type ResistanceValue :> Real { unit KiloOhm; }
    value type IntensityValue :> Real { unit Percent; }
    value type ConfidenceValue :> Real { unit Percent; }
    value type QualityScore :> Real { unit Points; }
    value type FrequencyValue :> Real { unit Hertz; }
    value type CurrentValue :> Real { unit MilliAmpere; }
    value type FlowRateValue :> Real { unit MilliLiter; }

    item def LiquidSample {
        attribute pH : Real;
        attribute temperature : TemperatureValue;
        attribute volume : VolumeValue;
        attribute sampleId : String;
        attribute origin : String;
    }

    item def WasteLiquid {
        attribute volume : VolumeValue;
        attribute contaminationLevel : Real;
        attribute disposalTime : String;
        attribute hazardous : Boolean;
    }

    item def CleaningSolution {
        attribute volume : VolumeValue;
        attribute concentration : Real;
        attribute solutionType : String;
        attribute temperature : TemperatureValue;
    }

    item def RawSensorData {
        attribute voltage : VoltageValue;
        attribute resistance : ResistanceValue;
        attribute sensorId : String;
        attribute timestamp : String;
        attribute tasteType : TasteCategory;
        attribute signalStrength : Real;
    }

    item def ProcessedData {
        attribute normalizedVoltage : Real;
        attribute normalizedResistance : Real;
        attribute sensorId : String;
        attribute timestamp : String;
        attribute tasteType : TasteCategory;
        attribute signalToNoiseRatio : Real;
    }

    item def TasteResult {
        attribute category : TasteCategory;
        attribute intensity : IntensityValue;
        attribute confidence : ConfidenceValue;
    }

    item def TasteProfile {
        attribute results : TasteResult[5];
        attribute overallQuality : QualityScore;
        attribute timestamp : String;
        attribute sampleId : String;
        attribute analysisDuration : Real;
    }

    item def NeuralNetworkModel {
        attribute modelVersion : String;
        attribute trainingSamples : Integer;
        attribute accuracy : Real;
        attribute layers : Integer;
        attribute inputNodes : Integer;
        attribute outputNodes : Integer;
    }

    item def SystemCommand {
        attribute commandType : String;
        attribute timestamp : String;
        attribute parameters : String;
        attribute priority : Integer;
    }

    item def SystemStatus {
        attribute state : String;
        attribute message : String;
        attribute timestamp : String;
        attribute errorCount : Integer;
        attribute progress : Real;
    }
}

package PortDefinitions {
    import TasteDomain::*;

    port def SampleOutputPort {
        out item sample : LiquidSample;
    }

    port def SampleInputPort {
        in item sample : LiquidSample;
    }

    port def WasteOutputPort {
        out item waste : WasteLiquid;
    }

    port def WasteInputPort {
        in item waste : WasteLiquid;
    }

    port def CleaningOutputPort {
        out item solution : CleaningSolution;
    }

    port def CleaningInputPort {
        in item solution : CleaningSolution;
    }

    port def SensorDataOutputPort {
        out item rawData : RawSensorData;
    }

    port def SensorDataInputPort {
        in item rawData : RawSensorData;
    }

    port def ProcessedDataOutputPort {
        out item processedData : ProcessedData;
    }

    port def ProcessedDataInputPort {
        in item processedData : ProcessedData;
    }

    port def ProfileOutputPort {
        out item profile : TasteProfile;
    }

    port def ProfileInputPort {
        in item profile : TasteProfile;
    }

    port def CommandOutputPort {
        out item command : SystemCommand;
    }

    port def CommandInputPort {
        in item command : SystemCommand;
    }

    port def StatusOutputPort {
        out item status : SystemStatus;
    }

    port def StatusInputPort {
        in item status : SystemStatus;
    }

    port def DisplayOutputPort {
        out item profile : TasteProfile;
        out item status : SystemStatus;
    }

    port def DisplayInputPort {
        in item profile : TasteProfile;
        in item status : SystemStatus;
    }
}

package Components {
    import TasteDomain::*;
    import PortDefinitions::*;

    part def ChemicalSensor {
        attribute tasteType : TasteCategory;
        attribute sensorId : String;
        attribute calibrationDate : String;
        attribute sensitivity : Real;
        attribute operatingRange : VoltageValue;
        attribute maxVoltage : VoltageValue;
        attribute minResistance : ResistanceValue;
        attribute maxResistance : ResistanceValue;

        port in fluidInput : SampleInputPort;
        port out sensorOutput : SensorDataOutputPort;

        action def SenseTaste {
            in item sample : LiquidSample;
            out item rawData : RawSensorData;

            action measureVoltage {
                in item sample : LiquidSample;
                out item voltage : VoltageValue;
            }
            then action measureResistance {
                in item sample : LiquidSample;
                out item resistance : ResistanceValue;
            }
            then action generateSignal {
                in item voltage : VoltageValue;
                in item resistance : ResistanceValue;
                out item rawData : RawSensorData;
            }
        }
    }

    part def SensorArray {
        port in fluidInput : SampleInputPort;
        port out dataOutput : SensorDataOutputPort;

        attribute sensorCount : Integer = 5;
        attribute responseTime : Real;
        attribute operatingTemperature : TemperatureValue;

        part sweetSensor : ChemicalSensor {
            tasteType = TasteCategory::SWEET;
            sensorId = "SWEET_001";
            sensitivity = 0.95;
        }
        part sourSensor : ChemicalSensor {
            tasteType = TasteCategory::SOUR;
            sensorId = "SOUR_001";
            sensitivity = 0.92;
        }
        part saltySensor : ChemicalSensor {
            tasteType = TasteCategory::SALTY;
            sensorId = "SALTY_001";
            sensitivity = 0.97;
        }
        part bitterSensor : ChemicalSensor {
            tasteType = TasteCategory::BITTER;
            sensorId = "BITTER_001";
            sensitivity = 0.93;
        }
        part umamiSensor : ChemicalSensor {
            tasteType = TasteCategory::UMAMI;
            sensorId = "UMAMI_001";
            sensitivity = 0.91;
        }

        connection from fluidInput to sweetSensor.fluidInput;
        connection from fluidInput to sourSensor.fluidInput;
        connection from fluidInput to saltySensor.fluidInput;
        connection from fluidInput to bitterSensor.fluidInput;
        connection from fluidInput to umamiSensor.fluidInput;

        connection from sweetSensor.sensorOutput to dataOutput;
        connection from sourSensor.sensorOutput to dataOutput;
        connection from saltySensor.sensorOutput to dataOutput;
        connection from bitterSensor.sensorOutput to dataOutput;
        connection from umamiSensor.sensorOutput to dataOutput;
    }

    part def FluidDeliverySystem {
        port in sampleInput : SampleInputPort;
        port out wasteOutput : WasteOutputPort;
        port in cleaningCommand : CommandInputPort;
        port out toSensors : SampleOutputPort;
        port out statusReport : StatusOutputPort;

        attribute chamberVolume : VolumeValue = 10;
        attribute flowRate : Real = 5.0;
        attribute isClean : Boolean = true;
        attribute totalSamplesProcessed : Integer = 0;

        part samplePump {
            attribute pumpRate : Real = 5.0;
            attribute isActive : Boolean = false;
            attribute powerConsumption : CurrentValue = 50;
            port in fluidIn : SampleInputPort;
            port out fluidOut : SampleOutputPort;
        }

        part measurementChamber {
            attribute capacity : VolumeValue = 10;
            attribute currentVolume : VolumeValue = 0;
            attribute isFilled : Boolean = false;
            attribute temperature : TemperatureValue = 25;
            port in fluidIn : SampleInputPort;
            port in cleaningIn : CleaningInputPort;
            port out fluidOut : WasteOutputPort;
            port out toSensors : SampleOutputPort;
        }

        part wastePump {
            attribute pumpRate : Real = 5.0;
            attribute isActive : Boolean = false;
            attribute powerConsumption : CurrentValue = 50;
            port in fluidIn : WasteInputPort;
            port out wasteOut : WasteOutputPort;
        }

        part cleaningUnit {
            attribute reservoirVolume : VolumeValue = 500;
            attribute rinseCycles : Integer = 3;
            attribute isActive : Boolean = false;
            attribute solutionType : String = "Deionized Water";
            port out cleaningOut : CleaningOutputPort;

            action def RinseChamber {
                action fillWithCleaningSolution {
                    out item solution : CleaningSolution;
                }
                then action circulateSolution {
                    in item solution : CleaningSolution;
                }
                then action drainSolution {
                    out item waste : WasteLiquid;
                }
            }
        }

        connection from sampleInput to samplePump.fluidIn;
        connection from samplePump.fluidOut to measurementChamber.fluidIn;
        connection from measurementChamber.toSensors to toSensors;
        connection from measurementChamber.fluidOut to wastePump.fluidIn;
        connection from wastePump.wasteOut to wasteOutput;
        connection from cleaningUnit.cleaningOut to measurementChamber.cleaningIn;
    }

    part def SignalProcessor {
        port in rawDataInput : SensorDataInputPort;
        port out processedOutput : ProcessedDataOutputPort;
        port out statusReport : StatusOutputPort;

        attribute amplificationFactor : Real = 100.0;
        attribute filterCutoff : FrequencyValue = 1000;
        attribute noiseFloor : VoltageValue = 0.1;
        attribute processingDelay : Real = 0.05;
        attribute isActive : Boolean = false;

        action def ProcessSignals {
            in item rawData : RawSensorData;
            out item processedData : ProcessedData;

            action amplify {
                in item rawVoltage : VoltageValue;
                out item amplifiedVoltage : VoltageValue;
            }
            then action filterNoise {
                in item amplifiedVoltage : VoltageValue;
                out item filteredVoltage : VoltageValue;
            }
            then action normalize {
                in item filteredVoltage : VoltageValue;
                in item filteredResistance : ResistanceValue;
                out item processedData : ProcessedData;
            }
        }
    }

    part def PatternAnalyzer {
        port in dataInput : ProcessedDataInputPort;
        port out profileOutput : ProfileOutputPort;
        port out statusReport : StatusOutputPort;

        attribute neuralNetwork : NeuralNetworkModel;
        attribute classificationThreshold : Real = 0.85;
        attribute isModelLoaded : Boolean = true;
        attribute processingTime : Real = 0.5;
        attribute isActive : Boolean = false;

        action def AnalyzePatterns {
            in item processedData : ProcessedData;
            out item profile : TasteProfile;

            action classifyTastes {
                in item data : ProcessedData;
                out item results : TasteResult[5];
            }
            then action calculateIntensities {
                in item results : TasteResult[5];
                out item intensities : TasteResult[5];
            }
            then action computeConfidence {
                in item results : TasteResult[5];
                out item confidences : TasteResult[5];
            }
            then action generateProfile {
                in item results : TasteResult[5];
                out item profile : TasteProfile;
            }
        }
    }

    part def ControlUnit {
        port in userCommand : CommandInputPort;
        port in profileInput : ProfileInputPort;
        port in fluidStatus : StatusInputPort;
        port in processorStatus : StatusInputPort;
        port in analyzerStatus : StatusInputPort;
        port out systemStatus : StatusOutputPort;
        port out fluidControl : CommandOutputPort;
        port out displayOutput : DisplayOutputPort;

        attribute currentState : String = "idle";
        attribute analysisCount : Integer = 0;
        attribute lastAnalysisTime : String;
        attribute firmwareVersion : String = "2.1.0";
        attribute uptime : Real;

        state machine ControlStateMachine {
            state idle {
                entry { }
            }
            state sampling {
                entry { }
            }
            state measuring {
                entry { }
            }
            state processing {
                entry { }
            }
            state complete {
                entry { }
            }

            transition from idle to sampling
                when userCommand.command.commandType == "start";
            transition from sampling to measuring
                when fluidStatus.status.message == "chamber_filled";
            transition from measuring to processing
                when processorStatus.status.message == "data_ready";
            transition from processing to complete
                when profileInput.profile != null;
            transition from complete to idle
                when userCommand.command.commandType == "reset";
        }
    }

    part def DisplayInterface {
        port in displayInput : DisplayInputPort;
        port out userCommand : CommandOutputPort;

        attribute screenResolution : String = "1920x1080";
        attribute brightness : Real = 500;
        attribute isTouchscreen : Boolean = true;
        attribute refreshRate : FrequencyValue = 60;
        attribute isConnected : Boolean = true;

        action def DisplayResults {
            in item profile : TasteProfile;
            in item status : SystemStatus;

            action renderProfile {
                in item profile : TasteProfile;
            }
            then action renderStatus {
                in item status : SystemStatus;
            }
            then action waitForUserInput;
        }

        action def StartAnalysis {
            out item command : SystemCommand;
        }
    }
}

package ElectronicTongueSystem {
    import TasteDomain::*;
    import PortDefinitions::*;
    import Components::*;

    part def ElectronicTongue {
        doc "Electronic Tongue system: a sophisticated analytical instrument that mimics the human sense of taste by evaluating liquid samples and identifying the five basic taste categories.";

        port in sampleInput : SampleInputPort;
        port out wasteOutput : WasteOutputPort;
        port in userCommand : CommandInputPort;
        port out displayOutput : DisplayOutputPort;

        attribute systemId : String = "ET-2024-001";
        attribute manufacturer : String = "TasteTech Instruments";
        attribute modelNumber : String = "ET-Pro-5000";
        attribute serialNumber : String;
        attribute installationDate : String;
        attribute calibrationInterval : Integer = 30;

        part fluidDelivery : FluidDeliverySystem;
        part sensorArray : SensorArray;
        part signalProcessor : SignalProcessor;
        part patternAnalyzer : PatternAnalyzer;
        part controlUnit : ControlUnit;
        part displayInterface : DisplayInterface;

        connection from sampleInput to fluidDelivery.sampleInput;
        connection from fluidDelivery.wasteOutput to wasteOutput;
        connection from fluidDelivery.toSensors to sensorArray.fluidInput;
        connection from sensorArray.dataOutput to signalProcessor.rawDataInput;
        connection from signalProcessor.processedOutput to patternAnalyzer.dataInput;
        connection from patternAnalyzer.profileOutput to controlUnit.profileInput;
        connection from controlUnit.displayOutput to displayInterface.displayInput;
        connection from displayInterface.userCommand to controlUnit.userCommand;
        connection from controlUnit.fluidControl to fluidDelivery.cleaningCommand;
        connection from fluidDelivery.statusReport to controlUnit.fluidStatus;
        connection from signalProcessor.statusReport to controlUnit.processorStatus;
        connection from patternAnalyzer.statusReport to controlUnit.analyzerStatus;
        connection from controlUnit.systemStatus to displayInterface.displayInput;

        satisfy req::TasteIdentificationRequirement;
        satisfy req::FluidDeliveryRequirement;
        satisfy req::CleaningRequirement;
        satisfy req::SensorArrayRequirement;
        satisfy req::SignalProcessingRequirement;
        satisfy req::PatternAnalysisRequirement;
        satisfy req::ControlUnitRequirement;
        satisfy req::DisplayInterfaceRequirement;
    }
}

package Requirements {
    import TasteDomain::*;
    import ElectronicTongueSystem::*;

    requirement def TasteIdentificationRequirement {
        doc "The Electronic Tongue shall identify and quantify the five basic taste categories: sweet, sour, salty, bitter, and umami, to generate a comprehensive taste profile.";
        subject system : ElectronicTongue;
        constraint { system.sensorArray.sweetSensor.tasteType == TasteCategory::SWEET }
        constraint { system.sensorArray.sourSensor.tasteType == TasteCategory::SOUR }
        constraint { system.sensorArray.saltySensor.tasteType == TasteCategory::SALTY }
        constraint { system.sensorArray.bitterSensor.tasteType == TasteCategory::BITTER }
        constraint { system.sensorArray.umamiSensor.tasteType == TasteCategory::UMAMI }
        constraint { system.patternAnalyzer.profileOutput.profile.results.size() == 5 }
    }

    requirement def FluidDeliveryRequirement {
        doc "The Fluid Delivery System shall draw in a liquid sample, pump it into a measurement chamber, and dispose of it as waste after analysis.";
        subject fluidSystem : FluidDeliverySystem;
        constraint { fluidSystem.chamberVolume <= 10 }
        constraint { fluidSystem.samplePump.pumpRate >= 1.0 }
        constraint { fluidSystem.wastePump.pumpRate >= 1.0 }
        constraint { fluidSystem.measurementChamber.capacity >= 5 }
    }

    requirement def CleaningRequirement {
        doc "The Fluid Delivery System shall include a cleaning unit to automatically rinse the chamber between samples, ensuring no cross-contamination.";
        subject cleaningUnit : FluidDeliverySystem::cleaningUnit;
        constraint { cleaningUnit.rinseCycles >= 3 }
        constraint { cleaningUnit.reservoirVolume >= 500 }
    }

    requirement def SensorArrayRequirement {
        doc "The Sensor Array shall consist of five distinct chemical sensors, each specifically engineered and calibrated to detect one of the five basic tastes, producing unique electrical responses in voltage and resistance.";
        subject sensorArray : SensorArray;
        constraint { sensorArray.sensorCount == 5 }
        constraint { sensorArray.sweetSensor.sensitivity >= 0.90 }
        constraint { sensorArray.sourSensor.sensitivity >= 0.90 }
        constraint { sensorArray.saltySensor.sensitivity >= 0.90 }
        constraint { sensorArray.bitterSensor.sensitivity >= 0.90 }
        constraint { sensorArray.umamiSensor.sensitivity >= 0.90 }
    }

    requirement def SignalProcessingRequirement {
        doc "The Signal Processor shall amplify weak signals from the sensors, filter out electrical noise, and normalize the data to prepare it for analysis.";
        subject processor : SignalProcessor;
        constraint { processor.amplificationFactor >= 100.0 }
        constraint { processor.filterCutoff <= 1000 }
        constraint { processor.noiseFloor <= 0.5 }
    }

    requirement def PatternAnalysisRequirement {
        doc "The Pattern Analyzer shall use a pre-trained neural network to interpret complex patterns from combined sensor data, classifying tastes and calculating intensities, confidence levels, and an overall quality score.";
        subject analyzer : PatternAnalyzer;
        constraint { analyzer.neuralNetwork.accuracy >= 0.90 }
        constraint { analyzer.classificationThreshold >= 0.85 }
        constraint { analyzer.isModelLoaded == true }
    }

    requirement def ControlUnitRequirement {
        doc "The Control Unit shall sequence the analysis through distinct operational states: idle, sampling, measuring, processing, and complete.";
        subject controlUnit : ControlUnit;
        constraint { controlUnit.currentState in {"idle", "sampling", "measuring", "processing", "complete"} }
    }

    requirement def DisplayInterfaceRequirement {
        doc "The Display Interface shall provide a user-friendly way to interact with the system, allowing an operator to start an analysis and view the final taste profile and system status on a high-resolution screen.";
        subject display : DisplayInterface;
        constraint { display.screenResolution == "1920x1080" }
        constraint { display.isTouchscreen == true }
        constraint { display.brightness >= 300 }
    }
}
