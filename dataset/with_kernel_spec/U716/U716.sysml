package HydrophoneSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def PressureValue :> ScalarValues::Real;
    attribute def VoltageValue :> ScalarValues::Real;
    attribute def CurrentValue :> ScalarValues::Real;
    attribute def FrequencyValue :> ScalarValues::Real;
    attribute def PowerValue :> ScalarValues::Real;
    attribute def ChargeValue :> ScalarValues::Real;
    attribute def LengthValue :> ScalarValues::Real;
    attribute def MassValue :> ScalarValues::Real;
    attribute def DataSizeValue :> ScalarValues::Real;

    item def AcousticWave {
        attribute pressure : PressureValue;
        attribute frequency : FrequencyValue;
    }

    item def AnalogSignal {
        attribute voltage : VoltageValue;
        attribute frequency : FrequencyValue;
    }

    item def DigitalAudioStream {
        attribute sampleRate : FrequencyValue;
        attribute bitDepth : ScalarValues::Integer;
        attribute data : ScalarValues::String;
    }

    attribute def ActivationCmd;
    attribute def DeactivationCmd;
    attribute def DetectionEvent;
    attribute def RecordingComplete;

    action def IdleAction;
    action def MonitorAction;
    action def RecordAction;

    port def AcousticPort {
        in item wave : AcousticWave;
    }

    port def AnalogInPort {
        in item signal : AnalogSignal;
    }

    port def AnalogOutPort {
        out item signal : AnalogSignal;
    }

    port def DigitalInPort {
        in item stream : DigitalAudioStream;
    }

    port def DigitalOutPort {
        out item stream : DigitalAudioStream;
    }

    port def PowerInPort {
        in attribute voltage : VoltageValue;
        in attribute current : CurrentValue;
    }

    port def PowerOutPort {
        out attribute voltage : VoltageValue;
        out attribute current : CurrentValue;
    }

    part def TitaniumCasing {
        attribute material : ScalarValues::String := "Titanium Alloy";
        attribute pressureRating : PressureValue := 60000000.0;
        attribute depthRating : LengthValue := 6000.0;
        attribute mass : MassValue := 2.5;
    }

    part def PiezoTransducer {
        port acousticIn : AcousticPort;
        port analogOut : AnalogOutPort;
        port powerIn : PowerInPort;
        attribute sensitivity : ScalarValues::Real := 0.001;
        attribute minFrequency : FrequencyValue := 10.0;
        attribute maxFrequency : FrequencyValue := 100000.0;
        action detect {
            in wave : AcousticWave;
            out signal : AnalogSignal;
        }
    }

    part def Preamplifier {
        port analogIn : AnalogInPort;
        port analogOut : AnalogOutPort;
        port powerIn : PowerInPort;
        attribute gain : ScalarValues::Real := 100.0;
        attribute noiseFloor : VoltageValue := 0.000001;
        action amplify {
            in signal : AnalogSignal;
            out amplified : AnalogSignal;
        }
    }

    part def AnalogDigitalConverter {
        port analogIn : AnalogInPort;
        port digitalOut : DigitalOutPort;
        port powerIn : PowerInPort;
        attribute sampleRate : FrequencyValue := 192000.0;
        attribute bitDepth : ScalarValues::Integer := 24;
        action convert {
            in analog : AnalogSignal;
            out digital : DigitalAudioStream;
        }
    }

    part def SignalProcessor {
        port digitalIn : DigitalInPort;
        port digitalOut : DigitalOutPort;
        port powerIn : PowerInPort;
        attribute lowCutoff : FrequencyValue := 10.0;
        attribute highCutoff : FrequencyValue := 100000.0;
        action applyBandpassFilter {
            in raw : DigitalAudioStream;
            out filtered : DigitalAudioStream;
        }
    }

    part def DataRecorder {
        port digitalIn : DigitalInPort;
        port powerIn : PowerInPort;
        attribute capacity : DataSizeValue := 1000000.0;
        attribute usedStorage : DataSizeValue := 0.0;
        action record {
            in stream : DigitalAudioStream;
        }
    }

    part def PowerSupply {
        port powerOut : PowerOutPort;
        attribute nominalVoltage : VoltageValue := 12.0;
        attribute capacity : ChargeValue := 36000.0;
        attribute maxPower : PowerValue := 50.0;
    }

    state def HydrophoneStates {
        entry; then standby;
        state standby {
            do action idle;
        }
        accept ActivationCmd
            then active;
        state active {
            do action monitor;
        }
        accept DetectionEvent
            then recording;
        accept DeactivationCmd
            then standby;
        state recording {
            do action recordData;
        }
        accept RecordingComplete
            then active;
        accept DeactivationCmd
            then standby;
    }

    part def Hydrophone {
        part casing : TitaniumCasing;
        part transducer : PiezoTransducer;
        part preamp : Preamplifier;
        part adc : AnalogDigitalConverter;
        part processor : SignalProcessor;
        part recorder : DataRecorder;
        part power : PowerSupply;

        port acousticInput : AcousticPort;
        port digitalOutput : DigitalOutPort;

        connect acousticInput to transducer.acousticIn;
        connect transducer.analogOut to preamp.analogIn;
        connect preamp.analogOut to adc.analogIn;
        connect adc.digitalOut to processor.digitalIn;
        connect processor.digitalOut to recorder.digitalIn;
        connect processor.digitalOut to digitalOutput;

        connect power.powerOut to transducer.powerIn;
        connect power.powerOut to preamp.powerIn;
        connect power.powerOut to adc.powerIn;
        connect power.powerOut to processor.powerIn;
        connect power.powerOut to recorder.powerIn;

        exhibit state operationalStates : HydrophoneStates;
    }

    requirement def PressureResistanceReq {
        subject h : Hydrophone;
        assert constraint {
            h.casing.pressureRating >= 60000000.0
        }
    }

    requirement def DepthRatingReq {
        subject h : Hydrophone;
        assert constraint {
            h.casing.depthRating >= 6000.0
        }
    }

    requirement def FrequencyRangeReq {
        subject t : PiezoTransducer;
        assert constraint {
            t.minFrequency <= 10.0 and
            t.maxFrequency >= 100000.0
        }
    }

    requirement def ADCResolutionReq {
        subject a : AnalogDigitalConverter;
        assert constraint {
            a.sampleRate >= 192000.0 and
            a.bitDepth >= 24
        }
    }

    requirement def BandpassFilterReq {
        subject s : SignalProcessor;
        assert constraint {
            s.lowCutoff <= 10.0 and
            s.highCutoff >= 100000.0
        }
    }

    requirement def PowerAutonomyReq {
        subject p : PowerSupply;
        assert constraint {
            p.capacity >= 36000.0 and
            p.nominalVoltage >= 12.0
        }
    }

    requirement def StorageCapacityReq {
        subject r : DataRecorder;
        assert constraint {
            r.capacity >= 1000000.0
        }
    }
}
