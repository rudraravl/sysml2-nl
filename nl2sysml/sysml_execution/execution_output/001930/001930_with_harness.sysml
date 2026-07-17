package SpacecraftSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def MissionPhase;
    attribute def AttitudeCommand;
    attribute def ThrustCommand;
    attribute def PowerMode;
    attribute def DataPacket;

    attribute def Attitude {
        attribute roll : ISQ::PlaneAngleValue;
        attribute pitch : ISQ::PlaneAngleValue;
        attribute yaw : ISQ::PlaneAngleValue;
    }

    attribute def Position3D {
        attribute x : ISQ::LengthValue;
        attribute y : ISQ::LengthValue;
        attribute z : ISQ::LengthValue;
    }

    attribute def Velocity3D {
        attribute vx : ISQ::SpeedValue;
        attribute vy : ISQ::SpeedValue;
        attribute vz : ISQ::SpeedValue;
    }

    item def ElectricalPower {
        attribute voltage : ISQ::ElectricPotentialValue;
        attribute current : ISQ::ElectricCurrentValue;
        attribute power : ISQ::PowerValue;
    }

    item def TelemetryData {
        attribute timestamp : Real;
        attribute dataContent : DataPacket;
    }

    item def CommandSignal {
        attribute commandType : String;
        attribute parameters : Real[*];
    }

    port def PowerPort {
        out item electricalPower : ElectricalPower;
    }

    port def DataPort {
        in item commands : CommandSignal;
        out item telemetry : TelemetryData;
    }

    port def ControlPort {
        in item attitudeCmd : AttitudeCommand;
        in item thrustCmd : ThrustCommand;
        out item currentAttitude : Attitude;
    }

    part def PowerSubsystem {
        attribute batteryCharge : Real;
        attribute solarPanelEfficiency : Real;
        attribute powerMode : PowerMode;

        port powerOut : PowerPort;

        action def GeneratePower {
            in solarIntensity : ISQ::PowerValue;
            out generatedPower : ISQ::PowerValue;
        }

        action def ManagePower {
            in demand : ISQ::PowerValue;
            in supply : ISQ::PowerValue;
            out mode : PowerMode;
        }
    }

    part def CommunicationSubsystem {
        attribute antennaGain : Real;
        attribute transmitPower : ISQ::PowerValue;
        attribute dataRate : Real;

        port dataInterface : DataPort;
        port powerIn : ~PowerPort;

        action def TransmitTelemetry {
            in data : TelemetryData;
            out transmitted : Boolean;
        }

        action def ReceiveCommands {
            out command : CommandSignal;
        }
    }

    part def AttitudeControlSubsystem {
        attribute currentAttitude : Attitude;
        attribute targetAttitude : Attitude;

        port controlInterface : ControlPort;
        port powerIn : ~PowerPort;

        action def DetermineAttitude {
            out attitude : Attitude;
        }

        action def ControlAttitude {
            in target : Attitude;
            in current : Attitude;
            out torqueCommand : ISQ::TorqueValue;
        }
    }

    part def PropulsionSubsystem {
        attribute fuelMass : ISQ::MassValue;
        attribute thrustLevel : ISQ::ForceValue;

        port controlInterface : ~ControlPort;
        port powerIn : ~PowerPort;

        action def GenerateThrust {
            in command : ThrustCommand;
            out thrust : ISQ::ForceValue;
            out fuelConsumed : ISQ::MassValue;
        }
    }

    part def PayloadSubsystem {
        attribute instrumentStatus : String;
        attribute dataCollected : Real;

        port powerIn : ~PowerPort;

        action def CollectScience {
            out scienceData : DataPacket;
        }
    }

    part def Spacecraft {
        attribute totalMass : ISQ::MassValue;
        attribute position : Position3D;
        attribute velocity : Velocity3D;
        attribute missionPhase : MissionPhase;

        part power : PowerSubsystem;
        part comms : CommunicationSubsystem;
        part adcs : AttitudeControlSubsystem;
        part propulsion : PropulsionSubsystem;
        part payload : PayloadSubsystem;

        connection powerToPropulsion connect power.powerOut to propulsion.powerIn;
        connection powerToComms connect power.powerOut to comms.powerIn;
        connection powerToADCS connect power.powerOut to adcs.powerIn;
        connection powerToPayload connect power.powerOut to payload.powerIn;
        connection controlToPropulsion connect adcs.controlInterface to propulsion.controlInterface;

        perform action executeMission references spacecraftMission;
    }

    action def MonitorAttitude {
        out currentAttitude : Attitude;
    }

    action def AdjustAttitude {
        in targetAttitude : Attitude;
        in currentAttitude : Attitude;
    }

    action def PerformManeuver {
        in deltaV : ISQ::SpeedValue;
        out fuelUsed : ISQ::MassValue;
    }

    action def CollectData {
        out data : DataPacket;
    }

    action def TransmitData {
        in data : DataPacket;
    }

    action def ReceiveGroundCommand {
        out command : CommandSignal;
    }

    action spacecraftMission : ExecuteSpacecraftMission {
        first start;
        then merge missionLoop;

        action monitorAttitude : MonitorAttitude {
            out currentAttitude : Attitude;
        }

        then decide;
            if monitorAttitude.currentAttitude.roll > 0.1[deg] then adjustAttitude;
            else checkManeuver;

        action adjustAttitude : AdjustAttitude {
            in targetAttitude : Attitude;
            in currentAttitude = monitorAttitude.currentAttitude;
        }
        then missionLoop;

        merge checkManeuver;
        then decide;
            if true then performManeuver;
            else collectScience;

        action performManeuver : PerformManeuver {
            in deltaV : ISQ::SpeedValue;
            out fuelUsed : ISQ::MassValue;
        }
        then missionLoop;

        merge collectScience;
        action collectData : CollectData {
            out scienceData : DataPacket;
        }

        then action transmitData : TransmitData {
            in data = collectData.scienceData;
        }

        then action receiveCommand : ReceiveGroundCommand {
            out groundCommand : CommandSignal;
        }

        then decide;
            if receiveCommand.groundCommand.commandType == "continue" then missionLoop;
            if receiveCommand.groundCommand.commandType == "terminate" then endMission;

        action endMission;
        then done;
    }

    action def ExecuteSpacecraftMission {
        doc /*
            The spacecraft executes its mission by continuously monitoring and
            controlling its attitude, performing orbital maneuvers as needed,
            collecting scientific data with its payload instruments, and
            transmitting that data to ground stations while receiving commands.
        */
    }

    requirement def SpacecraftMissionRequirement {
        doc /* The spacecraft shall execute its primary mission functions. */

        require constraint massConstraint : MassConstraint;
        require constraint powerConstraint : PowerConstraint;
        require constraint communicationConstraint : CommunicationConstraint;
    }

    requirement def MassConstraint {
        doc /* The total spacecraft mass shall not exceed the launch vehicle capacity. */

        subject spacecraft : Spacecraft;

        require constraint {
            spacecraft.totalMass <= 2000.0[kg]
        }
    }

    requirement def PowerConstraint {
        doc /* The power subsystem shall provide sufficient power for all mission phases. */

        subject powerSys : PowerSubsystem;

        require constraint {
            powerSys.batteryCharge >= 0.2
        }
    }

    requirement def CommunicationConstraint {
        doc /* The communication subsystem shall maintain contact with ground stations. */

        subject commSys : CommunicationSubsystem;

        require constraint {
            commSys.dataRate >= 1000.0
        }
    }

    requirement spacecraftMissionReq : SpacecraftMissionRequirement {
        subject spacecraft : Spacecraft;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SpacecraftSystem::*;
}
