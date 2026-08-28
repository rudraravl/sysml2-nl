package SoundLocatorSystem {
    private import ISQ::*;
    private import ScalarValues::*;
    private import Time::*;
    private import ISQ::Position3dVector;

    item def AcousticWave {
        attribute frequency : FrequencyValue;
        attribute intensity : PowerValue;
    }

    item def AnalogAudio {
        attribute amplitude : ElectricPotentialValue;
        attribute timestamp : TimeInstantValue;
    }

    item def DigitalAudio {
        attribute samples : Real[*];
        attribute timestamp : TimeInstantValue;
        attribute sampleRate : FrequencyValue;
    }

    item def TDOAResult {
        attribute delay12 : TimeValue;
        attribute delay13 : TimeValue;
        attribute delay14 : TimeValue;
        attribute delay23 : TimeValue;
        attribute delay24 : TimeValue;
        attribute delay34 : TimeValue;
    }

    item def SoundLocation {
        attribute azimuth : PlaneAngleValue;
        attribute elevation : PlaneAngleValue;
        attribute distance : LengthValue;
        attribute intensity : PowerValue;
        attribute confidence : Real;
    }

    port def AcousticPort { out item wave : AcousticWave; }
    port def AnalogOutPort { out item audio : AnalogAudio; }
    port def AnalogInPort { in item audio : AnalogAudio; }
    port def DigitalOutPort { out item audio : DigitalAudio; }
    port def DigitalInPort { in item audio : DigitalAudio; }
    port def LocationOutPort { out item location : SoundLocation; }
    port def LocationInPort { in item location : SoundLocation; }
    port def PowerOutPort { out item voltage : ElectricPotentialValue; }
    port def PowerInPort { in item voltage : ElectricPotentialValue; }

    action def CalculateTDOA {
        in signals : DigitalAudio[4];
        out tdoa : TDOAResult;
    }

    action def Triangulate {
        in tdoa : TDOAResult;
        in micPositions : Position3dVector[4];
        in speedOfSound : SpeedValue;
        out location : SoundLocation;
    }

    action def ValidateConfidence {
        in location : SoundLocation;
        out validated : SoundLocation;
    }

    action def ProcessAcousticEvent {
        in signals : DigitalAudio[4];
        in micPositions : Position3dVector[4];
        in speedOfSound : SpeedValue;
        out result : SoundLocation;
        action calc : CalculateTDOA {
            in signals = signals;
            out tdoa;
        }
        then action tri : Triangulate {
            in tdoa = calc.tdoa;
            in micPositions = micPositions;
            in speedOfSound = speedOfSound;
            out location;
        }
        then action val : ValidateConfidence {
            in location = tri.location;
            out validated;
        }
        then assign result := val.validated;
    }

    part def Microphone {
        attribute position : Position3dVector;
        port acousticIn : AcousticPort;
        port analogOut : AnalogOutPort;
        port powerIn : PowerInPort;
    }

    part def MicrophoneArray {
        attribute micPositions : Position3dVector[4];
        part mic1 : Microphone { attribute :>> position = micPositions[1]; }
        part mic2 : Microphone { attribute :>> position = micPositions[2]; }
        part mic3 : Microphone { attribute :>> position = micPositions[3]; }
        part mic4 : Microphone { attribute :>> position = micPositions[4]; }
        port powerIn : PowerInPort;
        connect powerIn to mic1.powerIn;
        connect powerIn to mic2.powerIn;
        connect powerIn to mic3.powerIn;
        connect powerIn to mic4.powerIn;
    }

    part def SignalConditioner {
        attribute gain : Real default 10.0;
        attribute noiseThreshold : PowerValue default 1e-6 [W];
        port analogIn1 : AnalogInPort;
        port analogIn2 : AnalogInPort;
        port analogIn3 : AnalogInPort;
        port analogIn4 : AnalogInPort;
        port digitalOut1 : DigitalOutPort;
        port digitalOut2 : DigitalOutPort;
        port digitalOut3 : DigitalOutPort;
        port digitalOut4 : DigitalOutPort;
        port powerIn : PowerInPort;
        action condition {
            in analog : AnalogAudio[4];
            out digital : DigitalAudio[4];
        }
    }

    part def DSP {
        attribute micPositions : Position3dVector[4];
        attribute speedOfSound : SpeedValue default 343.0 [m/s];
        port digitalIn1 : DigitalInPort;
        port digitalIn2 : DigitalInPort;
        port digitalIn3 : DigitalInPort;
        port digitalIn4 : DigitalInPort;
        port locationOut : LocationOutPort;
        port powerIn : PowerInPort;
        action processSound {
            in signals : DigitalAudio[4];
            out location : SoundLocation;
            action proc : ProcessAcousticEvent {
                in signals = signals;
                in micPositions = micPositions;
                in speedOfSound = speedOfSound;
                out result;
            }
            then assign location := proc.result;
        }
    }

    part def DisplayUnit {
        port locationIn : LocationInPort;
        port powerIn : PowerInPort;
        action display {
            in location : SoundLocation;
        }
    }

    part def PowerSupply {
        attribute outputVoltage : ElectricPotentialValue default 5.0 [V];
        port powerOut1 : PowerOutPort;
        port powerOut2 : PowerOutPort;
        port powerOut3 : PowerOutPort;
        port powerOut4 : PowerOutPort;
    }

    part def SoundLocator {
        attribute micPositions : Position3dVector[4];
        part microphoneArray : MicrophoneArray {
            attribute :>> micPositions = micPositions;
        }
        part signalConditioner : SignalConditioner;
        part dsp : DSP {
            attribute :>> micPositions = micPositions;
        }
        part displayUnit : DisplayUnit;
        part powerSupply : PowerSupply;

        connect microphoneArray.mic1.analogOut to signalConditioner.analogIn1;
        connect microphoneArray.mic2.analogOut to signalConditioner.analogIn2;
        connect microphoneArray.mic3.analogOut to signalConditioner.analogIn3;
        connect microphoneArray.mic4.analogOut to signalConditioner.analogIn4;

        connect signalConditioner.digitalOut1 to dsp.digitalIn1;
        connect signalConditioner.digitalOut2 to dsp.digitalIn2;
        connect signalConditioner.digitalOut3 to dsp.digitalIn3;
        connect signalConditioner.digitalOut4 to dsp.digitalIn4;

        connect dsp.locationOut to displayUnit.locationIn;

        connect powerSupply.powerOut1 to microphoneArray.powerIn;
        connect powerSupply.powerOut2 to signalConditioner.powerIn;
        connect powerSupply.powerOut3 to dsp.powerIn;
        connect powerSupply.powerOut4 to displayUnit.powerIn;

        event powerOn;
        event soundDetected;
        event locationComputed;
        event displayUpdated;
        event powerOff;

        state machine locatorStateMachine {
            state Idle;
            state Listening;
            state Processing;
            state Displaying;

            transition from Idle to Listening accept powerOn;
            transition from Listening to Processing accept soundDetected;
            transition from Processing to Displaying accept locationComputed;
            transition from Displaying to Listening accept displayUpdated;
            transition from Displaying to Idle accept powerOff;
        }
    }

    requirement def SoundLocatorRequirements {
        requirement TDOA_Detection {
            doc /* The system shall detect acoustic events using time differences of arrival across four microphones. */
        }
        requirement RealTime_Update {
            doc /* The system shall update the display in real-time with latency under 100 ms. */
            attribute maxLatency : TimeValue default 100 [ms];
        }
        requirement Localization_Accuracy {
            doc /* The system shall localize the sound source with angular accuracy within 5 degrees and distance accuracy within 0.5 m. */
            attribute angularAccuracy : PlaneAngleValue default 5 [deg];
            attribute distanceAccuracy : LengthValue default 0.5 [m];
        }
        requirement Noise_Filtering {
            doc /* The signal conditioner shall filter background noise before digital conversion. */
        }
        requirement Power_Distribution {
            doc /* The power supply shall provide regulated voltage to all components. */
        }
    }

    requirement req : SoundLocatorRequirements {
        subject locator : SoundLocator;
    }
}
