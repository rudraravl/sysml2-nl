package WaterPumpingSystem {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::Real;

    package Definitions {
        item def Water;

        port def FluidPort {
            out item water : Water;
        }

        port def MechanicalPowerPort {
            attribute torque :> ISQ::torque;
            attribute angularVelocity :> ISQ::angularVelocity;
        }

        part def SumpReservoir {
            port fluidOutPort : FluidPort;
            attribute minLevel :> ISQ::length;
            attribute maxLevel :> ISQ::length;
            attribute currentLevel :> ISQ::length;
        }

        part def WoodScrewPump {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            port drivePort : ~MechanicalPowerPort;
            attribute diameter :> ISQ::length;
            attribute length :> ISQ::length;
            attribute pitch :> ISQ::length;
            attribute inclinationAngle :> ISQ::planeAngle;

            state def PumpState {
                state idle;
                state starting;
                state running;
                state stopping;
                transition from idle to starting;
                transition from starting to running;
                transition from running to stopping;
                transition from stopping to idle;
            }
        }

        part def ElectricMotor {
            port shaftPort : MechanicalPowerPort;
            attribute nominalSpeed :> ISQ::angularVelocity;
            attribute nominalTorque :> ISQ::torque;

            state def MotorState {
                state stopped;
                state starting;
                state accelerating;
                state running;
                state decelerating;
                transition from stopped to starting;
                transition from starting to accelerating;
                transition from accelerating to running;
                transition from running to decelerating;
                transition from decelerating to stopped;
            }
        }

        part def FlowMeter {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            attribute flowRate :> ISQ::volumeFlowRate;
            attribute totalVolume :> ISQ::volume;
        }

        part def DischargeTank {
            port fluidInPort : ~FluidPort;
            attribute maxLevel :> ISQ::length;
            attribute currentLevel :> ISQ::length;
        }

        interface def DriveInterface {
            end motorShaft : MechanicalPowerPort;
            end pumpDrive : MechanicalPowerPort;
        }

        action def DriveShaft {
            out driveTorque : ISQ::torque;
            out driveSpeed : ISQ::angularVelocity;
        }

        action def LiftWater {
            in waterIn : Water;
            out waterOut : Water;
            in driveTorque : ISQ::torque;
            in driveSpeed : ISQ::angularVelocity;
        }

        action def MeasureFlow {
            in waterIn : Water;
            out waterOut : Water;
            out measuredFlowRate : ISQ::volumeFlowRate;
            out measuredVolume : ISQ::volume;
        }

        requirement def FlowRateRequirement {
            doc /* The system shall maintain a minimum flow rate from the sump to the discharge tank. */
            attribute actualFlowRate :> ISQ::volumeFlowRate;
            attribute requiredFlowRate :> ISQ::volumeFlowRate;
            require constraint { actualFlowRate >= requiredFlowRate }
        }

        requirement def EfficiencyRequirement {
            doc /* The system shall achieve at least the required hydraulic efficiency. */
            attribute actualEfficiency : Real;
            attribute requiredEfficiency : Real;
            require constraint { actualEfficiency >= requiredEfficiency }
        }

        requirement def ReliabilityRequirement {
            doc /* The system shall operate continuously for at least the required duration. */
            attribute actualDuration :> ISQ::time;
            attribute requiredDuration :> ISQ::time;
            require constraint { actualDuration >= requiredDuration }
        }
    }

    package Usages {
        public import Definitions::*;

        part waterPumpingSystem {
            part sump : SumpReservoir {
                attribute :>> minLevel = 0.5 [m];
                attribute :>> maxLevel = 2.0 [m];
                attribute :>> currentLevel = 1.5 [m];
            }

            part pump : WoodScrewPump {
                attribute :>> diameter = 0.5 [m];
                attribute :>> length = 4.0 [m];
                attribute :>> pitch = 1.0 [m];
                attribute :>> inclinationAngle = 0.5236 [rad];

                perform pumpState : PumpState;

                perform action liftWater : LiftWater {
                    in waterIn = fluidInPort.water;
                    in driveTorque = drivePort.torque;
                    in driveSpeed = drivePort.angularVelocity;
                    out waterOut = fluidOutPort.water;
                }
            }

            part motor : ElectricMotor {
                attribute :>> nominalSpeed = 157 [rad/s];
                attribute :>> nominalTorque = 100 [N*m];

                perform motorState : MotorState;

                perform action driveShaft : DriveShaft {
                    out driveTorque = shaftPort.torque;
                    out driveSpeed = shaftPort.angularVelocity;
                }
            }

            part flowMeter : FlowMeter {
                attribute :>> flowRate = 0 [m^3/s];
                attribute :>> totalVolume = 0 [m^3];

                perform action measureFlow : MeasureFlow {
                    in waterIn = fluidInPort.water;
                    out waterOut = fluidOutPort.water;
                    out measuredFlowRate = flowRate;
                    out measuredVolume = totalVolume;
                }
            }

            part dischargeTank : DischargeTank {
                attribute :>> maxLevel = 3.0 [m];
                attribute :>> currentLevel = 0.0 [m];
            }

            flow of water : Water
                from sump.fluidOutPort.water to pump.fluidInPort.water;

            interface motorToPump : DriveInterface
                connect motor.shaftPort to pump.drivePort;

            flow of water : Water
                from pump.fluidOutPort.water to flowMeter.fluidInPort.water;

            flow of water : Water
                from flowMeter.fluidOutPort.water to dischargeTank.fluidInPort.water;
        }

        requirement flowRateReq : FlowRateRequirement {
            attribute :>> requiredFlowRate = 0.01 [m^3/s];
            attribute :>> actualFlowRate = waterPumpingSystem.flowMeter.flowRate;
        }

        requirement efficiencyReq : EfficiencyRequirement {
            attribute :>> requiredEfficiency = 0.75;
            attribute :>> actualEfficiency = 0.78;
        }

        requirement reliabilityReq : ReliabilityRequirement {
            attribute :>> requiredDuration = 28800 [s];
            attribute :>> actualDuration = 36000 [s];
        }
    }
}
