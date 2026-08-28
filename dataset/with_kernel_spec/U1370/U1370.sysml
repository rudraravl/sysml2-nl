package EductorJetPumpingSystem {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        attribute def Pressure :> Real;
        attribute def Velocity :> Real;
        attribute def MassFlowRate :> Real;

        item def Fluid {
            attribute pressure : Pressure;
            attribute velocity : Velocity;
            attribute massFlowRate : MassFlowRate;
        }

        item def MotiveFluid :> Fluid;
        item def SuctionFluid :> Fluid;
        item def MixedFluid :> Fluid;

        port def FluidOutPort {
            out item fluid : Fluid;
        }

        port def FluidInPort {
            in item fluid : Fluid;
        }

        action def AccelerateMotiveFluid {
            in motiveFluid : Fluid;
            out jetFluid : Fluid;
        }

        action def EntrainSuctionFluid {
            in jetFluid : Fluid;
            in suctionFluid : Fluid;
            out mixedFluid : Fluid;
        }

        action def MixFluids {
            in mixedFluid : Fluid;
            out throatFluid : Fluid;
        }

        action def DiffuseFluid {
            in throatFluid : Fluid;
            out dischargeFluid : Fluid;
        }

        action def PumpFluid {
            in motiveFluid : Fluid;
            in suctionFluid : Fluid;
            out dischargeFluid : Fluid;
        }

        part def ConvergingNozzle {
            port motiveIn : FluidInPort;
            port jetOut : FluidOutPort;
        }

        part def SuctionChamber {
            port jetIn : FluidInPort;
            port suctionIn : FluidInPort;
            port mixedOut : FluidOutPort;
        }

        part def MixingThroat {
            port mixedIn : FluidInPort;
            port throatOut : FluidOutPort;
        }

        part def DivergingDiffuser {
            port diffuserIn : FluidInPort;
            port dischargeOut : FluidOutPort;
        }

        part def EductorJetPump {
            port motiveIn : FluidInPort;
            port suctionIn : FluidInPort;
            port dischargeOut : FluidOutPort;

            part nozzle : ConvergingNozzle;
            part chamber : SuctionChamber;
            part throat : MixingThroat;
            part diffuser : DivergingDiffuser;

            flow of MotiveFluid from motiveIn.fluid to nozzle.motiveIn.fluid;
            flow of MotiveFluid from nozzle.jetOut.fluid to chamber.jetIn.fluid;
            flow of SuctionFluid from suctionIn.fluid to chamber.suctionIn.fluid;
            flow of MixedFluid from chamber.mixedOut.fluid to throat.mixedIn.fluid;
            flow of MixedFluid from throat.throatOut.fluid to diffuser.diffuserIn.fluid;
            flow of MixedFluid from diffuser.dischargeOut.fluid to dischargeOut.fluid;
        }

        part def HighPressureSource {
            port supplyOut : FluidOutPort;
        }

        part def SuctionReservoir {
            port suctionOut : FluidOutPort;
        }

        part def DischargeDestination {
            port dischargeIn : FluidInPort;
        }

        attribute def StartSignal;
        attribute def MotiveFlowEstablished;
        attribute def StopSignal;
        attribute def ShutdownComplete;
        attribute def FlowFluctuation;
        attribute def FlowStabilized;

        state def EductorLifecycle {
            in pump : EductorJetPump;
            entry; then idle;
            state idle;
            accept StartSignal then starting;
            state starting;
            accept MotiveFlowEstablished then operating;
            state operating {
                entry; then steady;
                state steady;
                accept FlowFluctuation then fluctuating;
                state fluctuating;
                accept FlowStabilized then steady;
            }
            accept StopSignal then stopping;
            state stopping;
            accept ShutdownComplete then idle;
        }

        requirement def NoMovingPartsReq {
            doc /* The eductor-jet pump shall contain no moving mechanical components to ensure simplicity and reliability. */
        }

        requirement def VenturiPrincipleReq {
            doc /* The pump shall operate on the Venturi principle, converting motive fluid pressure to velocity in the converging nozzle and velocity back to pressure in the diverging diffuser. */
        }

        requirement def DischargePressureReq {
            doc /* The discharge fluid pressure shall be higher than the suction fluid starting pressure, enabling transfer to the desired destination. */
        }

        requirement def LifecycleReq {
            doc /* The system shall follow a defined lifecycle transitioning through idle, starting, operating, and stopping states with monitored flow conditions. */
        }
    }

    package Usages {
        public import Definitions::*;

        part context {
            part highPressureSource : HighPressureSource;
            part suctionReservoir : SuctionReservoir;
            part eductorPump : EductorJetPump {
                perform action pumpFluid : PumpFluid {
                    in motiveFluid = motiveIn.fluid;
                    in suctionFluid = suctionIn.fluid;
                    out dischargeFluid = dischargeOut.fluid;

                    action accelerate : AccelerateMotiveFluid {
                        in motiveFluid = pumpFluid.motiveFluid;
                    }
                    action entrain : EntrainSuctionFluid {
                        in suctionFluid = pumpFluid.suctionFluid;
                    }
                    action mix : MixFluids;
                    action diffuse : DiffuseFluid;

                    flow accelerate.jetFluid to entrain.jetFluid;
                    flow entrain.mixedFluid to mix.mixedFluid;
                    flow mix.throatFluid to diffuse.throatFluid;
                    flow diffuse.dischargeFluid to pumpFluid.dischargeFluid;

                    first start;
                    then accelerate;
                    then entrain;
                    then mix;
                    then diffuse;
                }
            }
            part dischargeDestination : DischargeDestination;

            flow of MotiveFluid from highPressureSource.supplyOut.fluid to eductorPump.motiveIn.fluid;
            flow of SuctionFluid from suctionReservoir.suctionOut.fluid to eductorPump.suctionIn.fluid;
            flow of MixedFluid from eductorPump.dischargeOut.fluid to dischargeDestination.dischargeIn.fluid;

            state eductorLifecycle : EductorLifecycle {
                in pump = eductorPump;
            }

            satisfy requirement NoMovingPartsReq by eductorPump;
            satisfy requirement VenturiPrincipleReq by eductorPump;
            satisfy requirement DischargePressureReq by eductorPump;
            satisfy requirement LifecycleReq by eductorLifecycle;
        }
    }
}
