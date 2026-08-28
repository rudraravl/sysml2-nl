package 'Volute Centrifugal Pump System' {
    package Definitions {
        import ISQ::*;
        import ScalarValues::*;

        item def Fluid {
            attribute pressure : ISQ::PressureValue;
            attribute flowRate : ISQ::VolumeFlowRateValue;
            attribute velocity : ScalarValues::Real;
        }

        item def ShaftPower {
            attribute torque : ISQ::TorqueValue;
            attribute speed : ISQ::AngularVelocityValue;
        }

        attribute def StartCommand;
        attribute def StopCommand;
        attribute def NominalSpeedReached;
        attribute def ZeroSpeedReached;
        attribute def CavitationDetected;
        attribute def CavitationCleared;

        port def FluidInPort {
            in item fluid : Fluid;
        }

        port def FluidOutPort {
            out item fluid : Fluid;
        }

        port def DriveShaftPort {
            in item power : ShaftPower;
        }

        part def Impeller {
            port suctionPort : FluidInPort;
            port dischargePort : FluidOutPort;
            port drivePort : DriveShaftPort;
        }

        part def VoluteCasing {
            port inletPort : FluidInPort;
            port outletPort : FluidOutPort;
        }

        part def DischargePipe {
            port inletPort : FluidInPort;
            port dischargePort : FluidOutPort;
        }

        part def VoluteCentrifugalPump {
            port suctionPort : FluidInPort;
            port dischargePort : FluidOutPort;
            port driveShaftPort : DriveShaftPort;
            attribute efficiency : ScalarValues::Real;

            part impeller : Impeller;
            part voluteCasing : VoluteCasing;
            part dischargePipe : DischargePipe;

            connect driveShaftPort to impeller.drivePort;
            connect suctionPort to impeller.suctionPort;
            connect impeller.dischargePort to voluteCasing.inletPort;
            connect voluteCasing.outletPort to dischargePipe.inletPort;
            connect dischargePipe.dischargePort to dischargePort;
        }

        action def 'Draw Fluid' {
            in inletFluid : Fluid;
            in shaftPower : ShaftPower;
            out acceleratedFluid : Fluid;
        }

        action def 'Convert Kinetic Energy to Pressure' {
            in highVelocityFluid : Fluid;
            out pressurizedFluid : Fluid;
        }

        action def 'Discharge Fluid' {
            in pressurizedFluid : Fluid;
            out dischargeFluid : Fluid;
        }

        action def 'Pump Fluid' {
            in inletFluid : Fluid;
            in shaftPower : ShaftPower;
            out dischargeFluid : Fluid;

            action 'draw fluid' : 'Draw Fluid' {
                in inletFluid = inletFluid;
                in shaftPower = shaftPower;
                out acceleratedFluid : Fluid;
            }
            flow 'draw fluid'.acceleratedFluid to 'convert energy'.highVelocityFluid;
            action 'convert energy' : 'Convert Kinetic Energy to Pressure' {
                in highVelocityFluid : Fluid;
                out pressurizedFluid : Fluid;
            }
            flow 'convert energy'.pressurizedFluid to 'discharge fluid'.pressurizedFluid;
            action 'discharge fluid' : 'Discharge Fluid' {
                in pressurizedFluid : Fluid;
                out dischargeFluid = dischargeFluid;
            }
        }

        action def 'Monitor Cavitation' {
            in inletPressure : ISQ::PressureValue;
            in vaporPressure : ISQ::PressureValue;
            out cavitationDetected : ScalarValues::Boolean;
        }

        state def PumpStates {
            in pump : VoluteCentrifugalPump;
            in inletPressure : ISQ::PressureValue;
            in shaftSpeed : ISQ::AngularVelocityValue;
            in nominalSpeed : ISQ::AngularVelocityValue;
            in vaporPressure : ISQ::PressureValue;
            entry; then stopped;
            state stopped;
            accept StartCommand then starting;
            state starting;
            accept NominalSpeedReached then running;
            state running {
                do action 'pump fluid' : 'Pump Fluid' {
                    in inletFluid = pump.suctionPort.fluid;
                    in shaftPower = pump.driveShaftPort.power;
                    out dischargeFluid : Fluid;
                }
                do action 'monitor cavitation' : 'Monitor Cavitation' {
                    in inletPressure = inletPressure;
                    in vaporPressure = vaporPressure;
                    out cavitationDetected : ScalarValues::Boolean;
                }
            }
            accept CavitationDetected then cavitationWarning;
            accept StopCommand then stopping;
            state cavitationWarning;
            accept CavitationCleared then running;
            accept StopCommand then stopping;
            state stopping;
            accept ZeroSpeedReached then stopped;
        }

        requirement def 'Flow Rate Requirement' {
            doc /* The pump shall deliver a minimum volumetric flow rate of 0.05 m^3/s at nominal speed. */
            attribute minFlowRate : ISQ::VolumeFlowRateValue = 0.05 [m^3/s];
            subject pump : VoluteCentrifugalPump;
            constraint { pump.dischargePort.fluid.flowRate >= minFlowRate }
        }

        requirement def 'Pressure Increase Requirement' {
            doc /* The pump shall increase fluid pressure by at least 200 kPa across the volute casing. */
            attribute minPressureIncrease : ISQ::PressureValue = 200000 [Pa];
            subject pump : VoluteCentrifugalPump;
            constraint { pump.dischargePort.fluid.pressure - pump.suctionPort.fluid.pressure >= minPressureIncrease }
        }

        requirement def 'Hydraulic Efficiency Requirement' {
            doc /* The pump shall maintain a hydraulic efficiency of no less than 75%. */
            attribute minEfficiency : ScalarValues::Real = 0.75;
            subject pump : VoluteCentrifugalPump;
            constraint { pump.efficiency >= minEfficiency }
        }
    }

    package Usages {
        import Definitions::*;

        part pumpSystem : VoluteCentrifugalPump {
            attribute nominalSpeed : ISQ::AngularVelocityValue = 150 [rad/s];
            attribute vaporPressure : ISQ::PressureValue = 2300 [Pa];

            state pumpStates : PumpStates {
                in pump = pumpSystem;
                in inletPressure = suctionPort.fluid.pressure;
                in shaftSpeed = driveShaftPort.power.speed;
                in nominalSpeed = 150 [rad/s];
                in vaporPressure = 2300 [Pa];
            }
        }

        requirement flowRateReq : 'Flow Rate Requirement';
        requirement pressureIncreaseReq : 'Pressure Increase Requirement';
        requirement efficiencyReq : 'Hydraulic Efficiency Requirement';

        satisfy flowRateReq by pumpSystem;
        satisfy pressureIncreaseReq by pumpSystem;
        satisfy efficiencyReq by pumpSystem;
    }
}
