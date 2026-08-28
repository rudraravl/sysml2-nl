package RoboticSpacecraftSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def ScienceData {
        attribute observationData : String;
    }

    item def Telemetry {
        attribute subsystemHealth : String;
        attribute sciencePayload : ScienceData;
    }

    item def CommandSignal {
        attribute commandId : String;
        attribute commandData : String;
    }

    item def AttitudeData {
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yaw : AngleValue;
    }

    item def PowerData {
        attribute voltage : Real;
        attribute current : Real;
    }

    item def ThrustCommand {
        attribute thrustLevel : Real;
    }

    item def NavigationData {
        attribute positionX : LengthValue;
        attribute positionY : LengthValue;
        attribute positionZ : LengthValue;
        attribute velocityX : Real;
        attribute velocityY : Real;
        attribute velocityZ : Real;
    }

    item def ScienceCommand {
        attribute target : String;
    }

    item def AttitudeCommand {
        attribute targetRoll : AngleValue;
        attribute targetPitch : AngleValue;
        attribute targetYaw : AngleValue;
    }

    action def GeneratePower;
    action def ListenForCommands;
    action def ProcessCommands;
    action def TransmitData;
    action def PointAntenna;
    action def DetermineAttitude;
    action def ControlAttitude;
    action def ConsumeFuel;
    action def AcquireScienceData;
    action def Navigate;

    part def SolarArray;
    part def Battery;
    part def HighGainAntenna;
    part def ReactionWheel;
    part def Thruster;
    part def ScienceInstrument;

    part def GroundStation {
        port commandOut {
            out attribute command : CommandSignal;
        }
        port telemetryIn {
            in attribute telemetry : Telemetry;
        }
    }

    part def PowerSubsystem {
        attribute generatedPower : PowerValue;
        attribute requiredPower : PowerValue;
        part solarArray1 : SolarArray;
        part solarArray2 : SolarArray;
        part battery1 : Battery;
        part battery2 : Battery;
        port powerOut {
            out attribute power : PowerData;
        }
        port chargeStatus {
            out attribute chargeLevel : Real;
        }
        perform action generatePower : GeneratePower;
    }

    part def CommandAndDataHandling {
        port commandIn {
            in attribute command : CommandSignal;
        }
        port telemetryOut {
            out attribute telemetry : Telemetry;
        }
        port powerIn {
            in attribute power : PowerData;
        }
        port powerHealthIn {
            in attribute chargeLevel : Real;
        }
        port scienceDataIn {
            in attribute scienceData : ScienceData;
        }
        port scienceCommandOut {
            out attribute scienceCommand : ScienceCommand;
        }
        port navDataIn {
            in attribute navData : NavigationData;
        }
        port thrustCommandOut {
            out attribute thrustCommand : ThrustCommand;
        }
        port attitudeDataIn {
            in attribute attitudeData : AttitudeData;
        }
        port attitudeCommandOut {
            out attribute attitudeCommand : AttitudeCommand;
        }
        perform action listenForCommands : ListenForCommands;
        perform action processCommands : ProcessCommands;
        perform action transmitData : TransmitData;
    }

    part def CommunicationSubsystem {
        part highGainAntenna : HighGainAntenna;
        port groundCommandIn {
            in attribute command : CommandSignal;
        }
        port groundTelemetryOut {
            out attribute telemetry : Telemetry;
        }
        port commandOut {
            out attribute command : CommandSignal;
        }
        port telemetryIn {
            in attribute telemetry : Telemetry;
        }
        port powerIn {
            in attribute power : PowerData;
        }
        port attitudeDataIn {
            in attribute attitudeData : AttitudeData;
        }
        perform action pointAntenna : PointAntenna;
        perform action transmitDataComm : TransmitData;
    }

    part def AttitudeControlSubsystem {
        attribute attitudeError : AngleValue;
        part reactionWheel1 : ReactionWheel;
        part reactionWheel2 : ReactionWheel;
        part reactionWheel3 : ReactionWheel;
        port attitudeDataOut {
            out attribute attitudeData : AttitudeData;
        }
        port attitudeCommandIn {
            in attribute attitudeCommand : AttitudeCommand;
        }
        port powerIn {
            in attribute power : PowerData;
        }
        perform action determineAttitude : DetermineAttitude;
        perform action controlAttitude : ControlAttitude;
    }

    part def PropulsionSubsystem {
        attribute fuelMass : MassValue;
        part thruster1 : Thruster;
        part thruster2 : Thruster;
        part thruster3 : Thruster;
        part thruster4 : Thruster;
        port thrustCommandIn {
            in attribute thrustCommand : ThrustCommand;
        }
        port powerIn {
            in attribute power : PowerData;
        }
        perform action consumeFuel : ConsumeFuel;
    }

    part def ScienceInstrumentSubsystem {
        part instrument : ScienceInstrument;
        port scienceCommandIn {
            in attribute scienceCommand : ScienceCommand;
        }
        port scienceDataOut {
            out attribute scienceData : ScienceData;
        }
        port powerIn {
            in attribute power : PowerData;
        }
        perform action acquireScienceData : AcquireScienceData;
    }

    part def NavigationSubsystem {
        port navDataOut {
            out attribute navData : NavigationData;
        }
        port powerIn {
            in attribute power : PowerData;
        }
        perform action navigate : Navigate;
    }

    state machine def SpacecraftMissionCycle {
        entry; then PowerGeneration;
        state PowerGeneration;
        state CommandListening;
        state AttitudeControl;
        state NavigationState;
        state ScienceAcquisition;
        state DataTransmission;
        transition from PowerGeneration to CommandListening;
        transition from CommandListening to AttitudeControl;
        transition from AttitudeControl to NavigationState;
        transition from NavigationState to ScienceAcquisition;
        transition from ScienceAcquisition to DataTransmission;
        transition from DataTransmission to PowerGeneration;
    }

    part def Spacecraft {
        attribute mass : MassValue;
        attribute attitudeError : AngleValue;
        part cds : CommandAndDataHandling;
        part power : PowerSubsystem;
        part comm : CommunicationSubsystem;
        part acs : AttitudeControlSubsystem;
        part propulsion : PropulsionSubsystem;
        part science : ScienceInstrumentSubsystem;
        part nav : NavigationSubsystem;

        connect power.powerOut to cds.powerIn;
        connect power.powerOut to comm.powerIn;
        connect power.powerOut to acs.powerIn;
        connect power.powerOut to propulsion.powerIn;
        connect power.powerOut to science.powerIn;
        connect power.powerOut to nav.powerIn;
        connect power.chargeStatus to cds.powerHealthIn;
        connect comm.commandOut to cds.commandIn;
        connect cds.telemetryOut to comm.telemetryIn;
        connect cds.scienceCommandOut to science.scienceCommandIn;
        connect science.scienceDataOut to cds.scienceDataIn;
        connect nav.navDataOut to cds.navDataIn;
        connect cds.thrustCommandOut to propulsion.thrustCommandIn;
        connect acs.attitudeDataOut to cds.attitudeDataIn;
        connect acs.attitudeDataOut to comm.attitudeDataIn;
        connect cds.attitudeCommandOut to acs.attitudeCommandIn;
    }

    part actualSpacecraft : Spacecraft {
        attribute :>> mass = 4800 [kg];
        attribute :>> attitudeError = 0.03 [rad];
        part :>> power {
            attribute :>> generatedPower = 3200 [W];
            attribute :>> requiredPower = 2800 [W];
        }
        part :>> propulsion {
            attribute :>> fuelMass = 250 [kg];
        }
        part :>> acs {
            attribute :>> attitudeError = 0.03 [rad];
        }
        exhibit missionCycle : SpacecraftMissionCycle;
    }

    part groundStation : GroundStation;

    connect groundStation.commandOut to actualSpacecraft.comm.groundCommandIn;
    connect actualSpacecraft.comm.groundTelemetryOut to groundStation.telemetryIn;

    requirement def MaxMassRequirement {
        doc /* The spacecraft total mass shall not exceed the maximum allowed launch mass. */
        attribute actualMass : MassValue;
        attribute maxAllowedMass : MassValue;
        require constraint {
            actualMass <= maxAllowedMass
        }
    }

    requirement def StableOrientationRequirement {
        doc /* The spacecraft shall maintain stable orientation within a specified angular error tolerance. */
        attribute actualAttitudeError : AngleValue;
        attribute maxAttitudeError : AngleValue;
        require constraint {
            actualAttitudeError <= maxAttitudeError
        }
    }

    requirement def ContinuousPowerRequirement {
        doc /* The power subsystem shall provide continuous electrical power sufficient for all operational subsystems. */
        attribute requiredPower : PowerValue;
        attribute generatedPower : PowerValue;
        require constraint {
            generatedPower >= requiredPower
        }
    }

    requirement <'RQ-1'> spacecraftMassRequirement : MaxMassRequirement {
        doc /* The total mass of the spacecraft shall be less than or equal to 5000 kg for launch compatibility. */
        subject spacecraft : Spacecraft;
        attribute :>> actualMass = spacecraft.mass;
        attribute :>> maxAllowedMass = 5000 [kg];
    }

    requirement <'RQ-2'> stableOrientationRequirement : StableOrientationRequirement {
        doc /* The attitude control subsystem shall keep orientation error less than or equal to 0.1 rad during science observations. */
        subject spacecraft : Spacecraft;
        attribute :>> actualAttitudeError = spacecraft.acs.attitudeError;
        attribute :>> maxAttitudeError = 0.1 [rad];
    }

    requirement <'RQ-3'> continuousPowerRequirement : ContinuousPowerRequirement {
        doc /* The power subsystem shall generate at least the required power during the mission. */
        subject spacecraft : Spacecraft;
        attribute :>> requiredPower = spacecraft.power.requiredPower;
        attribute :>> generatedPower = spacecraft.power.generatedPower;
    }
}
