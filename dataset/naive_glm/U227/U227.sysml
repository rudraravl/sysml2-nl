package FIASystem {
    import ScalarValues::*;

    // ===== Units =====
    unit def microliter;
    unit def milliliterPerMinute;
    unit def nanometer;
    unit def absorbanceUnit;
    unit def milligramPerLiter;
    unit def second;
    unit def meter;

    // ===== Value Types =====
    value def Volume :> Real { unit microliter; }
    value def FlowRate :> Real { unit milliliterPerMinute; }
    value def Wavelength :> Real { unit nanometer; }
    value def Absorbance :> Real { unit absorbanceUnit; }
    value def Concentration :> Real { unit milligramPerLiter; }
    value def Duration :> Real { unit second; }
    value def Length :> Real { unit meter; }

    // ===== Item Definitions =====
    item def Liquid;
    item def CarrierSolution :> Liquid;
    item def ReagentSolution :> Liquid;
    item def SampleSolution :> Liquid {
        attribute analyteConcentration : Concentration;
    }
    item def MixedSolution :> Liquid {
        attribute sampleFraction : Real;
        attribute reagentFraction : Real;
    }
    item def ReactionProductSolution :> Liquid {
        attribute productConcentration : Concentration;
        attribute measuredAbsorbance : Absorbance;
    }
    item def WasteSolution :> Liquid;
    item def ElectricalSignal {
        attribute voltage : Real;
        attribute timestamp : Duration;
    }
    item def CommandMessage {
        attribute commandType : String;
        attribute parameter : Real;
    }

    // ===== Port Definitions =====
    port def FluidInPort {
        in item liquid : Liquid;
    }
    port def FluidOutPort {
        out item liquid : Liquid;
    }
    port def SignalOutPort {
        out item signal : ElectricalSignal;
    }
    port def SignalInPort {
        in item signal : ElectricalSignal;
    }
    port def CommandOutPort {
        out item command : CommandMessage;
    }
    port def CommandInPort {
        in item command : CommandMessage;
    }

    // ===== Part Definitions =====

    part def PeristalticPump {
        attribute nominalFlowRate : FlowRate = 2.0;
        attribute isRunning : Boolean = false;
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port cmdIn : CommandInPort;

        flow pumpFlow from fluidIn.liquid to fluidOut.liquid;

        action def StartPump {
            in cmd : CommandMessage;
            // Begin rotating pump tubing at nominalFlowRate
        }
        action def StopPump {
            in cmd : CommandMessage;
            // Cease rotation, halt liquid flow
        }

        state machine PumpController {
            state Stopped;
            state Running;
            transition from Stopped to Running when cmdIn.command.commandType == "start";
            transition from Running to Stopped when cmdIn.command.commandType == "stop";
        }
    }

    part def InjectionValve {
        attribute sampleLoopVolume : Volume = 200;
        attribute valvePosition : String = "fill";
        attribute loopFilled : Boolean = false;

        port sampleIn : FluidInPort;
        port carrierIn : FluidInPort;
        port carrierOut : FluidOutPort;
        port cmdIn : CommandInPort;

        flow carrierFlow from carrierIn.liquid to carrierOut.liquid;

        action def FillSampleLoop {
            // Aspirate sample solution into the fixed-volume loop
            // until loop is full
        }
        action def InjectSample {
            // Rotate valve to inject position
            // Sample plug enters carrier stream without stopping flow
        }
        action def ResetValve {
            // Return valve to fill position for next sample
        }

        state machine ValveController {
            state FillPosition;
            state InjectPosition;
            transition from FillPosition to InjectPosition when cmdIn.command.commandType == "inject";
            transition from InjectPosition to FillPosition when cmdIn.command.commandType == "reset";
        }
    }

    part def MixingTee {
        port carrierIn : FluidInPort;
        port reagentIn : FluidInPort;
        port mixedOut : FluidOutPort;

        flow mixCarrier from carrierIn.liquid to mixedOut.liquid;
        flow mixReagent from reagentIn.liquid to mixedOut.liquid;

        action def CombineStreams {
            // Merge carrier stream containing sample plug
            // with reagent stream in a T-junction
        }
    }

    part def ReactionCoil {
        attribute coilLength : Length = 1.0;
        attribute coilVolume : Volume = 500;
        attribute residenceTime : Duration = 30;

        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;

        flow reactionFlow from fluidIn.liquid to fluidOut.liquid;

        action def ChemicalReaction {
            // Allow analyte and reagent to react while flowing through coil
            // Produce colored compound proportional to analyte concentration
        }
    }

    part def OpticalDetector {
        attribute measurementWavelength : Wavelength = 540;
        attribute measuredAbsorbance : Absorbance = 0.0;
        attribute baselineAbsorbance : Absorbance = 0.0;
        attribute lightSourceIntensity : Real = 100.0;

        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port signalOut : SignalOutPort;

        flow detectionFlow from fluidIn.liquid to fluidOut.liquid;

        action def Illuminate {
            // Direct light beam at measurementWavelength through flowing liquid
        }
        action def MeasureAbsorbance {
            // Detect transmitted light intensity
            // Calculate absorbance using Beer-Lambert law
            // Output electrical signal proportional to absorbance
        }
        action def CalibrateBaseline {
            // Establish baseline absorbance with pure carrier
        }
    }

    part def DataAcquisitionSystem {
        attribute calibrationCurveSlope : Real = 1.0;
        attribute calibrationCurveIntercept : Real = 0.0;
        attribute calculatedConcentration : Concentration = 0.0;
        attribute peakHeight : Absorbance = 0.0;
        attribute peakArea : Real = 0.0;
        attribute signalAcquired : Boolean = false;
        attribute peakDetected : Boolean = false;
        attribute analysisComplete : Boolean = false;

        port signalIn : SignalInPort;
        port cmdOut : CommandOutPort;

        action def AcquireSignal {
            // Continuously sample raw absorbance signal from detector
        }
        action def DetectPeak {
            // Identify peak height and peak area from signal trace
        }
        action def CalculateConcentration {
            // Apply calibration curve: concentration = slope * peakHeight + intercept
        }
        action def IssueStartCommand {
            // Send start command to pumps and injection valve
        }
        action def IssueInjectCommand {
            // Send inject command to injection valve
        }
        action def IssueResetCommand {
            // Send reset command to injection valve
        }

        state machine DAQController {
            state Idle;
            state WaitingForPeak;
            state Analyzing;
            state Reporting;
            transition from Idle to WaitingForPeak when signalIn.signal != null;
            transition from WaitingForPeak to Analyzing when peakDetected == true;
            transition from Analyzing to Reporting when calculatedConcentration > 0.0;
            transition from Reporting to Idle when analysisComplete == true;
        }
    }

    part def WasteReservoir {
        attribute capacity : Volume = 5000;
        attribute currentVolume : Volume = 0;
        port fluidIn : FluidInPort;

        flow wasteAccumulation from fluidIn.liquid to currentVolume;

        action def CollectWaste {
            // Accumulate all spent liquid from detector effluent
        }
    }

    // ===== Main System Assembly =====
    part def FlowInjectionAnalysisSystem {
        attribute systemName : String = "FIA-2000";
        attribute maxAnalysisTime : Duration = 60;
        attribute throughputPerHour : Real = 60;
        attribute analysisCycleCount : Integer = 0;

        part carrierPump : PeristalticPump {
            attribute nominalFlowRate : FlowRate = 2.0;
        }
        part reagentPump : PeristalticPump {
            attribute nominalFlowRate : FlowRate = 1.0;
        }
        part injectionValve : InjectionValve {
            attribute sampleLoopVolume : Volume = 200;
        }
        part mixingTee : MixingTee;
        part reactionCoil : ReactionCoil {
            attribute coilLength : Length = 1.0;
            attribute coilVolume : Volume = 500;
            attribute residenceTime : Duration = 30;
        }
        part detector : OpticalDetector {
            attribute measurementWavelength : Wavelength = 540;
        }
        part dataSystem : DataAcquisitionSystem;
        part wasteReservoir : WasteReservoir {
            attribute capacity : Volume = 5000;
        }

        // Fluidic connections
        connection carrierPump.fluidOut to injectionValve.carrierIn;
        connection injectionValve.carrierOut to mixingTee.carrierIn;
        connection reagentPump.fluidOut to mixingTee.reagentIn;
        connection mixingTee.mixedOut to reactionCoil.fluidIn;
        connection reactionCoil.fluidOut to detector.fluidIn;
        connection detector.fluidOut to wasteReservoir.fluidIn;

        // Signal and command connections
        connection detector.signalOut to dataSystem.signalIn;
        connection dataSystem.cmdOut to injectionValve.cmdIn;
        connection dataSystem.cmdOut to carrierPump.cmdIn;
        connection dataSystem.cmdOut to reagentPump.cmdIn;

        // System-level state machine
        state machine def SystemOperation {
            state Idle;
            state FillingSampleLoop;
            state InjectingSample;
            state TransportingAndReacting;
            state Detecting;
            state ProcessingData;
            state ReadyForNext;

            transition from Idle to FillingSampleLoop when startCommand;
            transition from FillingSampleLoop to InjectingSample when sampleLoopFilled;
            transition from InjectingSample to TransportingAndReacting when injectionComplete;
            transition from TransportingAndReacting to Detecting when residenceTimeElapsed;
            transition from Detecting to ProcessingData when peakDetected;
            transition from ProcessingData to ReadyForNext when concentrationCalculated;
            transition from ReadyForNext to Idle when resetCommand;
        }

        state machine operation : SystemOperation;

        action def RunAnalysisCycle {
            // Complete sequence: fill loop, inject, react, detect, process
        }
    }

    // ===== Requirements =====
    requirement def AnalysisTimeRequirement {
        attribute maxCycleTime : Duration = 60;
        doc "The FIA system shall complete a full analysis cycle in under 60 seconds.";
    }

    requirement def SampleVolumeRequirement {
        attribute maxSampleVolume : Volume = 200;
        doc "The system shall consume no more than 200 microliters of sample per analysis.";
    }

    requirement def DetectionWavelengthRequirement {
        attribute requiredWavelength : Wavelength = 540;
        doc "The optical detector shall measure absorbance at 540 nm wavelength.";
    }

    requirement def FlowRateControlRequirement {
        attribute carrierFlowRate : FlowRate = 2.0;
        attribute reagentFlowRate : FlowRate = 1.0;
        attribute flowRateTolerance : Real = 0.05;
        doc "The peristaltic pumps shall maintain constant, controlled flow rates within 5 percent of nominal.";
    }

    requirement def ResidenceTimeRequirement {
        attribute minResidenceTime : Duration = 30;
        doc "The reaction coil shall provide sufficient residence time for the chemical reaction to complete.";
    }

    requirement def HighThroughputRequirement {
        attribute minSamplesPerHour : Real = 60;
        doc "The system shall be capable of processing at least 60 samples per hour.";
    }

    requirement def CalibrationRequirement {
        attribute calibrationLinearity : Real = 0.999;
        doc "The data acquisition system shall use a calibration curve with R-squared of at least 0.999 to calculate concentration.";
    }

    requirement def WasteCollectionRequirement {
        attribute minWasteCapacity : Volume = 5000;
        doc "The waste reservoir shall have a minimum capacity of 5000 microliters.";
    }

    // ===== Requirement Satisfaction =====
    part def FIASystemWithRequirements :> FlowInjectionAnalysisSystem {
        satisfy AnalysisTimeRequirement {
            attribute maxCycleTime = maxAnalysisTime;
        }
        satisfy SampleVolumeRequirement {
            attribute maxSampleVolume = injectionValve.sampleLoopVolume;
        }
        satisfy DetectionWavelengthRequirement {
            attribute requiredWavelength = detector.measurementWavelength;
        }
        satisfy FlowRateControlRequirement {
            attribute carrierFlowRate = carrierPump.nominalFlowRate;
            attribute reagentFlowRate = reagentPump.nominalFlowRate;
        }
        satisfy ResidenceTimeRequirement {
            attribute minResidenceTime = reactionCoil.residenceTime;
        }
        satisfy HighThroughputRequirement {
            attribute minSamplesPerHour = throughputPerHour;
        }
        satisfy WasteCollectionRequirement {
            attribute minWasteCapacity = wasteReservoir.capacity;
        }
    }
}
