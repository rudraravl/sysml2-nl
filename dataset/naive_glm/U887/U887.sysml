package ActiveSonarSystemModel {

    import ScalarValues::*;

    // ===== Value Types with Units =====

    value type Distance :> Real {
        unit m;
    }

    value type Frequency :> Real {
        unit Hz;
    }

    value type TimeDelay :> Real {
        unit s;
    }

    value type SignalStrength :> Real {
        unit dB;
    }

    value type SoundSpeed :> Real {
        unit 'm/s';
    }

    value type Power :> Real {
        unit W;
    }

    // ===== Enumerations =====

    enum def TargetClass {
        obstacle;
        seafloor;
        marineLife;
        vessel;
        unknown;
    }

    enum def SonarMode {
        idle;
        transmitting;
        listening;
        processing;
        displaying;
    }

    enum def SystemStatus {
        operational;
        degraded;
        fault;
    }

    // ===== Item Definitions =====

    item def AcousticPulse {
        attribute frequency : Frequency = 50000[Hz];
        attribute duration : TimeDelay = 0.001[s];
        attribute sourceLevel : SignalStrength = 220[dB];
    }

    item def RawEcho {
        attribute amplitude : SignalStrength;
        attribute receiveTime : TimeDelay;
        attribute waveform : Real[0..*];
        attribute noiseLevel : SignalStrength;
    }

    item def ProcessedEcho {
        attribute amplitude : SignalStrength;
        attribute timeOfFlight : TimeDelay;
        attribute waveform : Real[0..*];
        attribute snr : Real;
    }

    item def TargetData {
        attribute distance : Distance;
        attribute classification : TargetClass;
        attribute echoStrength : SignalStrength;
        attribute confidence : Real;
        attribute timestamp : TimeDelay;
    }

    // ===== Port Definitions =====

    port def AcousticEmissionPort {
        out pulse : AcousticPulse;
    }

    port def AcousticReceptionPort {
        in echo : RawEcho;
    }

    port def RawSignalOutPort {
        out rawSignal : RawEcho;
    }

    port def ProcessedSignalOutPort {
        out processedSignal : ProcessedEcho;
    }

    port def TargetDataOutPort {
        out targetData : TargetData;
    }

    // ===== Requirements =====

    requirement def DetectionRangeRequirement {
        doc /* The system shall detect targets from 1 meter up to 5 kilometers. */
        attribute minRange : Distance = 1[m];
        attribute maxRange : Distance = 5000[m];
        constraint { minRange >= 1[m] and maxRange <= 5000[m] }
    }

    requirement def SpeedOfSoundRequirement {
        doc /* The system shall use 1500 m/s as the speed of sound in water for range calculations. */
        attribute soundSpeed : SoundSpeed = 1500['m/s'];
        constraint { soundSpeed == 1500['m/s'] }
    }

    requirement def ProcessingTimeRequirement {
        doc /* The system shall process signals rapidly to ensure timely information. */
        attribute maxProcessingTime : TimeDelay = 0.1[s];
        constraint { maxProcessingTime <= 0.1[s] }
    }

    requirement def ContinuousOperationRequirement {
        doc /* The system shall operate continuously and reliably. */
    }

    requirement def TargetClassificationRequirement {
        doc /* The system shall classify detected targets as obstacles, seafloor, marine life, or vessels. */
    }

    // ===== Part Definitions =====

    part def Transducer {
        port acousticEmission : AcousticEmissionPort;
        port acousticReception : AcousticReceptionPort;
        port rawSignalOut : RawSignalOutPort;

        attribute operatingFrequency : Frequency = 50000[Hz];
        attribute sourceLevel : SignalStrength = 220[dB];
        attribute maxRange : Distance = 5000[m];
        attribute minRange : Distance = 1[m];
        attribute pingDuration : TimeDelay = 0.001[s];

        satisfy ContinuousOperationRequirement;

        action emitAcousticPulse() : AcousticPulse {
            // Generate and emit high-frequency acoustic ping into water
        }

        action receiveEcho() : RawEcho {
            // Switch to listening mode and detect returning echoes
        }

        action forwardRawEcho(in echo : RawEcho) {
            // Forward raw echo signal to signal processor
        }

        state def TransducerOperation {
            attribute currentMode : SonarMode;

            initial start;
            state idle;
            state transmitting {
                entry action {
                    // Begin emitting acoustic pulse
                }
            }
            state listening {
                entry action {
                    // Switch to listening mode
                }
            }

            transition from idle to transmitting
                when { currentMode == SonarMode::transmitting };

            transition from transmitting to listening
                after 0.001[s];

            transition from listening to transmitting
                after 0.5[s];

            transition from listening to idle
                when { currentMode == SonarMode::idle };
        }
    }

    part def SignalProcessor {
        port rawSignalIn : ~RawSignalOutPort;
        port processedSignalOut : ProcessedSignalOutPort;

        attribute filterBandwidth : Frequency = 1000[Hz];
        attribute noiseFloor : SignalStrength = -40[dB];
        attribute processingDelay : TimeDelay = 0.01[s];
        attribute amplification : Real = 100.0;

        satisfy ProcessingTimeRequirement;

        action filterAmbientNoise(in raw : RawEcho) : ProcessedEcho {
            // Filter out ambient ocean noise to isolate true echo
        }

        action amplifySignal(in signal : ProcessedEcho) : ProcessedEcho {
            // Amplify the processed signal
        }

        action processEcho(in raw : RawEcho) : ProcessedEcho {
            // Complete signal processing: filter, amplify, extract time of flight
        }
    }

    part def TargetAnalyzer {
        port processedSignalIn : ~ProcessedSignalOutPort;
        port targetDataOut : TargetDataOutPort;

        attribute soundSpeed : SoundSpeed = 1500['m/s'];
        attribute classificationThreshold : Real = 0.7;

        satisfy SpeedOfSoundRequirement;
        satisfy TargetClassificationRequirement;

        action calculateDistance(in timeOfFlight : TimeDelay) : Distance {
            // distance = (soundSpeed * timeOfFlight) / 2
        }

        action classifyTarget(in echo : ProcessedEcho) : TargetClass {
            // Examine echo characteristics to classify object type
        }

        action estimateConfidence(in echo : ProcessedEcho) : Real {
            // Estimate confidence level in classification
        }

        action compileTargetData(in echo : ProcessedEcho) : TargetData {
            // Compile distance, classification, and echo strength into target data
        }
    }

    part def DisplayUnit {
        port targetDataIn : ~TargetDataOutPort;

        attribute refreshRate : Frequency = 10[Hz];
        attribute displayType : String = "Visual Display";
        attribute resolution : Distance = 1[m];

        action displayTargetData(in data : TargetData) {
            // Provide clear visual representation for operator
        }

        action updateDisplay(in data : TargetData) {
            // Update display with new target information
        }

        action logTargetData(in data : TargetData) {
            // Log target data for historical record
        }
    }

    // ===== Overall System =====

    part def ActiveSonarSystem {
        satisfy DetectionRangeRequirement;
        satisfy ContinuousOperationRequirement;
        satisfy ProcessingTimeRequirement;
        satisfy TargetClassificationRequirement;

        attribute systemStatus : SystemStatus = SystemStatus::operational;
        attribute pingInterval : TimeDelay = 0.5[s];
        attribute minDetectionRange : Distance = 1[m];
        attribute maxDetectionRange : Distance = 5000[m];

        part transducer : Transducer;
        part signalProcessor : SignalProcessor;
        part targetAnalyzer : TargetAnalyzer;
        part displayUnit : DisplayUnit;

        connect transducer.rawSignalOut to signalProcessor.rawSignalIn;
        connect signalProcessor.processedSignalOut to targetAnalyzer.processedSignalIn;
        connect targetAnalyzer.targetDataOut to displayUnit.targetDataIn;

        state def SonarCycle {
            attribute systemMode : SonarMode;

            initial start;
            state idle;
            state pinging {
                entry action {
                    // Trigger transducer to emit acoustic pulse
                }
            }
            state listening {
                entry action {
                    // Transducer in listening mode, waiting for echoes
                }
            }
            state processing {
                entry action {
                    // Signal processor and target analyzer process echo
                }
            }
            state displaying {
                entry action {
                    // Display unit shows target data
                }
            }

            transition from start to idle;

            transition from idle to pinging
                when { systemMode == SonarMode::transmitting };

            transition from pinging to listening
                after 0.001[s];

            transition from listening to processing
                when { systemMode == SonarMode::processing };

            transition from listening to pinging
                after 0.5[s];

            transition from processing to displaying
                when { systemMode == SonarMode::displaying };

            transition from displaying to idle
                when { systemMode == SonarMode::idle };
        }
    }
}
