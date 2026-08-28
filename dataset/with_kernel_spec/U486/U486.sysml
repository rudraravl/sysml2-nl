package 'Fluid Pumping System' {
    private import ScalarValues::Real;
    private import ScalarValues::Integer;
    private import ScalarValues::Boolean;
    private import ScalarValues::String;

    package Definitions {
        item def Fluid;
        item def CompressedAir;

        attribute def Pressure :> Real;
        attribute def FlowRate :> Real;
        attribute def Frequency :> Real;
        attribute def Efficiency :> Real;
        attribute def CycleLife :> Integer;
        attribute def Displacement :> Real;
        attribute def Volume :> Real;

        port def FluidPort {
            out item fluid : Fluid;
        }

        port def PneumaticPort {
            in item air : CompressedAir;
        }

        port def PressureSignalPort {
            out attribute pressure : Pressure;
        }

        port def FlowSignalPort {
            out attribute flowRate : FlowRate;
        }

        part def Reservoir {
            port fluidOutPort : FluidPort;
            attribute capacity : Volume = 100.0;
            attribute currentLevel : Volume = 80.0;
            item storedFluid : Fluid;
        }

        part def Diaphragm {
            attribute material : String = "PTFE";
            attribute maxDisplacement : Displacement = 10.0;
            attribute currentDisplacement : Displacement = 0.0;
            attribute cycleLife : CycleLife = 10000000;
        }

        part def PneumaticActuator {
            port airInPort : PneumaticPort;
            attribute strokeLength : Displacement = 10.0;
            attribute isRetracted : Boolean = false;
        }

        part def CheckValve {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            attribute crackingPressure : Pressure = 0.1;
            attribute isOpen : Boolean = false;
        }

        part def PumpChamber {
            attribute maxVolume : Volume = 50.0;
            attribute minVolume : Volume = 5.0;
            attribute currentVolume : Volume = 5.0;
            attribute pressure : Pressure = 1.0;
            item fluid : Fluid;
        }

        action def IntakeStroke {
            doc /* Actuator retracts the diaphragm, increasing chamber volume. Inlet check valve opens. */
        }

        action def DischargeStroke {
            doc /* Actuator pushes diaphragm forward, decreasing chamber volume. Outlet check valve opens. */
        }

        part def DiaphragmPump {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            port airInPort : PneumaticPort;
            port inletPressurePort : ~PressureSignalPort;
            port outletPressurePort : ~PressureSignalPort;
            port flowPort : ~FlowSignalPort;

            part diaphragm : Diaphragm;
            part actuator : PneumaticActuator;
            part chamber : PumpChamber;
            part inletValve : CheckValve;
            part outletValve : CheckValve;

            attribute cycleFrequency : Frequency = 2.0;
            attribute operatingPressure : Pressure;
            attribute outputFlowRate : FlowRate;
            attribute efficiency : Efficiency = 85.0;

            bind fluidInPort = inletValve.fluidInPort;
            bind fluidOutPort = outletValve.fluidOutPort;
            bind airInPort = actuator.airInPort;

            flow of fluid : Fluid
                from inletValve.fluidOutPort.fluid to chamber.fluid;
            flow of fluid : Fluid
                from chamber.fluid to outletValve.fluidInPort.fluid;

            state pumpCycle {
                entry; then Intake;

                state Intake {
                    do action intakeStroke : IntakeStroke;
                }
                transition Intake to Discharge
                    when chamber.currentVolume >= chamber.maxVolume;

                state Discharge {
                    do action dischargeStroke : DischargeStroke;
                }
                transition Discharge to Intake
                    when chamber.currentVolume <= chamber.minVolume;
            }
        }

        part def ProcessEquipment {
            port fluidInPort : ~FluidPort;
            attribute requiredPressure : Pressure = 2.0;
            item receivedFluid : Fluid;
        }

        part def PressureSensor {
            port signalOutPort : PressureSignalPort;
            attribute measuredPressure : Pressure;
        }

        part def FlowSensor {
            port signalOutPort : FlowSignalPort;
            attribute measuredFlowRate : FlowRate;
        }

        part def CompressedAirSupply {
            port airOutPort : ~PneumaticPort;
            attribute supplyPressure : Pressure = 6.0;
        }

        requirement def MinFlowRateRequirement {
            doc /* The pump shall deliver a minimum flow rate of 5 L/min. */
            attribute minFlowRate : FlowRate = 5.0;
            constraint { outputFlowRate >= minFlowRate }
        }

        requirement def MinPressureRequirement {
            doc /* The pump shall deliver a minimum discharge pressure of 2 bar. */
            attribute minPressure : Pressure = 2.0;
            constraint { operatingPressure >= minPressure }
        }

        requirement def EfficiencyRequirement {
            doc /* The pump shall operate at a minimum efficiency of 80 percent. */
            attribute minEfficiency : Efficiency = 80.0;
            constraint { efficiency >= minEfficiency }
        }

        requirement def CycleLifeRequirement {
            doc /* The diaphragm shall have a minimum cycle life of 10 million cycles. */
            attribute minCycleLife : CycleLife = 10000000;
            constraint { cycleLife >= minCycleLife }
        }
    }

    package Usages {
        private import Definitions::*;

        part pumpingSystem {
            part reservoir : Reservoir;
            part pump : DiaphragmPump;
            part equipment : ProcessEquipment;
            part airSupply : CompressedAirSupply;
            part inletPressureSensor : PressureSensor;
            part outletPressureSensor : PressureSensor;
            part flowSensor : FlowSensor;

            flow of fluid : Fluid
                from reservoir.fluidOutPort.fluid to pump.fluidInPort.fluid;
            flow of fluid : Fluid
                from pump.fluidOutPort.fluid to equipment.fluidInPort.fluid;
            flow of air : CompressedAir
                from airSupply.airOutPort.air to pump.airInPort.air;

            bind inletPressureSensor.signalOutPort = pump.inletPressurePort;
            bind outletPressureSensor.signalOutPort = pump.outletPressurePort;
            bind flowSensor.signalOutPort = pump.flowPort;

            requirement minFlowReq : MinFlowRateRequirement;
            requirement minPressureReq : MinPressureRequirement;
            requirement efficiencyReq : EfficiencyRequirement;
            requirement cycleLifeReq : CycleLifeRequirement;

            satisfy minFlowReq by pump;
            satisfy minPressureReq by pump;
            satisfy efficiencyReq by pump;
            satisfy cycleLifeReq by pump.diaphragm;
        }
    }
}
