package SoundLocatorSystem {

  import ScalarValues::*;

  package Common {

    package Units {
      attribute def second;
      attribute def metre;
      attribute def volt;
      attribute def degree;
      attribute def decibel;
      attribute def hertz;
      attribute def watt;
      attribute def ampere;
    }

    attribute def Time :> Real { unit = Units::second; }
    attribute def Distance :> Real { unit = Units::metre; }
    attribute def Voltage :> Real { unit = Units::volt; }
    attribute def Angle :> Real { unit = Units::degree; }
    attribute def Intensity :> Real { unit = Units::decibel; }
    attribute def Frequency :> Real { unit = Units::hertz; }
    attribute def Power :> Real { unit = Units::watt; }
    attribute def Current :> Real { unit = Units::ampere; }
    attribute def Confidence :> Real { min = 0; max = 1; }

    attribute def Position {
      attribute x : Distance;
      attribute y : Distance;
      attribute z : Distance;
    }
  }

  package Items {
    import Common::*;

    item def AcousticWave {
      attribute frequency : Frequency;
      attribute intensity : Intensity;
      attribute timestamp : Time;
    }

    item def ElectricalSignal {
      attribute voltage : Voltage;
      attribute timestamp : Time;
      attribute channel : Integer;
    }

    item def DigitalSample {
      attribute value : Real;
      attribute timestamp : Time;
      attribute channel : Integer;
    }

    item def TimeDelay {
      attribute delay : Time;
      attribute refChannel : Integer;
      attribute measChannel : Integer;
    }

    item def SoundLocation {
      attribute azimuth : Angle;
      attribute elevation : Angle;
      attribute distance : Distance;
      attribute intensity : Intensity;
      attribute confidence : Confidence;
      attribute timestamp : Time;
    }

    item def DisplayCommand {
      attribute location : SoundLocation;
      attribute mode : String;
    }

    item def PowerFlow {
      attribute voltage : Voltage;
      attribute current : Current;
    }
  }

  package Ports {
    import Items::*;

    port def AcousticInPort {
      in item wave : AcousticWave;
    }

    port def AnalogOutPort {
      out item signal : ElectricalSignal;
    }

    port def AnalogInPort {
      in item signal : ElectricalSignal;
    }

    port def DigitalOutPort {
      out item sample : DigitalSample;
    }

    port def DigitalInPort {
      in item sample : DigitalSample;
    }

    port def LocationOutPort {
      out item location : SoundLocation;
    }

    port def LocationInPort {
      in item location : SoundLocation;
    }

    port def DisplayCmdInPort {
      in item command : DisplayCommand;
    }

    port def PowerOutPort {
      out item power : PowerFlow;
    }

    port def PowerInPort {
      in item power : PowerFlow;
    }
  }

  package Parts {
    import Common::*;
    import Items::*;
    import Ports::*;

    part def Microphone {
      attribute id : Integer;
      attribute position : Position;
      attribute sensitivity : Real;
      port acousticIn : AcousticInPort;
      port analogOut : AnalogOutPort;
      port powerIn : PowerInPort;

      action def CaptureSound {
        in wave : AcousticWave;
        out signal : ElectricalSignal;
      }
    }

    part def MicrophoneArray {
      attribute spacing : Distance;
      attribute arrayGeometry : String;

      part mic1 : Microphone {
        attribute id = 1;
        attribute position.x = -0.1;
        attribute position.y = -0.1;
        attribute position.z = 0;
      }
      part mic2 : Microphone {
        attribute id = 2;
        attribute position.x = 0.1;
        attribute position.y = -0.1;
        attribute position.z = 0;
      }
      part mic3 : Microphone {
        attribute id = 3;
        attribute position.x = 0.1;
        attribute position.y = 0.1;
        attribute position.z = 0;
      }
      part mic4 : Microphone {
        attribute id = 4;
        attribute position.x = -0.1;
        attribute position.y = 0.1;
        attribute position.z = 0;
      }

      port acousticInputs : AcousticInPort[4];
      port analogOutputs : AnalogOutPort[4];
      port powerInputs : PowerInPort[4];

      connect acousticInputs[1] to mic1.acousticIn;
      connect acousticInputs[2] to mic2.acousticIn;
      connect acousticInputs[3] to mic3.acousticIn;
      connect acousticInputs[4] to mic4.acousticIn;

      connect mic1.analogOut to analogOutputs[1];
      connect mic2.analogOut to analogOutputs[2];
      connect mic3.analogOut to analogOutputs[3];
      connect mic4.analogOut to analogOutputs[4];

      connect powerInputs[1] to mic1.powerIn;
      connect powerInputs[2] to mic2.powerIn;
      connect powerInputs[3] to mic3.powerIn;
      connect powerInputs[4] to mic4.powerIn;
    }

    part def SignalConditioner {
      attribute gain : Real;
      attribute lowCutoff : Frequency;
      attribute highCutoff : Frequency;
      attribute sampleRate : Frequency;

      port analogIn : AnalogInPort[4];
      port digitalOut : DigitalOutPort[4];
      port powerIn : PowerInPort;

      action def Amplify {
        in raw : ElectricalSignal;
        out amplified : ElectricalSignal;
      }

      action def Filter {
        in amplified : ElectricalSignal;
        out filtered : ElectricalSignal;
      }

      action def Digitize {
        in filtered : ElectricalSignal;
        out digital : DigitalSample;
      }

      action def ConditionChannel {
        in raw : ElectricalSignal;
        out digital : DigitalSample;
        attribute amplified : ElectricalSignal;
        attribute filtered : ElectricalSignal;
        perform Amplify(in raw, out amplified);
        perform Filter(in amplified, out filtered);
        perform Digitize(in filtered, out digital);
      }

      action def ConditionAll {
        in rawSignals : ElectricalSignal[4];
        out digitalSamples : DigitalSample[4];
        perform ConditionChannel;
      }

      state def ConditioningStates {
        state Idle;
        state Active;
        transition Idle to Active when analogIn.signal->notEmpty();
        transition Active to Idle when analogIn.signal->isEmpty();
      }
    }

    part def DSP {
      attribute sampleRate : Frequency;
      attribute confidenceThreshold : Confidence;
      attribute arrayGeometry : Position[4];

      port digitalIn : DigitalInPort[4];
      port locationOut : LocationOutPort;
      port powerIn : PowerInPort;

      action def ComputeTDOA {
        in samples : DigitalSample[4];
        out delays : TimeDelay[3];
      }

      action def Triangulate {
        in delays : TimeDelay[3];
        in geometry : Position[4];
        out location : SoundLocation;
      }

      action def Validate {
        in location : SoundLocation;
        in threshold : Confidence;
        out valid : Boolean;
      }

      action def ProcessSound {
        in samples : DigitalSample[4];
        out location : SoundLocation;
        attribute delays : TimeDelay[3];
        attribute isValid : Boolean;
        perform ComputeTDOA(in samples, out delays);
        perform Triangulate(in delays, in arrayGeometry, out location);
        perform Validate(in location, in confidenceThreshold, out isValid);
      }

      state def ProcessingStates {
        state Idle;
        state Listening;
        state Computing;
        state Validating;
        transition Idle to Listening when powerIn.power->notEmpty();
        transition Listening to Computing when digitalIn.sample->notEmpty();
        transition Computing to Validating;
        transition Validating to Listening;
      }
    }

    part def DisplayUnit {
      attribute displayType : String;
      attribute resolution : Integer;
      attribute refreshRate : Frequency;

      port locationIn : LocationInPort;
      port displayCmdIn : DisplayCmdInPort;
      port powerIn : PowerInPort;

      action def Render {
        in location : SoundLocation;
      }

      action def UpdateDisplay {
        in command : DisplayCommand;
        perform Render(in command.location);
      }

      state def DisplayStates {
        state Blank;
        state Showing;
        transition Blank to Showing when locationIn.location->notEmpty();
        transition Showing to Blank when locationIn.location->isEmpty();
      }
    }

    part def PowerSupply {
      attribute outputVoltage : Voltage;
      attribute maxCurrent : Current;
      attribute efficiency : Real;

      port powerIn : PowerInPort;
      port powerOut : PowerOutPort;

      action def Regulate {
        in rawPower : PowerFlow;
        out regulatedPower : PowerFlow;
      }

      state def PowerStates {
        state Off;
        state On;
        transition Off to On when powerIn.power->notEmpty();
      }
    }
  }

  part def SoundLocator {
    import Parts::*;

    attribute systemId : String;
    attribute maxRange : Distance;

    port acousticInputs : AcousticInPort[4];
    port externalPower : PowerInPort;

    part microphoneArray : MicrophoneArray {
      attribute spacing = 0.2;
      attribute arrayGeometry = "square";
    }

    part signalConditioner : SignalConditioner {
      attribute gain = 100;
      attribute lowCutoff = 20;
      attribute highCutoff = 20000;
      attribute sampleRate = 48000;
    }

    part dsp : DSP {
      attribute sampleRate = 48000;
      attribute confidenceThreshold = 0.7;
      attribute arrayGeometry = (
        microphoneArray.mic1.position,
        microphoneArray.mic2.position,
        microphoneArray.mic3.position,
        microphoneArray.mic4.position
      );
    }

    part display : DisplayUnit {
      attribute displayType = "LED matrix";
      attribute resolution = 64;
      attribute refreshRate = 60;
    }

    part powerSupply : PowerSupply {
      attribute outputVoltage = 12;
      attribute maxCurrent = 5;
      attribute efficiency = 0.9;
    }

    connect externalPower to powerSupply.powerIn;
    connect powerSupply.powerOut to microphoneArray.powerInputs;
    connect powerSupply.powerOut to signalConditioner.powerIn;
    connect powerSupply.powerOut to dsp.powerIn;
    connect powerSupply.powerOut to display.powerIn;

    connect acousticInputs to microphoneArray.acousticInputs;
    connect microphoneArray.analogOutputs to signalConditioner.analogIn;
    connect signalConditioner.digitalOut to dsp.digitalIn;
    connect dsp.locationOut to display.locationIn;

    state def SystemOperation {
      state PoweredOff;
      state Initializing;
      state Listening;
      state Processing;
      state Displaying;

      transition PoweredOff to Initializing when externalPower.power->notEmpty();
      transition Initializing to Listening;
      transition Listening to Processing when acousticInputs.wave->notEmpty();
      transition Processing to Displaying;
      transition Displaying to Listening;
    }

    stateMachine : SystemOperation;
  }

  package Requirements {
    import Common::*;
    import Items::*;

    requirement def AcousticDetectionRequirement {
      attribute id = "REQ-001";
      attribute text = "The system shall detect and pinpoint the three-dimensional position of an acoustic source using Time Difference of Arrival.";
      attribute technique = "TDOA";
    }

    requirement def MicrophoneArrayRequirement {
      attribute id = "REQ-002";
      attribute text = "The system shall use a microphone array of four individual microphones in a known spatial configuration.";
      attribute minMicrophones = 4;
    }

    requirement def SignalConditioningRequirement {
      attribute id = "REQ-003";
      attribute text = "The signal conditioner shall amplify raw signals and filter out unwanted background noise.";
      attribute minGain : Real = 50;
      attribute lowCutoff : Frequency = 20;
      attribute highCutoff : Frequency = 20000;
    }

    requirement def TDOAProcessingRequirement {
      attribute id = "REQ-004";
      attribute text = "The DSP shall calculate time delays between microphone signals and triangulate the sound origin.";
      attribute maxProcessingTime : Time = 0.05;
    }

    requirement def LocationOutputRequirement {
      attribute id = "REQ-005";
      attribute text = "The system shall determine azimuth, elevation, distance, and intensity of the sound source.";
    }

    requirement def ConfidenceValidationRequirement {
      attribute id = "REQ-006";
      attribute text = "Location data shall be validated for confidence before being passed to the display.";
      attribute minConfidence : Confidence = 0.7;
    }

    requirement def DisplayRequirement {
      attribute id = "REQ-007";
      attribute text = "The display unit shall provide a visual representation of the sound source location.";
      attribute minRefreshRate : Frequency = 30;
    }

    requirement def RealTimeRequirement {
      attribute id = "REQ-008";
      attribute text = "The system shall continuously listen and update the display in real-time.";
      attribute maxLatency : Time = 0.1;
    }

    requirement def PowerSupplyRequirement {
      attribute id = "REQ-009";
      attribute text = "A dedicated power supply shall provide regulated electrical power to all components.";
      attribute outputVoltage : Voltage = 12;
    }

    requirement AcousticDetection : AcousticDetectionRequirement;
    requirement MicrophoneArray : MicrophoneArrayRequirement;
    requirement SignalConditioning : SignalConditioningRequirement;
    requirement TDOAProcessing : TDOAProcessingRequirement;
    requirement LocationOutput : LocationOutputRequirement;
    requirement ConfidenceValidation : ConfidenceValidationRequirement;
    requirement Display : DisplayRequirement;
    requirement RealTime : RealTimeRequirement;
    requirement Power : PowerSupplyRequirement;

    satisfaction AcousticDetection by SoundLocator;
    satisfaction MicrophoneArray by SoundLocator::microphoneArray;
    satisfaction SignalConditioning by SoundLocator::signalConditioner;
    satisfaction TDOAProcessing by SoundLocator::dsp;
    satisfaction LocationOutput by SoundLocator::dsp;
    satisfaction ConfidenceValidation by SoundLocator::dsp;
    satisfaction Display by SoundLocator::display;
    satisfaction RealTime by SoundLocator;
    satisfaction Power by SoundLocator::powerSupply;
  }
}
