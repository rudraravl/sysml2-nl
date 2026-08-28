package ClinicalChemistryAnalyzer {
    private import ScalarValues::*;
    private import SI::*;

    unit mL;
    unit uL;
    unit mgPerDeciliter;
    unit testsPerHour;
    unit nm;
    unit day;

    attribute def Absorbance :> Real;
    attribute def Concentration :> Real;
    attribute def Temperature :> Real;
    attribute def Volume :> Real;
    attribute def Throughput :> Real;
    attribute def Wavelength :> Real;
    attribute def Duration :> Real;

    enum def SampleType {
        serum;
        plasma;
        wholeBlood;
        urine;
    }
    enum def Analyte {
        glucose;
        cholesterol;
        creatinine;
        lactateDehydrogenase;
        alanineAminotransferase;
    }

    item def SampleLoaded;
    item def CleaningComplete;
    item def QCScheduled;
    item def QCComplete;

    item def BiologicalSample {
        attribute patientId : String;
        attribute sampleType : SampleType;
        attribute volume : Volume;
        attribute requestedAnalytes : Analyte[0..*];
    }
    item def Reagent {
        attribute reagentId : String;
        attribute targetAnalyte : Analyte;
        attribute volumeOnHand : Volume;
        attribute stockConcentration : Concentration;
    }
    item def ReactionMixture {
        attribute sampleId : String;
        attribute reagentId : String;
        attribute volume : Volume;
        attribute incubationTemperature : Temperature;
        attribute absorbance : Absorbance;
    }
    item def StandardSample {
        attribute standardId : String;
        attribute targetAnalyte : Analyte;
        attribute expectedConcentration : Concentration;
    }
    item def DiagnosticReport {
        attribute patientId : String;
        attribute analyte : Analyte;
        attribute measuredConcentration : Concentration;
        attribute referenceRangeLow : Concentration;
        attribute referenceRangeHigh : Concentration;
        attribute valid : Boolean;
        attribute timestamp : String;
    }
    item def OpticalSignal {
        attribute wavelength : Wavelength;
        attribute absorbance : Absorbance;
        attribute rawValue : Real;
    }
    item def CalibrationResult {
        attribute calibrated : Boolean;
        attribute calibrationTimestamp : String;
    }

    port def SampleInPort {
        in item sample : BiologicalSample;
    }
    port def SampleOutPort {
        out item sample : BiologicalSample;
    }
    port def ReagentOutPort {
        out item reagent : Reagent;
    }
    port def ReagentInPort {
        in item reagent : Reagent;
    }
    port def MixtureInPort {
        in item mixture : ReactionMixture;
    }
    port def MixtureOutPort {
        out item mixture : ReactionMixture;
    }
    port def OpticalInPort {
        in item signal : OpticalSignal;
    }
    port def OpticalOutPort {
        out item signal : OpticalSignal;
    }
    port def ReportOutPort {
        out item report : DiagnosticReport;
    }
    port def ReportInPort {
        in item report : DiagnosticReport;
    }
    port def StandardInPort {
        in item qcStandard : StandardSample;
    }
    port def CalibrationInPort {
        in item result : CalibrationResult;
    }
    port def CalibrationOutPort {
        out item result : CalibrationResult;
    }

    action def LoadSample {
        in sample : BiologicalSample;
        out preparedSample : BiologicalSample;
    }
    action def DispenseReagent {
        in analyte : Analyte;
        out reagent : Reagent;
    }
    action def Mix {
        in sample : BiologicalSample;
        in reagent : Reagent;
        out mixture : ReactionMixture;
    }
    action def Incubate {
        in mixture : ReactionMixture;
        out incubatedMixture : ReactionMixture;
    }
    action def Measure {
        in mixture : ReactionMixture;
        out signal : OpticalSignal;
    }
    action def Calculate {
        in signal : OpticalSignal;
        out concentration : Concentration;
    }
    action def Validate {
        in concentration : Concentration;
        in low : Concentration;
        in high : Concentration;
        out valid : Boolean;
    }
    action def CompileReport {
        in patientId : String;
        in analyte : Analyte;
        in concentration : Concentration;
        in valid : Boolean;
        out report : DiagnosticReport;
    }
    action def Clean;
    action def Calibrate {
        in qcStandard : StandardSample;
        out result : CalibrationResult;
    }
    action def RunQC {
        in qcStandard : StandardSample;
        out passed : Boolean;
    }

    part def SampleHandlingModule {
        port sampleIn : SampleInPort;
        port sampleOut : SampleOutPort;
    }
    part def ReagentManagementModule {
        port reagentOut : ReagentOutPort;
    }
    part def FluidicsModule {
        port sampleIn : SampleInPort;
        port reagentIn : ReagentInPort;
        port mixtureOut : MixtureOutPort;
    }
    part def OpticalDetectionModule {
        port mixtureIn : MixtureInPort;
        port signalOut : OpticalOutPort;
        port calibrationIn : CalibrationInPort;
    }
    part def DataProcessingModule {
        port signalIn : OpticalInPort;
        port reportOut : ReportOutPort;
    }
    part def QualityControlModule {
        port standardIn : StandardInPort;
        port calibrationOut : CalibrationOutPort;
    }

    part def ClinicalChemistryAnalyzer {
        attribute maxThroughput : Throughput = 220 [testsPerHour];
        attribute sampleVolume : Volume = 5 [uL];
        attribute calibrationInterval : Duration = 30 [day];
        attribute closedSystem : Boolean = true;
        attribute coefficientOfVariation : Real = 0.015;

        port sampleIn : SampleInPort;
        port reportOut : ReportOutPort;
        port lisOut : ReportOutPort;
        port qcIn : StandardInPort;

        part sampleHandling : SampleHandlingModule {
            action loadSample : LoadSample;
        }
        part reagentMgmt : ReagentManagementModule {
            action dispenseReagent : DispenseReagent;
        }
        part fluidics : FluidicsModule {
            action mix : Mix;
            action incubate : Incubate;
            action clean : Clean;
        }
        part optical : OpticalDetectionModule {
            action measure : Measure;
        }
        part dataProcessing : DataProcessingModule {
            action calculate : Calculate;
            action validate : Validate;
            action compileReport : CompileReport;
        }
        part qualityControl : QualityControlModule {
            action calibrate : Calibrate;
            action runQC : RunQC;
        }

        connect sampleIn to sampleHandling.sampleIn;
        connect sampleHandling.sampleOut to fluidics.sampleIn;
        connect reagentMgmt.reagentOut to fluidics.reagentIn;
        connect fluidics.mixtureOut to optical.mixtureIn;
        connect optical.signalOut to dataProcessing.signalIn;
        connect dataProcessing.reportOut to reportOut;
        connect dataProcessing.reportOut to lisOut;
        connect qcIn to qualityControl.standardIn;
        connect qualityControl.calibrationOut to optical.calibrationIn;

        state machine {
            initial state idle;
            state loading {
                entry / sampleHandling.loadSample;
            }
            state preparing {
                entry / reagentMgmt.dispenseReagent;
            }
            state mixing {
                entry / fluidics.mix;
            }
            state incubating {
                entry / fluidics.incubate;
            }
            state measuring {
                entry / optical.measure;
            }
            state calculating {
                entry / dataProcessing.calculate;
            }
            state validating {
                entry / dataProcessing.validate;
            }
            state reporting {
                entry / dataProcessing.compileReport;
            }
            state cleaning {
                entry / fluidics.clean;
            }
            state qualityControlState {
                entry / qualityControl.calibrate;
            }
            transition from idle to loading;
            transition from loading to preparing;
            transition from preparing to mixing;
            transition from mixing to incubating;
            transition from incubating to measuring;
            transition from measuring to calculating;
            transition from calculating to validating;
            transition from validating to reporting;
            transition from reporting to cleaning;
            transition from cleaning to idle;
            transition from idle to qualityControlState;
            transition from qualityControlState to idle;
        }
    }

    part def LaboratoryInformationSystem {
        port reportIn : ReportInPort;
        attribute systemId : String;
    }

    part labSystem {
        part clinicalAnalyzer : ClinicalChemistryAnalyzer;
        part lis : LaboratoryInformationSystem {
            attribute :>> systemId = "LIS-001";
        }
        connect clinicalAnalyzer.lisOut to lis.reportIn;
    }

    requirement def HighThroughputRequirement {
        subject analyzer : ClinicalChemistryAnalyzer;
        constraint { analyzer.maxThroughput >= 200 [testsPerHour]; }
    }
    requirement def HighPrecisionRequirement {
        subject analyzer : ClinicalChemistryAnalyzer;
        constraint { analyzer.coefficientOfVariation <= 0.02; }
    }
    requirement def SmallSampleVolumeRequirement {
        subject analyzer : ClinicalChemistryAnalyzer;
        constraint { analyzer.sampleVolume <= 10 [uL]; }
    }
    requirement def CalibrationStabilityRequirement {
        subject analyzer : ClinicalChemistryAnalyzer;
        constraint { analyzer.calibrationInterval >= 30 [day]; }
    }
    requirement def BiosafetyRequirement {
        subject analyzer : ClinicalChemistryAnalyzer;
        constraint { analyzer.closedSystem == true; }
    }

    satisfy HighThroughputRequirement by labSystem.clinicalAnalyzer;
    satisfy HighPrecisionRequirement by labSystem.clinicalAnalyzer;
    satisfy SmallSampleVolumeRequirement by labSystem.clinicalAnalyzer;
    satisfy CalibrationStabilityRequirement by labSystem.clinicalAnalyzer;
    satisfy BiosafetyRequirement by labSystem.clinicalAnalyzer;

    verification def ClinicalAnalyzerVerification {
        subject analyzer : ClinicalChemistryAnalyzer;
    }
    verification analyzerVerification : ClinicalAnalyzerVerification {
        subject :>> labSystem.clinicalAnalyzer;
    }
}
