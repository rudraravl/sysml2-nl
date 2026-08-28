package LabOnChipSystem {
    import ScalarValues::*;
    
    // --- Units and Value Types ---
    unit def uL;
    unit def degC;
    unit def mgPerDL;
    unit def s;
    unit def cd;
    
    value def Volume :> Real { unit :> uL; }
    value def Temperature :> Real { unit :> degC; }
    value def Concentration :> Real { unit :> mgPerDL; }
    value def TimeDuration :> Real { unit :> s; }
    value def LightIntensity :> Real { unit :> cd; }
    
    // --- Items ---
    item def BiologicalSample;
    item def Reagent;
    item def FluidMixture;
    item def WasteFluid;
    item def OpticalSignal;
    
    // --- Ports ---
    port def FluidOutPort { out item fluid; }
    port def FluidInPort { in item fluid; }
    port def ControlPort { in attribute command; out attribute status; }
    port def DataOutPort { out attribute data; }
    port def DataInPort { in attribute data; }
    
    // --- Components ---
    part def Reservoir {
        attribute capacity : Volume;
        port fluidOut : FluidOutPort;
        port fluidIn : FluidInPort;
    }
    
    part def Pump {
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port control : ControlPort;
        attribute flowRate : Volume;
        
        action def PumpFluid {
            in volume : Volume;
        }
    }
    
    part def Channel {
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
    }
    
    part def Mixer {
        port fluidIn1 : FluidInPort;
        port fluidIn2 : FluidInPort;
        port fluidIn3 : FluidInPort;
        port fluidOut : FluidOutPort;
        port control : ControlPort;
        
        action def Mix {
            in duration : TimeDuration;
        }
    }
    
    part def Incubator {
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port control : ControlPort;
        attribute targetTemp : Temperature;
        attribute incubationTime : TimeDuration;
        
        action def Incubate {
            in temp : Temperature;
            in duration : TimeDuration;
        }
    }
    
    part def OpticalDetector {
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port dataOut : DataOutPort;
        port control : ControlPort;
        attribute wavelength : Real;
        
        action def Measure {
            out signal : OpticalSignal;
        }
    }
    
    part def Microcontroller {
        port pump1Control : ControlPort;
        port pump2Control : ControlPort;
        port pump3Control : ControlPort;
        port mixerControl : ControlPort;
        port incubatorControl : ControlPort;
        port detectorControl : ControlPort;
        port detectorData : DataInPort;
        port userInterface : DataOutPort;
        
        attribute result : Concentration;
        attribute status : String;
        
        state machine ControlStateMachine {
            state idle;
            state mixing;
            state incubating;
            state measuring;
            state complete;
            state error;
            
            transition idle_to_mixing from idle to mixing if (startTest);
            transition mixing_to_incubating from mixing to incubating if (mixingDone);
            transition incubating_to_measuring from incubating to measuring if (incubationDone);
            transition measuring_to_complete from measuring to complete if (measurementDone);
            transition any_to_error from idle, mixing, incubating, measuring to error if (errorDetected);
        }
    }
    
    // --- System ---
    part def LabOnChipDevice {
        part sampleReservoir : Reservoir {
            item storedSample : BiologicalSample;
        }
        part reagentReservoir1 : Reservoir {
            item storedReagent1 : Reagent;
        }
        part reagentReservoir2 : Reservoir {
            item storedReagent2 : Reagent;
        }
        part wasteReservoir : Reservoir {
            item storedWaste : WasteFluid;
        }
        
        part samplePump : Pump;
        part reagentPump1 : Pump;
        part reagentPump2 : Pump;
        
        part channel1 : Channel;
        part channel2 : Channel;
        part channel3 : Channel;
        part channel4 : Channel;
        part channel5 : Channel;
        
        part mixer : Mixer;
        part incubator : Incubator;
        part detector : OpticalDetector;
        part controller : Microcontroller;
        
        connect sampleReservoir.fluidOut to samplePump.fluidIn;
        connect reagentReservoir1.fluidOut to reagentPump1.fluidIn;
        connect reagentReservoir2.fluidOut to reagentPump2.fluidIn;
        
        connect samplePump.fluidOut to channel1.fluidIn;
        connect reagentPump1.fluidOut to channel2.fluidIn;
        connect reagentPump2.fluidOut to channel3.fluidIn;
        
        connect channel1.fluidOut to mixer.fluidIn1;
        connect channel2.fluidOut to mixer.fluidIn2;
        connect channel3.fluidOut to mixer.fluidIn3;
        
        connect mixer.fluidOut to channel4.fluidIn;
        connect channel4.fluidOut to incubator.fluidIn;
        
        connect incubator.fluidOut to detector.fluidIn;
        connect detector.fluidOut to channel5.fluidIn;
        connect channel5.fluidOut to wasteReservoir.fluidIn;
        
        connect controller.pump1Control to samplePump.control;
        connect controller.pump2Control to reagentPump1.control;
        connect controller.pump3Control to reagentPump2.control;
        connect controller.mixerControl to mixer.control;
        connect controller.incubatorControl to incubator.control;
        connect controller.detectorControl to detector.control;
        connect detector.dataOut to controller.detectorData;
    }
    
    // --- Requirements ---
    requirement def DiagnosticTestRequirement {
        doc /* The LOC device shall perform an automated diagnostic test. */
        subject loc : LabOnChipDevice;
        
        requirement def MeasureBiomarker {
            doc /* The LOC device shall measure the concentration of a specific biomarker. */
            subject loc : LabOnChipDevice;
            attribute targetBiomarker : String;
            attribute concentration : Concentration;
        }
        
        requirement def ManageProcess {
            doc /* The LOC device shall manage the process automatically via an onboard microcontroller. */
            subject loc : LabOnChipDevice;
        }
        
        requirement def ContainWaste {
            doc /* The LOC device shall direct used fluids into an internal waste reservoir. */
            subject loc : LabOnChipDevice;
        }
    }
}
