package MicrofluidicLabOnChip {
  import ISQ::*;
  
  item def Liquid;
  item def Sample :> Liquid;
  item def Reagent :> Liquid;
  item def Buffer :> Liquid;
  item def Mixture :> Liquid;
  item def Signal;
  
  attribute def Volume :> Real { unit "uL"; }
  attribute def FlowRate :> Real { unit "uL/min"; }
  attribute def Temperature :> Real { unit "degC"; }
  attribute def Duration :> Real { unit "s"; }
  attribute def Absorbance :> Real { unit "AU"; }
  attribute def Wavelength :> Real { unit "nm"; }
  
  port def FluidInPort {
    in item Liquid;
  }
  
  port def FluidOutPort {
    out item Liquid;
  }
  
  port def SignalPort {
    item Signal;
  }
  
  part def Reservoir {
    out fluidOut : FluidOutPort;
    attribute capacity : Volume;
    attribute currentVolume : Volume;
  }
  
  part def WasteReservoir {
    in fluidIn : FluidInPort;
    attribute capacity : Volume;
  }
  
  part def Micropump {
    in fluidIn : FluidInPort;
    out fluidOut : FluidOutPort;
    in cmdIn : SignalPort;
    attribute maxFlowRate : FlowRate;
  }
  
  part def Microvalve {
    in fluidIn : FluidInPort;
    out fluidOut : FluidOutPort;
    in cmdIn : SignalPort;
    attribute isOpen : Boolean;
  }
  
  part def MixingChamber {
    in fluidIn1 : FluidInPort;
    in fluidIn2 : FluidInPort;
    in fluidIn3 : FluidInPort;
    out fluidOut : FluidOutPort;
    attribute volume : Volume;
  }
  
  part def IncubationZone {
    in fluidIn : FluidInPort;
    out fluidOut : FluidOutPort;
    in cmdIn : SignalPort;
    attribute targetTemp : Temperature;
  }
  
  part def OpticalDetector {
    in fluidIn : FluidInPort;
    out fluidOut : FluidOutPort;
    in cmdIn : SignalPort;
    out dataOut : SignalPort;
    attribute wavelength : Wavelength;
    attribute absorbance : Absorbance;
  }
  
  part def FlowSensor {
    in fluidIn : FluidInPort;
    out fluidOut : FluidOutPort;
    out dataOut : SignalPort;
    attribute measuredFlowRate : FlowRate;
  }
  
  state def ControlStates {
    entry; then Idle;
    
    state Operating {
      state Idle;
      state Initializing;
      state Loading;
      state Mixing;
      state Incubating;
      state Analyzing;
      state Cleaning;
      
      transition Idle -> Initializing when startRequested;
      transition Initializing -> Loading after 10 [s];
      transition Loading -> Mixing after 15 [s];
      transition Mixing -> Incubating after 30 [s];
      transition Incubating -> Analyzing after 120 [s];
      transition Analyzing -> Cleaning after 10 [s];
      transition Cleaning -> Idle after 20 [s];
    }
    
    state EmergencyShutdown;
    
    transition Operating -> EmergencyShutdown when emergencyRequested;
    transition EmergencyShutdown -> Operating.Idle after 5 [s];
  }
  
  part def Controller {
    out pumpCmd : SignalPort[3];
    out valveCmd : SignalPort[3];
    out tempCmd : SignalPort;
    out detectorCmd : SignalPort;
    in sensorData : SignalPort[3];
    in detectorData : SignalPort;
    
    attribute startRequested : Boolean;
    attribute emergencyRequested : Boolean;
    
    exhibit state behavior : ControlStates;
  }
  
  part def MicrofluidicChip {
    part sampleReservoir : Reservoir {
      attribute capacity = 100 [uL];
    }
    part reagentReservoir : Reservoir {
      attribute capacity = 100 [uL];
    }
    part bufferReservoir : Reservoir {
      attribute capacity = 200 [uL];
    }
    part wasteReservoir : WasteReservoir {
      attribute capacity = 500 [uL];
    }
    
    part samplePump : Micropump;
    part reagentPump : Micropump;
    part bufferPump : Micropump;
    
    part valve1 : Microvalve;
    part valve2 : Microvalve;
    part valve3 : Microvalve;
    
    part mixer : MixingChamber;
    part incubator : IncubationZone;
    part detector : OpticalDetector;
    
    part flowSensor1 : FlowSensor;
    part flowSensor2 : FlowSensor;
    part flowSensor3 : FlowSensor;
    
    part controller : Controller;
    
    connect sampleReservoir.fluidOut to samplePump.fluidIn;
    connect reagentReservoir.fluidOut to reagentPump.fluidIn;
    connect bufferReservoir.fluidOut to bufferPump.fluidIn;
    
    connect samplePump.fluidOut to valve1.fluidIn;
    connect reagentPump.fluidOut to valve2.fluidIn;
    connect bufferPump.fluidOut to valve3.fluidIn;
    
    connect valve1.fluidOut to flowSensor1.fluidIn;
    connect valve2.fluidOut to flowSensor2.fluidIn;
    connect valve3.fluidOut to flowSensor3.fluidIn;
    
    connect flowSensor1.fluidOut to mixer.fluidIn1;
    connect flowSensor2.fluidOut to mixer.fluidIn2;
    connect flowSensor3.fluidOut to mixer.fluidIn3;
    
    connect mixer.fluidOut to incubator.fluidIn;
    connect incubator.fluidOut to detector.fluidIn;
    connect detector.fluidOut to wasteReservoir.fluidIn;
    
    connect controller.pumpCmd[1] to samplePump.cmdIn;
    connect controller.pumpCmd[2] to reagentPump.cmdIn;
    connect controller.pumpCmd[3] to bufferPump.cmdIn;
    
    connect controller.valveCmd[1] to valve1.cmdIn;
    connect controller.valveCmd[2] to valve2.cmdIn;
    connect controller.valveCmd[3] to valve3.cmdIn;
    
    connect controller.tempCmd to incubator.cmdIn;
    connect controller.detectorCmd to detector.cmdIn;
    
    connect flowSensor1.dataOut to controller.sensorData[1];
    connect flowSensor2.dataOut to controller.sensorData[2];
    connect flowSensor3.dataOut to controller.sensorData[3];
    connect detector.dataOut to controller.detectorData;
  }
  
  requirement def AutomatedAnalysisReq {
    subject chip : MicrofluidicChip;
    objective {
      doc "The system shall perform automated biochemical analysis on small liquid samples."
    }
  }
  
  requirement def HighThroughputReq {
    subject chip : MicrofluidicChip;
    attribute maxDuration : Duration = 300 [s];
    objective {
      doc "The system shall complete a full analysis cycle within maxDuration."
    }
  }
  
  requirement def EmergencyShutdownReq {
    subject chip : MicrofluidicChip;
    objective {
      doc "The system shall include an emergency shutdown capability."
    }
  }
  
  requirement def CleaningCycleReq {
    subject chip : MicrofluidicChip;
    objective {
      doc "The system shall perform a cleaning cycle using buffer solution after analysis."
    }
  }
}
