package DigitalPathologyInstrumentSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====

    value def LengthUnit :> Real;
    value def Thickness :> LengthUnit { unit 'µm'; }
    value def Temperature :> Real { unit '°C'; }
    value def Humidity :> Real { unit '%RH'; }
    value def Volume :> Real { unit 'µL'; }
    value def Resolution :> Real { unit 'px/µm'; }
    value def Magnification :> Real { unit 'x'; }
    value def ConfidenceScore :> Real { unit '%'; }
    value def Pressure :> Real { unit 'mbar'; }
    value def FlowRate :> Real { unit 'µL/s'; }
    value def Power :> Real { unit 'W'; }
    value def Duration :> Real { unit 's'; }

    // ===== Item Definitions =====

    item def BiologicalTissueSample {
        attribute sampleId : String;
        attribute tissueType : String;
        attribute originOrgan : String;
        attribute grossDimensions : LengthUnit;
    }

    item def TissueSection {
        attribute sectionId : String;
        attribute thickness : Thickness;
        attribute parentSampleId : String;
    }

    item def GlassSlide {
        attribute slideId : String;
        attribute dimensions : LengthUnit;
        attribute loaded : Boolean;
    }

    item def Reagent {
        attribute reagentId : String;
        attribute chemicalName : String;
        attribute concentration : Real;
        attribute volume : Volume;
        attribute targetStain : String;
    }

    item def StainedSlide {
        attribute slideId : String;
        attribute stainProtocol : String;
        attribute qualityGrade : String;
    }

    item def DigitalImage {
        attribute imageId : String;
        attribute resolution : Resolution;
        attribute pixelCount : Integer;
        attribute colorDepth : Integer;
        attribute focusMetric : Real;
    }

    item def DiagnosticReport {
        attribute reportId : String;
        attribute findings : String;
        attribute confidence : ConfidenceScore;
        attribute flaggedForReview : Boolean;
        attribute timestamp : String;
        attribute recommendedAction : String;
    }

    item def EnvironmentalData {
        attribute temperature : Temperature;
        attribute humidity : Humidity;
        attribute filtrationLevel : Real;
    }

    // ===== Port Definitions =====

    port def SampleTransferPort {
        out item samples : BiologicalTissueSample[*];
        in item ack : Boolean;
    }

    port def SectionTransferPort {
        out item sections : TissueSection[*];
        in item ack : Boolean;
    }

    port def SlideTransferPort {
        out item slides : StainedSlide[*];
        in item ack : Boolean;
    }

    port def ImageTransferPort {
        out item images : DigitalImage[*];
        in item ack : Boolean;
    }

    port def ReportOutputPort {
        out item reports : DiagnosticReport[*];
    }

    port def ReagentSupplyPort {
        in item reagents : Reagent[*];
    }

    port def EnvironmentalMonitorPort {
        out item envData : EnvironmentalData;
    }

    port def ControlSignalPort {
        in attribute command : String;
        out attribute status : String;
    }

    // ===== Tissue Sectioner =====

    part def TissueSectioner {
        port sampleIn : SampleTransferPort;
        port sectionOut : SectionTransferPort;
        port envMonitor : EnvironmentalMonitorPort;
        port control : ControlSignalPort;

        attribute bladeSpeed : Real;
        attribute sectionThickness : Thickness;
        attribute currentSampleId : String;

        part bladeAssembly {
            attribute material : String;
            attribute angle : Real;
            attribute wearLevel : Real;
        }

        part positioningStage {
            attribute xAxis : Real;
            attribute yAxis : Real;
            attribute zAxis : Real;
            attribute precision : LengthUnit;
        }

        part sampleHolder {
            attribute clampForce : Real;
            attribute temperature : Temperature;
        }

        state sectionerBehavior {
            entry; then idle;
            state idle;
            state loading {
                entry action { /* accept sample */ }
            }
            state sectioning {
                entry action { /* perform slicing */ }
                do action { /* advance blade and stage */ }
            }
            state ejecting {
                entry action { /* output sections */ }
            }
            state cleaning;
            transition idle -> loading when sampleIn.samples->notEmpty();
            transition loading -> sectioning when currentSampleId->notEmpty();
            transition sectioning -> ejecting when sectionOut.ack == true;
            transition ejecting -> cleaning;
            transition cleaning -> idle;
        }
    }

    // ===== Automated Stainer =====

    part def AutomatedStainer {
        port sectionIn : SectionTransferPort;
        port slideOut : SlideTransferPort;
        port reagentIn : ReagentSupplyPort;
        port envMonitor : EnvironmentalMonitorPort;
        port control : ControlSignalPort;

        attribute currentProtocol : String;
        attribute slideCount : Integer;
        attribute processingTemperature : Temperature;

        part dispensingSystem {
            attribute dispensingPrecision : Volume;
            attribute reagentChannels : Integer;

            part pump[8] {
                attribute flowRate : FlowRate;
                attribute active : Boolean;
            }

            part nozzleAssembly {
                attribute nozzleCount : Integer;
                attribute position : Real;
            }
        }

        part heatingSystem {
            attribute targetTemperature : Temperature;
            attribute tolerance : Temperature;
            attribute powerRating : Power;

            part heatingPlate {
                attribute currentTemp : Temperature;
                attribute surfaceArea : Real;
            }

            part temperatureSensor {
                attribute accuracy : Temperature;
                attribute samplingRate : Real;
            }
        }

        part slideTransport {
            attribute capacity : Integer;
            attribute transferSpeed : Real;
        }

        state stainerBehavior {
            entry; then standby;
            state standby;
            state receiving {
                entry action { /* accept tissue sections */ }
            }
            state mounting {
                entry action { /* mount sections on slides */ }
            }
            state staining {
                entry action { /* apply reagent sequence */ }
                do action { /* dispense reagents and heat */ }
            }
            state rinsing {
                entry action { /* rinse excess reagent */ }
            }
            state drying {
                entry action { /* dry stained slide */ }
            }
            state outputting {
                entry action { /* output stained slide */ }
            }
            transition standby -> receiving when sectionIn.sections->notEmpty();
            transition receiving -> mounting;
            transition mounting -> staining;
            transition staining -> rinsing when heatingSystem.heatingPlate.currentTemp >= processingTemperature;
            transition rinsing -> drying;
            transition drying -> outputting;
            transition outputting -> standby;
        }
    }

    // ===== Digital Pathology Scanner =====

    part def DigitalPathologyScanner {
        port slideIn : SlideTransferPort;
        port imageOut : ImageTransferPort;
        port envMonitor : EnvironmentalMonitorPort;
        port control : ControlSignalPort;

        attribute scanResolution : Resolution;
        attribute currentSlideId : String;
        attribute totalScans : Integer;

        part objectiveLensAssembly {
            attribute magnificationLevels : Magnification[*];
            attribute currentMagnification : Magnification;
            attribute numericalAperture : Real;

            part objective[4] {
                attribute magnification : Magnification;
                attribute workingDistance : LengthUnit;
                attribute selected : Boolean;
            }
        }

        part imagingSensor {
            attribute pixelSize : LengthUnit;
            attribute sensorWidth : Integer;
            attribute sensorHeight : Integer;
            attribute dynamicRange : Real;
            attribute bitDepth : Integer;
            attribute exposureTime : Duration;
        }

        part autofocusSystem {
            attribute focusRange : LengthUnit;
            attribute stepSize : LengthUnit;
            attribute focusMetric : Real;
            attribute converged : Boolean;

            part focusMotor {
                attribute speed : Real;
                attribute position : Real;
            }

            part focusSensor {
                attribute samplingRate : Real;
                attribute accuracy : LengthUnit;
            }

            action focusSequence {
                action initializeFocus;
                action scanFocusRange;
                action computeFocusMetric;
                action adjustFocus;
                action verifyFocus;
            }
        }

        part illuminationSystem {
            attribute lightSource : String;
            attribute intensity : Real;
            attribute wavelength : Real;

            part ledArray {
                attribute ledCount : Integer;
                attribute colorTemperature : Temperature;
            }
        }

        part stageController {
            attribute xPosition : Real;
            attribute yPosition : Real;
            attribute zPosition : Real;
            attribute scanArea : Real;
            attribute stepResolution : LengthUnit;
        }

        part imageProcessor {
            attribute stitchingAlgorithm : String;
            attribute compressionFormat : String;
            attribute bufferSize : Integer;
        }

        state scannerBehavior {
            entry; then standby;
            state standby {
                entry action { /* low power mode */ }
            }
            state initialization {
                entry action { /* calibrate optics and stage */ }
                do action { /* run self-diagnostics */ }
            }
            state activeScanning {
                entry action { /* load slide and begin scan */ }
                do action { /* capture tiles across slide */ }
            }
            state processing {
                entry action { /* stitch and compress image */ }
                do action { /* run quality checks */ }
            }
            state maintenance {
                entry action { /* cleaning and calibration */ }
            }
            state error {
                entry action { /* log error and alert */ }
            }
            transition standby -> initialization when control.command == "start";
            transition initialization -> activeScanning when objectiveLensAssembly.currentMagnification > 0;
            transition activeScanning -> processing when stageController.scanArea == 100.0;
            transition processing -> standby when imageOut.ack == true;
            transition standby -> maintenance when control.command == "maintenance";
            transition maintenance -> standby when control.status == "complete";
            transition initialization -> error when objectiveLensAssembly.objective.selected == false;
            transition activeScanning -> error when autofocusSystem.converged == false;
            transition error -> maintenance;
        }
    }

    // ===== Image Analysis Workstation =====

    part def ImageAnalysisWorkstation {
        port imageIn : ImageTransferPort;
        port reportOut : ReportOutputPort;
        port control : ControlSignalPort;

        attribute processingPower : Real;
        attribute modelVersion : String;
        attribute confidenceThreshold : ConfidenceScore;

        part cpu {
            attribute cores : Integer;
            attribute clockSpeed : Real;
            attribute memory : Integer;
        }

    part gpu {
            attribute cudaCores : Integer;
            attribute memory : Integer;
            attribute modelLoaded : Boolean;
        }

        part aiModel {
            attribute modelName : String;
            attribute accuracy : Real;
            attribute trainedOn : Integer;
            attribute lastUpdated : String;

            action inferencePipeline {
                action preprocessImage;
                action segmentTissue;
                action classifyCells;
                action detectAbnormalities;
                action generateHeatmap;
                action computeConfidence;
            }
        }

        part imageProcessingSoftware {
            attribute version : String;
            attribute supportedFormats : String[*];

            action processImage {
                action loadImage;
                action normalize;
                action enhanceContrast;
                action tileImage;
                action runInference;
                action assembleResults;
            }
        }

        part reportGenerator {
            attribute templateVersion : String;
            attribute outputFormat : String;

            action generateReport {
                action collectFindings;
                action calculateConfidence;
                action applyThreshold;
                action formatReport;
                action flagIfLowConfidence;
            }
        }

        state workstationBehavior {
            entry; then waiting;
            state waiting;
            state analyzing {
                entry action { /* begin image analysis */ }
                do action { /* run AI inference */ }
            }
            state reporting {
                entry action { /* generate diagnostic report */ }
            }
            state reviewing {
                entry action { /* flag for human review */ }
            }
            state complete;
            transition waiting -> analyzing when imageIn.images->notEmpty();
            transition analyzing -> reporting when aiModel.inferencePipeline.computeConfidence.confidence >= 0;
            transition reporting -> reviewing when reportGenerator.generateReport.calculateConfidence.confidence < confidenceThreshold;
            transition reporting -> complete when reportGenerator.generateReport.calculateConfidence.confidence >= confidenceThreshold;
            transition reviewing -> complete;
            transition complete -> waiting;
        }
    }

    // ===== Environmental Control Unit =====

    part def EnvironmentalControlUnit {
        port envOut : EnvironmentalMonitorPort;
        port control : ControlSignalPort;

        attribute targetTemperature : Temperature;
        attribute targetHumidity : Humidity;
        attribute targetFiltrationLevel : Real;

        part temperatureController {
            attribute currentTemp : Temperature;
            attribute tolerance : Temperature;

            part heater {
                attribute power : Power;
                attribute active : Boolean;
            }

            part cooler {
                attribute power : Power;
                attribute active : Boolean;
            }

            part tempSensor {
                attribute accuracy : Temperature;
                attribute samplingRate : Real;
            }
        }

        part humidityController {
            attribute currentHumidity : Humidity;
            attribute tolerance : Humidity;

            part humidifier {
                attribute capacity : Volume;
                attribute active : Boolean;
            }

            part dehumidifier {
                attribute capacity : Volume;
                attribute active : Boolean;
            }

            part humiditySensor {
                attribute accuracy : Humidity;
                attribute samplingRate : Real;
            }
        }

        part airFiltrationSystem {
            attribute filterEfficiency : Real;
            attribute airflowRate : Real;

            part hepaFilter {
                attribute rating : String;
                attribute replacementInterval : Duration;
                attribute usageTime : Duration;
            }

            part fan {
                attribute speed : Real;
                attribute active : Boolean;
            }
        }

        state envControlBehavior {
            entry; then monitoring;
            state monitoring {
                do action { /* continuously read sensors */ }
            }
            state adjusting {
                do action { /* activate heaters/coolers/humidifiers */ }
            }
            state alerting {
                entry action { /* alert if out of range */ }
            }
            transition monitoring -> adjusting when temperatureController.currentTemp != targetTemperature or humidityController.currentHumidity != targetHumidity;
            transition adjusting -> monitoring when temperatureController.currentTemp == targetTemperature and humidityController.currentHumidity == targetHumidity;
            transition monitoring -> alerting when temperatureController.tempSensor.accuracy > tolerance;
            transition alerting -> monitoring;
        }
    }

    // ===== System Integration =====

    part def DigitalPathologySystem {
        attribute systemId : String;
        attribute systemStatus : String;
        attribute throughput : Real;

        port rawSampleInput : SampleTransferPort;
        port finalReportOutput : ReportOutputPort;
        port systemControl : ControlSignalPort;

        part tissueSectioner : TissueSectioner;
        part automatedStainer : AutomatedStainer;
        part digitalScanner : DigitalPathologyScanner;
        part analysisWorkstation : ImageAnalysisWorkstation;
        part envControlUnit : EnvironmentalControlUnit;

        connection sectionerToStainer connect tissueSectioner.sectionOut to automatedStainer.sectionIn;
        connection stainerToScanner connect automatedStainer.slideOut to digitalScanner.slideIn;
        connection scannerToWorkstation connect digitalScanner.imageOut to analysisWorkstation.imageIn;
        connection workstationOutput connect analysisWorkstation.reportOut to finalReportOutput;
        connection sampleInput connect rawSampleInput to tissueSectioner.sampleIn;

        connection envToSectioner connect envControlUnit.envOut to tissueSectioner.envMonitor;
        connection envToStainer connect envControlUnit.envOut to automatedStainer.envMonitor;
        connection envToScanner connect envControlUnit.envOut to digitalScanner.envMonitor;

        connection controlToSectioner connect systemControl to tissueSectioner.control;
        connection controlToStainer connect systemControl to automatedStainer.control;
        connection controlToScanner connect systemControl to digitalScanner.control;
        connection controlToWorkstation connect systemControl to analysisWorkstation.control;
        connection controlToEnv connect systemControl to envControlUnit.control;

        action systemWorkflow {
            action receiveSample {
                in item sample : BiologicalTissueSample;
            }
            action sectionTissue {
                in item sample : BiologicalTissueSample;
                out item sections : TissueSection[*];
            }
            action stainSections {
                in item sections : TissueSection[*];
                out item slides : StainedSlide[*];
            }
            action scanSlides {
                in item slides : StainedSlide[*];
                out item images : DigitalImage[*];
            }
            action analyzeImages {
                in item images : DigitalImage[*];
                out item reports : DiagnosticReport[*];
            }
            action outputReport {
                in item reports : DiagnosticReport[*];
            }

            flow from receiveSample.out to sectionTissue.in;
            flow from sectionTissue.out to stainSections.in;
            flow from stainSections.out to scanSlides.in;
            flow from scanSlides.out to analyzeImages.in;
            flow from analyzeImages.out to outputReport.in;
        }
    }

    // ===== Requirements =====

    requirement def ShallSectionTissue {
        subject instrument : DigitalPathologySystem;
        objective {
            doc /* The system shall section biological tissue samples into sections with thickness between 2 and 5 µm. */
            assert instrument.tissueSectioner.sectionThickness >= 2.0 and instrument.tissueSectioner.sectionThickness <= 5.0;
        }
    }

    requirement def ShallStainConsistently {
        subject stainer : AutomatedStainer;
        objective {
            doc /* The stainer shall apply reagents with dispensing precision of at least 0.5 µL and maintain temperature within ±1.0 °C of target. */
            assert stainer.dispensingSystem.dispensingPrecision <= 0.5;
            assert stainer.heatingSystem.tolerance <= 1.0;
        }
    }

    requirement def ShallScanAtHighResolution {
        subject scanner : DigitalPathologyScanner;
        objective {
            doc /* The scanner shall digitize slides at a minimum resolution of 0.25 px/µm with autofocus convergence. */
            assert scanner.scanResolution >= 0.25;
            assert scanner.autofocusSystem.converged == true;
        }
    }

    requirement def ShallProvideDiagnosticReport {
        subject workstation : ImageAnalysisWorkstation;
        objective {
            doc /* The workstation shall produce a diagnostic report with a confidence score and flag for review when confidence is below 85%. */
            assert workstation.confidenceThreshold == 85.0;
        }
    }

    requirement def ShallMaintainEnvironment {
        subject envUnit : EnvironmentalControlUnit;
        objective {
            doc /* The environmental control unit shall maintain temperature at 22 °C ±2 °C, humidity at 45% ±5% RH, and HEPA filtration efficiency above 99.97%. */
            assert envUnit.targetTemperature == 22.0;
            assert envUnit.temperatureController.tolerance <= 2.0;
            assert envUnit.targetHumidity == 45.0;
            assert envUnit.humidityController.tolerance <= 5.0;
            assert envUnit.airFiltrationSystem.hepaFilter.rating == "H13";
        }
    }

    requirement def ShallOperateScannerStates {
        subject scanner : DigitalPathologyScanner;
        objective {
            doc /* The scanner shall operate through states: standby, initialization, activeScanning, processing, and maintenance. */
            assert scanner.scannerBehavior.ownedStates->select(name == "standby")->size() == 1;
            assert scanner.scannerBehavior.ownedStates->select(name == "initialization")->size() == 1;
            assert scanner.scannerBehavior.ownedStates->select(name == "activeScanning")->size() == 1;
            assert scanner.scannerBehavior.ownedStates->select(name == "processing")->size() == 1;
            assert scanner.scannerBehavior.ownedStates->select(name == "maintenance")->size() == 1;
        }
    }

    requirement def ShallAutomateFullWorkflow {
        subject system : DigitalPathologySystem;
        objective {
            doc /* The system shall automate the full workflow from raw tissue sample input to diagnostic report output without manual intervention. */
            assert system.systemWorkflow.ownedActions->size() >= 6;
        }
    }

}
