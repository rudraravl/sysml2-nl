package Pulsocon {
    public import ScalarValues::*;
    public import SI::*;

    value def FrequencyValue :> Real { unit "Hz"; }
    value def AmplitudeValue :> Real { unit "V"; }
    value def DurationValue :> Real { unit "ms"; }
    value def TemperatureValue :> Real { unit "degC"; }
    value def CurrentValue :> Real { unit "A"; }
    value def VoltageValue :> Real { unit "V"; }
    value def QualityValue :> Real { unit "%"; }

    item def PulseWaveform {
        attribute frequency : FrequencyValue;
        attribute amplitude : AmplitudeValue;
        attribute duration : DurationValue;
    }

    item def TargetParameters {
        attribute targetFrequency : FrequencyValue;
        attribute targetAmplitude : AmplitudeValue;
        attribute targetDuration : DurationValue;
    }

    item def MeasurementFeedback {
        attribute measuredFrequency : FrequencyValue;
        attribute measuredAmplitude : AmplitudeValue;
        attribute signalQuality : QualityValue;
    }

    item def PowerSupply {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    item def TriggerSignal {
        attribute timestamp : DurationValue;
    }

    item def SafetyStatus {
        attribute overCurrent : Boolean;
        attribute overTemperature : Boolean;
        attribute temperature : TemperatureValue;
        attribute current : CurrentValue;
    }

    item def FaultLog {
        attribute code : String;
        attribute description : String;
        attribute timestamp : DurationValue;
    }

    port def WaveformOutPort {
        out waveform : PulseWaveform;
    }

    port def WaveformInPort {
        in waveform : PulseWaveform;
    }

    port def ControlOutPort {
        out adjustments : TargetParameters;
    }

    port def ControlInPort {
        in adjustments : TargetParameters;
    }

    port def FeedbackOutPort {
        out feedback : MeasurementFeedback;
    }

    port def FeedbackInPort {
        in feedback : MeasurementFeedback;
    }

    port def PowerOutPort {
        out supply : PowerSupply;
    }

    port def PowerInPort {
        in supply : PowerSupply;
    }

    port def TriggerInPort {
        in trigger : TriggerSignal;
    }

    port def SafetyOutPort {
        out status : SafetyStatus;
    }

    port def SafetyInPort {
        in status : SafetyStatus;
    }

    requirement def PrecisionPulseRequirement {
        subject pulse : PulseWaveform;
        objective {
            pulse.frequency >= 0.0 and
            pulse.amplitude >= 0.0 and
            pulse.duration >= 0.0
        }
    }

    requirement def SignalQualityRequirement {
        subject feedback : MeasurementFeedback;
        objective {
            feedback.signalQuality > 95.0
        }
    }

    requirement def SafetyRequirement {
        subject status : SafetyStatus;
        objective {
            status.overTemperature == false implies status.temperature < 85.0
        }
    }

    requirement def LifecycleRequirement {
        subject system : Pulsocon;
        objective {
            system.currentState == "standby" or
            system.currentState == "active" or
            system.currentState == "fault" or
            system.currentState == "off"
        }
    }

    part def WaveformGenerator {
        port waveformOut : WaveformOutPort;
        port controlIn : ControlInPort;
        port powerIn : PowerInPort;

        attribute currentSettings : TargetParameters;
        attribute enabled : Boolean;

        action def GeneratePulse {
            in settings : TargetParameters;
            in supply : PowerSupply;
            out pulse : PulseWaveform;
        }

        action generate : GeneratePulse {
            in settings = currentSettings;
            in supply = powerIn.supply;
            out pulse = waveformOut.waveform;
        }

        action def ApplyAdjustments {
            in adjustments : TargetParameters;
            out settings : TargetParameters;
        }

        action apply : ApplyAdjustments {
            in adjustments = controlIn.adjustments;
            out settings = currentSettings;
        }
    }

    part def ControlProcessor {
        port controlOut : ControlOutPort;
        port feedbackIn : FeedbackInPort;
        port safetyIn : SafetyInPort;

        attribute targetParams : TargetParameters;
        attribute lastFeedback : MeasurementFeedback;
        attribute lastSafetyStatus : SafetyStatus;

        action def ComputeAdjustments {
            in target : TargetParameters;
            in feedback : MeasurementFeedback;
            in safety : SafetyStatus;
            out adjustments : TargetParameters;
        }

        action compute : ComputeAdjustments {
            in target = targetParams;
            in feedback = feedbackIn.feedback;
            in safety = safetyIn.status;
            out adjustments = controlOut.adjustments;
        }

        action def ReceiveTarget {
            in target : TargetParameters;
        }

        action receive : ReceiveTarget {
            in target = targetParams;
        }
    }

    part def SignalAnalyzer {
        port waveformIn : WaveformInPort;
        port feedbackOut : FeedbackOutPort;

        action def Analyze {
            in waveform : PulseWaveform;
            out feedback : MeasurementFeedback;
        }

        action analyze : Analyze {
            in waveform = waveformIn.waveform;
            out feedback = feedbackOut.feedback;
        }
    }

    part def PowerManagement {
        port powerOut : PowerOutPort;

        attribute outputVoltage : VoltageValue = 12.0;
        attribute outputCurrent : CurrentValue = 5.0;
        attribute regulated : Boolean = true;

        action def Regulate {
            out supply : PowerSupply;
        }

        action regulate : Regulate {
            out supply = powerOut.supply;
        }
    }

    part def SafetyMonitor {
        port safetyOut : SafetyOutPort;

        attribute temperatureThreshold : TemperatureValue = 85.0;
        attribute currentThreshold : CurrentValue = 10.0;
        attribute currentTemperature : TemperatureValue;
        attribute currentCurrent : CurrentValue;

        action def MonitorConditions {
            in temperature : TemperatureValue;
            in current : CurrentValue;
            out status : SafetyStatus;
        }

        action monitor : MonitorConditions {
            in temperature = currentTemperature;
            in current = currentCurrent;
            out status = safetyOut.status;
        }

        action def Shutdown {
        }

        action shutdown : Shutdown;
    }

    part def Pulsocon {
        port triggerIn : TriggerInPort;
        port waveformOutput : WaveformOutPort;

        attribute currentState : String;
        attribute startCommandReceived : Boolean;
        attribute stopCommandReceived : Boolean;
        attribute resetCommandReceived : Boolean;
        attribute shutdownCommandReceived : Boolean;
        attribute faultDetected : Boolean;
        attribute selfTestComplete : Boolean;
        attribute calibrationComplete : Boolean;
        attribute adaptiveModeSelected : Boolean;
        attribute normalModeSelected : Boolean;
        attribute syncModeSelected : Boolean;
        attribute faultLog : FaultLog[0..*];

        part generator : WaveformGenerator {
            port waveformOut : WaveformOutPort;
            port controlIn : ControlInPort;
            port powerIn : PowerInPort;
        }

        part processor : ControlProcessor {
            port controlOut : ControlOutPort;
            port feedbackIn : FeedbackInPort;
            port safetyIn : SafetyInPort;
        }

        part analyzer : SignalAnalyzer {
            port waveformIn : WaveformInPort;
            port feedbackOut : FeedbackOutPort;
        }

        part power : PowerManagement {
            port powerOut : PowerOutPort;
        }

        part safety : SafetyMonitor {
            port safetyOut : SafetyOutPort;
        }

        connection powerToGenerator connect power.powerOut to generator.powerIn;
        connection processorToGenerator connect processor.controlOut to generator.controlIn;
        connection generatorToAnalyzer connect generator.waveformOut to analyzer.waveformIn;
        connection analyzerToProcessor connect analyzer.feedbackOut to processor.feedbackIn;
        connection safetyToProcessor connect safety.safetyOut to processor.safetyIn;
        connection generatorToOutput connect generator.waveformOut to waveformOutput;

        state machine def PulsoconStateMachine {
            entry action initialize {
                // System power-on entry
            }

            state startup {
                entry action doSelfTest {
                    // Perform self-tests on all subsystems
                }
                entry action doCalibration {
                    // Calibrate sensors and generator
                }
                transition startup to standby {
                    when selfTestComplete and calibrationComplete;
                }
            }

            state standby {
                entry action enterLowPower {
                    // Enter low-power standby
                }
                transition standby to active {
                    when startCommandReceived;
                }
                transition standby to off {
                    when shutdownCommandReceived;
                }
            }

            state active {
                entry action beginGeneration {
                    // Begin pulse generation
                }

                state normal {
                    entry action continuousOperation {
                        // Continuous pulse generation
                    }
                }

                state adaptive {
                    entry action optimizeWaveform {
                        // Actively optimize waveform for best quality
                    }
                }

                state synchronized {
                    entry action awaitTrigger {
                        // Generate pulses in response to external triggers
                    }
                }

                transition normal to adaptive {
                    when adaptiveModeSelected;
                }
                transition adaptive to normal {
                    when normalModeSelected;
                }
                transition normal to synchronized {
                    when syncModeSelected;
                }
                transition synchronized to normal {
                    when normalModeSelected;
                }
                transition adaptive to synchronized {
                    when syncModeSelected;
                }
                transition synchronized to adaptive {
                    when adaptiveModeSelected;
                }
                transition active to fault {
                    when faultDetected;
                }
                transition active to standby {
                    when stopCommandReceived;
                }
            }

            state fault {
                entry action logIssue {
                    // Log the fault issue
                }
                transition fault to standby {
                    when resetCommandReceived;
                }
                transition fault to off {
                    when shutdownCommandReceived;
                }
            }

            state off {
                entry action powerDown {
                    // Safe shutdown
                }
            }
        }

        state machine : PulsoconStateMachine;

        satisfy PrecisionPulseRequirement by waveformOutput.waveform;
        satisfy SignalQualityRequirement by analyzer.feedbackOut.feedback;
        satisfy SafetyRequirement by safety.safetyOut.status;
        satisfy LifecycleRequirement by self;
    }
}
