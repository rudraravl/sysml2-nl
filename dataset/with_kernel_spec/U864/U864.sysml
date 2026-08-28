package ScintillationCounter {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    item def RadiationParticle;
    item def LightFlash;
    item def ElectricalPulse {
        attribute amplitude : ElectricPotentialValue;
    }
    item def CountData {
        attribute totalCount : Integer;
        attribute countRate : FrequencyValue;
        attribute measurementTime : TimeValue;
    }
    item def MeasurementCompleteSignal;
    item def ResetSignal;

    port def RadiationIn { in item particle : RadiationParticle; }
    port def LightOut { out item flash : LightFlash; }
    port def LightIn { in item flash : LightFlash; }
    port def HVOut { out item voltage : ElectricPotentialValue; }
    port def HVIn { in item voltage : ElectricPotentialValue; }
    port def SignalOut { out item pulse : ElectricalPulse; }
    port def SignalIn { in item pulse : ElectricalPulse; }
    port def DataOut { out item data : CountData; }

    action def Scintillate {
        in particle : RadiationParticle;
        out flash : LightFlash;
    }
    action def Multiply {
        in flash : LightFlash;
        in voltage : ElectricPotentialValue;
        out pulse : ElectricalPulse;
    }
    action def PreAmplify {
        in rawPulse : ElectricalPulse;
        out ampPulse : ElectricalPulse;
    }
    action def Shape {
        in ampPulse : ElectricalPulse;
        out shapedPulse : ElectricalPulse;
    }
    action def Discriminate {
        in shapedPulse : ElectricalPulse;
        in threshold : ElectricPotentialValue;
        out validPulse : ElectricalPulse;
    }
    action def CountPulses {
        in validPulse : ElectricalPulse;
        in duration : TimeValue;
        out data : CountData;
    }

    state def ControlStates {
        state Idle;
        state Measuring;
        state Outputting;

        first Idle then Measuring accept radiationDetected : RadiationParticle;
        first Measuring then Outputting accept measurementCompleteSig : MeasurementCompleteSignal;
        first Outputting then Idle accept resetCmd : ResetSignal;
    }

    part def ScintillatorCrystal {
        port radIn : RadiationIn;
        port lightOut : LightOut;
        perform action scintillate : Scintillate {
            in particle = radIn.particle;
            out flash = lightOut.flash;
        }
    }
    part def PhotomultiplierTube {
        port lightIn : LightIn;
        port hvIn : HVIn;
        port signalOut : SignalOut;
        perform action multiply : Multiply {
            in flash = lightIn.flash;
            in voltage = hvIn.voltage;
            out pulse = signalOut.pulse;
        }
    }
    part def HighVoltageSupply {
        attribute voltage : ElectricPotentialValue = 1000 [V];
        port hvOut : HVOut;
        bind hvOut.voltage = voltage;
    }
    part def PreAmplifier {
        port signalIn : SignalIn;
        port signalOut : SignalOut;
        perform action preAmplify : PreAmplify {
            in rawPulse = signalIn.pulse;
            out ampPulse = signalOut.pulse;
        }
    }
    part def PulseShaper {
        port signalIn : SignalIn;
        port signalOut : SignalOut;
        perform action shape : Shape {
            in ampPulse = signalIn.pulse;
            out shapedPulse = signalOut.pulse;
        }
    }
    part def Discriminator {
        attribute threshold : ElectricPotentialValue = 0.5 [V];
        port signalIn : SignalIn;
        port signalOut : SignalOut;
        perform action discriminate : Discriminate {
            in shapedPulse = signalIn.pulse;
            in threshold = Discriminator::threshold;
            out validPulse = signalOut.pulse;
        }
    }
    part def Counter {
        attribute duration : TimeValue = 10 [s];
        port signalIn : SignalIn;
        port dataOut : DataOut;
        perform action countPulses : CountPulses {
            in validPulse = signalIn.pulse;
            in duration = Counter::duration;
            out data = dataOut.data;
        }
    }

    part def ScintillationCounterSystem {
        port radiationInput : RadiationIn;
        port dataOutput : DataOut;

        part scintillator : ScintillatorCrystal;
        part pmt : PhotomultiplierTube;
        part hvSupply : HighVoltageSupply;
        part preAmp : PreAmplifier;
        part shaper : PulseShaper;
        part disc : Discriminator;
        part counter : Counter;

        flow radiationInput.particle to scintillator.radIn.particle;
        flow scintillator.lightOut.flash to pmt.lightIn.flash;
        flow hvSupply.hvOut.voltage to pmt.hvIn.voltage;
        flow pmt.signalOut.pulse to preAmp.signalIn.pulse;
        flow preAmp.signalOut.pulse to shaper.signalIn.pulse;
        flow shaper.signalOut.pulse to disc.signalIn.pulse;
        flow disc.signalOut.pulse to counter.signalIn.pulse;
        flow counter.dataOut.data to dataOutput.data;

        state controlStates : ControlStates;
    }

    requirement def DetectRadiationRequirement {
        doc "The system shall detect ionizing radiation particles, convert them to electrical signals, filter noise, and output total counts and count rate over a specified measurement time.";
        subject system : ScintillationCounterSystem;
    }
}
