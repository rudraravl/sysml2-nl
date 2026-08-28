package LutronAutomatedLightingControlSystem {

    private import ScalarValues::*;

    attribute def Illuminance :> Real;
    attribute def Power :> Real;
    attribute def Duration :> Real;
    attribute def Percentage :> Real {
        constraint { self >= 0.0 and self <= 100.0 }
    }

    item def OccupancyStatus {
        attribute isOccupied : Boolean;
    }
    item def AmbientLightReading {
        attribute level : Illuminance;
    }
    item def DimmingCommand {
        attribute dimLevel : Percentage;
        attribute circuitId : Integer;
    }
    item def UserCommand {
        attribute buttonId : Integer;
        attribute sceneId : Integer;
    }

    requirement def EnergyEfficiencyReq {
        doc /* The system shall minimize energy consumption by dimming or turning off lights when sufficient natural light is available or when the room is unoccupied. */
        attribute energySaved : Percentage;
        attribute minEnergySaved : Percentage;
        require constraint { energySaved >= minEnergySaved }
    }

    requirement def OccupancyResponseReq {
        doc /* The system shall react to changes in occupancy in under half a second. */
        attribute responseTime : Duration;
        attribute maxResponseTime : Duration;
        require constraint { responseTime <= maxResponseTime }
    }

    requirement def ReliabilityReq {
        doc /* The system shall operate reliably without failure for at least 5 years. */
        attribute operationalYears : Real;
        attribute minOperationalYears : Real;
        require constraint { operationalYears >= minOperationalYears }
    }

    requirement def ManualOverrideReq {
        doc /* The system shall allow users to override automatic settings or select pre-programmed lighting scenes via a wall-mounted interface. */
        attribute overrideActive : Boolean;
        require constraint { overrideActive == true }
    }

    part def OccupancySensor {
        port occupancyPort {
            out occupancyStatus : OccupancyStatus;
        }
    }

    part def AmbientLightSensor {
        port ambientLightPort {
            out lightLevel : AmbientLightReading;
        }
    }

    part def DimmableLoadController {
        attribute maxLoad : Power;
        attribute currentPower : Power;
        port commandPort {
            in dimmingCommand : DimmingCommand;
        }
        port fixturePort {
            out powerOutput : Power;
        }
        action adjustLoad {
            in cmd : DimmingCommand;
            assign currentPower := (cmd.dimLevel / 100.0) * maxLoad;
        }
    }

    part def WallUserInterface {
        port commandPort {
            out userCommand : UserCommand;
        }
    }

    part def CentralProcessor {
        port occupancyInputPort {
            in occupancyStatus : OccupancyStatus;
        }
        port ambientLightInputPort {
            in lightLevel : AmbientLightReading;
        }
        port userCommandInputPort {
            in userCommand : UserCommand;
        }
        port dimmingCommandPort {
            out dimmingCommand : DimmingCommand;
        }

        attribute isOccupied : Boolean := false;
        attribute naturalLight : Illuminance := 0.0;
        attribute currentDimLevel : Percentage := 0.0;
        attribute manualOverrideActive : Boolean := false;

        state def ProcessorStates;
        state processorStates : ProcessorStates {
            entry; then off;
            state off;
            accept OccupancyStatus
                then monitoring;
            accept UserCommand
                then adjusting;
            state monitoring;
            accept OccupancyStatus
                do assign isOccupied := occupancyInputPort.occupancyStatus.isOccupied
                then adjusting;
            accept AmbientLightReading
                do assign naturalLight := ambientLightInputPort.lightLevel.level
                then adjusting;
            accept UserCommand
                do assign manualOverrideActive := true
                then adjusting;
            state adjusting {
                entry assign currentDimLevel := 100.0;
                do send new DimmingCommand() to dimmingCommandPort;
                then monitoring;
            }
        }
    }

    part def LightingSystem {
        requirement energyEfficiency : EnergyEfficiencyReq {
            attribute minEnergySaved := 30.0;
        }
        requirement occupancyResponse : OccupancyResponseReq {
            attribute maxResponseTime := 0.5;
        }
        requirement reliability : ReliabilityReq {
            attribute minOperationalYears := 5.0;
        }
        requirement manualOverride : ManualOverrideReq;

        part processor : CentralProcessor;
        part occupancySensor : OccupancySensor;
        part ambientLightSensor : AmbientLightSensor;
        part loadController600W : DimmableLoadController { attribute maxLoad := 600.0; }
        part loadController1000W : DimmableLoadController { attribute maxLoad := 1000.0; }
        part userInterface : WallUserInterface;

        interface occupancyInterface connect occupancySensor.occupancyPort to processor.occupancyInputPort {
            flow occupancyFlow of OccupancyStatus 
                from occupancySensor.occupancyPort.occupancyStatus to processor.occupancyInputPort.occupancyStatus;
        }

        interface ambientLightInterface connect ambientLightSensor.ambientLightPort to processor.ambientLightInputPort {
            flow ambientLightFlow of AmbientLightReading 
                from ambientLightSensor.ambientLightPort.lightLevel to processor.ambientLightInputPort.lightLevel;
        }

        interface userInterfaceConnection connect userInterface.commandPort to processor.userCommandInputPort {
            flow userCommandFlow of UserCommand 
                from userInterface.commandPort.userCommand to processor.userCommandInputPort.userCommand;
        }

        interface dimmingInterface600W connect processor.dimmingCommandPort to loadController600W.commandPort {
            flow dimmingCommandFlow600W of DimmingCommand 
                from processor.dimmingCommandPort.dimmingCommand to loadController600W.commandPort.dimmingCommand;
        }

        interface dimmingInterface1000W connect processor.dimmingCommandPort to loadController1000W.commandPort {
            flow dimmingCommandFlow1000W of DimmingCommand 
                from processor.dimmingCommandPort.dimmingCommand to loadController1000W.commandPort.dimmingCommand;
        }
    }
}
