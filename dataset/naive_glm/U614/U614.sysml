package BiochipAnalysisSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // ===== Value Types =====
    value type Concentration :> Real { unit 'µg/mL'; }
    value type Temperature :> Real { unit 'K'; }
    value type Duration :> Real { unit 'min'; }
    value type Wavelength :> Real { unit 'nm'; }
    value type SignalStrength :> Real { unit 'a.u.'; }
    value type FlowRate :> Real { unit 'µL/min'; }
    value type Volume :> Real { unit 'µL'; }
    value type Threshold :> Concentration;

    // ===== Enumerations =====
    enum def Determination { positive; negative; }
    enum def SampleType { blood; saliva; }

    // ===== Item Definitions =====
    item def BiologicalSample {
        attribute sampleId : String;
        attribute sampleType : SampleType;
        attribute collectionTime : String;
    }

    item def Reagent {
        attribute reagentName : String;
        attribute targetAnalyte : String;
        attribute lotNumber : String;
    }

    item def ReactionMixture {
        attribute sampleId : String;
        attribute reagentName : String;
        attribute incubated : Boolean = false;
    }

    item def WasteFluid {
        attribute originSampleId : String;
    }

    item def AssayResult {
        attribute sampleId : String;
        attribute measuredConcentration : Concentration;
        attribute signalStrength : SignalStrength;
        attribute determination : Determination;
        attribute analysisDuration : Duration;
    }

    // ===== Port Definitions =====
    port def FluidInPort {
        in item sample : BiologicalSample;
        in item reagent : Reagent;
        in item mixture : ReactionMixture;
    }

    port def FluidOutPort {
        out item mixture : ReactionMixture;
        out item waste : WasteFluid;
    }

    port def SignalPort {
        out attribute signal : SignalStrength;
    }

    port def CommandPort {
        in attribute command : String;
        out attribute status : String;
    }

    port def ResultPort {
        out item result : AssayResult;
    }

    // ===== Part Definitions =====
    part def FluidPump {
        attribute nominalFlowRate : FlowRate = 10.0;
        attribute maxFlowRate : FlowRate = 50.0;
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port cmd : CommandPort;

        action def PumpSample {
            in item sample : BiologicalSample;
            in item reagent : Reagent;
            out item mixture : ReactionMixture;
        }

        perform action pumpSample : PumpSample {
            in item sample = fluidIn.sample;
            in item reagent = fluidIn.reagent;
            out item mixture = fluidOut.mixture;
        }
    }

    part def MicrofluidicChannel {
        attribute length : Real = 25.0;
        attribute crossSection : Real = 0.01;
        port inlet : FluidInPort;
        port outlet : FluidOutPort;
    }

    part def ReactionChamber {
        attribute volume : Volume = 50.0;
        attribute incubationTime : Duration = 5.0;
        attribute currentTemperature : Temperature = 293.15;
        port inlet : FluidInPort;
        port outlet : FluidOutPort;
        port tempControl : CommandPort;

        action def Incubate {
            in item mixture : ReactionMixture;
            in attribute setTemp : Temperature;
            in attribute duration : Duration;
            out item incubatedMixture : ReactionMixture;
        }

        perform action incubate : Incubate {
            in item mixture = inlet.mixture;
            in attribute setTemp = 310.15;
            in attribute duration = incubationTime;
            out item incubatedMixture = outlet.mixture;
        }
    }

    part def TemperatureController {
        attribute setPoint : Temperature = 310.15;
        attribute tolerance : Temperature = 0.5;
        attribute heaterActive : Boolean = false;
        port sensor : CommandPort;
        port heater : CommandPort;

        action def Regulate {
            in attribute currentTemp : Temperature;
            out attribute heaterCommand : Boolean;
        }

        perform action regulate : Regulate {
            in attribute currentTemp = 310.15;
            out attribute heaterCommand = heaterActive;
        }
    }

    part def OpticalDetector {
        attribute excitationWavelength : Wavelength = 530.0;
        attribute emissionWavelength : Wavelength = 590.0;
        attribute detectionThreshold : Threshold = 0.1;
        attribute measuredSignal : SignalStrength = 0.0;
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port signalOut : SignalPort;

        action def Detect {
            in item mixture : ReactionMixture;
            out attribute signal : SignalStrength;
        }

        perform action detect : Detect {
            in item mixture = fluidIn.mixture;
            out attribute signal = signalOut.signal;
        }
    }

    part def WastePort {
        port inlet : FluidInPort;
        attribute capacity : Volume = 5000.0;
        attribute currentVolume : Volume = 0.0;
    }

    // ===== State Machine =====
    state def AnalysisStateMachine {
        attribute totalDuration : Duration = 0.0;
        attribute maxDuration : Duration = 15.0;

        state idle {
            entry action { send "System idle" to controllerStatus; }
        }

        state ready {
            entry action { send "System ready for new test" to controllerStatus; }
        }

        state processing {
            entry action { send "Assay processing started" to controllerStatus; }
            do action { perform assaySequence; }
        }

        state analyzing {
            entry action { send "Analyzing raw signal" to controllerStatus; }
            do action { perform interpretSignal; }
        }

        state complete {
            entry action { send "Analysis complete" to controllerStatus; }
            do action { perform outputResult; }
        }

        transition t_idle_to_ready first idle then ready
            when sampleLoaded;

        transition t_ready_to_processing first ready then processing
            when startAssay;

        transition t_processing_to_analyzing first processing then analyzing
            when detectionComplete;

        transition t_analyzing_to_complete first analyzing then complete
            when analysisComplete;

        transition t_complete_to_idle first complete then idle
            when resultDelivered;
    }

    // ===== Controller =====
    part def SystemController {
        attribute thresholdConcentration : Threshold = 0.5;
        attribute currentResult : AssayResult;
        port cmd : CommandPort;
        port resultOut : ResultPort;
        port detectorIn : SignalPort;

        action def InterpretSignal {
            in attribute signal : SignalStrength;
            in attribute sampleId : String;
            out item result : AssayResult;
        }

        perform action interpretSignal : InterpretSignal {
            in attribute signal = detectorIn.signal;
            in attribute sampleId = "unknown";
            out item result = resultOut.result;
        }

        exhibit state machine : AnalysisStateMachine;
    }

    // ===== Biochip Assembly =====
    part def Biochip {
        part pump : FluidPump;
        part channel : MicrofluidicChannel;
        part chamber : ReactionChamber;
        part detector : OpticalDetector;
        part tempController : TemperatureController;
        part waste : WastePort;

        port sampleIn : FluidInPort;
        port reagentIn : FluidInPort;
        port wasteOut : FluidOutPort;
        port signalOut : SignalPort;

        connection sampleToPump connect sampleIn to pump.fluidIn;
        connection reagentToPump connect reagentIn to pump.fluidIn;
        connection pumpToChannel connect pump.fluidOut to channel.inlet;
        connection channelToChamber connect channel.outlet to chamber.inlet;
        connection chamberToDetector connect chamber.outlet to detector.fluidIn;
        connection detectorToWaste connect detector.fluidOut to waste.inlet;
        connection wasteToPort connect waste.inlet to wasteOut;
        connection tempToChamber connect tempController.heater to chamber.tempControl;
        connection detectorSignal connect detector.signalOut to signalOut;
    }

    // ===== Top-Level System =====
    part def BiochipAnalysisSystem {
        attribute systemId : String = "BAS-001";
        attribute maxAnalysisTime : Duration = 15.0;
        attribute throughputPerHour : Integer = 240;

        part biochip : Biochip;
        part controller : SystemController;
        part wastePort : WastePort;

        port sampleInput : FluidInPort;
        port reagentInput : FluidInPort;
        port resultOutput : ResultPort;

        connection extSampleToBiochip connect sampleInput to biochip.sampleIn;
        connection extReagentToBiochip connect reagentInput to biochip.reagentIn;
        connection biochipWasteToPort connect biochip.wasteOut to wastePort.inlet;
        connection biochipSignalToController connect biochip.signalOut to controller.detectorIn;
        connection controllerResultOut connect controller.resultOut to resultOutput;

        action def AssaySequence {
            in item sample : BiologicalSample;
            in item reagent : Reagent;
            out item result : AssayResult;
            out item waste : WasteFluid;
        }

        perform action assaySequence : AssaySequence {
            in item sample = sampleInput.sample;
            in item reagent = reagentInput.reagent;
            out item result = resultOutput.result;
            out item waste = wastePort.inlet.waste;
        }
    }

    // ===== Requirements =====
    requirement def RapidAnalysisRequirement {
        attribute maxDuration : Duration = 15.0;
        subject : BiochipAnalysisSystem;
        objective {
            doc "The system shall complete a single analysis in under 15 minutes."
        }
        require subject.maxAnalysisTime <= maxDuration;
    }

    requirement def SensitivityRequirement {
        attribute minDetectableConcentration : Threshold = 0.1;
        subject : OpticalDetector;
        objective {
            doc "The detector shall identify analyte concentrations as low as 0.1 µg/mL."
        }
        require subject.detectionThreshold <= minDetectableConcentration;
    }

    requirement def TemperatureStabilityRequirement {
        attribute setPoint : Temperature = 310.15;
        attribute tolerance : Temperature = 0.5;
        subject : TemperatureController;
        objective {
            doc "The temperature controller shall maintain the chamber at 37°C ± 0.5 K."
        }
        require subject.tolerance <= tolerance;
    }

    requirement def ResultStructureRequirement {
        subject : AssayResult;
        objective {
            doc "Each assay result shall contain sample ID, measured concentration, signal strength, and determination."
        }
        require subject.sampleId.isDefined and
                subject.measuredConcentration.isDefined and
                subject.signalStrength.isDefined and
                subject.determination.isDefined;
    }

    requirement def StateSequenceRequirement {
        subject : AnalysisStateMachine;
        objective {
            doc "The system shall progress through idle, ready, processing, analyzing, and complete states."
        }
        require subject.idle.isDefined and
                subject.ready.isDefined and
                subject.processing.isDefined and
                subject.analyzing.isDefined and
                subject.complete.isDefined;
    }

    requirement def WasteManagementRequirement {
        subject : BiochipAnalysisSystem;
        objective {
            doc "Used fluids shall be directed to a waste port after analysis."
        }
        require subject.wastePort.isDefined;
    }

    // ===== Requirement Satisfaction =====
    satisfaction satisfy RapidAnalysisRequirement by BiochipAnalysisSystem;
    satisfaction satisfy SensitivityRequirement by OpticalDetector;
    satisfaction satisfy TemperatureStabilityRequirement by TemperatureController;
    satisfaction satisfy ResultStructureRequirement by AssayResult;
    satisfaction satisfy StateSequenceRequirement by AnalysisStateMachine;
    satisfaction satisfy WasteManagementRequirement by BiochipAnalysisSystem;
}
