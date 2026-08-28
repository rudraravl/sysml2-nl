package 'EnergyRecoveringPumpingSystem' {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ISQ::PressureValue;
    private import ISQ::VolumeFlowRateValue;
    private import ISQ::TorqueValue;
    private import ISQ::AngularVelocityValue;

    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        item def Fluid;

        port def FluidOutPort {
            out item fluid : Fluid;
            out attribute pressure : PressureValue;
            out attribute flowRate : VolumeFlowRateValue;
        }

        port def MechPowerPort {
            out attribute torque : TorqueValue;
            out attribute speed : AngularVelocityValue;
        }

        state machine def PATStateMachine {
            state idle;
            state starting;
            state operating {
                state normal;
                state highFlow;
                state lowFlow;
                transition normal to highFlow;
                transition highFlow to normal;
                transition normal to lowFlow;
                transition lowFlow to normal;
            }
            state stopping;
            transition idle to starting;
            transition starting to operating;
            transition operating to stopping;
            transition stopping to idle;
        }

        state machine def PumpStateMachine {
            state idle;
            state starting;
            state operating {
                state normal;
                state highFlow;
                state lowFlow;
                transition normal to highFlow;
                transition highFlow to normal;
                transition normal to lowFlow;
                transition lowFlow to normal;
            }
            state stopping;
            transition idle to starting;
            transition starting to operating;
            transition operating to stopping;
            transition stopping to idle;
        }

        part def HighPressureReservoir {
            port fluidOutPort : FluidOutPort;
            attribute volume : Real;
            attribute currentPressure : PressureValue;
        }

        part def LowPressureReservoir {
            port fluidInPort : ~FluidOutPort;
            port fluidOutPort : FluidOutPort;
            attribute volume : Real;
            attribute currentPressure : PressureValue;
        }

        part def DischargePoint {
            port fluidInPort : ~FluidOutPort;
            attribute targetPressure : PressureValue;
        }

        part def PumpAsTurbine {
            port fluidInPort : ~FluidOutPort;
            port fluidOutPort : FluidOutPort;
            port shaftOutPort : MechPowerPort;
            attribute efficiency : Real;
            attribute ratedSpeed : AngularVelocityValue;
            in attribute startCmd : Boolean;
            in attribute stopCmd : Boolean;
            in attribute highFlowCmd : Boolean;
            in attribute lowFlowCmd : Boolean;
            in attribute normalFlowCmd : Boolean;
        }

        part def MainPump {
            port fluidInPort : ~FluidOutPort;
            port fluidOutPort : FluidOutPort;
            port shaftInPort : ~MechPowerPort;
            attribute efficiency : Real;
            attribute ratedSpeed : AngularVelocityValue;
            in attribute startCmd : Boolean;
            in attribute stopCmd : Boolean;
            in attribute highFlowCmd : Boolean;
            in attribute lowFlowCmd : Boolean;
            in attribute normalFlowCmd : Boolean;
        }

        part def MechanicalCoupling {
            port shaftInPort : ~MechPowerPort;
            port shaftOutPort : MechPowerPort;
            attribute couplingEfficiency : Real;
        }

        part def PressureSensor {
            port fluidInPort : ~FluidOutPort;
            out attribute reading : PressureValue;
        }

        part def FlowRateSensor {
            port fluidInPort : ~FluidOutPort;
            out attribute reading : VolumeFlowRateValue;
        }

        part def Controller {
            out attribute startCmd : Boolean;
            out attribute stopCmd : Boolean;
            out attribute highFlowCmd : Boolean;
            out attribute lowFlowCmd : Boolean;
            out attribute normalFlowCmd : Boolean;
            in attribute patPressureIn : PressureValue;
            in attribute patPressureOut : PressureValue;
            in attribute pumpPressureOut : PressureValue;
            in attribute patFlowRate : VolumeFlowRateValue;
            in attribute pumpFlowRate : VolumeFlowRateValue;
        }

        action def RecoverEnergy {
            in fluidIn : Fluid;
            in pressureIn : PressureValue;
            out fluidOut : Fluid;
            out pressureOut : PressureValue;
            out torque : TorqueValue;
            out speed : AngularVelocityValue;
        }

        action def PumpFluid {
            in fluidIn : Fluid;
            in pressureIn : PressureValue;
            in torque : TorqueValue;
            in speed : AngularVelocityValue;
            out fluidOut : Fluid;
            out pressureOut : PressureValue;
        }

        requirement def EnergyRecoveryRequirement {
            doc /* The system shall recover energy from a high-pressure fluid stream using a PAT and use that energy to power a main pump. */
        }

        requirement def PumpingRequirement {
            doc /* The system shall move fluid from a low-pressure source to a high-pressure destination. */
        }

        part def EnergyRecoveringPumpingSystem {
            part highPressureReservoir : HighPressureReservoir;
            part pat : PumpAsTurbine;
            part lowPressureReservoir : LowPressureReservoir;
            part mainPump : MainPump;
            part mechanicalCoupling : MechanicalCoupling;
            part dischargePoint : DischargePoint;
            part patInPressureSensor : PressureSensor;
            part patOutPressureSensor : PressureSensor;
            part pumpOutPressureSensor : PressureSensor;
            part patFlowSensor : FlowRateSensor;
            part pumpFlowSensor : FlowRateSensor;
            part controller : Controller;
        }
    }

    package Usages {
        part system : EnergyRecoveringPumpingSystem {
            satisfy EnergyRecoveryRequirement;
            satisfy PumpingRequirement;

            part highPressureReservoir : HighPressureReservoir {
                attribute volume : Real = 1000;
                attribute currentPressure : PressureValue = 500000;
            }

            flow of fluid : Fluid
                from highPressureReservoir.fluidOutPort.fluid to pat.fluidInPort.fluid;

            part pat : PumpAsTurbine {
                attribute efficiency : Real = 0.85;
                attribute ratedSpeed : AngularVelocityValue = 1500;
                perform patSM : PATStateMachine;
                perform action recoverEnergy : RecoverEnergy {
                    in fluidIn = fluidInPort.fluid;
                    in pressureIn = fluidInPort.pressure;
                    out fluidOut = fluidOutPort.fluid;
                    out pressureOut = fluidOutPort.pressure;
                    out torque = shaftOutPort.torque;
                    out speed = shaftOutPort.speed;
                }
            }

            flow of fluid : Fluid
                from pat.fluidOutPort.fluid to lowPressureReservoir.fluidInPort.fluid;

            part lowPressureReservoir : LowPressureReservoir {
                attribute volume : Real = 800;
                attribute currentPressure : PressureValue = 100000;
            }

            flow of fluid : Fluid
                from lowPressureReservoir.fluidOutPort.fluid to mainPump.fluidInPort.fluid;

            part mainPump : MainPump {
                attribute efficiency : Real = 0.80;
                attribute ratedSpeed : AngularVelocityValue = 1500;
                perform pumpSM : PumpStateMachine;
                perform action pumpFluid : PumpFluid {
                    in fluidIn = fluidInPort.fluid;
                    in pressureIn = fluidInPort.pressure;
                    in torque = shaftInPort.torque;
                    in speed = shaftInPort.speed;
                    out fluidOut = fluidOutPort.fluid;
                    out pressureOut = fluidOutPort.pressure;
                }
            }

            flow of fluid : Fluid
                from mainPump.fluidOutPort.fluid to dischargePoint.fluidInPort.fluid;

            part dischargePoint : DischargePoint {
                attribute targetPressure : PressureValue = 400000;
            }

            part mechanicalCoupling : MechanicalCoupling {
                attribute couplingEfficiency : Real = 0.98;
            }

            part patInPressureSensor : PressureSensor;
            part patOutPressureSensor : PressureSensor;
            part pumpOutPressureSensor : PressureSensor;
            part patFlowSensor : FlowRateSensor;
            part pumpFlowSensor : FlowRateSensor;
            part controller : Controller;

            bind patInPressureSensor.fluidInPort = highPressureReservoir.fluidOutPort;
            bind patOutPressureSensor.fluidInPort = pat.fluidOutPort;
            bind pumpOutPressureSensor.fluidInPort = mainPump.fluidOutPort;
            bind patFlowSensor.fluidInPort = pat.fluidOutPort;
            bind pumpFlowSensor.fluidInPort = mainPump.fluidOutPort;

            bind pat.shaftOutPort.torque = mechanicalCoupling.shaftInPort.torque;
            bind pat.shaftOutPort.speed = mechanicalCoupling.shaftInPort.speed;
            bind mechanicalCoupling.shaftOutPort.torque = mainPump.shaftInPort.torque;
            bind mechanicalCoupling.shaftOutPort.speed = mainPump.shaftInPort.speed;

            bind patInPressureSensor.reading = controller.patPressureIn;
            bind patOutPressureSensor.reading = controller.patPressureOut;
            bind pumpOutPressureSensor.reading = controller.pumpPressureOut;
            bind patFlowSensor.reading = controller.patFlowRate;
            bind pumpFlowSensor.reading = controller.pumpFlowRate;

            bind pat.startCmd = controller.startCmd;
            bind pat.stopCmd = controller.stopCmd;
            bind pat.highFlowCmd = controller.highFlowCmd;
            bind pat.lowFlowCmd = controller.lowFlowCmd;
            bind pat.normalFlowCmd = controller.normalFlowCmd;

            bind mainPump.startCmd = controller.startCmd;
            bind mainPump.stopCmd = controller.stopCmd;
            bind mainPump.highFlowCmd = controller.highFlowCmd;
            bind mainPump.lowFlowCmd = controller.lowFlowCmd;
            bind mainPump.normalFlowCmd = controller.normalFlowCmd;
        }
    }
}
