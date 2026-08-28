package GeigerCounterSystem {
    public import ISQ::*;
    public import SI::*;
    public import ScalarValues::*;

    item def RadiationParticle;
    item def ElectricalPulse;
    item def ProcessedSignal;
    item def AudioClick;

    action def DetectRadiation {
        in particle : RadiationParticle;
        out pulse : ElectricalPulse;
    }

    action def ProcessPulse {
        in pulse : ElectricalPulse;
        out signal : ProcessedSignal;
    }

    action def EmitSound {
        in signal : ProcessedSignal;
        out click : AudioClick;
    }

    action def CountPulses {
        in signal : ProcessedSignal;
        out rate : ISQ::FrequencyValue;
    }

    action def DisplayIntensity {
        in rate : ISQ::FrequencyValue;
    }

    part def HighVoltageSupply {
        attribute nominalVoltage : ISQ::ElectricPotentialValue := 450 [V];
        out port voltageOut : ISQ::ElectricPotentialValue;
    }

    part def GeigerMullerTube {
        in port voltageIn : ISQ::ElectricPotentialValue;
        in port radiationIn : RadiationParticle;
        out port pulseOut : ElectricalPulse;

        state def TubeState {
            attribute deadTime : ISQ::TimeValue := 100 [us];

            state idle;
            accept RadiationParticle
                then detecting;
            state detecting {
                do action generatePulse {
                    out pulse : ElectricalPulse;
                }
            }
            then dead;
            state dead {
                do action resetTube {
                    in duration : ISQ::TimeValue = deadTime;
                }
            }
            then idle;
        }

        state tubeState : TubeState;
    }

    part def PulseProcessor {
        in port pulseIn : ElectricalPulse;
        out port signalOut : ProcessedSignal;

        perform action process : ProcessPulse {
            in pulse = pulseIn;
            out signal = signalOut;
        }
    }

    part def AudioIndicator {
        in port signalIn : ProcessedSignal;
        out port soundOut : AudioClick;

        perform action emit : EmitSound {
            in signal = signalIn;
            out click = soundOut;
        }
    }

    part def RateCounter {
        in port signalIn : ProcessedSignal;
        out port cpmOut : ISQ::FrequencyValue;
        attribute tally : ScalarValues::Integer := 0;
        attribute rate : ISQ::FrequencyValue := 0 [Hz];
        attribute period : ISQ::TimeValue := 60 [s];

        state def CountingState {
            state tallying;
            accept ProcessedSignal
                then increment;
            state increment {
                do assign tally := tally + 1;
            }
            then tallying;
        }

        state counterState : CountingState;
        bind cpmOut = rate;
    }

    part def DisplayUnit {
        in port cpmIn : ISQ::FrequencyValue;
    }

    part GeigerCounter {
        part hvSupply : HighVoltageSupply;
        part gmTube : GeigerMullerTube;
        part processor : PulseProcessor;
        part speaker : AudioIndicator;
        part counter : RateCounter;
        part display : DisplayUnit;

        connect hvSupply.voltageOut to gmTube.voltageIn;
        connect gmTube.pulseOut to processor.pulseIn;
        connect processor.signalOut to speaker.signalIn;
        connect processor.signalOut to counter.signalIn;
        connect counter.cpmOut to display.cpmIn;

        perform action operate {
            action detect : DetectRadiation;
            action process : ProcessPulse;
            action emit : EmitSound;
            action count : CountPulses;
            action show : DisplayIntensity;

            flow from detect.pulse to process.pulse;
            flow from process.signal to emit.signal;
            flow from process.signal to count.signal;
            flow from count.rate to show.rate;

            first start;
            then detect;
            then process;
            then emit;
            then count;
            then show;
        }
    }

    requirement def RadiationDetectionRequirement {
        doc /* The system shall detect ionizing radiation particles entering the Geiger-Muller tube and produce an electrical pulse for each event. */
    }

    requirement def HighVoltageRequirement {
        doc /* The High-Voltage Supply shall provide a stable 450V operating voltage to the Geiger-Muller tube. */
    }

    requirement def DeadTimeRequirement {
        doc /* The Geiger-Muller tube shall enter a dead time of approximately 100 microseconds after each detection event during which it is unable to detect new radiation. */
    }

    requirement def AudioFeedbackRequirement {
        doc /* The Audio Indicator shall produce an audible click for each processed radiation pulse to provide real-time feedback. */
    }

    requirement def RateMeasurementRequirement {
        doc /* The Rate Counter shall tally pulses over a 60-second window and calculate the radiation intensity in Counts Per Minute. */
    }

    requirement def DisplayRequirement {
        doc /* The Display Unit shall show the calculated CPM value to the user. */
    }

    requirement radiationDetectionReq : RadiationDetectionRequirement;
    requirement highVoltageReq : HighVoltageRequirement;
    requirement deadTimeReq : DeadTimeRequirement;
    requirement audioFeedbackReq : AudioFeedbackRequirement;
    requirement rateMeasurementReq : RateMeasurementRequirement;
    requirement displayReq : DisplayRequirement;

    satisfy radiationDetectionReq by GeigerCounter::gmTube;
    satisfy highVoltageReq by GeigerCounter::hvSupply;
    satisfy deadTimeReq by GeigerCounter::gmTube;
    satisfy audioFeedbackReq by GeigerCounter::speaker;
    satisfy rateMeasurementReq by GeigerCounter::counter;
    satisfy displayReq by GeigerCounter::display;
}
