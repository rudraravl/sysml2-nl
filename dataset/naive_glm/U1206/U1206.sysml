package SiliceneFETModel {

    package Units {
        unit Volt;
        unit Ampere;
        unit Meter;
        unit Second;
        unit Watt;
        unit Farad;
        unit Kelvin;
        unit One;
        unit VoltPerMeter = Volt / Meter;
        unit MeterSquaredPerVoltSecond = Meter * Meter / (Volt * Second);
        unit AmperePerVoltSquared = Ampere / (Volt * Volt);
        unit Picosecond = 10**-12 Second;
        unit Nanometer = 10**-9 Meter;
        unit Milliampere = 10**-3 Ampere;
        unit Microwatt = 10**-6 Watt;
        unit Femtofarad = 10**-12 Farad;
        unit WattPerMeterKelvin = Watt / (Meter * Kelvin);

        value type Voltage { :>> unit Volt; }
        value type Current { :>> unit Ampere; }
        value type Length { :>> unit Meter; }
        value type Duration { :>> unit Second; }
        value type Power { :>> unit Watt; }
        value type Capacitance { :>> unit Farad; }
        value type ElectricField { :>> unit VoltPerMeter; }
        value type Mobility { :>> unit MeterSquaredPerVoltSecond; }
        value type TransconductanceParameter { :>> unit AmperePerVoltSquared; }
        value type Dimensionless { :>> unit One; }
        value type Temperature { :>> unit Kelvin; }
        value type ThermalConductivity { :>> unit WattPerMeterKelvin; }
    }

    package Ports {
        port def ElectricalPort {
            attribute voltage : Voltage;
            attribute current : Current;
        }
    }

    package Components {
        part def MetalContact {
            attribute material : String;
            attribute resistivity : Real;
            port electrical : ElectricalPort;
        }

        part def Source :> MetalContact {
            attribute material = "Aluminum";
        }

        part def Drain :> MetalContact {
            attribute material = "Aluminum";
        }

        part def GateElectrode {
            attribute material : String;
            attribute workFunction : Voltage;
            port gatePort : ElectricalPort;
        }

        part def Dielectric {
            attribute material : String;
            attribute thickness : Length;
            attribute relativePermittivity : Dimensionless;
            port top : ElectricalPort;
            port bottom : ElectricalPort;
        }

        part def SiliceneChannel {
            attribute thickness : Length;
            attribute width : Length;
            attribute length : Length;
            attribute electronMobility : Mobility;
            attribute thresholdVoltage : Voltage;
            attribute bandgap : Voltage;
            port sourceSide : ElectricalPort;
            port drainSide : ElectricalPort;
            port gateInterface : ElectricalPort;
        }

        part def Substrate {
            attribute material : String;
            attribute thickness : Length;
            attribute thermalConductivity : ThermalConductivity;
        }
    }

    package Behaviors {
        action def ComputeDrainCurrent {
            in Vgs : Voltage;
            in Vds : Voltage;
            in Vth : Voltage;
            in beta : TransconductanceParameter;
            out Id : Current;

            if Vgs <= Vth {
                Id = 0 [A];
            } else if Vds < (Vgs - Vth) {
                Id = beta * ((Vgs - Vth) * Vds - 0.5 * Vds * Vds);
            } else {
                Id = 0.5 * beta * (Vgs - Vth) * (Vgs - Vth);
            }
        }

        state def FETOperation {
            in Vgs : Voltage;
            in Vds : Voltage;
            in Vth : Voltage;
            in beta : TransconductanceParameter;
            out Id : Current;

            state Cutoff {
                entry { Id = 0 [A]; }
            }
            state Linear {
                entry { Id = beta * ((Vgs - Vth) * Vds - 0.5 * Vds * Vds); }
            }
            state Saturation {
                entry { Id = 0.5 * beta * (Vgs - Vth) * (Vgs - Vth); }
            }

            transition from Cutoff to Linear
                when Vgs > Vth;
            transition from Linear to Saturation
                when Vds >= (Vgs - Vth);
            transition from Linear to Cutoff
                when Vgs <= Vth;
            transition from Saturation to Linear
                when Vds < (Vgs - Vth);
            transition from Saturation to Cutoff
                when Vgs <= Vth;
        }
    }

    package Requirements {
        requirement def SwitchingTimeRequirement {
            doc "The transistor shall switch states in under one picosecond.";
            attribute maxSwitchingTime : Duration;
            constraint { maxSwitchingTime < 1 [ps]; }
        }

        requirement def PowerConsumptionRequirement {
            doc "The transistor shall consume low power for energy efficiency.";
            attribute maxStaticPower : Power;
            constraint { maxStaticPower < 10 [uW]; }
        }

        requirement def ScalabilityRequirement {
            doc "The transistor shall be scalable to nanometer dimensions.";
            attribute minGateLength : Length;
            constraint { minGateLength <= 5 [nm]; }
        }

        requirement def ElectronMobilityRequirement {
            doc "The silicene channel shall exhibit very high electron mobility.";
            attribute minMobility : Mobility;
            constraint { minMobility > 1000 [m^2/(V*s)]; }
        }

        requirement def OperatingStateRequirement {
            doc "The transistor shall operate in Cutoff, Linear, and Saturation states.";
            subject fet : SiliceneFET;
            constraint { fet.stateMachine.state in {"Cutoff", "Linear", "Saturation"}; }
        }
    }

    package System {
        part def SiliceneFET {
            part source : Components::Source;
            part drain : Components::Drain;
            part gate : Components::GateElectrode;
            part dielectric : Components::Dielectric;
            part channel : Components::SiliceneChannel;
            part substrate : Components::Substrate;

            port sourcePort : Ports::ElectricalPort;
            port drainPort : Ports::ElectricalPort;
            port gatePort : Ports::ElectricalPort;

            attribute gateLength : Length = 5 [nm];
            attribute gateWidth : Length = 20 [nm];
            attribute oxideThickness : Length = 1 [nm];
            attribute oxideCapacitance : Capacitance = 2.3 [fF];
            attribute thresholdVoltage : Voltage = 0.3 [V];
            attribute supplyVoltage : Voltage = 0.9 [V];
            attribute beta : TransconductanceParameter = 0.5 [mA/V^2];
            attribute maxSwitchingTime : Duration = 0.8 [ps];
            attribute staticPower : Power = 5 [uW];

            private stateMachine stateMachine : Behaviors::FETOperation {
                in Vgs = gatePort.voltage;
                in Vds = drainPort.voltage - sourcePort.voltage;
                in Vth = thresholdVoltage;
                in beta = beta;
                out Id = drainPort.current;
            }

            connection sourceExternal connect sourcePort to source.electrical;
            connection drainExternal connect drainPort to drain.electrical;
            connection gateExternal connect gatePort to gate.gatePort;

            connection sourceToChannel connect source.electrical to channel.sourceSide;
            connection drainToChannel connect drain.electrical to channel.drainSide;
            connection gateToDielectric connect gate.gatePort to dielectric.top;
            connection dielectricToChannel connect dielectric.bottom to channel.gateInterface;

            connection substrateSupport connect substrate to channel;

            requirement switchingTimeReq : Requirements::SwitchingTimeRequirement {
                attribute maxSwitchingTime = maxSwitchingTime;
            }
            requirement powerReq : Requirements::PowerConsumptionRequirement {
                attribute maxStaticPower = staticPower;
            }
            requirement scalabilityReq : Requirements::ScalabilityRequirement {
                attribute minGateLength = gateLength;
            }
            requirement mobilityReq : Requirements::ElectronMobilityRequirement {
                attribute minMobility = channel.electronMobility;
            }
            requirement operatingStateReq : Requirements::OperatingStateRequirement {
                subject = this;
            }
        }

        part siliceneFetInstance : SiliceneFET {
            part source {
                attribute material = "Aluminum";
            }
            part drain {
                attribute material = "Aluminum";
            }
            part gate {
                attribute material = "Titanium Nitride";
                attribute workFunction = 4.6 [V];
            }
            part dielectric {
                attribute material = "Hafnium Oxide";
                attribute thickness = 1 [nm];
                attribute relativePermittivity = 25;
            }
            part channel {
                attribute thickness = 0.4 [nm];
                attribute width = 20 [nm];
                attribute length = 5 [nm];
                attribute electronMobility = 1200 [m^2/(V*s)];
                attribute thresholdVoltage = 0.3 [V];
                attribute bandgap = 0.05 [V];
            }
            part substrate {
                attribute material = "Silicon Dioxide";
                attribute thickness = 100 [nm];
                attribute thermalConductivity = 1.4 [W/(m*K)];
            }
        }
    }
}
