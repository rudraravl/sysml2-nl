package ActiveSonarSystem {
    import ScalarValues::*;

    value def Distance :> Real { unit 'm'; }
    value def Time :> Real { unit 's'; }
    value def Speed :> Real { unit 'm/s'; }
    value def EchoStrength :> Real { unit 'dB'; }
    value def Frequency :> Real { unit 'Hz'; }

    attribute def StartPing;

    enum def TargetType {
        obstacle;
        seafloor;
        marineLife;
        otherVessel;
    }

    item def AcousticPulse {
        attribute frequency : Frequency;
        attribute duration : Time;
    }

    item def EchoSignal {
        attribute arrivalTime : Time;
        attribute intensity : EchoStrength;
    }

    item def ProcessedSignal {
        attribute timeOfFlight : Time;
        attribute filteredIntensity : EchoStrength;
    }

    item def TargetData {
        attribute distance : Distance;
        attribute classification : TargetType;
        attribute echoStrength : EchoStrength;
    }

    action def TransmitPulse {
        out pulse : AcousticPulse;
    }

    action def FilterNoise {
        in rawEcho : EchoSignal;
        out filteredEcho : ProcessedSignal;
    }

    action def AnalyzeTarget {
        in processedSignal : ProcessedSignal;
        out target : TargetData;
    }

    action def DisplayTarget {
        in data : TargetData;
    }

    part def Transducer {
        port transmitPort {
            out ping : AcousticPulse;
        }
        port receivePort {
            in echo : EchoSignal;
        }
        port echoOutPort {
            out echoForward : EchoSignal;
        }
    }

    part def SignalProcessor {
        port echoInPort {
            in echo : EchoSignal;
        }
        port processedOutPort {
            out processed : ProcessedSignal;
        }
    }

    part def TargetAnalyzer {
        port processedInPort {
            in processed : ProcessedSignal;
        }
        port targetOutPort {
            out targetData : TargetData;
        }
    }

    part def DisplayUnit {
        port targetInPort {
            in targetData : TargetData;
        }
    }

    part def WaterMedium {
        port pingInPort {
            in ping : AcousticPulse;
        }
        port echoOutPort {
            out echo : EchoSignal;
        }
    }

    state def SonarOperation {
        entry; then Pinging;

        state Pinging {
            do action TransmitPulse;
        }
        transition first Pinging then Listening;

        state Listening;
        transition
            first Listening
            accept echo : EchoSignal
            then Processing;

        state Processing {
            do action FilterNoise;
        }
        transition first Processing then Analyzing;

        state Analyzing {
            do action AnalyzeTarget;
        }
        transition first Analyzing then Displaying;

        state Displaying {
            do action DisplayTarget;
        }
        transition first Displaying then Pinging;
    }

    part sonarSystem {
        part transducer : Transducer;
        part waterMedium : WaterMedium;
        part signalProcessor : SignalProcessor;
        part targetAnalyzer : TargetAnalyzer;
        part displayUnit : DisplayUnit;

        flow pingFlow of AcousticPulse
            from transducer.transmitPort.ping to waterMedium.pingInPort.ping;
        flow mediumEchoFlow of EchoSignal
            from waterMedium.echoOutPort.echo to transducer.receivePort.echo;
        flow echoForwardFlow of EchoSignal
            from transducer.echoOutPort.echoForward to signalProcessor.echoInPort.echo;
        flow processedFlow of ProcessedSignal
            from signalProcessor.processedOutPort.processed to targetAnalyzer.processedInPort.processed;
        flow targetDataFlow of TargetData
            from targetAnalyzer.targetOutPort.targetData to displayUnit.targetInPort.targetData;

        state sonarOperation : SonarOperation;

        satisfy DetectionRange;
        satisfy ProcessingLatency;
        satisfy ReliableOperation;
        satisfy SpeedOfSound;
    }

    requirement DetectionRange {
        doc /* The system shall detect targets within a range of 1 meter to 5 kilometers. */
        attribute minRange : Distance = 1 [m];
        attribute maxRange : Distance = 5000 [m];
    }

    requirement ProcessingLatency {
        doc /* Signal processing shall complete within 100 milliseconds to ensure timely information. */
        attribute maxLatency : Time = 0.1 [s];
    }

    requirement ReliableOperation {
        doc /* The system shall operate reliably and continuously during underwater missions. */
    }

    requirement SpeedOfSound {
        doc /* The system shall use a standard speed of sound in water of 1500 m/s for distance calculations. */
        attribute speedOfSound : Speed = 1500 [m/s];
    }
}
