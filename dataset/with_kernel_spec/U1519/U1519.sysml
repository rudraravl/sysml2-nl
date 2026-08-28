package VacuumTubeAmplifierModel {
    attribute def Voltage :> ISQ::voltage;
    attribute def Current :> ISQ::current;
    attribute def Resistance :> ISQ::resistance;
    attribute def Power :> ISQ::power;
    attribute def Temperature :> ISQ::temperature;
    attribute def Frequency :> ISQ::frequency;
    attribute def Pressure :> ISQ::pressure;

    attribute def PowerOnSignal;
    attribute def WarmupCompleteSignal;
    attribute def AudioDetectedSignal;
    attribute def AudioStopSignal;
    attribute def OverloadSignal;
    attribute def VacuumFailureSignal;

    item def AudioSignal {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute frequency : Frequency;
    }
    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    port def AudioInPort {
        in item audioSignal : AudioSignal;
    }
    port def AudioOutPort {
        out item audioSignal : AudioSignal;
    }
    port def PowerInPort {
        in item power : ElectricalPower;
    }
    port def PowerOutPort {
        out item power : ElectricalPower;
    }

    action def HeatCathode;
    action def AmplifySignal;
    action def ReducePower;
    action def EmergencyShutdown;
    action def MonitorSystem;

    part def GlassEnvelope {
        attribute vacuumIntegrity : ScalarValues::Boolean;
        attribute vacuumPressure : Pressure;
    }
    part def Heater {
        attribute resistance : Resistance;
        attribute powerRating : Power;
    }
    part def Cathode {
        attribute temperature : Temperature;
        attribute emissionCurrent : Current;
    }
    part def Anode {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    part def ControlGrid {
        attribute voltage : Voltage;
    }
    part def TriodeTube {
        attribute amplificationFactor : ScalarValues::Real;
        attribute plateCurrent : Current;
        part heater : Heater;
        part cathode : Cathode;
        part anode : Anode;
        part controlGrid : ControlGrid;
        part envelope : GlassEnvelope;
        port heaterPort : PowerInPort;
        port gridPort : AudioInPort;
        port anodePort : AudioOutPort;
        port hvPort : PowerInPort;
        assert constraint {
            envelope.vacuumIntegrity == true implies cathode.emissionCurrent >= 0
        }
    }
    part def HighVoltageSupply {
        attribute outputVoltage : Voltage;
        attribute maxCurrent : Current;
        port hvOut : PowerOutPort;
    }
    part def LowVoltageSupply {
        attribute outputVoltage : Voltage;
        attribute maxCurrent : Current;
        port lvOut : PowerOutPort;
    }
    part def InputTransformer {
        attribute turnsRatio : ScalarValues::Real;
        attribute primaryImpedance : Resistance;
        attribute secondaryImpedance : Resistance;
        port primary : AudioInPort;
        port secondary : AudioOutPort;
    }
    part def OutputTransformer {
        attribute turnsRatio : ScalarValues::Real;
        attribute primaryImpedance : Resistance;
        attribute secondaryImpedance : Resistance;
        port primary : AudioInPort;
        port secondary : AudioOutPort;
    }
    part def SpeakerLoad {
        attribute resistance : Resistance;
        attribute powerHandling : Power;
        port audioIn : AudioInPort;
    }
    part def AudioSource {
        port output : AudioOutPort;
    }

    state def AmplifierStates {
        in tube : TriodeTube;
        entry; then warmingUp;
        state warmingUp {
            do HeatCathode;
        }
        transition warmingUp_to_standby
            first warmingUp
            accept WarmupCompleteSignal
            if tube.cathode.temperature >= 800 [K]
            then standby;
        state standby {
            do MonitorSystem;
        }
        transition standby_to_amplifying
            first standby
            accept AudioDetectedSignal
            then amplifying;
        state amplifying {
            do AmplifySignal;
        }
        transition amplifying_to_standby
            first amplifying
            accept AudioStopSignal
            then standby;
        transition amplifying_to_overload
            first amplifying
            accept OverloadSignal
            if tube.anode.current > 100 [mA]
            then overload;
        state overload {
            do ReducePower;
        }
        transition overload_to_standby
            first overload
            accept WarmupCompleteSignal
            then standby;
        accept VacuumFailureSignal
            then failed;
        state failed {
            entry EmergencyShutdown;
        }
    }

    part def AmplifierSystem {
        attribute gain : ScalarValues::Real;
        attribute outputPower : Power;
        attribute currentDraw : Current;
        part source : AudioSource;
        part triodeTube : TriodeTube;
        part hvSupply : HighVoltageSupply;
        part lvSupply : LowVoltageSupply;
        part inputTransformer : InputTransformer;
        part outputTransformer : OutputTransformer;
        part speaker : SpeakerLoad;
        exhibit state amplifierStates : AmplifierStates {
            in tube = triodeTube;
        }
        connect source.output to inputTransformer.primary;
        connect inputTransformer.secondary to triodeTube.gridPort;
        connect triodeTube.anodePort to outputTransformer.primary;
        connect outputTransformer.secondary to speaker.audioIn;
        connect hvSupply.hvOut to triodeTube.hvPort;
        connect lvSupply.lvOut to triodeTube.heaterPort;
    }

    requirement def AmplificationRequirement {
        doc /* The amplifier shall provide a voltage gain of at least 20 dB from input to output. */
        attribute minGain : ScalarValues::Real = 20.0;
    }
    requirement def OutputPowerRequirement {
        doc /* The amplifier shall deliver at least 5 watts RMS into an 8-ohm speaker load. */
        attribute minOutputPower : Power = 5 [W];
        attribute loadResistance : Resistance = 8 [ohm];
    }
    requirement def OverloadProtectionRequirement {
        doc /* The amplifier shall transition to overload state if anode current exceeds 100 mA. */
        attribute maxSafeCurrent : Current = 100 [mA];
    }
    requirement def VacuumIntegrityRequirement {
        doc /* The amplifier shall transition to failed state if vacuum integrity is lost. */
    }

    part amplifier : AmplifierSystem {
        satisfy AmplificationRequirement;
        satisfy OutputPowerRequirement;
        satisfy OverloadProtectionRequirement;
        satisfy VacuumIntegrityRequirement;
    }
}
