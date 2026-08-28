package MicrofluidicLabOnChip {
    private import ScalarValues::*;
    
    attribute def Volume :> Real;
    attribute def FlowRate :> Real;
    attribute def Temperature :> Real;
    attribute def Duration :> Real;
    attribute def Absorbance :> Real;
    attribute def Wavelength :> Real;
    
    item def Fluid;
    item def Sample :> Fluid;
    item def Reagent :> Fluid;
    item def Buffer :> Fluid;
    item def Mixture :> Fluid;
    
    attribute def StartSignal;
    attribute def LoadComplete;
    attribute def MixComplete;
    attribute def IncubationComplete;
    attribute def AnalysisComplete;
    attribute def CleanComplete;
    attribute def EmergencyStop;
    
    port def FluidPort {
        inout fluid : Fluid;
    }
    
    port def ControlPort {
        in command : String;
        out status : String;
    }
    
    part def FluidReservoir {
        port fluidOut : FluidPort;
        attribute capacity : Volume;
        attribute currentVolume : Volume;
    }
    
    part def WasteReservoir {
        port fluidIn : FluidPort;
        attribute capacity : Volume;
    }
    
    part def MicroPump {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port control : ControlPort;
        attribute flowRate : FlowRate;
    }
    
    part def MicroValve {
        port fluidIn1 : FluidPort;
        port fluidIn2 : FluidPort;
        port fluidOut : FluidPort;
        port control : ControlPort;
        attribute isOpen : Boolean;
    }
    
    part def MixingChamber {
        port fluidIn1 : FluidPort;
        port fluidIn2 : FluidPort;
        port fluidOut : FluidPort;
        attribute volume : Volume;
    }
    
    part def TemperatureController {
        port control : ControlPort;
        attribute targetTemp : Temperature;
        attribute currentTemp : Temperature;
    }
    
    part def OpticalDetector {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port control : ControlPort;
        attribute wavelength : Wavelength;
        attribute absorbance : Absorbance;
    }
    
    part def FlowSensor {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port control : ControlPort;
        attribute measuredFlowRate : FlowRate;
    }
    
    action def PrimeChannels;
    action def LoadSampleAndReagents;
    action def MixFluids;
    action def IncubateMixture;
    action def AnalyzeFluid;
    action def CleanChannels;
    
    part def MicrofluidicChip {
        port controlPort : ControlPort;
        
        part sampleReservoir : FluidReservoir {
            attribute capacity = 100;
        }
        part reagentReservoir : FluidReservoir {
            attribute capacity = 50;
        }
        part bufferReservoir : FluidReservoir {
            attribute capacity = 200;
        }
        part wasteReservoir : WasteReservoir {
            attribute capacity = 500;
        }
        
        part samplePump : MicroPump;
        part reagentPump : MicroPump;
        part bufferPump : MicroPump;
        
        part valve1 : MicroValve;
        part valve2 : MicroValve;
        
        part mixer : MixingChamber;
        part incubator : TemperatureController;
        part detector : OpticalDetector;
        part flowSensor1 : FlowSensor;
        part flowSensor2 : FlowSensor;
        
        connect sampleReservoir.fluidOut to samplePump.fluidIn;
        connect reagentReservoir.fluidOut to reagentPump.fluidIn;
        connect bufferReservoir.fluidOut to bufferPump.fluidIn;
        
        connect samplePump.fluidOut to flowSensor1.fluidIn;
        connect flowSensor1.fluidOut to mixer.fluidIn1;
        
        connect reagentPump.fluidOut to mixer.fluidIn2;
        
        connect mixer.fluidOut to valve1.fluidIn1;
        connect bufferPump.fluidOut to valve1.fluidIn2;
        
        connect valve1.fluidOut to flowSensor2.fluidIn;
        connect flowSensor2.fluidOut to detector.fluidIn;
        connect detector.fluidOut to wasteReservoir.fluidIn;
        
        attribute analysisDuration : Duration;
    }
    
    state def ChipOperation {
        entry; then Initializing;
        state Initializing {
            do action PrimeChannels;
        }
        transition init_to_loading 
            first Initializing 
            accept StartSignal 
            then Loading;
            
        state Loading {
            do action LoadSampleAndReagents;
        }
        transition load_to_mixing 
            first Loading 
            accept LoadComplete 
            then Mixing;
            
        state Mixing {
            do action MixFluids;
        }
        transition mix_to_incubating 
            first Mixing 
            accept MixComplete 
            then Incubating;
            
        state Incubating {
            do action IncubateMixture;
        }
        transition incub_to_analyzing 
            first Incubating 
            accept IncubationComplete 
            then Analyzing;
            
        state Analyzing {
            do action AnalyzeFluid;
        }
        transition analyze_to_cleaning 
            first Analyzing 
            accept AnalysisComplete 
            then Cleaning;
            
        state Cleaning {
            do action CleanChannels;
        }
        transition clean_to_ready 
            first Cleaning 
            accept CleanComplete 
            then Ready;
            
        state Ready;
        transition ready_to_init 
            first Ready 
            accept StartSignal 
            then Initializing;
        
        accept EmergencyStop then Shutdown;
        state Shutdown;
    }
    
    requirement def AnalysisTimeRequirement {
        doc /* The system shall complete a full analysis cycle within the maximum time. */
        subject chip : MicrofluidicChip;
        attribute maxTime : Duration = 5;
    }
    
    requirement def SafetyRequirement {
        doc /* The system shall enter the Shutdown state upon receiving an EmergencyStop signal. */
        subject chip : MicrofluidicChip;
    }
    
    requirement def PrecisionRequirement {
        doc /* The micropumps shall maintain flow rate accuracy within +/-2 percent of the setpoint. */
        subject pump : MicroPump;
        attribute flowAccuracy : Real = 0.02;
    }
    
    requirement def TemperatureStabilityRequirement {
        doc /* The incubation zone shall maintain temperature within +/-0.5 degrees of the target setpoint. */
        subject controller : TemperatureController;
        attribute tempTolerance : Temperature = 0.5;
    }
}
