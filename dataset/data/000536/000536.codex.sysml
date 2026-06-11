package AutoAnalyzerSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Concentration {
        :> ScalarValues::Real;
        unit = "mmol/L";
    }

    attribute def VolumeFlowRate {
        :> ScalarValues::Real;
        unit = "mL/min";
    }

    attribute def SampleVolume {
        :> ScalarValues::Real;
        unit = "uL";
    }

    attribute def Temperature {
        :> ScalarValues::Real;
        unit = "degC";
    }

    attribute def OpticalAbsorbance {
        :> ScalarValues::Real;
        unit = "AU";
    }

    attribute def Wavelength {
        :> ScalarValues::Real;
        unit = "nm";
    }

    attribute def Pressure {
        :> ScalarValues::Real;
        unit = "kPa";
    }

    attribute def TimeDuration {
        :> ScalarValues::Real;
        unit = "s";
    }

    attribute def ResultConfidence {
        :> ScalarValues::Real;
        unit = "percent";
    }

    enum def AnalyzerMode {
        enum idle;
        enum priming;
        enum sampling;
        enum reacting;
        enum measuring;
        enum reporting;
        enum cleaning;
        enum faulted;
    }

    enum def SampleKind {
        enum serum;
        enum plasma;
        enum urine;
        enum control;
        enum calibrator;
        enum blank;
    }

    enum def FaultKind {
        enum noFault;
        enum sampleClot;
        enum lowReagent;
        enum opticalDrift;
        enum temperatureOutOfRange;
        enum pressureHigh;
        enum wasteFull;
        enum communicationLoss;
    }

    item def SampleItem {
        attribute sampleId : String;
        attribute kind : SampleKind;
        attribute requestedAnalyte : String;
        attribute volume : SampleVolume;
        attribute expectedConcentration : Concentration;
    }

    item def ReagentItem {
        attribute reagentId : String;
        attribute analyteTarget : String;
        attribute concentration : Concentration;
        attribute remainingVolume_mL : Real;
        attribute expiryDate : String;
    }

    item def MixedReactionStream {
        attribute sampleFraction : Real;
        attribute reagentFraction : Real;
        attribute flowRate : VolumeFlowRate;
        attribute reactionTemperature : Temperature;
        attribute residenceTime : TimeDuration;
    }

    item def OpticalSignal {
        attribute wavelength : Wavelength;
        attribute absorbance : OpticalAbsorbance;
        attribute integrationTime : TimeDuration;
        attribute darkCorrected : Boolean;
    }

    item def AnalysisResult {
        attribute sampleId : String;
        attribute analyte : String;
        attribute measuredConcentration : Concentration;
        attribute confidence : ResultConfidence;
        attribute valid : Boolean;
        attribute flags : String;
    }

    item def WasteFluid {
        attribute volume_mL : Real;
        attribute containsBiohazard : Boolean;
        attribute containsChemicalReagent : Boolean;
    }

    port def FluidInPort {
        in item fluid;
    }

    port def FluidOutPort {
        out item fluid;
    }

    port def SampleInputPort {
        in item sample : SampleItem;
    }

    port def ReagentInputPort {
        in item reagent : ReagentItem;
    }

    port def ReactionStreamPort {
        inout item stream : MixedReactionStream;
    }

    port def OpticalSignalPort {
        out item signal : OpticalSignal;
    }

    port def ResultPort {
        out item result : AnalysisResult;
    }

    port def CommandPort {
        in item command : String;
    }

    port def StatusPort {
        out item mode : AnalyzerMode;
        out item fault : FaultKind;
    }

    part def SampleCarousel {
        attribute capacity : Integer = 60;
        attribute loadedSamples : Integer;
        attribute currentPosition : Integer;
        attribute minimumSampleVolume : SampleVolume = 50;

        port sampleLoad : SampleInputPort;
        port selectedSample : FluidOutPort;
        port status : StatusPort;

        action selectNextSample {
            in item requestedSampleId : String;
            out item sample : SampleItem;
        }

        action verifySampleVolume {
            in item sample : SampleItem;
            out item sufficient : Boolean;
        }
    }

    part def ReagentRack {
        attribute capacity : Integer = 24;
        attribute refrigeratedTemperature : Temperature = 6;
        attribute lowReagentThreshold_mL : Real = 5.0;

        port reagentLoad : ReagentInputPort;
        port selectedReagent : FluidOutPort;
        port status : StatusPort;

        action selectReagent {
            in item analyte : String;
            out item reagent : ReagentItem;
        }

        action verifyReagentAvailability {
            in item reagent : ReagentItem;
            out item available : Boolean;
        }
    }

    part def PeristalticPump {
        attribute commandedFlowRate : VolumeFlowRate;
        attribute actualFlowRate : VolumeFlowRate;
        attribute maximumFlowRate : VolumeFlowRate = 10;
        attribute pressureLimit : Pressure = 250;

        port inlet : FluidInPort;
        port outlet : FluidOutPort;
        port status : StatusPort;

        action pumpFluid {
            in item requestedFlowRate : VolumeFlowRate;
            out item deliveredFlowRate : VolumeFlowRate;
        }

        action detectOcclusion {
            in item linePressure : Pressure;
            out item occluded : Boolean;
        }
    }

    part def ProportioningManifold {
        attribute sampleToReagentRatio : Real = 0.10;
        attribute airSegmentationEnabled : Boolean = true;
        attribute carryoverLimitPercent : Real = 1.0;

        port sampleIn : FluidInPort;
        port reagentIn : FluidInPort;
        port mixedOut : ReactionStreamPort;

        action combineSampleAndReagent {
            in item sample : SampleItem;
            in item reagent : ReagentItem;
            out item stream : MixedReactionStream;
        }

        action insertAirSegments {
            inout item stream : MixedReactionStream;
        }
    }

    part def IncubationCoil {
        attribute setpointTemperature : Temperature = 37;
        attribute actualTemperature : Temperature;
        attribute residenceTime : TimeDuration = 120;
        attribute temperatureTolerance : Temperature = 0.5;

        port streamIn : ReactionStreamPort;
        port streamOut : ReactionStreamPort;
        port status : StatusPort;

        action incubateReaction {
            in item incoming : MixedReactionStream;
            out item reacted : MixedReactionStream;
        }

        action regulateTemperature {
            in item setpoint : Temperature;
            out item stable : Boolean;
        }
    }

    part def Colorimeter {
        attribute selectedWavelength : Wavelength = 540;
        attribute absorbanceRangeMin : OpticalAbsorbance = 0;
        attribute absorbanceRangeMax : OpticalAbsorbance = 3;
        attribute baselineAbsorbance : OpticalAbsorbance;

        port opticalCellIn : ReactionStreamPort;
        port opticalCellOut : FluidOutPort;
        port signalOut : OpticalSignalPort;
        port status : StatusPort;

        action measureAbsorbance {
            in item reactedStream : MixedReactionStream;
            out item signal : OpticalSignal;
        }

        action correctBaseline {
            in item rawSignal : OpticalSignal;
            out item correctedSignal : OpticalSignal;
        }
    }

    part def CalibrationProcessor {
        attribute calibrationSlope : Real;
        attribute calibrationIntercept : Real;
        attribute lastCalibrationDate : String;
        attribute maximumCalibrationAge_h : Real = 24;

        port signalIn : OpticalSignalPort;
        port resultOut : ResultPort;

        action convertSignalToConcentration {
            in item signal : OpticalSignal;
            in item sample : SampleItem;
            out item result : AnalysisResult;
        }

        action validateCalibration {
            out item valid : Boolean;
        }
    }

    part def DataManager {
        attribute localStorageCapacityResults : Integer = 100000;
        attribute networkEnabled : Boolean = true;
        attribute operatorId : String;

        port resultIn : ResultPort;
        port reportOut : ResultPort;
        port commandIn : CommandPort;
        port status : StatusPort;

        action storeResult {
            in item result : AnalysisResult;
            out item stored : Boolean;
        }

        action transmitResult {
            in item result : AnalysisResult;
            out item transmitted : Boolean;
        }
    }

    part def WashSystem {
        attribute washFluidVolume_mL : Real;
        attribute washCycleDuration : TimeDuration = 45;
        attribute residualCarryoverPercent : Real;

        port washFluidIn : FluidInPort;
        port washOut : FluidOutPort;
        port status : StatusPort;

        action flushLines {
            out item waste : WasteFluid;
        }

        action verifyCarryover {
            out item acceptable : Boolean;
        }
    }

    part def WasteContainer {
        attribute capacity_mL : Real = 5000;
        attribute currentVolume_mL : Real;
        attribute fullThresholdPercent : Real = 90;

        port wasteIn : FluidInPort;
        port status : StatusPort;

        action acceptWaste {
            in item waste : WasteFluid;
            out item accepted : Boolean;
        }

        action checkWasteLevel {
            out item full : Boolean;
        }
    }

    part def AnalyzerController {
        attribute currentMode : AnalyzerMode = AnalyzerMode::idle;
        attribute activeFault : FaultKind = FaultKind::noFault;
        attribute samplesProcessedToday : Integer;
        attribute maximumThroughputPerHour : Integer = 120;

        port commandIn : CommandPort;
        port statusOut : StatusPort;

        action startRun {
            in item worklistId : String;
        }

        action pauseRun;

        action stopRun;

        action raiseFault {
            in item fault : FaultKind;
        }

        action clearFault {
            in item operatorAuthorization : String;
            out item cleared : Boolean;
        }

        state def AnalyzerOperatingState {
            entry action initializeStatus;

            state idle;
            state priming;
            state sampling;
            state reacting;
            state measuring;
            state reporting;
            state cleaning;
            state faulted;

            transition idle_to_priming
                first idle
                then priming
                accept commandStart
                do startRun;

            transition priming_to_sampling
                first priming
                then sampling
                if primingComplete;

            transition sampling_to_reacting
                first sampling
                then reacting
                if sampleAspirated and reagentAvailable;

            transition reacting_to_measuring
                first reacting
                then measuring
                if residenceTimeComplete;

            transition measuring_to_reporting
                first measuring
                then reporting
                if opticalSignalAccepted;

            transition reporting_to_sampling
                first reporting
                then sampling
                if worklistHasNextSample;

            transition reporting_to_cleaning
                first reporting
                then cleaning
                if worklistComplete;

            transition cleaning_to_idle
                first cleaning
                then idle
                if cleaningComplete;

            transition any_to_faulted
                first idle
                then faulted
                accept faultDetected
                do raiseFault;

            transition faulted_to_cleaning
                first faulted
                then cleaning
                accept faultCleared
                do clearFault;
        }
    }

    part def AutoAnalyzer {
        attribute primaryFunction : String =
            "Automatically aspirate biological samples, proportion them with analytical reagents, incubate the resulting reaction stream, measure optical absorbance, calculate analyte concentration, and report validated laboratory results with minimal operator intervention.";

        attribute nominalThroughputPerHour : Integer = 90;
        attribute sampleCarryoverLimitPercent : Real = 1.0;
        attribute operatingTemperature : Temperature = 22;
        attribute standbyPower_W : Real = 250;
        attribute runningPower_W : Real = 900;

        port sampleInput : SampleInputPort;
        port reagentInput : ReagentInputPort;
        port commandInput : CommandPort;
        port resultOutput : ResultPort;
        port statusOutput : StatusPort;

        part controller : AnalyzerController;
        part carousel : SampleCarousel;
        part reagentRack : ReagentRack;
        part samplePump : PeristalticPump;
        part reagentPump : PeristalticPump;
        part manifold : ProportioningManifold;
        part incubationCoil : IncubationCoil;
        part detector : Colorimeter;
        part processor : CalibrationProcessor;
        part dataManager : DataManager;
        part washSystem : WashSystem;
        part wasteContainer : WasteContainer;

        connect sampleInput to carousel.sampleLoad;
        connect reagentInput to reagentRack.reagentLoad;
        connect commandInput to controller.commandIn;
        connect commandInput to dataManager.commandIn;
        connect controller.statusOut to statusOutput;
        connect dataManager.reportOut to resultOutput;

        connect carousel.selectedSample to samplePump.inlet;
        connect samplePump.outlet to manifold.sampleIn;
        connect reagentRack.selectedReagent to reagentPump.inlet;
        connect reagentPump.outlet to manifold.reagentIn;
        connect manifold.mixedOut to incubationCoil.streamIn;
        connect incubationCoil.streamOut to detector.opticalCellIn;
        connect detector.signalOut to processor.signalIn;
        connect processor.resultOut to dataManager.resultIn;
        connect detector.opticalCellOut to wasteContainer.wasteIn;
        connect washSystem.washOut to wasteContainer.wasteIn;

        perform action analyzeSample {
            in item sample : SampleItem;
            in item reagent : ReagentItem;
            out item result : AnalysisResult;

            first start;
            then verify_sample;
            then verify_reagent;
            then aspirate_sample;
            then aspirate_reagent;
            then mix;
            then incubate;
            then measure;
            then calculate;
            then report;
            then clean;

            action start {
                controller.currentMode = AnalyzerMode::sampling;
            }

            action verify_sample {
                carousel.verifySampleVolume(sample, sufficient);
            }

            action verify_reagent {
                reagentRack.verifyReagentAvailability(reagent, available);
            }

            action aspirate_sample {
                samplePump.pumpFluid(1.0, deliveredSampleFlow);
            }

            action aspirate_reagent {
                reagentPump.pumpFluid(9.0, deliveredReagentFlow);
            }

            action mix {
                manifold.combineSampleAndReagent(sample, reagent, stream);
                manifold.insertAirSegments(stream);
            }

            action incubate {
                incubationCoil.incubateReaction(stream, reactedStream);
            }

            action measure {
                detector.measureAbsorbance(reactedStream, opticalSignal);
                detector.correctBaseline(opticalSignal, correctedSignal);
            }

            action calculate {
                processor.convertSignalToConcentration(correctedSignal, sample, result);
            }

            action report {
                dataManager.storeResult(result, stored);
                dataManager.transmitResult(result, transmitted);
            }

            action clean {
                washSystem.flushLines(waste);
                wasteContainer.acceptWaste(waste, accepted);
            }
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject analyzer : AutoAnalyzer;
        require constraint {
            analyzer.primaryFunction ==
            "Automatically aspirate biological samples, proportion them with analytical reagents, incubate the resulting reaction stream, measure optical absorbance, calculate analyte concentration, and report validated laboratory results with minimal operator intervention."
        }
    }

    requirement def ThroughputRequirement {
        subject analyzer : AutoAnalyzer;
        require constraint {
            analyzer.nominalThroughputPerHour >= 60
        }
    }

    requirement def CarryoverRequirement {
        subject analyzer : AutoAnalyzer;
        require constraint {
            analyzer.sampleCarryoverLimitPercent <= 1.0
        }
    }

    requirement def TemperatureControlRequirement {
        subject coil : IncubationCoil;
        require constraint {
            coil.actualTemperature >= coil.setpointTemperature - coil.temperatureTolerance and
            coil.actualTemperature <= coil.setpointTemperature + coil.temperatureTolerance
        }
    }

    requirement def AbsorbanceMeasurementRequirement {
        subject detector : Colorimeter;
        require constraint {
            detector.selectedWavelength >= 340 and
            detector.selectedWavelength <= 700 and
            detector.absorbanceRangeMax >= 2.0
        }
    }

    requirement def WasteContainmentRequirement {
        subject waste : WasteContainer;
        require constraint {
            waste.currentVolume_mL <= waste.capacity_mL * waste.fullThresholdPercent / 100
        }
    }

    requirement def ResultValidityRequirement {
        subject result : AnalysisResult;
        require constraint {
            result.confidence >= 95 and result.valid == true
        }
    }

    requirement def FaultDetectionRequirement {
        subject controller : AnalyzerController;
        require constraint {
            controller.activeFault != FaultKind::noFault implies
            controller.currentMode == AnalyzerMode::faulted
        }
    }

    satisfy PrimaryFunctionRequirement by AutoAnalyzer;
    satisfy ThroughputRequirement by AutoAnalyzer;
    satisfy CarryoverRequirement by AutoAnalyzer;
    satisfy TemperatureControlRequirement by AutoAnalyzer::incubationCoil;
    satisfy AbsorbanceMeasurementRequirement by AutoAnalyzer::detector;
    satisfy WasteContainmentRequirement by AutoAnalyzer::wasteContainer;
    satisfy FaultDetectionRequirement by AutoAnalyzer::controller;

    part autoAnalyzerSystem : AutoAnalyzer {
        attribute nominalThroughputPerHour = 90;
        attribute sampleCarryoverLimitPercent = 0.8;
        attribute operatingTemperature = 22;
        attribute standbyPower_W = 250;
        attribute runningPower_W = 900;

        part controller {
            attribute currentMode = AnalyzerMode::idle;
            attribute activeFault = FaultKind::noFault;
            attribute samplesProcessedToday = 0;
        }

        part carousel {
            attribute loadedSamples = 48;
            attribute currentPosition = 1;
        }

        part reagentRack {
            attribute refrigeratedTemperature = 6;
        }

        part samplePump {
            attribute commandedFlowRate = 1.0;
            attribute actualFlowRate = 1.0;
        }

        part reagentPump {
            attribute commandedFlowRate = 9.0;
            attribute actualFlowRate = 9.0;
        }

        part incubationCoil {
            attribute setpointTemperature = 37;
            attribute actualTemperature = 37.1;
            attribute residenceTime = 120;
        }

        part detector {
            attribute selectedWavelength = 540;
            attribute baselineAbsorbance = 0.02;
        }

        part processor {
            attribute calibrationSlope = 12.5;
            attribute calibrationIntercept = 0.01;
            attribute lastCalibrationDate = "2026-06-10";
        }

        part dataManager {
            attribute operatorId = "LAB-OP-014";
            attribute networkEnabled = true;
        }

        part washSystem {
            attribute washFluidVolume_mL = 1800;
            attribute residualCarryoverPercent = 0.5;
        }

        part wasteContainer {
            attribute currentVolume_mL = 1250;
        }
    }
}