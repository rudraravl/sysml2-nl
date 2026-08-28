package ClinicalChemistryAnalyzer {
    private import ScalarValues::*;

    attribute def mgPerdL;
    attribute def AbsorbanceUnit;
    attribute def degC;
    attribute def sec;
    attribute def nm;
    attribute def uL;

    attribute def ConcentrationValue {
        attribute value : Real;
        attribute unitRef : mgPerdL;
    }
    attribute def AbsorbanceValue {
        attribute value : Real;
        attribute unitRef : AbsorbanceUnit;
    }
    attribute def TemperatureValue {
        attribute value : Real;
        attribute unitRef : degC;
    }
    attribute def DurationValue {
        attribute value : Real;
        attribute unitRef : sec;
    }
    attribute def VolumeValue {
        attribute value : Real;
        attribute unitRef : uL;
    }
    attribute def WavelengthValue {
        attribute value : Real;
        attribute unitRef : nm;
    }

    item def BiologicalSample {
        attribute sampleId : String;
        attribute volume : VolumeValue;
        attribute matrixType : String;
    }
    item def Reagent {
        attribute reagentId : String;
        attribute volume : VolumeValue;
        attribute testType : String;
    }
    item def ReactionMixture {
        attribute sampleId : String;
        attribute reagentId : String;
        attribute totalVolume : VolumeValue;
    }
    item def IncubatedMixture {
        attribute sampleId : String;
        attribute reagentId : String;
        attribute incubationTemp : TemperatureValue;
        attribute incubationDuration : DurationValue;
    }

    attribute def ControlSignal {
        attribute commandCode : String;
        attribute targetModule : String;
    }
    attribute def StatusReport {
        attribute moduleName : String;
        attribute operationalState : String;
    }
    attribute def FaultSignal {
        attribute errorCode : String;
        attribute description : String;
    }
    attribute def AnalyteResult {
        attribute testType : String;
        attribute concentration : ConcentrationValue;
        attribute absorbance : AbsorbanceValue;
        attribute qualityStatus : String;
    }

    action def LoadSampleAction {
        out preparedSample : BiologicalSample;
    }
    action def DispenseReagentAction {
        out reagent : Reagent;
    }
    action def MixAction {
        in sample : BiologicalSample;
        in reagent : Reagent;
        out mixture : ReactionMixture;
    }
    action def IncubateAction {
        in mixture : ReactionMixture;
        out incubated : IncubatedMixture;
    }
    action def MeasureAbsorbanceAction {
        in incubated : IncubatedMixture;
        out absorbance : AbsorbanceValue;
        out usedMixture : IncubatedMixture;
    }
    action def AnalyzeDataAction {
        in absorbance : AbsorbanceValue;
        out result : AnalyteResult;
    }
    action def CollectWasteAction {
        in waste : IncubatedMixture;
    }

    action def PerformAnalysis {
        out result : AnalyteResult;

        action intake : LoadSampleAction;
        action dispense : DispenseReagentAction;
        action mix : MixAction;
        action incubate : IncubateAction;
        action measure : MeasureAbsorbanceAction;
        action analyze : AnalyzeDataAction;
        action dispose : CollectWasteAction;

        flow intake.preparedSample to mix.sample;
        flow dispense.reagent to mix.reagent;
        flow mix.mixture to incubate.mixture;
        flow incubate.incubated to measure.incubated;
        flow measure.absorbance to analyze.absorbance;
        flow measure.usedMixture to dispose.waste;
        flow analyze.result to result;

        first start then intake;
        first intake then dispense;
        first dispense then mix;
        first mix then incubate;
        first incubate then measure;
        first measure then analyze;
        first analyze then dispose;
    }

    stateMachine def IncubationStates {
        state Idle;
        state HeatingUp;
        state MaintainingTemp;
        state Complete;
        transition from Idle to HeatingUp;
        transition from HeatingUp to MaintainingTemp;
        transition from MaintainingTemp to Complete;
        transition from Complete to Idle;
    }

    stateMachine def ControllerStates {
        state Idle;
        state Running;
        state Error;
        transition from Idle to Running;
        transition from Running to Error;
        transition from Error to Idle;
        transition from Running to Idle;
    }

    part def SampleIntakeModule {
        port sampleOut {
            out sample : BiologicalSample;
        }
        port controlIn {
            in cmd : ControlSignal;
        }
        port statusOut {
            out status : StatusReport;
        }
        perform load : LoadSampleAction;
        flow load.preparedSample to sampleOut.sample;
    }

    part def ReagentDeliveryModule {
        port reagentOut {
            out reagent : Reagent;
        }
        port controlIn {
            in cmd : ControlSignal;
        }
        port statusOut {
            out status : StatusReport;
        }
        perform dispense : DispenseReagentAction;
        flow dispense.reagent to reagentOut.reagent;
    }

    part def MixingChamber {
        port sampleIn {
            in sample : BiologicalSample;
        }
        port reagentIn {
            in reagent : Reagent;
        }
        port mixtureOut {
            out mixture : ReactionMixture;
        }
        port controlIn {
            in cmd : ControlSignal;
        }
        port statusOut {
            out status : StatusReport;
        }
        perform mix : MixAction;
        flow sampleIn.sample to mix.sample;
        flow reagentIn.reagent to mix.reagent;
        flow mix.mixture to mixtureOut.mixture;
    }

    part def IncubationUnit {
        port mixtureIn {
            in mixture : ReactionMixture;
        }
        port mixtureOut {
            out incubated : IncubatedMixture;
        }
        port controlIn {
            in cmd : ControlSignal;
        }
        port statusOut {
            out status : StatusReport;
        }
        port faultOut {
            out fault : FaultSignal;
        }

        attribute targetTemp : TemperatureValue;
        attribute currentTemp : TemperatureValue;
        attribute incubationTime : DurationValue;
        attribute timer : DurationValue;

        stateMachine incubation : IncubationStates;
        perform incubate : IncubateAction;
        flow mixtureIn.mixture to incubate.mixture;
        flow incubate.incubated to mixtureOut.incubated;
    }

    part def SpectrophotometerModule {
        port mixtureIn {
            in incubated : IncubatedMixture;
        }
        port mixtureOut {
            out usedMixture : IncubatedMixture;
        }
        port absorbanceOut {
            out absorbance : AbsorbanceValue;
        }
        port controlIn {
            in cmd : ControlSignal;
        }
        port statusOut {
            out status : StatusReport;
        }

        attribute wavelength : WavelengthValue;

        perform measure : MeasureAbsorbanceAction;
        flow mixtureIn.incubated to measure.incubated;
        flow measure.absorbance to absorbanceOut.absorbance;
        flow measure.usedMixture to mixtureOut.usedMixture;
    }

    part def DataAnalysisModule {
        port absorbanceIn {
            in absorbance : AbsorbanceValue;
        }
        port resultOut {
            out result : AnalyteResult;
        }
        port controlIn {
            in cmd : ControlSignal;
        }
        port statusOut {
            out status : StatusReport;
        }
        perform analyze : AnalyzeDataAction;
        flow absorbanceIn.absorbance to analyze.absorbance;
        flow analyze.result to resultOut.result;
    }

    part def WasteManagementModule {
        port wasteIn {
            in waste : IncubatedMixture;
        }
        port controlIn {
            in cmd : ControlSignal;
        }
        port statusOut {
            out status : StatusReport;
        }
        perform collect : CollectWasteAction;
        flow wasteIn.waste to collect.waste;
    }

    part def SystemController {
        port controlOut {
            out cmd : ControlSignal;
        }
        port statusIn {
            in status : StatusReport;
        }
        port faultIn {
            in fault : FaultSignal;
        }
        port externalCommandIn {
            in cmd : ControlSignal;
        }

        stateMachine controllerSM : ControllerStates;
    }

    part def Analyzer {
        port commandInput {
            in cmd : ControlSignal;
        }
        port resultOutput {
            out result : AnalyteResult;
        }

        part sampleIntake : SampleIntakeModule;
        part reagentDelivery : ReagentDeliveryModule;
        part mixingChamber : MixingChamber;
        part incubationUnit : IncubationUnit;
        part spectrophotometer : SpectrophotometerModule;
        part dataAnalysis : DataAnalysisModule;
        part wasteManagement : WasteManagementModule;
        part systemController : SystemController;

        flow sampleIntake.sampleOut.sample to mixingChamber.sampleIn.sample;
        flow reagentDelivery.reagentOut.reagent to mixingChamber.reagentIn.reagent;
        flow mixingChamber.mixtureOut.mixture to incubationUnit.mixtureIn.mixture;
        flow incubationUnit.mixtureOut.incubated to spectrophotometer.mixtureIn.incubated;
        flow spectrophotometer.mixtureOut.usedMixture to wasteManagement.wasteIn.waste;
        flow spectrophotometer.absorbanceOut.absorbance to dataAnalysis.absorbanceIn.absorbance;

        flow systemController.controlOut.cmd to sampleIntake.controlIn.cmd;
        flow systemController.controlOut.cmd to reagentDelivery.controlIn.cmd;
        flow systemController.controlOut.cmd to mixingChamber.controlIn.cmd;
        flow systemController.controlOut.cmd to incubationUnit.controlIn.cmd;
        flow systemController.controlOut.cmd to spectrophotometer.controlIn.cmd;
        flow systemController.controlOut.cmd to dataAnalysis.controlIn.cmd;
        flow systemController.controlOut.cmd to wasteManagement.controlIn.cmd;

        flow sampleIntake.statusOut.status to systemController.statusIn.status;
        flow reagentDelivery.statusOut.status to systemController.statusIn.status;
        flow mixingChamber.statusOut.status to systemController.statusIn.status;
        flow incubationUnit.statusOut.status to systemController.statusIn.status;
        flow spectrophotometer.statusOut.status to systemController.statusIn.status;
        flow dataAnalysis.statusOut.status to systemController.statusIn.status;
        flow wasteManagement.statusOut.status to systemController.statusIn.status;

        flow incubationUnit.faultOut.fault to systemController.faultIn.fault;

        bind commandInput = systemController.externalCommandIn;
        bind resultOutput = dataAnalysis.resultOut;
    }

    requirement def AutomatedAnalysis {
        doc "The system shall fully automate the testing process from sample handling to result delivery.";
    }
    requirement def HighThroughput {
        doc "The system shall process at least 120 samples per hour.";
    }
    requirement def IncubationTemperatureStability {
        doc "The incubation unit shall maintain the target temperature within plus or minus 0.5 degrees Celsius.";
    }
    requirement def MeasurementAccuracy {
        doc "The data analysis module shall convert absorbance to concentration with an accuracy of plus or minus 2 percent.";
    }
    requirement def SafeWasteContainment {
        doc "The waste management module shall safely contain biohazardous liquid waste.";
    }

    part analyzer : Analyzer {
        satisfy AutomatedAnalysis;
        satisfy HighThroughput;
        satisfy MeasurementAccuracy;
        satisfy SafeWasteContainment;
    }

    part incubator : IncubationUnit {
        satisfy IncubationTemperatureStability;
    }
}
