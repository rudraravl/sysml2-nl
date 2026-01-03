package MicrobiologyInstrumentSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def BiologicalSample {
        attribute sampleId : String;
        attribute volume : VolumeValue;
        attribute sourceType : String;
        attribute collectionDate : String;
    }

    item def CultureMedium {
        attribute mediumType : String;
        attribute agarConcentration : Real;
        attribute nutrientLevel : Real;
        attribute pH : Real;
    }

    item def MicrobialCulture {
        attribute cultureId : String;
        attribute colonyCount : Real;
        attribute cellDensity : Real;
        attribute growthStage : String;
    }

    item def TestResult {
        attribute resultId : String;
        attribute microbialLoad : Real;
        attribute identifiedSpecies : String[*];
        attribute contaminationLevel : Real;
        attribute analysisTimestamp : String;
    }

    item def ReagentSolution {
        attribute reagentType : String;
        attribute concentration : Real;
        attribute expirationDate : String;
    }

    attribute def IncubationTemperature :> ThermodynamicTemperatureValue;
    attribute def IncubationDuration :> TimeValue;
    attribute def OpticalDensity :> Real;
    attribute def SterilizationTemperature :> ThermodynamicTemperatureValue;
    attribute def SterilizationPressure :> PressureValue;

    port def SampleInputPort {
        in item sample : BiologicalSample;
    }

    port def SampleOutputPort {
        out item processedSample : BiologicalSample;
    }

    port def CulturePort {
        inout item culture : MicrobialCulture;
    }

    port def ResultPort {
        out item result : TestResult;
    }

    port def ControlSignalPort {
        in attribute temperatureSetpoint : IncubationTemperature;
        in attribute durationSetpoint : IncubationDuration;
        out attribute currentTemperature : ThermodynamicTemperatureValue;
        out attribute operationStatus : String;
    }

    port def ReagentPort {
        in item reagent : ReagentSolution;
    }

    part def SamplePreparationStation {
        port sampleIn : SampleInputPort;
        port sampleOut : SampleOutputPort;
        port reagentIn : ReagentPort;

        attribute preparationTime : TimeValue;
        attribute dilutionFactor : Real;

        action prepareSample {
            in rawSample : BiologicalSample;
            in reagent : ReagentSolution;
            out preparedSample : BiologicalSample;

            action homogenize {
                in sample : BiologicalSample;
                out homogenizedSample : BiologicalSample;
            }
            action dilute {
                in sample : BiologicalSample;
                in factor : Real;
                out dilutedSample : BiologicalSample;
            }
            action filterSample {
                in sample : BiologicalSample;
                out filteredSample : BiologicalSample;
            }
        }
    }

    part def Autoclave {
        port sampleIn : SampleInputPort;
        port sampleOut : SampleOutputPort;
        port control : ControlSignalPort;

        attribute maxTemperature : SterilizationTemperature;
        attribute maxPressure : SterilizationPressure;
        attribute chamberVolume : VolumeValue;

        part pressureVessel {
            attribute wallThickness : LengthValue;
            attribute material : String;
        }

        part heatingElement {
            attribute powerRating : PowerValue;
        }

        part pressureSensor {
            out attribute measuredPressure : PressureValue;
        }

        part temperatureSensor {
            out attribute measuredTemperature : ThermodynamicTemperatureValue;
        }

        action sterilize {
            in item : BiologicalSample;
            in temperature : SterilizationTemperature;
            in pressure : SterilizationPressure;
            in duration : TimeValue;
            out sterilizedItem : BiologicalSample;
        }
    }

    part def IncubationChamber {
        port sampleIn : SampleInputPort;
        port cultureOut : CulturePort;
        port control : ControlSignalPort;

        attribute targetTemperature : IncubationTemperature;
        attribute incubationTime : IncubationDuration;
        attribute chamberCapacity : Real;
        attribute currentTemperature : ThermodynamicTemperatureValue;

        part heatingSystem {
            attribute heaterPower : PowerValue;
        }

        part coolingSystem {
            attribute coolingCapacity : PowerValue;
        }

        part temperatureController {
            attribute controlAccuracy : ThermodynamicTemperatureValue;
        }

        part humidityControl {
            attribute relativeHumidity : Real;
        }

        action incubateSample {
            in sample : BiologicalSample;
            in medium : CultureMedium;
            in temperature : IncubationTemperature;
            in duration : IncubationDuration;
            out culture : MicrobialCulture;
        }
    }

    part def OpticalMicroscope {
        port cultureIn : CulturePort;
        port resultOut : ResultPort;

        attribute magnificationRange : Real[2];
        attribute resolution : LengthValue;
        attribute illuminationType : String;

        part objectiveLens {
            attribute magnification : Real;
            attribute numericalAperture : Real;
        }

        part eyepiece {
            attribute magnification : Real;
        }

        part illuminationSystem {
            attribute lightSource : String;
            attribute intensity : Real;
        }

        part imagingCamera {
            attribute resolution : Real;
            attribute frameRate : Real;
        }

        action examineCulture {
            in culture : MicrobialCulture;
            out observation : TestResult;
        }
    }

    part def Spectrophotometer {
        port cultureIn : CulturePort;
        port resultOut : ResultPort;

        attribute wavelengthRange : LengthValue[2];
        attribute accuracy : Real;

        part lightSource {
            attribute wavelength : LengthValue;
        }

        part monochromator {
            attribute bandwidth : LengthValue;
        }

        part detector {
            attribute sensitivity : Real;
        }

        action measureOpticalDensity {
            in culture : MicrobialCulture;
            out opticalDensity : OpticalDensity;
            out result : TestResult;
        }
    }

    part def ColonyCounter {
        port cultureIn : CulturePort;
        port resultOut : ResultPort;

        attribute countingAccuracy : Real;
        attribute detectionThreshold : Real;

        part imageCapture {
            attribute cameraResolution : Real;
        }

        part imageProcessor {
            action processImage {
                in image : String;
                out colonyCount : Real;
            }
        }

        action countColonies {
            in culture : MicrobialCulture;
            out result : TestResult;
        }
    }

    part def BioSafetyWorkstation {
        port sampleIn : SampleInputPort;
        port sampleOut : SampleOutputPort;

        attribute airflowVelocity : Real;
        attribute hepaFilterEfficiency : Real;
        attribute workSurfaceArea : AreaValue;

        part hepaFilter {
            attribute filterClass : String;
        }

        part uvSterilizer {
            attribute uvWavelength : LengthValue;
        }

        part airflowSystem {
            attribute flowRate : Real;
        }
    }

    state def IncubatorOperationState {
        entry; then idle;

        state idle;

        transition idle_to_preheating
            first idle
            then preheating;

        state preheating;

        transition preheating_to_incubating
            first preheating
            then incubating;

        state incubating;

        transition incubating_to_complete
            first incubating
            then complete;

        state complete;

        transition complete_to_cooling
            first complete
            then cooling;

        state cooling;

        transition cooling_to_idle
            first cooling
            then idle;
    }

    action def PerformMicrobiologicalAnalysis {
        in inputSample : BiologicalSample;
        in cultureMedium : CultureMedium;
        in incubationTemp : IncubationTemperature;
        in incubationTime : IncubationDuration;
        out finalResult : TestResult;

        first start;

        then action prepareSample {
            in rawSample = inputSample;
            out preparedSample : BiologicalSample;
        }

        then action sterilizeEquipment {
            in temperature : SterilizationTemperature;
            in pressure : SterilizationPressure;
        }

        then action inoculateMedium {
            in sample = prepareSample.preparedSample;
            in medium = cultureMedium;
            out inoculatedCulture : MicrobialCulture;
        }

        then action incubateCulture {
            in culture = inoculateMedium.inoculatedCulture;
            in temperature = incubationTemp;
            in duration = incubationTime;
            out grownCulture : MicrobialCulture;
        }

        then action measureGrowth {
            in culture = incubateCulture.grownCulture;
            out opticalDensity : OpticalDensity;
        }

        then action examineUnderMicroscope {
            in culture = incubateCulture.grownCulture;
            out microscopeResult : TestResult;
        }

        then action countColonies {
            in culture = incubateCulture.grownCulture;
            out countResult : TestResult;
        }

        then action consolidateResults {
            in odMeasurement = measureGrowth.opticalDensity;
            in microscopeData = examineUnderMicroscope.microscopeResult;
            in colonyData = countColonies.countResult;
            out consolidatedResult : TestResult;
        }

        then assign finalResult := consolidateResults.consolidatedResult;

        then done;
    }

    requirement def TemperatureControlRequirement {
        doc /* The incubation chamber shall maintain temperature within ±0.3°C of setpoint during incubation */
        attribute id = "REQ-TEMP-001";
        attribute tolerance : ThermodynamicTemperatureValue;
    }

    requirement def SterilityRequirement {
        doc /* All sample contact surfaces shall be sterilizable to achieve 10^-6 sterility assurance level */
        attribute id = "REQ-STER-001";
        attribute sterilityLevel : Real;
    }

    requirement def MeasurementAccuracyRequirement {
        doc /* Optical density measurements shall have accuracy of ±2% across the measurement range */
        attribute id = "REQ-MEAS-001";
        attribute accuracy : Real;
    }

    requirement def ThroughputRequirement {
        doc /* System shall process minimum 30 samples per 8-hour operational period */
        attribute id = "REQ-THRU-001";
        attribute minimumSamples : Real;
        attribute operationalPeriod : TimeValue;
    }

    requirement def SafetyRequirement {
        doc /* Biosafety workstation shall maintain Class II Type A2 containment standards */
        attribute id = "REQ-SAFE-001";
        attribute containmentClass : String;
    }

    part def MicrobiologyInstrumentSystem {
        doc /*
         * Integrated microbiology instrument system for comprehensive microbiological analysis.
         * Primary function: Automated processing and analysis of biological samples to detect,
         * identify, quantify, and characterize microbial populations through controlled incubation,
         * optical examination, spectrophotometric measurement, and automated colony enumeration.
         * Applications include clinical diagnostics, pharmaceutical quality control, food safety
         * testing, environmental monitoring, and research microbiology.
         */

        part preparationStation : SamplePreparationStation;
        part autoclave : Autoclave;
        part incubator : IncubationChamber;
        part microscope : OpticalMicroscope;
        part spectrophotometer : Spectrophotometer;
        part colonyCounter : ColonyCounter;
        part biosafetyCabinet : BioSafetyWorkstation;

        connection samplePreparationFlow connect
            preparationStation.sampleOut to incubator.sampleIn;

        connection cultureToMicroscope connect
            incubator.cultureOut to microscope.cultureIn;

        connection cultureToSpectrophotometer connect
            incubator.cultureOut to spectrophotometer.cultureIn;

        connection cultureToCounter connect
            incubator.cultureOut to colonyCounter.cultureIn;

        perform action conductAnalysis : PerformMicrobiologicalAnalysis;

        satisfy temperatureReq : TemperatureControlRequirement;
        satisfy sterilityReq : SterilityRequirement;
        satisfy accuracyReq : MeasurementAccuracyRequirement;
        satisfy throughputReq : ThroughputRequirement;
        satisfy safetyReq : SafetyRequirement;
    }

    part microbiologyInstrumentSystem : MicrobiologyInstrumentSystem;
}
