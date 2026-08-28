package MicrobiologyAnalysisSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ============================================================
    // Value Types with Units
    // ============================================================

    value type TemperatureValue :> Real { unit '°C'; }
    value type PressureValue :> Real { unit 'kPa'; }
    value type VolumeValue :> Real { unit 'mL'; }
    value type DurationValue :> Real { unit 'min'; }
    value type OpticalDensityValue :> Real { unit 'OD600'; }
    value type ConcentrationValue :> Real { unit 'CFU/mL'; }
    value type HumidityValue :> Real { unit '%RH'; }
    value type PowerValue :> Real { unit 'W'; }
    value type MassValue :> Real { unit 'g'; }
    value type WavelengthValue :> Real { unit 'nm'; }
    value type MagnificationValue :> Real { unit 'x'; }
    value type CountValue :> Integer { unit 'CFU'; }
    value type PercentValue :> Real { unit '%'; }

    // ============================================================
    // Item Definitions
    // ============================================================

    item def BiologicalSample {
        attribute source : String;
        attribute collectedVolume : VolumeValue;
        attribute estimatedLoad : ConcentrationValue;
    }

    item def Diluent {
        attribute volume : VolumeValue;
    }

    item def PreparedSample {
        attribute dilutionFactor : Real;
        attribute volume : VolumeValue;
        attribute homogenized : Boolean;
    }

    item def Debris;

    item def CultureMedium {
        attribute volume : VolumeValue;
        attribute nutrientConcentration : MassValue;
        attribute sterilized : Boolean;
    }

    item def InoculatedMedium {
        attribute volume : VolumeValue;
        attribute sampleVolume : VolumeValue;
    }

    item def MicrobialCulture {
        attribute volume : VolumeValue;
        attribute opticalDensity : OpticalDensityValue;
        attribute colonyCount : CountValue;
        attribute identifiedSpecies : String[0..*];
    }

    item def SterileAir {
        attribute flowRate : Real { unit 'm^3/min'; }
    }

    item def Steam {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
    }

    item def LightBeam {
        attribute wavelength : WavelengthValue;
        attribute intensity : Real { unit 'cd'; }
    }

    item def DigitalImage {
        attribute resolution : String;
        attribute magnification : MagnificationValue;
    }

    item def AnalysisData {
        attribute opticalDensity : OpticalDensityValue;
        attribute colonyCount : CountValue;
        attribute morphologyNotes : String;
        attribute imageSet : DigitalImage[0..*];
    }

    item def TestResult {
        attribute sampleId : String;
        attribute microbialLoad : ConcentrationValue;
        attribute colonyCount : CountValue;
        attribute identifiedSpecies : String[0..*];
        attribute timestamp : String;
    }

    item def Command {
        attribute commandType : String;
    }

    item def Status {
        attribute state : String;
        attribute healthy : Boolean;
    }

    // ============================================================
    // Port Definitions
    // ============================================================

    port def SampleInPort {
        in item BiologicalSample;
    }

    port def PreparedSampleOutPort {
        out item PreparedSample;
    }

    port def DebrisOutPort {
        out item Debris;
    }

    port def MediumPort {
        in item CultureMedium;
        out item CultureMedium;
    }

    port def InoculatedMediumPort {
        in item InoculatedMedium;
        out item MicrobialCulture;
    }

    port def DataOutPort {
        out item AnalysisData;
    }

    port def ResultOutPort {
        out item TestResult;
    }

    port def ControlPort {
        in item Command;
        out item Status;
    }

    port def AirPort {
        out item SterileAir;
    }

    port def SteamPort {
        out item Steam;
    }

    // ============================================================
    // Bio-Safety Workstation
    // ============================================================

    part def BioSafetyWorkstation {
        attribute hepaFilterEfficiency : PercentValue = 99.97;
        attribute uvExposureTime : DurationValue = 15;
        attribute internalPressure : PressureValue = -0.05;

        port airOut : AirPort;
        port control : ControlPort;

        part hepaFilter {
            attribute efficiency : PercentValue;
        }
        part uvLamp {
            attribute power : PowerValue;
            attribute active : Boolean;
        }
        part airflowController {
            attribute flowRate : Real { unit 'm^3/min'; };
        }

        action def SterilizeCycle {
            in duration : DurationValue;
            then action activateUV { in duration : DurationValue; }
            then action flushAir { in duration : DurationValue; }
        }

        state def BioSafetyStates {
            entry; then Idle;
            state Idle;
            state Sterilizing;
            state Operating;
            transition from Idle to Sterilizing when control.in.commandType == "sterilize";
            transition from Sterilizing to Operating when SterilizeCycle.done;
            transition from Operating to Idle when control.in.commandType == "standby";
        }

        exhibit state machine BioSafetyStates;

        requirement def SterilityMaintenance {
            doc /* The bio-safety workstation shall maintain a sterile environment using HEPA-filtered airflow and UV sterilization. */
            subject workstation : BioSafetyWorkstation;
            constraint { workstation.hepaFilterEfficiency >= 99.97 }
            constraint { workstation.uvExposureTime >= 10 }
        }
    }

    // ============================================================
    // Sample Preparation Station
    // ============================================================

    part def SamplePreparationStation {
        attribute targetDilution : Real = 100;
        attribute homogenizeTime : DurationValue = 5;
        attribute filterPoreSize : Real { unit 'um'; } = 0.45;

        port sampleIn : SampleInPort;
        port preparedOut : PreparedSampleOutPort;
        port debrisOut : DebrisOutPort;
        port control : ControlPort;

        part diluter {
            attribute dilutionFactor : Real;
            action def Dilute {
                in sample : BiologicalSample;
                in diluent : Diluent;
                out prepared : PreparedSample;
            }
        }
        part homogenizer {
            attribute speed : Real { unit 'rpm'; };
            action def Homogenize {
                in out sample : PreparedSample;
            }
        }
        part filter {
            attribute poreSize : Real { unit 'um'; };
            action def Filter {
                in sample : PreparedSample;
                out filtered : PreparedSample;
                out debris : Debris;
            }
        }

        action def PrepareSample {
            in rawSample : BiologicalSample;
            out prepared : PreparedSample;
            out debris : Debris;
            then action dilute : diluter.Dilute;
            then action homogenize : homogenizer.Homogenize;
            then action filter : filter.Filter;
        }

        state def PreparationStates {
            entry; then Ready;
            state Ready;
            state Diluting;
            state Homogenizing;
            state Filtering;
            state Complete;
            transition from Ready to Diluting when sampleIn.received;
            transition from Diluting to Homogenizing when dilute.done;
            transition from Homogenizing to Filtering when homogenize.done;
            transition from Filtering to Complete when filter.done;
            transition from Complete to Ready when control.in.commandType == "reset";
        }

        exhibit state machine PreparationStates;

        requirement def PreparationAccuracy {
            doc /* The sample preparation station shall dilute, homogenize, and filter the raw sample to a uniform, debris-free prepared sample. */
            subject station : SamplePreparationStation;
            constraint { station.targetDilution > 0 }
            constraint { station.homogenizeTime > 0 }
        }
    }

    // ============================================================
    // Autoclave
    // ============================================================

    part def Autoclave {
        attribute sterilizeTemperature : TemperatureValue = 121;
        attribute sterilizePressure : PressureValue = 103;
        attribute sterilizeDuration : DurationValue = 20;
        attribute coolingTemperature : TemperatureValue = 50;

        port steamOut : SteamPort;
        port mediumPort : MediumPort;
        port control : ControlPort;

        part pressureVessel {
            attribute maxPressure : PressureValue;
        }
        part heater {
            attribute maxPower : PowerValue;
        }

        action def SterilizeLoad {
            in out medium : CultureMedium;
            then action heatUp { in targetTemp : TemperatureValue; }
            then action hold { in duration : DurationValue; in temp : TemperatureValue; }
            then action coolDown { in targetTemp : TemperatureValue; }
        }

        state def AutoclaveStates {
            entry; then Standby;
            state Standby;
            state Preheating;
            state Sterilizing;
            state Cooling;
            state Ready;
            transition from Standby to Preheating when control.in.commandType == "sterilize";
            transition from Preheating to Sterilizing when heater.temperature >= sterilizeTemperature;
            transition from Sterilizing to Cooling when SterilizeLoad.hold.done;
            transition from Cooling to Ready when pressureVessel.temperature <= coolingTemperature;
            transition from Ready to Standby when control.in.commandType == "reset";
        }

        exhibit state machine AutoclaveStates;

        requirement def SterilizationEffectiveness {
            doc /* The autoclave shall sterilize culture media and equipment using high-pressure, high-temperature steam before each analysis. */
            subject autoclave : Autoclave;
            constraint { autoclave.sterilizeTemperature >= 121 }
            constraint { autoclave.sterilizePressure >= 103 }
            constraint { autoclave.sterilizeDuration >= 15 }
        }
    }

    // ============================================================
    // Incubation Chamber
    // ============================================================

    part def IncubationChamber {
        attribute targetTemperature : TemperatureValue = 37;
        attribute targetHumidity : HumidityValue = 95;
        attribute incubationDuration : DurationValue = 1440;
        attribute coolingTemperature : TemperatureValue = 25;

        port mediumIn : InoculatedMediumPort;
        port cultureOut : InoculatedMediumPort;
        port control : ControlPort;

        part temperatureController {
            attribute currentTemperature : TemperatureValue;
            attribute tolerance : TemperatureValue = 0.5;
        }
        part humidityController {
            attribute currentHumidity : HumidityValue;
            attribute tolerance : HumidityValue = 2;
        }
        part tray {
            attribute capacity : Integer;
        }

        action def IncubationCycle {
            in inoculated : InoculatedMedium;
            out culture : MicrobialCulture;
            then action preheat { in targetTemp : TemperatureValue; }
            then action incubate {
                in duration : DurationValue;
                in temp : TemperatureValue;
                in humidity : HumidityValue;
            }
            then action cool { in targetTemp : TemperatureValue; }
        }

        state def IncubationStates {
            entry; then Empty;
            state Empty;
            state Preheating;
            state Incubating;
            state Cooling;
            state Complete;
            transition from Empty to Preheating when mediumIn.received;
            transition from Preheating to Incubating when temperatureController.currentTemperature >= targetTemperature - temperatureController.tolerance;
            transition from Incubating to Cooling when IncubationCycle.incubate.done;
            transition from Cooling to Complete when temperatureController.currentTemperature <= coolingTemperature;
            transition from Complete to Empty when control.in.commandType == "unload";
        }

        exhibit state machine IncubationStates;

        requirement def IncubationControl {
            doc /* The incubation chamber shall maintain precise temperature and humidity for a defined duration following a preheat-incubate-cool cycle. */
            subject chamber : IncubationChamber;
            constraint { chamber.targetTemperature > 0 }
            constraint { chamber.targetHumidity >= 80 }
            constraint { chamber.incubationDuration > 0 }
        }
    }

    // ============================================================
    // Analysis Suite
    // ============================================================

    part def Spectrophotometer {
        attribute wavelength : WavelengthValue = 600;
        attribute measurementRange : OpticalDensityValue = 3.0;

        port dataOut : DataOutPort;
        port control : ControlPort;

        part lightSource {
            attribute wavelength : WavelengthValue;
        }
        part detector {
            attribute sensitivity : OpticalDensityValue;
        }

        action def MeasureOpticalDensity {
            in culture : MicrobialCulture;
            in beam : LightBeam;
            out od : OpticalDensityValue;
        }

        exhibit action MeasureOpticalDensity;

        requirement def SpectrophotometryAccuracy {
            doc /* The spectrophotometer shall measure optical density of the culture at 600 nm wavelength. */
            subject device : Spectrophotometer;
            constraint { device.wavelength == 600 }
        }
    }

    part def OpticalMicroscope {
        attribute maxMagnification : MagnificationValue = 1000;
        attribute cameraResolution : String = "12MP";

        port dataOut : DataOutPort;
        port control : ControlPort;

        part objectiveLens {
            attribute magnification : MagnificationValue;
        }
        part digitalCamera {
            attribute resolution : String;
            action def CaptureImage {
                in culture : MicrobialCulture;
                out image : DigitalImage;
            }
        }

        action def ExamineCulture {
            in culture : MicrobialCulture;
            out image : DigitalImage;
            out morphologyNotes : String;
            then action capture : digitalCamera.CaptureImage;
        }

        exhibit action ExamineCulture;

        requirement def MicroscopyCapability {
            doc /* The optical microscope shall visually examine the culture and capture digital images for morphological identification. */
            subject device : OpticalMicroscope;
            constraint { device.maxMagnification >= 400 }
        }
    }

    part def AutomatedColonyCounter {
        attribute imageProcessingAlgorithm : String = "watershed";
        attribute detectionThreshold : PercentValue = 70;

        port dataOut : DataOutPort;
        port control : ControlPort;

        part camera {
            attribute resolution : String;
        }
        part imageProcessor {
            attribute algorithm : String;
            action def CountColonies {
                in image : DigitalImage;
                out count : CountValue;
            }
        }

        action def CountCulture {
            in culture : MicrobialCulture;
            out count : CountValue;
            then action capture { out image : DigitalImage; }
            then action count : imageProcessor.CountColonies;
        }

        exhibit action CountCulture;

        requirement def ColonyCountingAccuracy {
            doc /* The automated colony counter shall count microbial colonies using image processing. */
            subject device : AutomatedColonyCounter;
            constraint { device.detectionThreshold > 50 }
        }
    }

    part def AnalysisSuite {
        port cultureIn : InoculatedMediumPort;
        port resultOut : ResultOutPort;
        port control : ControlPort;

        part spectrophotometer : Spectrophotometer;
        part opticalMicroscope : OpticalMicroscope;
        part colonyCounter : AutomatedColonyCounter;
        part dataConsolidator {
            attribute resultBuffer : AnalysisData[0..*];
            action def Consolidate {
                in od : OpticalDensityValue;
                in count : CountValue;
                in images : DigitalImage[0..*];
                in notes : String;
                out result : TestResult;
            }
        }

        action def AnalyzeCulture {
            in culture : MicrobialCulture;
            out result : TestResult;
            then action measureOD : spectrophotometer.MeasureOpticalDensity;
            then action examine : opticalMicroscope.ExamineCulture;
            then action count : colonyCounter.CountCulture;
            then action consolidate : dataConsolidator.Consolidate;
        }

        exhibit action AnalyzeCulture;

        requirement def AnalysisCompleteness {
            doc /* The analysis suite shall consolidate optical density, colony count, and morphological data into a comprehensive test result. */
            subject suite : AnalysisSuite;
            constraint { suite.spectrophotometer.wavelength == 600 }
            constraint { suite.colonyCounter.detectionThreshold > 50 }
        }
    }

    // ============================================================
    // Integrated Microbiology Analysis System
    // ============================================================

    part def MicrobiologyAnalysisSystem {
        attribute systemId : String;
        attribute throughputPerDay : Integer;

        port sampleInput : SampleInPort;
        port resultOutput : ResultOutPort;
        port systemControl : ControlPort;

        part bioSafetyWorkstation : BioSafetyWorkstation;
        part samplePreparationStation : SamplePreparationStation;
        part autoclave : Autoclave;
        part incubationChamber : IncubationChamber;
        part analysisSuite : AnalysisSuite;

        // Sterile airflow distribution
        connection bioSafetyWorkstation.airOut to samplePreparationStation.control;
        connection bioSafetyWorkstation.airOut to incubationChamber.control;
        connection bioSafetyWorkstation.airOut to analysisSuite.control;

        // Sample flow
        connection sampleInput to samplePreparationStation.sampleIn;
        connection samplePreparationStation.preparedOut to incubationChamber.mediumIn;
        connection samplePreparationStation.debrisOut to bioSafetyWorkstation.control;

        // Medium sterilization flow
        connection autoclave.mediumPort to incubationChamber.mediumIn;

        // Culture flow to analysis
        connection incubationChamber.cultureOut to analysisSuite.cultureIn;

        // Result flow
        connection analysisSuite.resultOut to resultOutput;

        // Control bus
        connection systemControl to bioSafetyWorkstation.control;
        connection systemControl to samplePreparationStation.control;
        connection systemControl to autoclave.control;
        connection systemControl to incubationChamber.control;
        connection systemControl to analysisSuite.control;

        action def FullAnalysisWorkflow {
            in rawSample : BiologicalSample;
            out result : TestResult;
            then action sterilize : autoclave.SterilizeLoad;
            then action prepare : samplePreparationStation.PrepareSample;
            then action incubate : incubationChamber.IncubationCycle;
            then action analyze : analysisSuite.AnalyzeCulture;
        }

        exhibit action FullAnalysisWorkflow;

        state def SystemStates {
            entry; then Initialized;
            state Initialized;
            state Sterilizing;
            state Preparing;
            state Incubating;
            state Analyzing;
            state ResultReady;
            transition from Initialized to Sterilizing when systemControl.in.commandType == "start";
            transition from Sterilizing to Preparing when autoclave.SterilizeLoad.done;
            transition from Preparing to Incubating when samplePreparationStation.PrepareSample.done;
            transition from Incubating to Analyzing when incubationChamber.IncubationCycle.done;
            transition from Analyzing to ResultReady when analysisSuite.AnalyzeCulture.done;
            transition from ResultReady to Initialized when systemControl.in.commandType == "reset";
        }

        exhibit state machine SystemStates;

        requirement def SystemIntegration {
            doc /* The system shall integrate bio-safety, preparation, sterilization, incubation, and analysis modules into a single automated workflow. */
            subject system : MicrobiologyAnalysisSystem;
            constraint { system.bioSafetyWorkstation.hepaFilterEfficiency >= 99.97 }
            constraint { system.autoclave.sterilizeTemperature >= 121 }
            constraint { system.incubationChamber.targetTemperature > 0 }
            constraint { system.analysisSuite.spectrophotometer.wavelength == 600 }
        }

        requirement def ResultCompleteness {
            doc /* The system shall produce a test result containing microbial load, colony count, and identified species. */
            subject system : MicrobiologyAnalysisSystem;
            constraint { system.resultOutput.microbialLoad >= 0 }
            constraint { system.resultOutput.colonyCount >= 0 }
        }

        satisfy SystemIntegration by system;
        satisfy ResultCompleteness by system;
    }

}
