package MicrobiologyAnalysisSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def OpticalDensityValue :> Real;
    attribute def ColonyCountValue :> Integer;
    attribute def HumidityValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def PressureValue :> Real;
    attribute def TimeValue :> Real;

    item def BiologicalSample;
    item def PreparedSample;
    item def CultureMedium;
    item def SterilizedMedium;
    item def InoculatedCulture;
    item def IncubatedCulture;
    item def TestResult {
        attribute microbialLoad : OpticalDensityValue;
        attribute colonyCount : ColonyCountValue;
        attribute identifiedSpecies : String[0..*];
    }

    action def Sterilize {
        in item medium : CultureMedium;
        out item sterilizedMedium : SterilizedMedium;
    }
    action def PrepareSample {
        in item rawSample : BiologicalSample;
        out item preparedSample : PreparedSample;
    }
    action def Inoculate {
        in item preparedSample : PreparedSample;
        in item sterilizedMedium : SterilizedMedium;
        out item culture : InoculatedCulture;
    }
    action def Incubate {
        in item culture : InoculatedCulture;
        out item incubatedCulture : IncubatedCulture;
    }
    action def MeasureOpticalDensity {
        in item culture : IncubatedCulture;
        out attribute opticalDensity : OpticalDensityValue;
    }
    action def ExamineMicroscopically {
        in item culture : IncubatedCulture;
        out attribute identifiedSpecies : String[0..*];
    }
    action def CountColonies {
        in item culture : IncubatedCulture;
        out attribute colonyCount : ColonyCountValue;
    }
    action def ConsolidateResults {
        in attribute od : OpticalDensityValue;
        in attribute species : String[0..*];
        in attribute count : ColonyCountValue;
        out item result : TestResult;
    }
    action def RunAnalysis {
        in item rawSample : BiologicalSample;
        in item medium : CultureMedium;
        out item result : TestResult;
    }

    part def BioSafetyWorkstation;
    part def SamplePreparationStation;
    part def Autoclave;
    part def IncubationChamber;
    part def Spectrophotometer;
    part def OpticalMicroscope;
    part def AutomatedColonyCounter;
    part def AnalysisSuite;
    part def MicrobiologyLabSystem;

    port def SamplePort { in item sample : BiologicalSample; }
    port def MediumPort { in item medium : CultureMedium; }
    port def ResultPort { out item result : TestResult; }

    state def IncubationStateMachine {
        attribute currentTemp : TemperatureValue;
        attribute targetTemperature : TemperatureValue = 37;
        attribute targetHumidity : HumidityValue = 0.95;
        attribute incubationDuration : TimeValue = 24;
        attribute elapsedTime : TimeValue;

        state idle;
        state preheating;
        state incubating;
        state cooling;
        state done;

        transition t1 { source idle; target preheating; }
        transition t2 { source preheating; target incubating; guard currentTemp >= targetTemperature; }
        transition t3 { source incubating; target cooling; guard elapsedTime >= incubationDuration; }
        transition t4 { source cooling; target done; guard currentTemp <= 25; }
        transition t5 { source done; target idle; }
    }

    requirement SterilityRequirement {
        attribute hepaFilterEfficiency : Real = 0.9999;
    }
    requirement SamplePreparationRequirement {
    }
    requirement AutoclaveRequirement {
    }
    requirement IncubationRequirement {
    }
    requirement AnalysisRequirement {
    }
    requirement ResultConsolidationRequirement {
    }

    part labSystem : MicrobiologyLabSystem {
        satisfy SterilityRequirement;
        satisfy SamplePreparationRequirement;
        satisfy AutoclaveRequirement;
        satisfy IncubationRequirement;
        satisfy AnalysisRequirement;
        satisfy ResultConsolidationRequirement;

        in port sampleIn : SamplePort;
        in port mediumIn : MediumPort;
        out port resultOut : ResultPort;

        perform action runAnalysis : RunAnalysis {
            in item rawSample : BiologicalSample = sampleIn.sample;
            in item medium : CultureMedium = mediumIn.medium;
            out item result : TestResult = resultOut.result;

            action sterilize : Sterilize {
                in item medium = runAnalysis.medium;
                out item sterilizedMedium;
            }
            action prepareSample : PrepareSample {
                in item rawSample = runAnalysis.rawSample;
                out item preparedSample;
            }
            action inoculate : Inoculate {
                in item preparedSample = prepareSample.preparedSample;
                in item sterilizedMedium = sterilize.sterilizedMedium;
                out item culture;
            }
            action incubate : Incubate {
                in item culture = inoculate.culture;
                out item incubatedCulture;
            }
            action measureOD : MeasureOpticalDensity {
                in item culture = incubate.incubatedCulture;
                out attribute opticalDensity;
            }
            action examine : ExamineMicroscopically {
                in item culture = incubate.incubatedCulture;
                out attribute identifiedSpecies;
            }
            action countColonies : CountColonies {
                in item culture = incubate.incubatedCulture;
                out attribute colonyCount;
            }
            action consolidate : ConsolidateResults {
                in attribute od = measureOD.opticalDensity;
                in attribute species = examine.identifiedSpecies;
                in attribute count = countColonies.colonyCount;
                out item result = runAnalysis.result;
            }

            first start;
            then sterilize;
            then prepareSample;
            then inoculate;
            then incubate;
            then measureOD;
            then examine;
            then countColonies;
            then consolidate;
            then done;
        }

        part bioSafetyWorkstation : BioSafetyWorkstation {
            attribute hepaFilterEfficiency : Real = 0.9999;
        }
        part samplePreparationStation : SamplePreparationStation {
            perform runAnalysis.prepareSample;
        }
        part autoclave : Autoclave {
            perform runAnalysis.sterilize;
        }
        part incubationChamber : IncubationChamber {
            perform runAnalysis.incubate;
            attribute targetTemperature : TemperatureValue = 37;
            attribute targetHumidity : HumidityValue = 0.95;
            attribute incubationDuration : TimeValue = 24;
            attribute currentTemp : TemperatureValue;
            attribute elapsedTime : TimeValue;
            state incubationStateMachine : IncubationStateMachine;
        }
        part analysisSuite : AnalysisSuite {
            perform runAnalysis.measureOD;
            perform runAnalysis.examine;
            perform runAnalysis.countColonies;
            perform runAnalysis.consolidate;

            part spectrophotometer : Spectrophotometer {
                perform runAnalysis.measureOD;
            }
            part opticalMicroscope : OpticalMicroscope {
                perform runAnalysis.examine;
            }
            part colonyCounter : AutomatedColonyCounter {
                perform runAnalysis.countColonies;
            }
        }
    }

    individual def TestLabSystem :> MicrobiologyLabSystem;
    individual def TestSample1 :> BiologicalSample;
    individual def TestMedium1 :> CultureMedium;

    individual testLab : TestLabSystem :> labSystem {
        timeslice analysisRun1 {
            perform action :>> runAnalysis {
                in item :>> rawSample : TestSample1;
                in item :>> medium : TestMedium1;
            }
        }
    }
}
