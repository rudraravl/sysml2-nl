package SpaceLogistics {

  import ScalarValues::*;
  import SI::*;

  attribute def Mass :> Real { unit = "kg"; }
  attribute def Volume :> Real { unit = "m^3"; }
  attribute def Distance :> Real { unit = "km"; }
  attribute def Time :> Real { unit = "s"; }
  attribute def Temperature :> Real { unit = "K"; }
  attribute def Power :> Real { unit = "W"; }
  attribute def DataRate :> Real { unit = "Mbps"; }
  attribute def DeltaV :> Real { unit = "m/s"; }
  attribute def Availability :> Real { unit = "percent"; }

  item def LogisticsRequest {
    attribute requestId : String;
    attribute destinationOrbit : String;
    attribute requiredDeliveryTime : Time;
    attribute payloadMass : Mass;
    attribute payloadVolume : Volume;
    attribute priority : Integer;
  }

  item def CargoPackage {
    attribute packageId : String;
    attribute mass : Mass;
    attribute volume : Volume;
    attribute thermalMin : Temperature;
    attribute thermalMax : Temperature;
    attribute hazardous : Boolean;
    attribute destinationNode : String;
  }

  item def Propellant {
    attribute type : String;
    attribute mass : Mass;
    attribute storageTemperature : Temperature;
  }

  item def Telemetry {
    attribute vehiclePosition : Distance;
    attribute remainingDeltaV : DeltaV;
    attribute powerMargin : Power;
    attribute cargoHealthNominal : Boolean;
    attribute dataRate : DataRate;
  }

  item def Command {
    attribute commandId : String;
    attribute commandType : String;
    attribute executionTime : Time;
  }

  item def DeliveryReport {
    attribute requestId : String;
    attribute deliveredMass : Mass;
    attribute deliveryTime : Time;
    attribute destinationConfirmed : Boolean;
    attribute exceptions : String;
  }

  port def CargoPort {
    in item receivedCargo : CargoPackage;
    out item dispatchedCargo : CargoPackage;
  }

  port def PropellantPort {
    in item loadedPropellant : Propellant;
    out item transferredPropellant : Propellant;
  }

  port def CommandTelemetryPort {
    in item command : Command;
    out item telemetry : Telemetry;
  }

  port def DockingPort {
    in item inboundCargo : CargoPackage;
    out item outboundCargo : CargoPackage;
    in item inboundPropellant : Propellant;
    out item outboundPropellant : Propellant;
  }

  part def MissionControlCenter {
    attribute operatorCount : Integer = 12;
    attribute planningAvailability : Availability = 99.9;

    port networkPort : CommandTelemetryPort;

    action def PlanMission {
      in request : LogisticsRequest;
      out commandPlan : Command;
    }
  }

  part def GroundLogisticsHub {
    attribute storageCapacityMass : Mass = 250000;
    attribute storageCapacityVolume : Volume = 1800;
    attribute coldStoragePower : Power = 50000;

    port cargoInterface : CargoPort;
    port propellantInterface : PropellantPort;

    action def PrepareManifest {
      in request : LogisticsRequest;
      out package : CargoPackage;
    }
  }

  part def LaunchComplex {
    attribute maxPayloadMass : Mass = 22000;
    attribute launchCadence : Time = 604800;

    port cargoLoadPort : CargoPort;
    port propellantLoadPort : PropellantPort;
    port commandPort : CommandTelemetryPort;

    action def IntegrateLaunchVehicle {
      in cargo : CargoPackage;
      in propellant : Propellant;
      out readyForLaunch : Boolean;
    }
  }

  part def OrbitalTransferVehicle {
    attribute dryMass : Mass = 6500;
    attribute maxCargoMass : Mass = 12000;
    attribute maxCargoVolume : Volume = 95;
    attribute propellantCapacity : Mass = 18000;
    attribute availableDeltaV : DeltaV = 4200;
    attribute solarArrayPower : Power = 28000;

    port cargoBayPort : CargoPort;
    port refuelPort : PropellantPort;
    port dockingPort : DockingPort;
    port commandTelemetryPort : CommandTelemetryPort;

    action def ExecuteTransfer {
      in targetNode : String;
      in cargo : CargoPackage;
      out deliveredCargo : CargoPackage;
    }

    state def VehicleMissionState {
      state Dormant;
      state Checkout;
      state CargoLoaded;
      state LaunchAscent;
      state OrbitInsertion;
      state Rendezvous;
      state DockedTransfer;
      state ReturnOrDisposal;
      state SafeMode;

      transition initial then Dormant;
      transition Dormant to Checkout accept command.commandType == "ACTIVATE";
      transition Checkout to CargoLoaded accept command.commandType == "LOAD_COMPLETE";
      transition CargoLoaded to LaunchAscent accept command.commandType == "LAUNCH";
      transition LaunchAscent to OrbitInsertion accept telemetry.vehiclePosition > 160;
      transition OrbitInsertion to Rendezvous accept command.commandType == "RENDEZVOUS";
      transition Rendezvous to DockedTransfer accept command.commandType == "DOCK_CONFIRMED";
      transition DockedTransfer to ReturnOrDisposal accept command.commandType == "TRANSFER_COMPLETE";
      transition Checkout to SafeMode accept telemetry.powerMargin < 1000;
      transition OrbitInsertion to SafeMode accept telemetry.remainingDeltaV < 300;
      transition Rendezvous to SafeMode accept telemetry.cargoHealthNominal == false;
      transition SafeMode to Checkout accept command.commandType == "RECOVER";
    }
  }

  part def OrbitalDepot {
    attribute depotOrbit : String = "LEO 500 km circular";
    attribute cargoCapacityMass : Mass = 80000;
    attribute propellantCapacity : Mass = 120000;
    attribute averagePowerAvailable : Power = 65000;

    port dockingNode : DockingPort;
    port depotCommandPort : CommandTelemetryPort;

    action def ReceiveAndStore {
      in deliveredCargo : CargoPackage;
      out storageConfirmed : Boolean;
    }

    action def RefuelVehicle {
      in transferVehicle : String;
      out propellantIssued : Propellant;
    }
  }

  part def CustomerSpacecraft {
    attribute operationalOrbit : String = "Cislunar transfer staging orbit";
    attribute cargoNeedMass : Mass = 5000;
    attribute resupplyInterval : Time = 2592000;

    port serviceDock : DockingPort;
    port serviceCommandPort : CommandTelemetryPort;

    action def AcceptDelivery {
      in cargo : CargoPackage;
      out report : DeliveryReport;
    }
  }

  action def FulfillOrbitalLogisticsRequest {
    in request : LogisticsRequest;
    out report : DeliveryReport;

    action receiveRequest;
    action planTrajectory;
    action prepareCargo;
    action loadVehicle;
    action launchToOrbit;
    action performRendezvous;
    action dockAndTransfer;
    action confirmDelivery;

    flow receiveRequest then planTrajectory;
    flow planTrajectory then prepareCargo;
    flow prepareCargo then loadVehicle;
    flow loadVehicle then launchToOrbit;
    flow launchToOrbit then performRendezvous;
    flow performRendezvous then dockAndTransfer;
    flow dockAndTransfer then confirmDelivery;
  }

  part def SpaceLogisticsArchitecture {
    doc /* Primary function: receive logistics demand from orbital customers, prepare cargo and propellant on Earth, launch and transfer payloads through orbital nodes, and deliver confirmed supplies to spacecraft or depots while maintaining command, telemetry, cargo health, and mission safety. */

    part missionControl : MissionControlCenter;
    part groundHub : GroundLogisticsHub;
    part launchComplex : LaunchComplex;
    part transferVehicle : OrbitalTransferVehicle;
    part orbitalDepot : OrbitalDepot;
    part customerSpacecraft : CustomerSpacecraft;

    port externalRequestPort : CommandTelemetryPort;

    connection controlToLaunch connect missionControl.networkPort to launchComplex.commandPort;
    connection controlToVehicle connect missionControl.networkPort to transferVehicle.commandTelemetryPort;
    connection controlToDepot connect missionControl.networkPort to orbitalDepot.depotCommandPort;
    connection controlToCustomer connect missionControl.networkPort to customerSpacecraft.serviceCommandPort;

    connection cargoGroundToLaunch connect groundHub.cargoInterface to launchComplex.cargoLoadPort;
    connection propellantGroundToLaunch connect groundHub.propellantInterface to launchComplex.propellantLoadPort;
    connection launchToVehicleCargo connect launchComplex.cargoLoadPort to transferVehicle.cargoBayPort;
    connection launchToVehiclePropellant connect launchComplex.propellantLoadPort to transferVehicle.refuelPort;

    connection vehicleToDepotDocking connect transferVehicle.dockingPort to orbitalDepot.dockingNode;
    connection depotToCustomerDocking connect orbitalDepot.dockingNode to customerSpacecraft.serviceDock;

    perform primaryMission : FulfillOrbitalLogisticsRequest;
  }

  requirement def HighLevelFunctionRequirement {
    subject system : SpaceLogisticsArchitecture;
    require constraint {
      system.primaryMission.report.destinationConfirmed == true
    }
    doc /* The space logistics system shall complete end-to-end orbital delivery from request acceptance through delivery confirmation. */
  }

  requirement def PayloadCapacityRequirement {
    subject vehicle : OrbitalTransferVehicle;
    require constraint {
      vehicle.maxCargoMass >= 10000 and vehicle.maxCargoVolume >= 80
    }
  }

  requirement def DepotStorageRequirement {
    subject depot : OrbitalDepot;
    require constraint {
      depot.cargoCapacityMass >= 75000 and depot.propellantCapacity >= 100000
    }
  }

  requirement def MissionSafetyRequirement {
    subject vehicle : OrbitalTransferVehicle;
    require constraint {
      vehicle.availableDeltaV >= 3500 and vehicle.solarArrayPower >= 25000
    }
  }

  requirement def CommandTelemetryRequirement {
    subject control : MissionControlCenter;
    require constraint {
      control.planningAvailability >= 99.5
    }
  }

}