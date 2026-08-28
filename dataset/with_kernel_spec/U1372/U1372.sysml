package SaqiyaWaterRaisingMachine {
    private import ISQ::*;
    private import ScalarValues::*;
    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        item def Water {
            attribute volume : VolumeValue;
        }

        attribute def TorqueValue :> ISQ::TorqueValue;
        attribute def AngularVelocityValue :> ISQ::AngularVelocityValue;
        attribute def ForceValue :> ISQ::ForceValue;
        attribute def LengthValue :> ISQ::LengthValue;
        attribute def SpeedValue :> ISQ::SpeedValue;
        attribute def VolumeValue :> ISQ::VolumeValue;
        attribute def VolumeFlowRateValue :> ISQ::VolumeFlowRateValue;
        attribute def MassValue :> ISQ::MassValue;

        port def RotaryPowerPort {
            out attribute torque : TorqueValue;
            out attribute angularVelocity : AngularVelocityValue;
        }

        port def LinearMotionPort {
            out attribute force : ForceValue;
            out attribute linearVelocity : SpeedValue;
            out attribute displacement : LengthValue;
        }

        port def FluidOutPort {
            out item water : Water;
        }

        port def FluidInPort {
            in item water : Water;
        }

        action def ProvidePower {
            out torque : TorqueValue;
            out angularVelocity : AngularVelocityValue;
        }

        action def TransmitRotation {
            in torque : TorqueValue;
            in angularVelocity : AngularVelocityValue;
            out torque : TorqueValue;
            out angularVelocity : AngularVelocityValue;
        }

        action def ConvertRotaryToLinear {
            in torque : TorqueValue;
            in angularVelocity : AngularVelocityValue;
            in crankRadius : LengthValue;
            out force : ForceValue;
            out linearVelocity : SpeedValue;
            out displacement : LengthValue;
        }

        action def TransferForce {
            in force : ForceValue;
            in linearVelocity : SpeedValue;
            in displacement : LengthValue;
            out force : ForceValue;
            out linearVelocity : SpeedValue;
            out displacement : LengthValue;
        }

        action def PumpWater {
            in force : ForceValue;
            in linearVelocity : SpeedValue;
            in displacement : LengthValue;
            in waterIn : Water;
            out waterOut : Water;
        }

        part def Animal {
            attribute species : String;
            port drivePort : RotaryPowerPort;
            perform action providePower : ProvidePower {
                out torque = drivePort.torque;
                out angularVelocity = drivePort.angularVelocity;
            }
        }

        part def HorizontalWheel {
            attribute radius : LengthValue;
            attribute material : String = "wood";
            port inputPort : ~RotaryPowerPort;
            port outputPort : RotaryPowerPort;
            perform action transmitRotation : TransmitRotation {
                in torque = inputPort.torque;
                in angularVelocity = inputPort.angularVelocity;
                out torque = outputPort.torque;
                out angularVelocity = outputPort.angularVelocity;
            }
        }

        part def Crankshaft {
            attribute crankRadius : LengthValue;
            port rotaryInput : ~RotaryPowerPort;
            port crankOutput : LinearMotionPort;
            perform action convertRotaryToLinear : ConvertRotaryToLinear {
                in torque = rotaryInput.torque;
                in angularVelocity = rotaryInput.angularVelocity;
                in crankRadius = crankRadius;
                out force = crankOutput.force;
                out linearVelocity = crankOutput.linearVelocity;
                out displacement = crankOutput.displacement;
            }
        }

        part def ConnectingRod {
            attribute length : LengthValue;
            port crankEnd : ~LinearMotionPort;
            port pistonEnd : LinearMotionPort;
            perform action transferForce : TransferForce {
                in force = crankEnd.force;
                in linearVelocity = crankEnd.linearVelocity;
                in displacement = crankEnd.displacement;
                out force = pistonEnd.force;
                out linearVelocity = pistonEnd.linearVelocity;
                out displacement = pistonEnd.displacement;
            }
        }

        part def PistonAssembly {
            attribute diameter : LengthValue;
            attribute stroke : LengthValue;
            attribute mass : MassValue;
            port rodEnd : ~LinearMotionPort;
            port waterInPort : FluidInPort;
            port waterOutPort : FluidOutPort;
            perform action pumpWater : PumpWater {
                in force = rodEnd.force;
                in linearVelocity = rodEnd.linearVelocity;
                in displacement = rodEnd.displacement;
                in waterIn = waterInPort.water;
                out waterOut = waterOutPort.water;
            }
        }

        part def Cylinder {
            attribute boreDiameter : LengthValue;
            attribute strokeLength : LengthValue;
            port pistonInterface : ~LinearMotionPort;
            port waterInlet : FluidInPort;
            port waterOutlet : FluidOutPort;
        }

        part def RiverSource {
            attribute waterLevel : LengthValue;
            port waterOut : FluidOutPort;
        }

        part def Aqueduct {
            attribute elevation : LengthValue;
            attribute capacity : VolumeValue;
            port waterIn : FluidInPort;
        }

        attribute def StartSignal;
        attribute def RunningSignal;
        attribute def StopSignal;
        attribute def MaintenanceSignal;
        attribute def ResetSignal;

        state def SaqiyaOperationalStates {
            entry; then idle;

            state idle;
            transition idle_to_starting
                first idle
                accept StartSignal
                then starting;

            state starting;
            transition starting_to_running
                first starting
                accept RunningSignal
                then running;

            state running;
            transition running_to_stopped
                first running
                accept StopSignal
                then stopped;
            transition running_to_maintenance
                first running
                accept MaintenanceSignal
                then maintenance;

            state stopped;
            transition stopped_to_idle
                first stopped
                accept ResetSignal
                then idle;

            state maintenance;
            transition maintenance_to_idle
                first maintenance
                accept ResetSignal
                then idle;
        }

        requirement def WaterLiftingRequirement {
            doc /* The saqiya shall lift water from a low-level river source to an elevated aqueduct for irrigation. */
            attribute minFlowRate : VolumeFlowRateValue;
        }

        requirement def MechanicalEfficiencyRequirement {
            doc /* The crank-and-connecting-rod mechanism shall efficiently convert rotary motion to reciprocating linear motion. */
            attribute minEfficiency : Real;
        }
    }

    package Usages {
        part def SaqiyaSystem {
            part animal : Definitions::Animal;
            part horizontalWheel : Definitions::HorizontalWheel;
            part crankshaft : Definitions::Crankshaft;
            part connectingRod : Definitions::ConnectingRod;
            part pistonAssembly : Definitions::PistonAssembly;
            part cylinder : Definitions::Cylinder;
            part river : Definitions::RiverSource;
            part aqueduct : Definitions::Aqueduct;

            flow of Definitions::Water
                from river.waterOut to cylinder.waterInlet;

            flow of Definitions::Water
                from cylinder.waterOutlet to pistonAssembly.waterInPort;

            flow of Definitions::Water
                from pistonAssembly.waterOutPort to aqueduct.waterIn;

            connect animal.drivePort to horizontalWheel.inputPort;
            connect horizontalWheel.outputPort to crankshaft.rotaryInput;
            connect crankshaft.crankOutput to connectingRod.crankEnd;
            connect connectingRod.pistonEnd to pistonAssembly.rodEnd;
            connect pistonAssembly.rodEnd to cylinder.pistonInterface;

            state operationalState : Definitions::SaqiyaOperationalStates;
        }

        requirement waterLiftingReq : Definitions::WaterLiftingRequirement;

        requirement mechanicalEfficiencyReq : Definitions::MechanicalEfficiencyRequirement;

        part saqiyaContext {
            part system : SaqiyaSystem;
            satisfy waterLiftingReq by system;
            satisfy mechanicalEfficiencyReq by system;
        }
    }
}
