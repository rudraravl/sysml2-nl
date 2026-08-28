package 'Piston Pump System' {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ISQ::PressureValue;
    private import ISQ::VolumeValue;
    private import ISQ::TorqueValue;
    private import ISQ::LengthValue;
    private import ISQ::AngularVelocityValue;
    private import ISQ::Pa;

    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        item def Fluid;

        attribute def StartCmd;
        attribute def StopCmd;
        attribute def PrimingComplete;
        attribute def TopDeadCenter;
        attribute def BottomDeadCenter;

        port def FluidPort {
            out item fluid : Fluid;
        }

        part def Reservoir {
            port fluidOutPort : FluidPort;
            attribute pressure : PressureValue;
        }

        part def Receiver {
            port fluidInPort : ~FluidPort;
            attribute pressure : PressureValue;
        }

        part def CheckValve {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            attribute isOpen : Boolean;
            attribute crackingPressure : PressureValue;
        }

        part def Cylinder {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            attribute pressure : PressureValue;
            attribute volume : VolumeValue;
            attribute boreDiameter : LengthValue;
            attribute strokeLength : LengthValue;
        }

        part def Piston {
            attribute position : LengthValue;
        }

        part def CrankshaftDrive {
            attribute torque : TorqueValue;
            attribute rotationalSpeed : AngularVelocityValue;
        }

        part def PistonPump {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;

            part crankshaft : CrankshaftDrive;
            part piston : Piston;
            part cylinder : Cylinder;
            part inletValve : CheckValve;
            part outletValve : CheckValve;

            flow of fluid : Fluid
                from fluidInPort.fluid to inletValve.fluidInPort.fluid;
            flow of fluid : Fluid
                from inletValve.fluidOutPort.fluid to cylinder.fluidInPort.fluid;
            flow of fluid : Fluid
                from cylinder.fluidOutPort.fluid to outletValve.fluidInPort.fluid;
            flow of fluid : Fluid
                from outletValve.fluidOutPort.fluid to fluidOutPort.fluid;
        }

        action def IntakeStroke {
            in piston : Piston;
            in cylinder : Cylinder;
            out fluidDrawn : Fluid;
        }

        action def DischargeStroke {
            in piston : Piston;
            in cylinder : Cylinder;
            out fluidDischarged : Fluid;
        }

        action def PrimePump;
        action def ShutdownPump;

        state def PumpStates {
            in pump : PistonPump;
            entry; then idle;

            state idle;
            accept StartCmd then priming;

            state priming {
                do action prime : PrimePump;
            }
            accept PrimingComplete then operating;

            state operating {
                do action runCycle {
                    loop {
                        action intake : IntakeStroke {
                            in piston = pump.piston;
                            in cylinder = pump.cylinder;
                        }
                        then accept bdc : BottomDeadCenter;
                        then action discharge : DischargeStroke {
                            in piston = pump.piston;
                            in cylinder = pump.cylinder;
                        }
                        then accept tdc : TopDeadCenter;
                    }
                }
            }
            accept StopCmd then shutdown;

            state shutdown {
                do action shutdownPump : ShutdownPump;
            }
            then idle;
        }

        requirement def PositiveDisplacement {
            doc
            /*
             * The pump shall transfer fluid by mechanically trapping a fixed volume
             * and forcing it into the discharge pipe.
             */
            attribute displacementVolume : VolumeValue;
        }

        requirement def CheckValveOperation {
            doc
            /*
             * The inlet check valve shall open when cylinder pressure is below
             * reservoir pressure. The outlet check valve shall open when cylinder
             * pressure exceeds receiver pressure.
             */
        }

        requirement def TwoStrokeCycle {
            doc
            /*
             * The pump shall complete one intake stroke and one discharge stroke
             * per full rotation of the crankshaft.
             */
        }
    }

    package Usages {
        part context {
            part reservoir : Reservoir {
                attribute redefines pressure = 101325 [Pa];
            }

            flow of fluid : Fluid
                from reservoir.fluidOutPort.fluid to pump.fluidInPort.fluid;

            part pump : PistonPump {
                state pumpStates : PumpStates {
                    in pump = self;
                }
            }

            flow of fluid : Fluid
                from pump.fluidOutPort.fluid to receiver.fluidInPort.fluid;

            part receiver : Receiver {
                attribute redefines pressure = 500000 [Pa];
            }

            requirement positiveDisplacement : PositiveDisplacement;
            requirement checkValveOperation : CheckValveOperation;
            requirement twoStrokeCycle : TwoStrokeCycle;
        }
    }
}
