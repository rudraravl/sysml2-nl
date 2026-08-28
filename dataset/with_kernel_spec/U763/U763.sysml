package MagneticLevelGaugeSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        item def ProcessFluid;

        attribute def FluidLevelValue :> LengthValue;
        attribute def CurrentValue :> Real;
        attribute def LevelUpdate;
        attribute def AlarmSignal :> Boolean;

        port def FluidPort {
            inout fluid: ProcessFluid;
        }

        port def AnalogSignalPort {
            out current: CurrentValue;
        }

        port def DiscreteSignalPort {
            out signal: AlarmSignal;
        }

        part def ProcessVessel {
            port top: FluidPort;
            port bottom: FluidPort;
            attribute fluid_level: FluidLevelValue;
        }

        part def MagneticFloat {
            attribute position: FluidLevelValue;
        }

        part def BypassChamber {
            port top: FluidPort;
            port bottom: FluidPort;
            part float: MagneticFloat;
            attribute internal_level: FluidLevelValue;
        }

        part def IndicatorAssembly {
            attribute display_level: FluidLevelValue;
            exhibit state indicator_states: IndicatorStates;
        }

        part def LevelTransmitter {
            port analog_out: AnalogSignalPort;
            exhibit state transmitter_states: TransmitterStates;
        }

        part def AlarmSwitch {
            port discrete_out: DiscreteSignalPort;
            attribute setpoint: FluidLevelValue;
            exhibit state alarm_states: AlarmStates;
        }

        part def MagneticLevelGauge {
            part chamber: BypassChamber;
            part indicator: IndicatorAssembly;
            part transmitter: LevelTransmitter;
            part high_alarm: AlarmSwitch;
            part low_alarm: AlarmSwitch;
        }

        state def IndicatorStates;
        state def TransmitterStates;
        state def AlarmStates;

        action def UpdateDisplayAction {
            in float_position: FluidLevelValue;
            out display_level: FluidLevelValue;
        }

        action def TrackLevel {
            in level: FluidLevelValue;
            out position: FluidLevelValue;
        }

        action def TransmitSignal {
            in position: FluidLevelValue;
            out current: CurrentValue;
        }

        requirement def LevelMeasurementRequirement {
            subject gauge: MagneticLevelGauge;
            doc /* The float position must match the internal level */
            assert { gauge.chamber.float.position == gauge.chamber.internal_level }
        }

        requirement def AlarmRequirement {
            subject gauge: MagneticLevelGauge;
            doc /* The alarm must trigger when setpoint is reached */
            assert { gauge.chamber.float.position >= gauge.high_alarm.setpoint }
        }

        requirement def TransmitterSignalRequirement {
            subject transmitter: LevelTransmitter;
            doc /* The transmitter shall output a 4-20 mA signal proportional to level. */
            assert { transmitter.analog_out.current >= 4.0 and transmitter.analog_out.current <= 20.0 }
        }

        requirement def MaterialRequirement {
            doc /* The gauge shall be constructed from robust materials like stainless steel. */
        }
    }

    package Usages {
        private import Definitions::*;

        part vessel: ProcessVessel;

        part gauge: MagneticLevelGauge {
            part chamber: BypassChamber {
                part float: MagneticFloat;
            }
            part indicator: IndicatorAssembly {
                state indicator_states: IndicatorStates {
                    entry; then updating;
                    state updating;
                    accept when indicator.display_level != gauge.chamber.float.position
                        then updating;
                }
            }
            part transmitter: LevelTransmitter {
                state transmitter_states: TransmitterStates parallel {
                    state operational {
                        entry; then sensing;
                        state sensing;
                        accept LevelUpdate
                            then transmitting;
                        state transmitting;
                        accept LevelUpdate
                            then sensing;
                    }
                }
            }
            part high_alarm: AlarmSwitch {
                attribute setpoint: FluidLevelValue = 1.0;
                state alarm_states: AlarmStates {
                    entry; then normal;
                    state normal;
                    accept when gauge.chamber.float.position >= setpoint
                        then triggered;
                    state triggered;
                    accept when gauge.chamber.float.position < setpoint
                        then normal;
                }
            }
            part low_alarm: AlarmSwitch {
                attribute setpoint: FluidLevelValue = 0.1;
                state alarm_states: AlarmStates {
                    entry; then normal;
                    state normal;
                    accept when gauge.chamber.float.position <= setpoint
                        then triggered;
                    state triggered;
                    accept when gauge.chamber.float.position > setpoint
                        then normal;
                }
            }
        }

        connection vessel_top_to_chamber_top connect vessel.top to gauge.chamber.top;
        connection vessel_bottom_to_chamber_bottom connect vessel.bottom to gauge.chamber.bottom;

        requirement levelReq : LevelMeasurementRequirement {
            subject gauge = gauge;
        }
        requirement alarmReq : AlarmRequirement {
            subject gauge = gauge;
        }
        requirement txReq : TransmitterSignalRequirement {
            subject transmitter = gauge.transmitter;
        }
        requirement matReq : MaterialRequirement;
    }
}
