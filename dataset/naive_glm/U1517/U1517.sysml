package CommonEmitterAmplifier {

    package Units {
        item def Unit;
        item volt : Unit;
        item ampere : Unit;
        item ohm : Unit;
        item farad : Unit;
        item watt : Unit;
        item hertz : Unit;
        item kelvin : Unit;

        value def Voltage :> Real { unit volt; }
        value def Current :> Real { unit ampere; }
        value def Resistance :> Real { unit ohm; }
        value def Capacitance :> Real { unit farad; }
        value def Power :> Real { unit watt; }
        value def Frequency :> Real { unit hertz; }
        value def Temperature :> Real { unit kelvin; }
        value def Gain :> Real;
    }

    package Items {
        import Units::*;

        item def ElectricalSignal {
            attribute voltage : Voltage;
            attribute current : Current;
            attribute frequency : Frequency;
        }
        item def DCSignal :> ElectricalSignal;
        item def ACSignal :> ElectricalSignal;
        item def AudioSignal :> ACSignal;
    }

    package Components {
        import Units::*;
        import Items::*;

        port def ElectricalPort {
            attribute voltage : Voltage;
            attribute current : Current;
            out item signal : ElectricalSignal;
        }

        part def TwoTerminalComponent {
            attribute nominalValue : Real;
            in port terminalA : ElectricalPort;
            in port terminalB : ElectricalPort;
        }

        part def Resistor :> TwoTerminalComponent {
            attribute resistance : Resistance;
            attribute powerRating : Power;
            attribute tolerance : Real;
        }

        part def Capacitor :> TwoTerminalComponent {
            attribute capacitance : Capacitance;
            attribute voltageRating : Voltage;
        }

        part def NPNTransistor {
            attribute beta : Real = 100;
            attribute vbeOn : Voltage = 0.7 [volt];
            attribute vceSat : Voltage = 0.2 [volt];
            attribute vce : Voltage;
            attribute vbe : Voltage;
            attribute ic : Current;
            attribute ib : Current;
            attribute ie : Current;
            attribute junctionTemp : Temperature = 300 [kelvin];

            in port base : ElectricalPort;
            in port collector : ElectricalPort;
            in port emitter : ElectricalPort;

            state machine TransistorStates {
                entry; then cutoff;

                state cutoff {
                    entry { ic = 0 [ampere]; }
                }
                state active {
                    entry { ic = beta * ib; }
                }
                state saturated {
                    entry { vce = vceSat; }
                }

                transition cutoff to active
                    when base.voltage >= vbeOn;
                transition active to cutoff
                    when base.voltage < vbeOn;
                transition active to saturated
                    when vce <= vceSat;
                transition saturated to active
                    when vce > vceSat and base.voltage >= vbeOn;
            }

            exhibit TransistorStates;
        }

        part def PowerSupply {
            attribute outputVoltage : Voltage = 12 [volt];
            attribute maxCurrent : Current = 1 [ampere];
            out port positive : ElectricalPort;
            out port ground : ElectricalPort;
        }

        part def SignalSource {
            attribute amplitude : Voltage = 0.01 [volt];
            attribute frequency : Frequency = 1000 [hertz];
            attribute sourceResistance : Resistance = 600 [ohm];
            out port output : ElectricalPort;
        }

        part def Speaker {
            attribute impedance : Resistance = 8 [ohm];
            attribute powerRating : Power = 1 [watt];
            attribute efficiency : Real = 0.02;
            in port positive : ElectricalPort;
            in port negative : ElectricalPort;
        }
    }

    package Subsystems {
        import Units::*;
        import Items::*;
        import Components::*;

        part def BiasCircuit {
            attribute baseBiasVoltage : Voltage;
            attribute dividerCurrent : Current;

            part upperResistor : Resistor {
                attribute resistance = 47 [kiloohm];
            }
            part lowerResistor : Resistor {
                attribute resistance = 10 [kiloohm];
            }

            in port supplyPort : ElectricalPort;
            in port groundPort : ElectricalPort;
            out port baseOutput : ElectricalPort;

            connection upperTop connect supplyPort to upperResistor.terminalA;
            connection upperBottom connect upperResistor.terminalB to lowerResistor.terminalA;
            connection lowerBottom connect lowerResistor.terminalB to groundPort;
            connection baseTap connect upperResistor.terminalB to baseOutput;
        }
    }

    package AmplifierSystem {
        import Units::*;
        import Items::*;
        import Components::*;
        import Subsystems::*;

        part def CommonEmitterAmplifier {
            attribute supplyVoltage : Voltage = 12 [volt];
            attribute voltageGain : Gain;
            attribute quiescentCurrent : Current;
            attribute quiescentVce : Voltage;
            attribute operatingTemperature : Temperature = 300 [kelvin];

            part powerSupply : PowerSupply;
            part biasCircuit : BiasCircuit;
            part signalSource : SignalSource;
            part inputCapacitor : Capacitor {
                attribute capacitance = 10 [microfarad];
            }
            part outputCapacitor : Capacitor {
                attribute capacitance = 100 [microfarad];
            }
            part collectorResistor : Resistor {
                attribute resistance = 4 [kiloohm];
            }
            part emitterResistor : Resistor {
                attribute resistance = 1 [kiloohm];
            }
            part transistor : NPNTransistor;
            part speaker : Speaker;

            connection supplyToBias connect powerSupply.positive to biasCircuit.supplyPort;
            connection groundToBias connect powerSupply.ground to biasCircuit.groundPort;
            connection biasToBase connect biasCircuit.baseOutput to transistor.base;
            connection sourceToInputCap connect signalSource.output to inputCapacitor.terminalA;
            connection inputCapToBase connect inputCapacitor.terminalB to transistor.base;
            connection supplyToCollectorR connect powerSupply.positive to collectorResistor.terminalA;
            connection collectorRToCollector connect collectorResistor.terminalB to transistor.collector;
            connection emitterToEmitterR connect transistor.emitter to emitterResistor.terminalA;
            connection emitterRToGround connect emitterResistor.terminalB to powerSupply.ground;
            connection collectorToOutputCap connect transistor.collector to outputCapacitor.terminalA;
            connection outputCapToSpeaker connect outputCapacitor.terminalB to speaker.positive;
            connection speakerReturn connect speaker.negative to powerSupply.ground;

            action def AmplifySignal {
                in weakInput : AudioSignal;
                out amplifiedOutput : AudioSignal;
                
                perform applyBias;
                perform modulateBaseCurrent;
                perform controlCollectorCurrent;
                perform developOutputVoltage;
                perform coupleOutput;

                action applyBias {
                    in biasVoltage : Voltage;
                }
                action modulateBaseCurrent {
                    in input : AudioSignal;
                    out baseCurrent : Current;
                }
                action controlCollectorCurrent {
                    in baseCurrent : Current;
                    out collectorCurrent : Current;
                }
                action developOutputVoltage {
                    in collectorCurrent : Current;
                    out outputVoltage : Voltage;
                }
                action coupleOutput {
                    in outputVoltage : Voltage;
                    out amplifiedOutput : AudioSignal;
                }
            }

            exhibit {
                action amplify : AmplifySignal {
                    in weakInput = signalSource.output.signal;
                    out amplifiedOutput = speaker.positive.signal;
                }
            }
        }
    }

    package Requirements {
        import Units::*;
        import AmplifierSystem::*;

        requirement def AmplifierRequirements {
            subject amp : CommonEmitterAmplifier;

            requirement ProvideVoltageGain {
                subject : amp;
                requirement constraint { amp.voltageGain >= 10 }
            }

            requirement OperateInActiveRegion {
                subject : amp;
                requirement constraint {
                    amp.transistor.vce > 0.2 [volt] and
                    amp.transistor.vce < 12 [volt]
                }
            }

            requirement SupplyVoltageLevel {
                subject : amp;
                requirement constraint { amp.powerSupply.outputVoltage == 12 [volt] }
            }

            requirement SpeakerImpedance {
                subject : amp;
                requirement constraint { amp.speaker.impedance == 8 [ohm] }
            }

            requirement InputCouplingDCBlocking {
                subject : amp;
                requirement constraint { amp.inputCapacitor.capacitance >= 1 [microfarad] }
            }

            requirement OutputCouplingDCBlocking {
                subject : amp;
                requirement constraint { amp.outputCapacitor.capacitance >= 1 [microfarad] }
            }

            requirement ThermalStability {
                subject : amp;
                requirement constraint {
                    amp.emitterResistor.resistance >= 100 [ohm]
                }
            }

            requirement QuiescentPointStability {
                subject : amp;
                requirement constraint {
                    amp.quiescentCurrent > 0 [ampere] and
                    amp.quiescentVce > 0.3 [volt] and
                    amp.quiescentVce < 11.7 [volt]
                }
            }
        }

        verification VerifyVoltageGain {
            subject : CommonEmitterAmplifier;
            objective { return subject.voltageGain >= 10; }
        }

        verification VerifyActiveRegion {
            subject : CommonEmitterAmplifier;
            objective {
                return subject.transistor.vce > 0.2 [volt] and
                       subject.transistor.vce < 12 [volt];
            }
        }
    }
}
