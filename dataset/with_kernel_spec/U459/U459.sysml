package IndustrialFluidTransportSystem {
    private import ISQ::*;
    private import ScalarValues::*;
    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        public import AttributeDefinitions::*;
        public import ItemDefinitions::*;
        public import PortDefinitions::*;
        public import ActionDefinitions::*;
        public import StateDefinitions::*;
        public import PartDefinitions::*;
        public import RequirementDefinitions::*;

        package AttributeDefinitions {
            attribute def StartCmd;
            attribute def StopCmd;
            attribute def ResetCmd;
            attribute def LowFlowAlert;
            attribute def NormalFlowRestored;
            attribute def OverPressureAlert;
            attribute def SpeedSetpoint :> ISQ::AngularVelocity;
        }

        package ItemDefinitions {
            item def Fluid {
                attribute density :> ISQ::MassDensity;
                attribute viscosity :> ISQ::DynamicViscosity;
            }
            item def PressurizedFluid :> Fluid {
                attribute pressure :> ISQ::Pressure;
            }
        }

        package PortDefinitions {
            private import ItemDefinitions::*;
            private import AttributeDefinitions::*;

            port def FluidInPort {
                in fluid : Fluid;
            }
            port def FluidOutPort {
                out fluid : Fluid;
            }
            port def PressurizedFluidOutPort {
                out fluid : PressurizedFluid;
            }
            port def FlowReadingOutPort {
                out flowReading :> ISQ::VolumeFlowRate;
            }
            port def FlowReadingInPort {
                in flowReading :> ISQ::VolumeFlowRate;
            }
            port def PressureReadingOutPort {
                out pressureReading :> ISQ::Pressure;
            }
            port def PressureReadingInPort {
                in pressureReading :> ISQ::Pressure;
            }
            port def SpeedCmdInPort {
                in speedCmd :> ISQ::AngularVelocity;
            }
            port def SpeedCmdOutPort {
                out speedCmd :> ISQ::AngularVelocity;
            }
            port def CmdInPort {
                in startCmd : StartCmd;
                in stopCmd : StopCmd;
                in resetCmd : ResetCmd;
            }
        }

        package ActionDefinitions {
            private import ItemDefinitions::*;
            private import AttributeDefinitions::*;

            action def ProvideFlow {
                in fluidIn : Fluid;
                out fluidOut : PressurizedFluid;
            }
            action def AdjustMotorSpeed {
                in setpoint : SpeedSetpoint;
                in flowReading :> ISQ::VolumeFlowRate;
                in pressureReading :> ISQ::Pressure;
                out speedCmd :> ISQ::AngularVelocity;
            }
            action def MonitorSensors {
                in flowReading :> ISQ::VolumeFlowRate;
                in pressureReading :> ISQ::Pressure;
                out lowFlow : LowFlowAlert;
                out overPressure : OverPressureAlert;
                out normal : NormalFlowRestored;
            }
        }

        package StateDefinitions {
            state def TransportStates;
        }

        package PartDefinitions {
            private import AttributeDefinitions::*;
            private import ItemDefinitions::*;
            private import PortDefinitions::*;
            private import ActionDefinitions::*;
            private import StateDefinitions::*;

            part def SourceTank {
                attribute capacity :> ISQ::Volume;
                attribute fillLevel :> ISQ::Volume;
                port outletPort : FluidOutPort;
            }

            part def DestinationTank {
                attribute capacity :> ISQ::Volume;
                attribute fillLevel :> ISQ::Volume;
                port inletPort : FluidInPort;
            }

            part def Pipe {
                attribute length :> ISQ::Length;
                attribute innerDiameter :> ISQ::Length;
                port inletPort : FluidInPort;
                port outletPort : FluidOutPort;
            }

            part def IsolationValve {
                attribute openPosition : Real;
                port inletPort : FluidInPort;
                port outletPort : FluidOutPort;
            }

            part def RegulationValve {
                attribute openPosition : Real;
                port inletPort : FluidInPort;
                port outletPort : FluidOutPort;
            }

            part def FlowMeter {
                attribute measuredFlow :> ISQ::VolumeFlowRate;
                attribute lowFlowThreshold :> ISQ::VolumeFlowRate;
                port inletPort : FluidInPort;
                port outletPort : FluidOutPort;
                port readingPort : FlowReadingOutPort;
            }

            part def PressureSensor {
                attribute measuredPressure :> ISQ::Pressure;
                attribute maxPressure :> ISQ::Pressure;
                port inletPort : FluidInPort;
                port outletPort : FluidOutPort;
                port readingPort : PressureReadingOutPort;
            }

            part def ElectricMotor {
                attribute ratedPower :> ISQ::Power;
                attribute maxSpeed :> ISQ::AngularVelocity;
                attribute currentSpeed :> ISQ::AngularVelocity;
                port speedCmdPort : SpeedCmdInPort;
            }

            part def Shaft {
                attribute material : String = "316 stainless steel";
                attribute length :> ISQ::Length;
                attribute diameter :> ISQ::Length;
            }

            part def Bearing {
                attribute loadRating :> ISQ::Force;
                attribute bearingType : String;
            }

            part def Impeller {
                attribute bladeCount : Integer = 6;
                attribute diameter :> ISQ::Length;
            }

            part def PumpCasing {
                attribute material : String = "cast iron";
                attribute inletDiameter :> ISQ::Length;
                attribute outletDiameter :> ISQ::Length;
                port casingInlet : FluidInPort;
                port casingOutlet : PressurizedFluidOutPort;
            }

            part def MechanicalSeal {
                attribute material : String = "silicon carbide";
            }

            part def CentrifugalPump {
                attribute targetSpeed :> ISQ::AngularVelocity;
                attribute speed :> ISQ::AngularVelocity;
                port inletPort : FluidInPort;
                port outletPort : PressurizedFluidOutPort;
                port speedCmdPort : SpeedCmdInPort;

                part motor : ElectricMotor;
                part shaft : Shaft;
                part radialBearing : Bearing {
                    :>> bearingType = "radial";
                }
                part thrustBearing : Bearing {
                    :>> bearingType = "thrust";
                }
                part impeller : Impeller;
                part casing : PumpCasing;
                part seal1 : MechanicalSeal;
                part seal2 : MechanicalSeal;

                bind inletPort = casing.casingInlet;
                bind outletPort = casing.casingOutlet;
                bind speedCmdPort = motor.speedCmdPort;

                perform action provideFlow : ProvideFlow;
            }

            part def FluidController {
                attribute setpoint : SpeedSetpoint;
                attribute targetFlowRate :> ISQ::VolumeFlowRate;
                attribute maxOperatingPressure :> ISQ::Pressure;
                attribute lowFlowThreshold :> ISQ::VolumeFlowRate;
                attribute flowRestored : Boolean;
                port cmdPort : CmdInPort;
                port flowSensorPort : FlowReadingInPort;
                port pressureSensorPort : PressureReadingInPort;
                port speedCmdPort : SpeedCmdOutPort;

                perform action adjustMotorSpeed : AdjustMotorSpeed;
                perform action monitorSensors : MonitorSensors;
            }

            part def AutomatedFluidTransportSystem {
                port cmdPort : CmdInPort;
                attribute targetFlowRate :> ISQ::VolumeFlowRate;
                attribute maxOperatingPressure :> ISQ::Pressure;

                part sourceTank : SourceTank;
                part suctionPipe : Pipe;
                part isolationValve : IsolationValve;
                part pump : CentrifugalPump;
                part dischargePipe : Pipe;
                part regulationValve : RegulationValve;
                part flowMeter : FlowMeter;
                part pressureSensor : PressureSensor;
                part destinationTank : DestinationTank;
                part controller : FluidController;

                connect sourceTank.outletPort to suctionPipe.inletPort;
                connect suctionPipe.outletPort to isolationValve.inletPort;
                connect isolationValve.outletPort to pump.inletPort;
                connect pump.outletPort to dischargePipe.inletPort;
                connect dischargePipe.outletPort to regulationValve.inletPort;
                connect regulationValve.outletPort to flowMeter.inletPort;
                connect flowMeter.outletPort to pressureSensor.inletPort;
                connect pressureSensor.outletPort to destinationTank.inletPort;

                connect flowMeter.readingPort to controller.flowSensorPort;
                connect pressureSensor.readingPort to controller.pressureSensorPort;
                connect controller.speedCmdPort to pump.speedCmdPort;
                bind cmdPort = controller.cmdPort;

                exhibit state transportStates : TransportStates {
                    entry; then idle;

                    state idle;
                    transition idle_to_starting
                        first idle
                        accept StartCmd via cmdPort
                        then starting;

                    state starting;
                    transition starting_to_operating
                        first starting
                        accept when pump.speed >= pump.targetSpeed
                        then operating;

                    state operating {
                        do controller.adjustMotorSpeed;
                        do controller.monitorSensors;
                    }
                    transition operating_to_lowFlow
                        first operating
                        accept LowFlowAlert
                        then low_flow;
                    transition operating_to_stopping
                        first operating
                        accept StopCmd via cmdPort
                        then stopping;
                    transition operating_to_fault
                        first operating
                        accept OverPressureAlert
                        then fault;

                    state low_flow;
                    transition lowFlow_to_operating
                        first low_flow
                        accept NormalFlowRestored
                        then operating;
                    transition lowFlow_to_stopping
                        first low_flow
                        accept StopCmd via cmdPort
                        then stopping;
                    transition lowFlow_to_fault
                        first low_flow
                        accept OverPressureAlert
                        then fault;

                    state stopping;
                    transition stopping_to_idle
                        first stopping
                        accept when pump.speed == 0
                        then idle;

                    state fault;
                    transition fault_to_idle
                        first fault
                        accept ResetCmd via cmdPort
                        then idle;
                }
            }
        }

        package RequirementDefinitions {
            requirement def PreciseFlowControl {
                attribute targetFlowRate :> ISQ::VolumeFlowRate;
                attribute flowTolerance :> ISQ::VolumeFlowRate;
                attribute maxPressure :> ISQ::Pressure;
                doc { /*
                    The system shall autonomously transport fluid from a source tank
                    to a destination tank at a flow rate within flowTolerance of
                    targetFlowRate while keeping pressure below maxPressure.
                    */ }
            }

            requirement def SafetyInterlock {
                doc { /*
                    The fault state shall require a manual ResetCmd to exit
                    and return the system to its idle state.
                    */ }
            }

            requirement def LowFlowDetection {
                attribute lowFlowThreshold :> ISQ::VolumeFlowRate;
                doc { /*
                    The controller shall detect a low-flow condition when measured
                    flow falls below lowFlowThreshold and transition to low_flow.
                    */ }
            }
        }
    }

    package Usages {
        private import Definitions::*;

        part 'automated fluid transport system' : AutomatedFluidTransportSystem {
            attribute targetFlowRate :> ISQ::VolumeFlowRate = 50 [L/min];
            attribute maxOperatingPressure :> ISQ::Pressure = 1000 [kPa];
        }

        requirement 'precise flow control' : PreciseFlowControl {
            attribute targetFlowRate :> ISQ::VolumeFlowRate = 50 [L/min];
            attribute flowTolerance :> ISQ::VolumeFlowRate = 1 [L/min];
            attribute maxPressure :> ISQ::Pressure = 1000 [kPa];
        }

        requirement 'safety interlock' : SafetyInterlock;

        requirement 'low flow detection' : LowFlowDetection {
            attribute lowFlowThreshold :> ISQ::VolumeFlowRate = 5 [L/min];
        }
    }
}
