package SonarSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def SignalStrength :> Real;
    attribute def DistanceValue :> LengthValue;
    attribute def TimeValue :> DurationValue;
    attribute def FrequencyValue :> Real;

    enum def TargetType {
        unknown;
        obstacle;
        seafloor;
        marine_life;
        vessel;
    }

    item def AcousticPulse {
        attribute frequency : FrequencyValue;
        attribute amplitude : SignalStrength;
        attribute duration : TimeValue;
    }

    item def EchoSignal {
        attribute frequency : FrequencyValue;
        attribute amplitude : SignalStrength;
        attribute travelTime : TimeValue;
    }

    item def TargetData {
        attribute distance : DistanceValue;
        attribute bearing : Real;
        attribute classification : TargetType;
        attribute echoStrength : SignalStrength;
    }

    port def TransducerPort {
        out transmittedPulse : AcousticPulse;
        in receivedEcho : EchoSignal;
    }

    port def DataPort {
        out targetData : TargetData;
    }

    part def Transducer {
        attribute operatingFrequency : FrequencyValue;
        attribute transmitPower : PowerValue;
        attribute sensitivity : SignalStrength;
        port transducerPort : TransducerPort;
    }

    part def SignalProcessor {
        attribute processingDelay : TimeValue;
        attribute noiseThreshold : SignalStrength;
        attribute filterBandwidth : FrequencyValue;
    }

    part def TargetAnalyzer {
        attribute maxDetectionRange : DistanceValue;
        attribute minDetectionRange : DistanceValue;
        attribute soundSpeed : Real;
    }

    part def DisplayUnit {
        port dataInput : ~DataPort;
        attribute refreshRate : Real;
        attribute displayResolution : Real;
    }

    action def TransmitAcousticPulse {
        out pulse : AcousticPulse;
    }

    action def ListenForEcho {
        in echo : EchoSignal;
        out echoData : EchoSignal;
    }

    action def FilterSignal {
        in rawEcho : EchoSignal;
        out filteredSignal : EchoSignal;
    }

    action def ComputeRange {
        in echoTime : TimeValue;
        in soundSpeed : Real;
        out range : DistanceValue;
    }

    action def IdentifyTarget {
        in echoCharacteristics : EchoSignal;
        in targetRange : DistanceValue;
        out targetClass : TargetType;
    }

    action def DisplayTarget {
        in targetInfo : TargetData;
    }

    action def SonarOperationCycle {
        first start;
        then merge cycleStart;

        then action transmit : TransmitAcousticPulse {
            out transmittedPulse : AcousticPulse;
        }

        then action listen : ListenForEcho {
            in echo : EchoSignal;
            out detectedEcho : EchoSignal;
        }

        then decide;
            if listen.detectedEcho.amplitude > 0.1 then processSignal;
            if listen.detectedEcho.amplitude <= 0.1 then cycleStart;

        action processSignal : FilterSignal {
            in rawEcho = listen.detectedEcho;
            out cleanSignal : EchoSignal;
        }

        then action calculateRange : ComputeRange {
            in echoTime = processSignal.cleanSignal.travelTime;
            in soundSpeed = 1500.0;
            out measuredRange : DistanceValue;
        }

        then action classify : IdentifyTarget {
            in echoCharacteristics = processSignal.cleanSignal;
            in targetRange = calculateRange.measuredRange;
            out classification : TargetType;
        }

        then action displayResult : DisplayTarget {
            in targetInfo : TargetData {
                :>> distance = calculateRange.measuredRange;
                :>> classification = classify.classification;
                :>> echoStrength = processSignal.cleanSignal.amplitude;
            }
        }

        then cycleStart;
    }

    part def SonarSystem {
        attribute systemPower : PowerValue;
        attribute transducerActive : Boolean;
        attribute receiverActive : Boolean;
        attribute processorActive : Boolean;
        attribute soundSpeed : Real = 1500.0;

        port sonarPort : TransducerPort;
        port outputPort : DataPort;

        part transducer : Transducer {
            attribute :>> operatingFrequency = 50000.0;
            attribute :>> transmitPower = 500.0 [W];
            attribute :>> sensitivity = 0.8;
            port :>> transducerPort;
        }

        part processor : SignalProcessor {
            attribute :>> processingDelay = 0.01 [s];
            attribute :>> noiseThreshold = 0.05;
            attribute :>> filterBandwidth = 10000.0;
        }

        part analyzer : TargetAnalyzer {
            attribute :>> maxDetectionRange = 5000.0 [m];
            attribute :>> minDetectionRange = 1.0 [m];
            attribute :>> soundSpeed = 1500.0;
        }

        part display : DisplayUnit {
            attribute :>> refreshRate = 10.0;
            attribute :>> displayResolution = 1920.0;
            port :>> dataInput;
        }

        connection transducerToProcessor connect transducer.transducerPort to processor;
        connection processorToAnalyzer connect processor to analyzer;
        connection analyzerToDisplay connect analyzer to display.dataInput;

        perform action operationCycle : SonarOperationCycle;
    }

    requirement <'REQ-SONAR-001'> primaryFunction {
        doc /* The sonar system shall detect and classify underwater targets 
             * by transmitting acoustic pulses and analyzing returned echoes 
             * to determine target distance, bearing, and type.
             */
        subject sonarSystem : SonarSystem;

        require detectionCapability;
        require rangeAccuracy;
        require operationalReliability;
    }

    requirement <'REQ-SONAR-002'> detectionCapability {
        doc /* The sonar system shall detect targets within a range 
             * of 1 meter to 5000 meters.
             */
        subject analyzer :>> SonarSystem::analyzer;

        assert constraint {
            analyzer.minDetectionRange == 1.0 [m] and
            analyzer.maxDetectionRange == 5000.0 [m]
        }
    }

    requirement <'REQ-SONAR-003'> rangeAccuracy {
        doc /* The sonar system shall calculate target distance with 
             * accuracy based on echo propagation time and sound speed 
             * of 1500 m/s in water.
             */
        subject analyzer :>> SonarSystem::analyzer;

        assert constraint {
            analyzer.soundSpeed == 1500.0
        }
    }

    requirement <'REQ-SONAR-004'> operationalReliability {
        doc /* The sonar system shall operate continuously in active mode 
             * with proper state transitions between transmitting, listening, 
             * and processing states.
             */
        subject sonarSystem : SonarSystem;
    }

    requirement <'REQ-SONAR-005'> powerRequirement {
        doc /* The sonar transducer shall operate at 500 watts 
             * transmit power during active operation.
             */
        subject transducer :>> SonarSystem::transducer;

        assert constraint {
            transducer.transmitPower == 500.0 [W]
        }
    }

    requirement <'REQ-SONAR-006'> signalProcessing {
        doc /* The signal processor shall filter received echoes 
             * with a noise threshold of 0.05 and processing delay 
             * not exceeding 0.01 seconds.
             */
        subject processor :>> SonarSystem::processor;

        assert constraint {
            processor.noiseThreshold == 0.05 and
            processor.processingDelay == 0.01 [s]
        }
    }

    part activeSonar : SonarSystem {
        attribute :>> systemPower = 500.0 [W];
        attribute :>> soundSpeed = 1500.0;

        part :>> transducer {
            attribute :>> operatingFrequency = 50000.0;
            attribute :>> transmitPower = 500.0 [W];
            attribute :>> sensitivity = 0.8;
        }

        part :>> processor {
            attribute :>> processingDelay = 0.01 [s];
            attribute :>> noiseThreshold = 0.05;
            attribute :>> filterBandwidth = 10000.0;
        }

        part :>> analyzer {
            attribute :>> maxDetectionRange = 5000.0 [m];
            attribute :>> minDetectionRange = 1.0 [m];
            attribute :>> soundSpeed = 1500.0;
        }

        part :>> display {
            attribute :>> refreshRate = 10.0;
            attribute :>> displayResolution = 1920.0;
        }
    }

    satisfy primaryFunction by activeSonar;
}
