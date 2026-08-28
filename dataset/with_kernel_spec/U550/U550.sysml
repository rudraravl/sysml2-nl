package HydraulicPumpingSubsystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        item def HydraulicFluid {
            attribute pressure : PressureValue;
            attribute temperature : TemperatureValue;
            attribute flowRate : VolumeFlowRateValue;
            attribute vaporPressure : PressureValue;
        }

        attribute def StartSignal;
        attribute def StopSignal;
        attribute def PrimingComplete;
        attribute def OverPressureAlert;
        attribute def HighTempAlert;
        attribute def CavitationAlert;

        port def FluidOutPort {
            out item fluid : HydraulicFluid;
        }
        port def FluidInPort {
            in item fluid : HydraulicFluid;
        }
        port def MechanicalDrivePort {
            attribute torque : TorqueValue;
            attribute rotationalSpeed : AngularVelocityValue;
        }
        port def PressureSignalPort {
            out pressure : PressureValue;
        }
        port def FlowRateSignalPort {
            out flowRate : VolumeFlowRateValue;
        }
        port def TemperatureSignalPort {
            out temperature : TemperatureValue;
        }

        part def ElectricMotor {
            port drivePort : MechanicalDrivePort;
            perform action rotateShaft;
        }

        part def Piston;
        part def Cylinder {
            port intakePort : FluidInPort;
            port exhaustPort : FluidOutPort;
        }
        part def CheckValve {
            port inlet : FluidInPort;
            port outlet : FluidOutPort;
        }

        part def RadialPistonPump {
            attribute pistonCount : Integer = 7;
            port drivePort : MechanicalDrivePort;
            port fluidInlet : FluidInPort;
            port fluidOutlet : FluidOutPort;

            part driveShaft;
            part camRing;
            part pistons[7] : Piston;
            part cylinders[7] : Cylinder;
            part intakeValves[7] : CheckValve;
            part dischargeValves[7] : CheckValve;

            perform action pumpFluid;
        }

        part def FluidReservoir {
            port fluidOutPort : FluidOutPort;
            port returnPort : FluidInPort;
            item fluid : HydraulicFluid;
            attribute capacity : VolumeValue;
        }

        part def Accumulator {
            port fluidInPort : FluidInPort;
            port fluidOutPort : FluidOutPort;
            attribute volume : VolumeValue;
            attribute prechargePressure : PressureValue;
        }

        part def ReliefValve {
            port fluidInPort : FluidInPort;
            port fluidOutPort : FluidOutPort;
            attribute maxPressure : PressureValue;
        }

        part def PressureTransducer {
            port fluidPort : FluidInPort;
            port signalPort : PressureSignalPort;
        }
        part def FlowMeter {
            port fluidInPort : FluidInPort;
            port fluidOutPort : FluidOutPort;
            port signalPort : FlowRateSignalPort;
        }
        part def TemperatureSensor {
            port fluidPort : FluidInPort;
            port signalPort : TemperatureSignalPort;
        }

        part def PumpController {
            port pressureIn : ~PressureSignalPort;
            port flowIn : ~FlowRateSignalPort;
            port tempIn : ~TemperatureSignalPort;
        }

        part def HydraulicPumpingSystem {
            attribute maxPressure : PressureValue = 350;
            attribute maxTemp : TemperatureValue = 80;
            attribute minFlowRate : VolumeFlowRateValue = 30;

            part motor : ElectricMotor;
            part pump : RadialPistonPump;
            part reservoir : FluidReservoir;
            part accumulator : Accumulator;
            part reliefValve : ReliefValve;
            part pressureTransducer : PressureTransducer;
            part flowMeter : FlowMeter;
            part tempSensor : TemperatureSensor;
            part controller : PumpController;

            connect motor.drivePort to pump.drivePort;

            flow of fluid : HydraulicFluid
                from reservoir.fluidOutPort.fluid to pump.fluidInlet.fluid;
            flow of fluid : HydraulicFluid
                from pump.fluidOutlet.fluid to accumulator.fluidInPort.fluid;
            flow of fluid : HydraulicFluid
                from accumulator.fluidOutPort.fluid to reliefValve.fluidInPort.fluid;
            flow of fluid : HydraulicFluid
                from reliefValve.fluidOutPort.fluid to reservoir.returnPort.fluid;

            flow of fluid : HydraulicFluid
                from pump.fluidOutlet.fluid to pressureTransducer.fluidPort.fluid;
            flow of fluid : HydraulicFluid
                from accumulator.fluidOutPort.fluid to flowMeter.fluidInPort.fluid;
            flow of fluid : HydraulicFluid
                from flowMeter.fluidOutPort.fluid to reservoir.returnPort.fluid;
            flow of fluid : HydraulicFluid
                from reservoir.fluidOutPort.fluid to tempSensor.fluidPort.fluid;

            connect pressureTransducer.signalPort to controller.pressureIn;
            connect flowMeter.signalPort to controller.flowIn;
            connect tempSensor.signalPort to controller.tempIn;

            exhibit state systemStates {
                entry; then startup;
                state startup;
                accept StartSignal then priming;
                state priming;
                accept PrimingComplete then normalOperation;
                state normalOperation;
                accept StopSignal then shutdown;
                accept when pressureTransducer.signalPort.pressure > maxPressure
                    do send new OverPressureAlert() to controller
                    then fault;
                accept when tempSensor.signalPort.temperature > maxTemp
                    do send new HighTempAlert() to controller
                    then fault;
                accept when flowMeter.signalPort.flowRate < minFlowRate
                    do send new CavitationAlert() to controller
                    then fault;
                state shutdown;
                state fault;
                accept StopSignal then shutdown;
            }
        }

        requirement def MaxPressureRequirement {
            doc /* The system pressure shall not exceed the maximum safe pressure. */
            attribute maxPressure : PressureValue = 350;
            subject pump : RadialPistonPump;
            require {
                pump.fluidOutlet.fluid.pressure <= maxPressure
            }
        }
        requirement def MinFlowRateRequirement {
            doc /* The subsystem shall deliver a minimum flow rate during normal operation. */
            attribute minFlowRate : VolumeFlowRateValue = 30;
            subject pump : RadialPistonPump;
            require {
                pump.fluidOutlet.fluid.flowRate >= minFlowRate
            }
        }
        requirement def TemperatureRangeRequirement {
            doc /* Hydraulic fluid temperature shall not exceed the maximum safe temperature. */
            attribute maxTemp : TemperatureValue = 80;
            subject system : HydraulicPumpingSystem;
            require {
                system.tempSensor.fluidPort.fluid.temperature <= maxTemp
            }
        }
        requirement def CavitationPreventionRequirement {
            doc /* Suction pressure shall be maintained above vapor pressure to prevent cavitation. */
            subject pump : RadialPistonPump;
            require {
                pump.fluidInlet.fluid.pressure > pump.fluidInlet.fluid.vaporPressure
            }
        }
    }

    public import Definitions::*;

    package Usages {
        private import Definitions::*;

        part hydraulicSystem : HydraulicPumpingSystem;
    }
}
