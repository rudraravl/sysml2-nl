package 'Portable Geiger Counter' {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def CPMValue :> Real;
    attribute def DoseRateValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def AlarmSignal;

    item def RadiationPulse;

    action def Click;
    action def DisplayCPM { in cpm : CPMValue; }
    action def DisplayDoseRate { in doseRate : DoseRateValue; }
    action def SoundAlarm;

    action def CountPulses {
        in pulse : RadiationPulse;
        out count : Integer;
    }

    action def ComputeCPM {
        in count : Integer;
        out cpm : CPMValue;
        out doseRate : DoseRateValue;
    }

    state def AlarmStates {
        in cpm : CPMValue;
        out alarm : AlarmSignal;

        entry; then normal;
        state normal;
        accept when cpm > 120 then alarming;
        state alarming;
        accept when cpm <= 120 then normal;
    }

    state def RadiationSafetyLevels {
        in cpm : CPMValue;

        entry; then background;
        state background;
        accept when cpm > 50 and cpm <= 100 then elevated;
        accept when cpm > 100 and cpm <= 120 then warning;
        accept when cpm > 120 then danger;

        state elevated;
        accept when cpm <= 50 then background;
        accept when cpm > 100 and cpm <= 120 then warning;
        accept when cpm > 120 then danger;

        state warning;
        accept when cpm <= 50 then background;
        accept when cpm > 50 and cpm <= 100 then elevated;
        accept when cpm > 120 then danger;

        state danger;
        accept when cpm <= 50 then background;
        accept when cpm > 50 and cpm <= 100 then elevated;
        accept when cpm > 100 and cpm <= 120 then warning;
    }

    part def GeigerMullerTube {
        attribute gas : String = "Neon-Halogen";
        port pulseOut { out pulse : RadiationPulse; }
        port hvIn { in voltage : VoltageValue; }
    }

    part def HighVoltageSupply {
        port hvOut { out voltage : VoltageValue = 450; }
    }

    part def AudioIndicator {
        port pulseIn { in pulse : RadiationPulse; }
        perform action 'click' : Click;
    }

    part def CentralProcessingUnit {
        port pulseIn { in pulse : RadiationPulse; }
        port cpmOut { out cpm : CPMValue; }
        port doseRateOut { out doseRate : DoseRateValue; }
        perform action 'count pulses' : CountPulses;
        perform action 'compute CPM' : ComputeCPM;
    }

    part def VisualDisplay {
        port cpmIn { in cpm : CPMValue; }
        port doseRateIn { in doseRate : DoseRateValue; }
        perform action 'display CPM' : DisplayCPM;
        perform action 'display dose rate' : DisplayDoseRate;
    }

    part def AlarmUnit {
        port cpmIn { in cpm : CPMValue; }
        port alarmOut { out alarm : AlarmSignal; }
        exhibit state alarmStates : AlarmStates;
    }

    part def AlarmSounder {
        port alarmIn { in alarm : AlarmSignal; }
        perform action 'sound alarm' : SoundAlarm;
    }

    part def GeigerCounter {
        part gmTube : GeigerMullerTube;
        part hvSupply : HighVoltageSupply;
        part audio : AudioIndicator;
        part cpu : CentralProcessingUnit;
        part display : VisualDisplay;
        part alarmUnit : AlarmUnit;
        part alarmSounder : AlarmSounder;
        exhibit state safetyLevels : RadiationSafetyLevels;
    }

    requirement def 'Real-time Feedback' {
        doc /* The system shall provide real-time audible and visual feedback of radiation level. */
    }
    requirement def 'Unsafe Warning' {
        doc /* The system shall issue an audible warning when radiation level exceeds 120 CPM. */
    }

    part geigerCounter : GeigerCounter {
        part :>> gmTube : GeigerMullerTube;
        part :>> hvSupply : HighVoltageSupply;
        part :>> audio : AudioIndicator;
        part :>> cpu : CentralProcessingUnit;
        part :>> display : VisualDisplay;
        part :>> alarmUnit : AlarmUnit;
        part :>> alarmSounder : AlarmSounder;

        flow hvFlow of VoltageValue from hvSupply.hvOut.voltage to gmTube.hvIn.voltage;
        flow pulseFlow1 of RadiationPulse from gmTube.pulseOut.pulse to audio.pulseIn.pulse;
        flow pulseFlow2 of RadiationPulse from gmTube.pulseOut.pulse to cpu.pulseIn.pulse;
        flow cpmFlow1 of CPMValue from cpu.cpmOut.cpm to display.cpmIn.cpm;
        flow cpmFlow2 of CPMValue from cpu.cpmOut.cpm to alarmUnit.cpmIn.cpm;
        flow doseRateFlow of DoseRateValue from cpu.doseRateOut.doseRate to display.doseRateIn.doseRate;
        flow alarmFlow of AlarmSignal from alarmUnit.alarmOut.alarm to alarmSounder.alarmIn.alarm;

        exhibit state 'safety levels' : RadiationSafetyLevels {
            in cpm = cpu.cpmOut.cpm;
        }
    }

    requirement 'real-time feedback' : 'Real-time Feedback';
    requirement 'unsafe warning' : 'Unsafe Warning';

    satisfy 'real-time feedback' by geigerCounter;
    satisfy 'unsafe warning' by geigerCounter;
}
