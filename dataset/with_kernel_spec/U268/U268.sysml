package DigitalPathologyInstrumentSystem {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ScalarValues::Integer;
    private import ScalarValues::String;

    attribute def Micrometer :> Real;
    attribute def Celsius :> Real;
    attribute def Percent :> Real;
    attribute def ConfidenceScore :> Real;

    item def TissueSample;
    item def TissueSection {
        attribute thickness : Micrometer;
    }
    item def GlassSlide;
    item def StainedSlide;
    item def DigitalImage;
    item def DiagnosticReport {
        attribute findings : String;
        attribute confidenceScore : ConfidenceScore;
        attribute requiresReview : Boolean;
        attribute isFinalized : Boolean;
    }

    port def TissueSamplePort {
        out item sample : TissueSample;
    }
    port def TissueSectionPort {
        out item section : TissueSection;
    }
    port def GlassSlidePort {
        out item slide : GlassSlide;
    }
    port def StainedSlidePort {
        out item stainedSlide : StainedSlide;
    }
    port def ImageDataPort {
        out item image : DigitalImage;
    }
    port def ReportDataPort {
        out item report : DiagnosticReport;
    }
    port def EnvironmentControlPort {
        out attribute temp : Celsius;
        out attribute humidity : Percent;
        out attribute filtration : Percent;
    }

    action def SectionTissue {
        in sample : TissueSample;
        out section : TissueSection;
    }
    action def StainSlide {
        in section : TissueSection;
        in slide : GlassSlide;
        out stainedSlide : StainedSlide;
    }
    action def ScanSlide {
        in stainedSlide : StainedSlide;
        out digitalImage : DigitalImage;
    }
    action def AnalyzeImage {
        in image : DigitalImage;
        out report : DiagnosticReport;
    }
    action def ProcessPathologySample {
        in rawSample : TissueSample;
        in glassSlide : GlassSlide;
        out finalReport : DiagnosticReport;

        action doSection : SectionTissue;
        action doStain : StainSlide;
        action doScan : ScanSlide;
        action doAnalyze : AnalyzeImage;

        bind doSection.sample = rawSample;
        bind doStain.slide = glassSlide;
        bind doAnalyze.report = finalReport;

        flow from doSection.section to doStain.section;
        flow from doStain.stainedSlide to doScan.stainedSlide;
        flow from doScan.digitalImage to doAnalyze.image;

        first doSection then doStain;
        first doStain then doScan;
        first doScan then doAnalyze;
    }

    part def TissueSectioner {
        port sampleInPort : ~TissueSamplePort;
        port sectionOutPort : TissueSectionPort;
        perform action section : SectionTissue {
            in sample = sampleInPort.sample;
            out section = sectionOutPort.section;
        }
    }

    part def HeatingSystem {
        attribute setPoint : Celsius = 37.0;
    }
    part def DispensingSystem {
        attribute reagentVolume : Real = 100.0;
    }

    part def AutomatedStainer {
        port sectionInPort : ~TissueSectionPort;
        port slideInPort : ~GlassSlidePort;
        port stainedSlideOutPort : StainedSlidePort;
        part heating : HeatingSystem;
        part dispensing : DispensingSystem;
        perform action stain : StainSlide {
            in section = sectionInPort.section;
            in slide = slideInPort.slide;
            out stainedSlide = stainedSlideOutPort.stainedSlide;
        }
    }

    part def ObjectiveLensAssembly;
    part def ImagingSensor;
    part def AutoFocusSystem;

    part def DigitalPathologyScanner {
        port slideInPort : ~StainedSlidePort;
        port imageOutPort : ImageDataPort;
        part objectiveLens : ObjectiveLensAssembly;
        part imagingSensor : ImagingSensor;
        part autoFocus : AutoFocusSystem;
        perform action scan : ScanSlide {
            in stainedSlide = slideInPort.stainedSlide;
            out digitalImage = imageOutPort.image;
        }
        state machine scannerSM {
            state standby;
            state initialization;
            state activeScanning;
            state processing;
            state maintenance;
            transition from standby to initialization;
            transition from initialization to activeScanning;
            transition from activeScanning to processing;
            transition from processing to standby;
            transition from standby to maintenance;
            transition from maintenance to standby;
            transition from activeScanning to maintenance;
        }
    }

    part def ImageAnalysisWorkstation {
        port imageInPort : ~ImageDataPort;
        port reportOutPort : ReportDataPort;
        attribute confidenceThreshold : ConfidenceScore = 0.85;
        perform action analyze : AnalyzeImage {
            in image = imageInPort.image;
            out report = reportOutPort.report;
        }
    }

    part def EnvironmentalControlUnit {
        port envOutPort : EnvironmentControlPort;
        attribute targetTemp : Celsius = 22.0;
        attribute targetHumidity : Percent = 45.0;
        attribute targetFiltration : Percent = 95.0;
    }

    part def DigitalPathologyInstrument {
        port sampleInPort : ~TissueSamplePort;
        port slideInPort : ~GlassSlidePort;
        port reportOutPort : ReportDataPort;

        part sectioner : TissueSectioner;
        part stainer : AutomatedStainer;
        part scanner : DigitalPathologyScanner;
        part workstation : ImageAnalysisWorkstation;
        part envControl : EnvironmentalControlUnit;

        flow of sample : TissueSample
            from sampleInPort.sample to sectioner.sampleInPort.sample;
        flow of section : TissueSection
            from sectioner.sectionOutPort.section to stainer.sectionInPort.section;
        flow of slide : GlassSlide
            from slideInPort.slide to stainer.slideInPort.slide;
        flow of stainedSlide : StainedSlide
            from stainer.stainedSlideOutPort.stainedSlide to scanner.slideInPort.stainedSlide;
        flow of image : DigitalImage
            from scanner.imageOutPort.image to workstation.imageInPort.image;
        flow of report : DiagnosticReport
            from workstation.reportOutPort.report to reportOutPort.report;

        perform action processWorkflow : ProcessPathologySample {
            in rawSample = sampleInPort.sample;
            in glassSlide = slideInPort.slide;
            out finalReport = reportOutPort.report;
        }
    }

    requirement def AutomateWorkflow {
        subject instrument : DigitalPathologyInstrument;
        objective "The system shall automate the entire pathology workflow from tissue sectioning to diagnostic report generation.";
    }
    requirement def MaintainEnvironment {
        subject envUnit : EnvironmentalControlUnit;
        attribute tempRange : Celsius = 20.0;
        attribute humidityRange : Percent = 40.0;
        objective "The system shall maintain stable temperature, humidity, and air filtration levels for reliable results.";
    }
    requirement def GenerateReport {
        subject workstation : ImageAnalysisWorkstation;
        attribute minConfidence : ConfidenceScore = 0.85;
        objective "The analysis workstation shall generate a diagnostic report with a confidence score and flag for review if confidence is low.";
    }
    requirement def ScannerStateManagement {
        subject scanner : DigitalPathologyScanner;
        objective "The scanner shall operate through standby, initialization, active scanning, processing, and maintenance states.";
    }

    part context {
        part instrument : DigitalPathologyInstrument;
        satisfy AutomateWorkflow by instrument;
        satisfy MaintainEnvironment by instrument.envControl;
        satisfy GenerateReport by instrument.workstation;
        satisfy ScannerStateManagement by instrument.scanner;
    }
}
