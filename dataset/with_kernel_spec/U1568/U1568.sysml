package SpaceLogisticsSystem {
    private import ScalarValues::Real;
    private import ScalarValues::Integer;
    private import ScalarValues::String;
    private import ScalarValues::Boolean;
    private import ISQ::*;
    private import Definitions::*;
    
    package Definitions {
        attribute def Day :> Real;
        
        item def Cargo {
            attribute mass : MassValue;
            attribute volume : VolumeValue;
            attribute description : String;
        }
        item def Consumable :> Cargo {
            attribute consumptionRatePerDay : Real;
        }
        item def Telemetry {
            attribute position : LengthValue;
            attribute velocity : VelocityValue;
            attribute status : String;
        }
        item def Command {
            attribute type : String;
            attribute payload : String;
        }
        item def ResupplyRequest {
            attribute requestedCargoType : String;
            attribute urgency : String;
        }
        
        attribute def LaunchSeparation;
        attribute def ApproachInitiated;
        attribute def DockingApproved;
        attribute def Docked;
        attribute def TransferComplete;
        attribute def Undocked;
        attribute def MissionComplete;
        
        port def TelemetryPort {
            out item telemetry : Telemetry;
        }
        port def CommandPort {
            in item command : Command;
        }
        port def PayloadPort {
            out item payload : Cargo;
        }
        port def DockingPort {
            attribute isDocked : Boolean;
            out item cargoOut : Cargo;
            in item cargoIn : Cargo;
        }
        
        part def MissionControl {
            port telemetryIn : ~TelemetryPort;
            port commandOut : CommandPort;
            
            action def PlanMission {
                out flightPlan : String;
                out cargoManifest : Cargo[0..*];
            }
            action def MonitorMission {
                in telemetry : Telemetry;
                out command : Command;
            }
        }
        
        part def LaunchVehicle {
            port telemetryOut : TelemetryPort;
            port commandIn : ~CommandPort;
            port payloadOut : PayloadPort;
            
            part propulsionSystem;
            part guidanceSystem;
            part structuralFrame;
            
            action def LaunchAndAscend {
                in flightPlan : String;
                out orbitInsertion : Boolean;
            }
        }
        
        part def CargoSpacecraft {
            port telemetryOut : TelemetryPort;
            port commandIn : ~CommandPort;
            port payloadIn : ~PayloadPort;
            port dockingPort : DockingPort;
            
            part propulsionSystem;
            part navigationSystem;
            part rendezvousSystem;
            part dockingMechanism;
            part cargoModule {
                attribute temperature : ThermodynamicTemperatureValue;
                attribute pressure : PressureValue;
                item cargo : Cargo;
            }
            
            state def SpacecraftOperation {
                entry; then idle;
                state idle;
                first idle then cruising on LaunchSeparation;
                state cruising;
                first cruising then approaching on ApproachInitiated;
                state approaching;
                first approaching then docked on DockingApproved;
                state docked;
                first docked then transferring on Docked;
                state transferring;
                first transferring then undocking on TransferComplete;
                state undocking;
                first undocking then departing on Undocked;
                state departing;
                first departing then idle on MissionComplete;
            }
            
            action def OrbitalTransfer {
                in initialOrbit : Boolean;
                out approachPoint : Boolean;
            }
            action def Rendezvous {
                in approachPoint : Boolean;
                out readyForDocking : Boolean;
            }
            action def Docking {
                in readyForDocking : Boolean;
                out docked : Boolean;
            }
            action def TransferCargo {
                in docked : Boolean;
                out transferComplete : Boolean;
            }
            action def Undocking {
                in docked : Boolean;
                out undocked : Boolean;
            }
        }
        
        part def SpaceStation {
            port telemetryOut : TelemetryPort;
            port commandIn : ~CommandPort;
            port dockingPort : ~DockingPort;
            
            attribute crewSize : Integer;
            attribute foodLevel : Day;
            attribute waterLevel : Day;
            attribute oxygenLevel : Day;
            
            state def StationOperation {
                entry; then operational;
                state operational;
                first operational then lowSupply when (foodLevel < 30 or waterLevel < 30 or oxygenLevel < 30);
                state lowSupply;
                first lowSupply then operational when (dockingPort.isDocked == true);
            }
            
            action def GenerateResupplyRequest {
                out request : ResupplyRequest;
            }
            action def ReceiveCargo {
                in item cargo : Cargo;
            }
        }
    }
    
    package Usages {
        part context {
            part missionControl : MissionControl {
                perform action planMission : PlanMission;
                perform action monitorMission : MonitorMission {
                    in telemetry = telemetryIn.telemetry;
                    out command = commandOut.command;
                }
            }
            
            part launchVehicle : LaunchVehicle {
                perform action launchAndAscend : LaunchAndAscend;
            }
            
            part cargoSpacecraft : CargoSpacecraft {
                exhibit state operation : SpacecraftOperation;
                perform action orbitalTransfer : OrbitalTransfer;
                perform action rendezvous : Rendezvous;
                perform action docking : Docking;
                perform action transferCargo : TransferCargo;
                perform action undocking : Undocking;
            }
            
            part spaceStation : SpaceStation {
                exhibit state operation : StationOperation;
                perform action generateResupplyRequest : GenerateResupplyRequest;
                perform action receiveCargo : ReceiveCargo;
            }
            
            flow of telemetry : Telemetry from launchVehicle.telemetryOut.telemetry to missionControl.telemetryIn.telemetry;
            flow of telemetry : Telemetry from cargoSpacecraft.telemetryOut.telemetry to missionControl.telemetryIn.telemetry;
            flow of telemetry : Telemetry from spaceStation.telemetryOut.telemetry to missionControl.telemetryIn.telemetry;
            flow of command : Command from missionControl.commandOut.command to launchVehicle.commandIn.command;
            flow of command : Command from missionControl.commandOut.command to cargoSpacecraft.commandIn.command;
            flow of command : Command from missionControl.commandOut.command to spaceStation.commandIn.command;
            flow of payload : Cargo from launchVehicle.payloadOut.payload to cargoSpacecraft.payloadIn.payload;
            flow of cargo : Cargo from cargoSpacecraft.dockingPort.cargoOut to spaceStation.dockingPort.cargoIn;
            
            connection cargoSpacecraft.dockingPort to spaceStation.dockingPort;
            
            action executeMission {
                first start;
                then action plan : PlanMission;
                then action launch : LaunchAndAscend {
                    in flightPlan = plan.flightPlan;
                }
                then action cruise : OrbitalTransfer {
                    in initialOrbit = launch.orbitInsertion;
                }
                then action approach : Rendezvous {
                    in approachPoint = cruise.approachPoint;
                }
                then action dock : Docking {
                    in readyForDocking = approach.readyForDocking;
                }
                then action transfer : TransferCargo {
                    in docked = dock.docked;
                }
                then action undock : Undocking {
                    in docked = dock.docked;
                }
                then done;
            }
        }
    }
    
    package Requirements {
        private import Usages::*;
        requirement def LogisticsMissionRequirement {
            doc /* The system shall deliver cargo from Earth to the space station. */
            subject system : SpaceLogisticsSystem::Usages::context;
        }
        requirement def SafeDockingRequirement {
            doc /* The cargo spacecraft shall dock safely with the space station. */
            subject spacecraft : CargoSpacecraft;
        }
        requirement def ResupplyRequirement {
            doc /* The space station shall generate a resupply request when consumables are low. */
            subject station : SpaceStation;
        }
        requirement def EnvironmentalControlRequirement {
            doc /* The cargo module shall maintain temperature and pressure within specified limits. */
            subject spacecraft : CargoSpacecraft;
        }
        
        satisfy LogisticsMissionRequirement by context.executeMission;
        satisfy SafeDockingRequirement by context.cargoSpacecraft.docking;
        satisfy ResupplyRequirement by context.spaceStation.generateResupplyRequest;
        satisfy EnvironmentalControlRequirement by context.cargoSpacecraft.cargoModule;
    }
}
