package 'GeigerMullerRadiationDetector' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def CountsPerMinute :> Real {
        doc /* Radiation intensity measured in counts per minute */
    }

    attribute def HighVoltage :> ISQ::ElectricPotentialValue;

    item def IonizingRadiation {
        attribute particleType : String;
        attribute energy : ISQ::EnergyValue;
    }

    item def IonPair {
        doc /* Primary ion-electron pair created by radiation */
    }

    item def ElectronAvalanche {
        doc /* Cascade of electrons in gas multiplication */
    }

    item def DetectionPulse {
        attribute amplitude : HighVoltage;
        attribute timestamp : ISQ::TimeValue;
    }

    port def RadiationPort {
        in item radiation : IonizingRadiation;
    }

    port def VoltageSupplyPort {
        in attribute voltage : HighVoltage;
    }

    port def PulsePort {
        out item pulse : DetectionPulse;
    }

    port def CountDataPort {
        out attribute countRate : CountsPerMinute;
    }

    port def AudioPort {
        out attribute clickSignal : Boolean;
    }

    part def GeigerMullerTube {
        doc /* Gas-filled detector tube that produces electrical pulses when ionizing radiation passes through */
        
        port radiationInput : RadiationPort;
        port hvInput : VoltageSupplyPort;
        port pulseOutput : PulsePort;

        attribute operatingVoltage : HighVoltage;
        attribute fillGas : String = "neon-argon";
        attribute deadTime : ISQ::TimeValue;

        action def DetectRadiationEvent {
            in item incomingRadiation : IonizingRadiation;
            out item outputPulse : DetectionPulse;

            first start;
            then action ionization {
                doc /* Radiation ionizes gas atoms creating primary ion pairs */
                in item radiation = incomingRadiation;
                out item primaryIons : IonPair;
            }
            then action gasMultiplication {
                doc /* Electric field accelerates electrons causing avalanche */
                in item ions = ionization.primaryIons;
                out item avalanche : ElectronAvalanche;
            }
            then action pulseGeneration {
                doc /* Avalanche creates detectable voltage pulse */
                in item avalanche = gasMultiplication.avalanche;
                out item pulse : DetectionPulse = outputPulse;
            }
            then action quenching {
                doc /* Discharge is terminated by quenching gas */
            }
            then done;
        }

        state def TubeStates {
            entry; then ready;

            state ready {
                doc /* Tube is ready to detect next radiation event */
            }

            accept at ready
                item radiation : IonizingRadiation
                then ionizing;

            state ionizing {
                doc /* Primary ionization occurring */
                entry; then avalanche;
            }

            state avalanche {
                doc /* Gas multiplication in progress */
                entry; then pulsing;
            }

            state pulsing {
                doc /* Output pulse being generated */
                entry; then deadTimeState;
            }

            state deadTimeState {
                doc /* Recovery period where tube cannot detect */
                entry; then ready;
            }
        }
    }

    part def HighVoltageSupply {
        doc /* Provides stable high voltage bias for tube operation */
        
        port hvOutput : ~VoltageSupplyPort;

        attribute outputVoltage : HighVoltage;
        attribute ripple : HighVoltage;

        action def ProvideVoltage {
            out attribute voltage : HighVoltage;
        }
    }

    part def PulseProcessor {
        doc /* Amplifies and shapes pulses from GM tube */
        
        port pulseInput : ~PulsePort;
        port processedOutput : PulsePort;

        attribute gain : Real;
        attribute shapingTime : ISQ::TimeValue;

        action def ProcessPulse {
            in item rawPulse : DetectionPulse;
            out item shapedPulse : DetectionPulse;
        }
    }

    part def RateCounter {
        doc /* Counts pulses over time window to determine radiation intensity */
        
        port pulseInput : ~PulsePort;
        port rateOutput : CountDataPort;

        attribute countWindow : ISQ::TimeValue;
        attribute totalCounts : Integer;

        action def CalculateCountRate {
            in item pulse : DetectionPulse;
            inout attribute counts : Integer;
            out attribute rate : CountsPerMinute;

            first start;
            then action incrementCount {
                in item detectedPulse = pulse;
            }
            then assign counts := counts + 1;
            then action computeRate {
                out attribute cpm : CountsPerMinute = rate;
            }
            then done;
        }
    }

    part def AudioIndicator {
        doc /* Produces audible click for each detected event */
        
        port pulseInput : ~PulsePort;
        port audioOutput : AudioPort;

        action def GenerateClick {
            in item triggerPulse : DetectionPulse;
            out attribute click : Boolean;
        }
    }

    part def DisplayUnit {
        doc /* Shows radiation count rate to user */
        
        port dataInput : ~CountDataPort;

        attribute displayedRate : CountsPerMinute;

        action def UpdateDisplay {
            in attribute newRate : CountsPerMinute;
            out attribute shown : CountsPerMinute;
        }
    }

    part geigerCounter {
        doc /* Complete radiation detection system using Geiger-Muller principle */

        part gmTube : GeigerMullerTube {
            attribute :>> operatingVoltage = 450.0 [V];
            attribute :>> deadTime = 100.0 [us];
            exhibit state tubeOperation : TubeStates;
            perform action DetectRadiationEvent[*] ordered;
        }

        part hvPowerSupply : HighVoltageSupply {
            attribute :>> outputVoltage = 450.0 [V];
            attribute :>> ripple = 2.0 [V];
            perform action ProvideVoltage;
        }

        part pulseProcessor : PulseProcessor {
            attribute :>> gain = 10.0;
            attribute :>> shapingTime = 5.0 [us];
            perform action ProcessPulse[*];
        }

        part counter : RateCounter {
            attribute :>> countWindow = 60.0 [s];
            attribute :>> totalCounts = 0;
            perform action CalculateCountRate[*];
        }

        part speaker : AudioIndicator {
            perform action GenerateClick[*];
        }

        part display : DisplayUnit {
            perform action UpdateDisplay[*];
        }

        connect hvPowerSupply.hvOutput to gmTube.hvInput;
        connect gmTube.pulseOutput to pulseProcessor.pulseInput;
        connect pulseProcessor.processedOutput to counter.pulseInput;
        connect pulseProcessor.processedOutput to speaker.pulseInput;
        connect counter.rateOutput to display.dataInput;
    }

    action def MonitorRadiation {
        doc /* Primary system function: continuously detect ionizing radiation and provide real-time indication through audible clicks and visual count rate display */

        in attribute backgroundRadiation : CountsPerMinute;
        out attribute measuredRadiation : CountsPerMinute;

        first start;
        then merge continuousOperation;

        then action energizeTube {
            doc /* Apply high voltage to establish electric field */
            out attribute voltage : HighVoltage;
        }

        then action waitForEvent {
            doc /* Tube in ready state awaiting radiation */
        }

        then decide;
            if backgroundRadiation > 0.0 then detectAndProcess;
            if backgroundRadiation == 0.0 then continuousOperation;

        action detectAndProcess {
            doc /* Process radiation event through detection chain */
            in attribute radiation = backgroundRadiation;
            out item detectedPulse : DetectionPulse;
        }

        then action amplifyPulse {
            in item pulse = detectAndProcess.detectedPulse;
            out item processedPulse : DetectionPulse;
        }

        then action updateIndicators {
            doc /* Update audio and visual outputs */
            out attribute audioClick : Boolean;
            out attribute displayRate : CountsPerMinute = measuredRadiation;
        }

        then continuousOperation;
    }

    requirement def <'GM-REQ-001'> RadiationDetectionCapability {
        doc /* The system shall detect ionizing radiation including alpha, beta, and gamma particles */

        subject detector : geigerCounter;

        require constraint {
            detector.gmTube.operatingVoltage >= 300.0 [V] and
            detector.gmTube.operatingVoltage <= 600.0 [V]
        }
    }

    requirement def <'GM-REQ-002'> CountRateMeasurement {
        doc /* The system shall measure and display radiation intensity in counts per minute */

        subject detector : geigerCounter;

        require constraint {
            detector.counter.totalCounts >= 0
        }
    }

    requirement def <'GM-REQ-003'> AudibleIndication {
        doc /* The system shall provide audible click for each detected radiation event */

        subject detector : geigerCounter;
    }

    requirement def <'GM-REQ-004'> DeadTimeRecovery {
        doc /* The system shall recover from dead time to enable detection of subsequent events */

        subject detector : geigerCounter;

        require constraint {
            detector.gmTube.deadTime <= 200.0 [us]
        }
    }

    requirement <'GM-SYS-001'> systemRequirement {
        doc /* The Geiger-Muller radiation detector shall continuously monitor for ionizing radiation and provide immediate audible and visual indication of radiation presence and intensity for safety and measurement applications */

        subject system : geigerCounter;

        require RadiationDetectionCapability;
        require CountRateMeasurement;
        require AudibleIndication;
        require DeadTimeRecovery;
    }
}
