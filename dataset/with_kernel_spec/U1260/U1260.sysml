package 'Electrical Power Transmission System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    package Definitions {
        attribute def ResistivityValue :> Real;

        item def ElectricalPower;
        attribute def PowerOnSignal;
        attribute def PowerOffSignal;
        attribute def OverloadSignal;

        port def PowerOutPort {
            out power : ElectricalPower;
        }

        port def PowerInPort {
            in power : ElectricalPower;
        }

        part def PowerSource {
            out port powerOut : PowerOutPort;
        }

        part def ElectricalLoad {
            in port powerIn : PowerInPort;
        }

        part def Conductor {
            attribute length : LengthValue;
            attribute crossSectionalArea : AreaValue;
            attribute resistivity : ResistivityValue;
            attribute resistance : ResistanceValue = (resistivity * length) / crossSectionalArea;
            attribute maxSafeCurrent : ElectricCurrentValue;
            attribute temperature : TemperatureValue;
            attribute current : ElectricCurrentValue;
        }

        part def Insulation {
            attribute thickness : LengthValue;
            attribute maxTemperature : TemperatureValue;
        }

        part def Wire {
            part conductor : Conductor;
            part insulation : Insulation;

            in port powerIn : PowerInPort;
            out port powerOut : PowerOutPort;

            attribute sourceVoltage : ElectricPotentialValue;
            attribute loadVoltage : ElectricPotentialValue;
            attribute voltageDrop : ElectricPotentialValue = sourceVoltage - loadVoltage;
            attribute powerLoss : PowerValue = conductor.resistance * conductor.current * conductor.current;
            attribute idleTempThreshold : TemperatureValue;

            exhibit state wireStates : WireStates;

            perform action transmitPower : TransmitPower;
            perform action monitorConditions : MonitorConditions;
        }

        state def WireStates;

        action def TransmitPower {
            in inputPower : ElectricalPower;
            out outputPower : ElectricalPower;
        }

        action def MonitorConditions {
            out current : ElectricCurrentValue;
            out temperature : TemperatureValue;
        }

        constraint def VoltageDropConstraint {
            in voltageDrop : ElectricPotentialValue;
            in sourceVoltage : ElectricPotentialValue;
            voltageDrop <= 0.03 * sourceVoltage
        }

        constraint def TemperatureConstraint {
            in wireTemperature : TemperatureValue;
            in maxInsulationTemp : TemperatureValue;
            wireTemperature < maxInsulationTemp
        }

        interface def PowerConnection {
            end supplier : PowerOutPort;
            end consumer : PowerInPort;
        }
    }

    package Usages {
        private import Definitions::*;

        part powerSource : PowerSource;
        part electricalLoad : ElectricalLoad;

        part wire : Wire {
            attribute sourceVoltage = 120 [V];
            attribute loadVoltage = 116.4 [V];
            attribute idleTempThreshold = 25.0 [degC];

            constraint voltageDropConstraint : VoltageDropConstraint {
                in voltageDrop = voltageDrop;
                in sourceVoltage = sourceVoltage;
            }

            constraint temperatureConstraint : TemperatureConstraint {
                in wireTemperature = conductor.temperature;
                in maxInsulationTemp = insulation.maxTemperature;
            }

            action transmitPower : TransmitPower;
            action monitorConditions : MonitorConditions;

            state wireStates : WireStates {
                entry; then idle;

                state idle;
                accept PowerOnSignal then conducting;

                state conducting {
                    do transmitPower;
                    do monitorConditions;
                }
                accept when monitorConditions.current > conductor.maxSafeCurrent then overload;
                accept PowerOffSignal then cooling;

                state overload {
                    do monitorConditions;
                }
                accept PowerOffSignal then cooling;

                state cooling;
                accept when monitorConditions.temperature <= idleTempThreshold then idle;
            }
        }

        interface : PowerConnection connect
            supplier ::> powerSource.powerOut to
            consumer ::> wire.powerIn;

        interface : PowerConnection connect
            supplier ::> wire.powerOut to
            consumer ::> electricalLoad.powerIn;
    }

    package Requirements {
        requirement 'Voltage Drop Limit' {
            doc /* The voltage drop along the wire shall not exceed 3% of the source voltage. */
        }

        requirement 'Temperature Limit' {
            doc /* The wire temperature shall remain below the insulation maximum temperature. */
        }

        requirement 'Current Limit' {
            doc /* The current shall not exceed the maximum safe rating of the wire. */
        }
    }
}
