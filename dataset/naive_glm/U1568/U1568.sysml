package SpaceLogisticsSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type Mass :> Real {
        unit kg;
    }
    value type Volume :> Real {
        unit m3;
    }
    value type Distance :> Real {
        unit km;
    }
    value type Velocity :> Real {
        unit 'km/s';
    }
    value type Acceleration :> Real {
        unit 'm/s2';
    }
    value type Temperature :> Real {
        unit 'K';
    }
    value type Pressure :> Real {
        unit kPa;
    }
    value type Duration :> Real {
        unit day;
    }
    value type Force :> Real {
        unit kN;
    }
    value type Angle :> Real {
        unit 'deg';
    }
    value type Percent :> Real {
        unit '%';
    }

    // ===== Item Types =====
    item def CargoItem {
        attribute name : String;
        attribute mass : Mass;
        attribute volume : Volume;
        attribute perishable : Boolean;
        attribute fragile : Boolean;
    }

    item def Food :> CargoItem {
        attribute shelfLife : Duration;
    }

    item def Water :> CargoItem {
        attribute potable : Boolean default true;
    }

    item def Oxygen :> CargoItem {
        attribute tankPressure : Pressure;
    }

    item def ScientificEquipment :> CargoItem {
        attribute calibrationRequired : Boolean;
    }

    item def CargoManifest {
        attribute missionId : String;
        attribute totalMass : Mass;
        attribute totalVolume : Volume;
        part items : CargoItem[*];
    }

    item def TelemetryData {
        attribute position : Distance[3];
        attribute velocity : Velocity[3];
        attribute systemStatus : String;
        attribute timestamp : String;
    }

    item def CommandMessage {
        attribute commandId : String;
        attribute commandType : String;
        attribute payload : String;
    }

    item def ResupplyRequest {
        attribute requestId : String;
        attribute requestedItems : CargoItem[*];
        attribute urgency : String;
        attribute dueDate : String;
    }

    // ===== Port Definitions =====
    port def TelemetryPort {
        out telemetry : TelemetryData;
        in command : CommandMessage;
    }

    port def CommandPort {
        out command : CommandMessage;
        in telemetry : TelemetryData;
    }

    port def ResupplyPort {
        in request : ResupplyRequest;
    }

    port def DockingPort {
        in captureSignal : Boolean;
        out captureConfirm : Boolean;
        in latchEngage : Boolean;
        out latchConfirm : Boolean;
        in undockSignal : Boolean;
        out undockConfirm : Boolean;
        out cargoTransferReady : Boolean;
        in cargoTransferComplete : Boolean;
    }

    port def CargoTransferPort {
        in cargo : CargoItem[*];
        out transferAck : Boolean;
    }

    port def LaunchInterfacePort {
        out separationSignal : Boolean;
        in insertionConfirm : Boolean;
    }

    // ===== Mission Control =====
    part def MissionControl {
        port commandDownlink : CommandPort;
        port resupplyUplink : ResupplyPort;

        attribute missionId : String;
        attribute launchWindow : String;
        attribute flightPlan : String;

        part missionPlanner {
            attribute manifest : CargoManifest;
            attribute calculatedTrajectory : String;
            attribute optimalWindow : String;

            action planMission {
                in req : ResupplyRequest;
                out manifest : CargoManifest;
                out flightPlan : String;
                out window : String;
            }
        }

        part telemetryMonitor {
            attribute latestTelemetry : TelemetryData[*];
            attribute alertThreshold : Percent = 10;

            action monitorTelemetry {
                in data : TelemetryData;
                out status : String;
            }

            action evaluateCorrectiveAction {
                in data : TelemetryData;
                out command : CommandMessage;
            }
        }

        part authorizationSystem {
            attribute dockingApprovalGranted : Boolean = false;

            action authorizeDocking {
                in data : TelemetryData;
                out approval : Boolean;
            }

            action authorizeCriticalPhase {
                in phase : String;
                out approval : Boolean;
            }
        }

        state missionControlBehavior {
            entry;
            state Planning {
                entry;
                transition Planning -> Monitoring
                    when resupplyUplink.request.isReceived();
            }
            state Monitoring {
                entry;
                transition Monitoring -> Authorizing
                    when telemetryMonitor.latestTelemetry->forAll(t | t.systemStatus == "dockingReady");
            }
            state Authorizing {
                entry;
                transition Authorizing -> Monitoring
                    when authorizationSystem.dockingApprovalGranted;
            }
        }

        flow commandDownlink.command to telemetryMonitor;
        flow telemetryMonitor.status to authorizationSystem;
    }

    // ===== Launch Vehicle =====
    part def LaunchVehicle {
        port telemetryDownlink : TelemetryPort;
        port launchInterface : LaunchInterfacePort;

        attribute totalThrust : Force;
        attribute payloadCapacity : Mass;
        attribute maxAltitude : Distance;

        part propulsionSystem {
            attribute thrust : Force;
            attribute fuelMass : Mass;
            attribute specificImpulse : Real;

            action igniteEngines {
                out thrustOutput : Force;
            }

            action throttleControl {
                in targetThrust : Force;
                out actualThrust : Force;
            }

            action shutdownEngines;
        }

        part guidanceSystem {
            attribute trajectory : String;
            attribute currentHeading : Angle;
            attribute ascentProfile : String;

            action steerAscent {
                in targetTrajectory : String;
                out headingCorrection : Angle;
            }

            action calculateInsertion {
                out insertionPoint : Distance[3];
                out insertionVelocity : Velocity[3];
            }
        }

        part structuralFrame {
            attribute dryMass : Mass;
            attribute maxLoad : Mass;
            attribute structuralIntegrity : Percent = 100;
        }

        state launchVehicleBehavior {
            entry;
            state PreLaunch {
                entry;
                transition PreLaunch -> Ascent
                    when propulsionSystem.igniteEngines.thrustOutput > 0;
            }
            state Ascent {
                entry;
                do propulsionSystem.throttleControl;
                transition Ascent -> Coast
                    when guidanceSystem.calculateInsertion.insertionPoint != null;
            }
            state Coast {
                entry;
                transition Coast -> Separation
                    when guidanceSystem.calculateInsertion.insertionVelocity != null;
            }
            state Separation {
                entry;
                do launchInterface.separationSignal = true;
                transition Separation -> Done
                    when launchInterface.insertionConfirm;
            }
            state Done;
        }

        connect propulsionSystem.thrustOutput to guidanceSystem;
        connect guidanceSystem.headingCorrection to propulsionSystem.throttleControl;
    }

    // ===== Cargo Spacecraft =====
    part def CargoSpacecraft {
        port telemetryDownlink : TelemetryPort;
        port dockingPort : DockingPort;
        port cargoTransferPort : CargoTransferPort;
        port launchInterface : LaunchInterfacePort;

        attribute spacecraftId : String;
        attribute dryMass : Mass;
        attribute cargoCapacity : Mass;
        attribute cargoVolume : Volume;

        part spacecraftPropulsion {
            attribute thrust : Force;
            attribute propellantMass : Mass;

            action orbitalManeuver {
                in deltaV : Velocity;
                out thrustOutput : Force;
            }

            action rendezvousBurn {
                in targetPosition : Distance[3];
                out thrustOutput : Force;
            }
        }

        part navigationSystem {
            attribute currentPosition : Distance[3];
            attribute currentVelocity : Velocity[3];
            attribute targetPosition : Distance[3];

            action computeTrajectory {
                in currentPos : Distance[3];
                in targetPos : Distance[3];
                out trajectory : String;
            }

            action determineDeltaV {
                in currentVel : Velocity[3];
                in targetVel : Velocity[3];
                out deltaV : Velocity;
            }
        }

        part rendezvousSystem {
            attribute relativeDistance : Distance;
            attribute relativeVelocity : Velocity;
            attribute approachCorridor : Angle;

            part proximitySensors {
                attribute range : Distance;
                attribute accuracy : Distance;

                action measureRelativePosition {
                    out relPos : Distance[3];
                    out relVel : Velocity[3];
                }
            }

            part lidarSensor {
                attribute maxRange : Distance;
                attribute resolution : Distance;

                action scanTarget {
                    out targetShape : String;
                    out reflectivity : Percent;
                }
            }

            action approachStation {
                in relPos : Distance[3];
                out thrustCommand : Force;
            }

            action holdPosition {
                in relPos : Distance[3];
                out thrustCommand : Force;
            }
        }

        part dockingMechanism {
            attribute captureLatchStatus : String = "open";
            attribute sealStatus : String = "unsealed";
            attribute dockingConfirmed : Boolean = false;

            action extendProbe {
                out probeExtended : Boolean;
            }

            action captureLatches {
                in captureSignal : Boolean;
                out captureConfirm : Boolean;
            }

            action engageLatches {
                in latchEngage : Boolean;
                out latchConfirm : Boolean;
            }

            action createSeal {
                out sealConfirmed : Boolean;
            }

            action releaseLatches {
                in undockSignal : Boolean;
                out undockConfirm : Boolean;
            }
        }

        part cargoModule {
            attribute internalTemperature : Temperature = 293.15;
            attribute internalPressure : Pressure = 101.325;
            attribute targetTemperature : Temperature = 277.15;
            attribute targetPressure : Pressure = 101.325;
            part cargo : CargoManifest;

            action environmentalControl {
                in targetTemp : Temperature;
                in targetPres : Pressure;
                out actualTemp : Temperature;
                out actualPres : Pressure;
            }

            action transferCargo {
                in items : CargoItem[*];
                out transferred : CargoItem[*];
            }
        }

        state spacecraftMissionBehavior {
            entry;
            state Separated {
                entry;
                transition Separated -> Cruising
                    when launchInterface.separationSignal;
            }
            state Cruising {
                entry;
                do navigationSystem.computeTrajectory;
                do spacecraftPropulsion.orbitalManeuver;
                transition Cruising -> Approaching
                    when navigationSystem.currentPosition == navigationSystem.targetPosition;
            }
            state Approaching {
                entry;
                do rendezvousSystem.approachStation;
                transition Approaching -> Docking
                    when rendezvousSystem.relativeDistance < 1;
            }
            state Docking {
                entry;
                do dockingMechanism.extendProbe;
                do dockingMechanism.captureLatches;
                do dockingMechanism.engageLatches;
                do dockingMechanism.createSeal;
                transition Docking -> Docked
                    when dockingMechanism.dockingConfirmed;
            }
            state Docked {
                entry;
                do cargoModule.transferCargo;
                transition Docked -> Undocking
                    when cargoTransferPort.transferAck;
            }
            state Undocking {
                entry;
                do dockingMechanism.releaseLatches;
                transition Undocking -> Departing
                    when dockingPort.undockConfirm;
            }
            state Departing {
                entry;
                do spacecraftPropulsion.orbitalManeuver;
            }
        }

        connect navigationSystem.computeTrajectory.trajectory to spacecraftPropulsion.orbitalManeuver;
        connect rendezvousSystem.proximitySensors.measureRelativePosition.relPos to rendezvousSystem.approachStation;
        connect rendezvousSystem.approachStation.thrustCommand to spacecraftPropulsion.rendezvousBurn;
        connect dockingMechanism.captureLatches.captureConfirm to dockingPort.captureConfirm;
        connect dockingMechanism.engageLatches.latchConfirm to dockingPort.latchConfirm;
        connect dockingMechanism.releaseLatches.undockConfirm to dockingPort.undockConfirm;
        connect cargoModule.transferCargo.transferred to cargoTransferPort.cargo;
    }

    // ===== Space Station =====
    part def SpaceStation {
        port dockingPort : DockingPort;
        port cargoTransferPort : CargoTransferPort;
        port resupplyUplink : ResupplyPort;

        attribute stationId : String;
        attribute crewSize : Integer;
        attribute orbitAltitude : Distance;

        part dockingPortAssembly {
            attribute portStatus : String = "available";
            attribute dockedSpacecraftId : String;

            action receiveCapture {
                in captureSignal : Boolean;
                out captureConfirm : Boolean;
            }

            action confirmLatches {
                in latchEngage : Boolean;
                out latchConfirm : Boolean;
            }

            action confirmUndock {
                in undockSignal : Boolean;
                out undockConfirm : Boolean;
            }
        }

        part inventorySystem {
            attribute foodLevel : Duration;
            attribute waterLevel : Duration;
            attribute oxygenLevel : Duration;
            attribute equipmentList : CargoItem[*];
            attribute resupplyThreshold : Duration = 30;

            action monitorInventory {
                out foodRemaining : Duration;
                out waterRemaining : Duration;
                out oxygenRemaining : Duration;
            }

            action generateResupplyRequest {
                in food : Duration;
                in water : Duration;
                in oxygen : Duration;
                out request : ResupplyRequest;
            }

            action receiveCargo {
                in items : CargoItem[*];
                out transferAck : Boolean;
            }

            action storeCargo {
                in items : CargoItem[*];
                out stored : Boolean;
            }
        }

        part lifeSupportSystem {
            attribute crewConsumptionRate : Mass;
            attribute atmosphericPressure : Pressure = 101.325;
            attribute cabinTemperature : Temperature = 293.15;

            action consumeResources {
                in crew : Integer;
                out foodConsumed : Mass;
                out waterConsumed : Mass;
                out oxygenConsumed : Mass;
            }

            action regenerateAtmosphere {
                out oxygenProduced : Mass;
            }
        }

        part crewHabitat {
            attribute crewCount : Integer;
            attribute habitableVolume : Volume;
        }

        state stationBehavior {
            entry;
            state NormalOperations {
                entry;
                do inventorySystem.monitorInventory;
                transition NormalOperations -> ResupplyNeeded
                    when inventorySystem.foodLevel < inventorySystem.resupplyThreshold
                        or inventorySystem.waterLevel < inventorySystem.resupplyThreshold
                        or inventorySystem.oxygenLevel < inventorySystem.resupplyThreshold;
            }
            state ResupplyNeeded {
                entry;
                do inventorySystem.generateResupplyRequest;
                transition ResupplyNeeded -> AwaitingDocking
                    when resupplyUplink.request.isSent();
            }
            state AwaitingDocking {
                entry;
                transition AwaitingDocking -> Docked
                    when dockingPort.latchConfirm;
            }
            state Docked {
                entry;
                do inventorySystem.receiveCargo;
                do inventorySystem.storeCargo;
                transition Docked -> NormalOperations
                    when dockingPort.undockConfirm;
            }
        }

        connect dockingPort.captureSignal to dockingPortAssembly.receiveCapture.captureSignal;
        connect dockingPortAssembly.receiveCapture.captureConfirm to dockingPort.captureConfirm;
        connect dockingPortAssembly.confirmLatches.latchConfirm to dockingPort.latchConfirm;
        connect dockingPortAssembly.confirmUndock.undockConfirm to dockingPort.undockConfirm;
        connect cargoTransferPort.cargo to inventorySystem.receiveCargo.items;
        connect inventorySystem.receiveCargo.transferAck to cargoTransferPort.transferAck;
        connect inventorySystem.generateResupplyRequest.request to resupplyUplink.request;
        connect lifeSupportSystem.consumeResources to inventorySystem.monitorInventory;
    }

    // ===== Top-Level System =====
    part SpaceLogisticsSystem {
        part missionControl : MissionControl;
        part launchVehicle : LaunchVehicle;
        part cargoSpacecraft : CargoSpacecraft;
        part spaceStation : SpaceStation;

        connect missionControl.commandDownlink.command to launchVehicle.telemetryDownlink.command;
        connect launchVehicle.telemetryDownlink.telemetry to missionControl.commandDownlink.telemetry;

        connect missionControl.commandDownlink.command to cargoSpacecraft.telemetryDownlink.command;
        connect cargoSpacecraft.telemetryDownlink.telemetry to missionControl.commandDownlink.telemetry;

        connect launchVehicle.launchInterface.separationSignal to cargoSpacecraft.launchInterface.separationSignal;
        connect cargoSpacecraft.launchInterface.insertionConfirm to launchVehicle.launchInterface.insertionConfirm;

        connect cargoSpacecraft.dockingPort.captureSignal to spaceStation.dockingPort.captureSignal;
        connect spaceStation.dockingPort.captureConfirm to cargoSpacecraft.dockingPort.captureConfirm;
        connect cargoSpacecraft.dockingPort.latchEngage to spaceStation.dockingPort.latchEngage;
        connect spaceStation.dockingPort.latchConfirm to cargoSpacecraft.dockingPort.latchConfirm;
        connect cargoSpacecraft.dockingPort.undockSignal to spaceStation.dockingPort.undockSignal;
        connect spaceStation.dockingPort.undockConfirm to cargoSpacecraft.dockingPort.undockConfirm;

        connect cargoSpacecraft.cargoTransferPort.cargo to spaceStation.cargoTransferPort.cargo;
        connect spaceStation.cargoTransferPort.transferAck to cargoSpacecraft.cargoTransferPort.transferAck;

        connect spaceStation.resupplyUplink.request to missionControl.resupplyUplink.request;
    }

    // ===== Requirements =====
    requirement def LogisticsMissionRequirement {
        subject system : SpaceLogisticsSystem;
        attribute missionSuccessCriteria : String;
    }

    requirement CargoDeliveryRequirement :> LogisticsMissionRequirement {
        doc /* The system shall deliver cargo from Earth to an orbiting space station. */
        require system.cargoSpacecraft.cargoModule.cargo.totalMass > 0;
    }

    requirement ResupplyThresholdRequirement :> LogisticsMissionRequirement {
        doc /* The station shall generate a resupply request when consumables fall below 30 days. */
        require system.spaceStation.inventorySystem.resupplyThreshold == 30;
    }

    requirement DockingRequirement :> LogisticsMissionRequirement {
        doc /* The cargo spacecraft shall securely dock with the space station using capture latches. */
        require system.cargoSpacecraft.dockingMechanism.dockingConfirmed == true;
    }

    requirement EnvironmentalControlRequirement :> LogisticsMissionRequirement {
        doc /* The cargo module shall maintain temperature and pressure for perishable items. */
        require system.cargoSpacecraft.cargoModule.internalTemperature == system.cargoSpacecraft.cargoModule.targetTemperature;
        require system.cargoSpacecraft.cargoModule.internalPressure == system.cargoSpacecraft.cargoModule.targetPressure;
    }

    requirement MissionControlAuthorizationRequirement :> LogisticsMissionRequirement {
        doc /* Mission control shall authorize critical mission phases including docking. */
        require system.missionControl.authorizationSystem.dockingApprovalGranted == true;
    }

    requirement LaunchVehicleSeparationRequirement :> LogisticsMissionRequirement {
        doc /* The launch vehicle shall separate from the cargo spacecraft at orbital insertion. */
        require system.launchVehicle.launchInterface.separationSignal == true;
    }

    requirement TelemetryMonitoringRequirement :> LogisticsMissionRequirement {
        doc /* Mission control shall continuously monitor telemetry from all vehicles. */
        require system.missionControl.telemetryMonitor.latestTelemetry->size() > 0;
    }

    requirement CargoTransferRequirement :> LogisticsMissionRequirement {
        doc /* The station shall receive and store all transferred cargo items upon docking. */
        require system.spaceStation.inventorySystem.receiveCargo.transferAck == true;
    }
}
