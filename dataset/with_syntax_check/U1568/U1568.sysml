package 'Space Logistics System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def MissionID;
	attribute def CargoManifest;
	attribute def OrbitParameters;
	
	enum def DockingStatus {
		enum standby;
		enum approaching;
		enum aligned;
		enum locked;
		enum transferring;
		enum separated;
	}
	
	enum def MissionPhase {
		enum planning;
		enum launch;
		enum ascent;
		enum orbitalTransfer;
		enum rendezvous;
		enum docking;
		enum cargoTransfer;
		enum undocking;
		enum deorbit;
		enum completed;
	}
	
	item def Propellant {
		attribute mass : MassValue;
		attribute type : String;
		attribute density : DensityValue;
	}
	
	item def CargoItem {
		attribute itemID : String;
		attribute mass : MassValue;
		attribute volume : VolumeValue;
		attribute priority : Integer;
		attribute perishable : Boolean;
	}
	
	item def Cargo {
		attribute totalMass : MassValue;
		attribute totalVolume : VolumeValue;
		attribute manifest : CargoManifest;
		item cargoItems : CargoItem[*];
	}
	
	item def Consumables {
		attribute water : MassValue;
		attribute food : MassValue;
		attribute oxygen : MassValue;
		attribute supplies : MassValue;
	}
	
	attribute def DeltaV :> ISQ::speed;
	attribute def ThrustLevel :> ISQ::force;
	attribute def PropellantFlow :> ISQ::massFlowRate;
	
	port def CargoTransferPort {
		in item incomingCargo : Cargo;
		out item outgoingCargo : Cargo;
		attribute transferRate : ISQ::massFlowRate;
	}
	
	port def DockingInterfacePort {
		attribute status : DockingStatus;
		attribute alignment : Real;
		attribute relativeVelocity : SpeedValue;
	}
	
	port def TelemetryPort {
		out attribute position : OrbitParameters;
		out attribute velocity : SpeedValue;
		out attribute attitude : String;
		out attribute systemStatus : String;
	}
	
	port def CommandPort {
		in attribute missionCommands : String;
		in attribute maneuverCommands : DeltaV;
	}
	
	part def MissionControl {
		port commandPort : CommandPort;
		port telemetryPort : TelemetryPort;
		
		action def PlanMission {
			in missionID : MissionID;
			in cargoRequirements : CargoManifest;
			in targetOrbit : OrbitParameters;
			out flightPlan : String;
			out launchWindow : String;
			out requiredDeltaV : DeltaV;
		}
		
		action def MonitorMission {
			in telemetryData : String;
			in currentPhase : MissionPhase;
			out statusAssessment : String;
			out correctionCommands : String;
		}
		
		action def AuthorizeDocking {
			in approachData : String;
			in safetyCheck : Boolean;
			out dockingClearance : Boolean;
		}
	}
	
	part def LaunchVehicle {
		attribute dryMass : MassValue;
		attribute maxPayloadMass : MassValue;
		attribute currentPayloadMass : MassValue;
		
		port cargoPort : CargoTransferPort;
		port telemetryPort : TelemetryPort;
		port commandPort : CommandPort;
		
		part propulsionSystem {
			attribute propellantMass : MassValue;
			attribute maxThrust : ThrustLevel;
			attribute specificImpulse : SpeedValue;
			item propellant : Propellant;
		}
		
		part guidanceSystem {
			attribute targetOrbit : OrbitParameters;
			attribute currentOrbit : OrbitParameters;
			attribute navigationAccuracy : LengthValue;
		}
		
		part structuralSystem {
			attribute structuralMass : MassValue;
			attribute maxLoadFactor : Real;
		}
		
		action def Launch {
			in launchWindow : String;
			in targetOrbit : OrbitParameters;
			in payloadMass : MassValue;
			out launchSuccess : Boolean;
			out actualOrbit : OrbitParameters;
		}
		
		action def AscentToOrbit {
			in currentAltitude : LengthValue;
			in currentVelocity : SpeedValue;
			in targetVelocity : SpeedValue;
			out orbitalInsertionStatus : Boolean;
			out propellantRemaining : MassValue;
		}
		
		action def StageSeparation {
			in separationAltitude : LengthValue;
			out separationSuccess : Boolean;
		}
	}
	
	part def CargoSpacecraft {
		attribute spacecraftMass : MassValue;
		attribute cargoCapacity : MassValue;
		attribute currentCargoMass : MassValue;
		attribute autonomyLevel : Integer;
		
		port dockingPort : DockingInterfacePort;
		port cargoPort : CargoTransferPort;
		port telemetryPort : TelemetryPort;
		port commandPort : CommandPort;
		
		part navigationSystem {
			attribute currentPosition : OrbitParameters;
			attribute targetPosition : OrbitParameters;
			attribute positionAccuracy : LengthValue;
			attribute velocityAccuracy : SpeedValue;
		}
		
		part cargoModule {
			attribute storedCargo : Cargo;
			attribute internalVolume : VolumeValue;
			attribute temperature : TemperatureValue;
			attribute pressure : PressureValue;
			attribute environmentalControl : Boolean;
		}
		
		part rendezvousSystem {
			attribute relativeVelocity : SpeedValue;
			attribute relativeDistance : LengthValue;
			attribute approachRate : SpeedValue;
			attribute sensorRange : LengthValue;
		}
		
		part propulsionModule {
			attribute propellantMass : MassValue;
			attribute thrusterCount : Integer;
			attribute maxThrust : ThrustLevel;
		}
		
		part dockingMechanism {
			attribute dockingStatus : DockingStatus;
			attribute captureLatches : Integer;
			attribute sealIntegrity : Real;
		}
		
		action def OrbitalManeuver {
			in requiredDeltaV : DeltaV;
			in currentOrbit : OrbitParameters;
			out newOrbit : OrbitParameters;
			out propellantUsed : MassValue;
		}
		
		action def RendezvousApproach {
			in stationOrbit : OrbitParameters;
			in approachVector : String;
			in safetyDistance : LengthValue;
			out rendezvousComplete : Boolean;
			out finalDistance : LengthValue;
		}
		
		action def ExecuteDocking {
			in alignmentData : String;
			in approachVelocity : SpeedValue;
			out dockingSuccess : Boolean;
			out contactTime : String;
		}
		
		action def TransferCargo {
			in cargoToTransfer : Cargo;
			in transferDuration : TimeValue;
			out transferComplete : Boolean;
			out cargoDelivered : MassValue;
		}
		
		state def OperationalStates {
			entry; then cruise;
			
			state cruise {
				entry assign navigationSystem.currentPosition := navigationSystem.targetPosition;
			}
			accept at when rendezvousSystem.relativeDistance < 10000.0[m]
				then approaching;
			
			state approaching;
			do action approachAction : RendezvousApproach;
			accept at when rendezvousSystem.relativeDistance < 100.0[m]
				then finalApproach;
			
			state finalApproach;
			accept at when dockingMechanism.dockingStatus == DockingStatus::aligned
				then docking;
			
			state docking;
			do action dockAction : ExecuteDocking;
			accept at when dockingMechanism.dockingStatus == DockingStatus::locked
				then docked;
			
			state docked;
			do action transferAction : TransferCargo;
			accept at when transferAction.transferComplete
				then undocking;
			
			state undocking;
			accept at when dockingMechanism.dockingStatus == DockingStatus::separated
				then departure;
			
			state departure;
			then done;
		}
	}
	
	part def SpaceStation {
		attribute stationMass : MassValue;
		attribute orbitAltitude : LengthValue;
		attribute orbitInclination : Real;
		attribute crewCapacity : Integer;
		attribute currentCrewSize : Integer;
		
		port dockingPort1 : DockingInterfacePort;
		port dockingPort2 : DockingInterfacePort;
		port cargoReceivingPort : CargoTransferPort;
		port telemetryPort : TelemetryPort;
		port commandPort : CommandPort;
		
		part storageModule {
			attribute totalStorageVolume : VolumeValue;
			attribute availableVolume : VolumeValue;
			attribute storedSupplies : Consumables;
			attribute inventoryMass : MassValue;
		}
		
		part lifeSupportSystem {
			attribute oxygenLevel : Real;
			attribute waterReserves : MassValue;
			attribute foodReserves : MassValue;
			attribute co2RemovalCapacity : ISQ::massFlowRate;
			attribute waterRecyclingRate : Real;
		}
		
		part crewModule {
			attribute crewMembers : Integer;
			attribute dailyWaterConsumption : MassValue;
			attribute dailyFoodConsumption : MassValue;
			attribute dailyOxygenConsumption : MassValue;
		}
		
		part powerSystem {
			attribute solarArrayArea : AreaValue;
			attribute batteryCapacity : EnergyValue;
			attribute currentPowerOutput : PowerValue;
		}
		
		action def ReceiveCargo {
			in incomingCargo : Cargo;
			in dockingPortID : String;
			out storageAllocation : String;
			out inventoryUpdate : String;
		}
		
		action def ManageInventory {
			in currentInventory : Consumables;
			in consumptionRate : MassValue;
			in crewSize : Integer;
			out daysRemaining : Real;
			out resupplyNeeded : Boolean;
		}
		
		action def GenerateResupplyRequest {
			in projectedShortfall : Consumables;
			in urgencyLevel : Integer;
			out resupplyManifest : CargoManifest;
			out requestedDeliveryDate : String;
		}
		
		state def StationOperationalStates {
			entry; then normalOperations;
			
			state normalOperations {
				entry assign lifeSupportSystem.oxygenLevel := 100.0;
			}
			do action inventoryCheck : ManageInventory;
			accept at when inventoryCheck.daysRemaining < 30.0
				then resupplyRequired;
			
			state resupplyRequired;
			do action requestResupply : GenerateResupplyRequest;
			accept at dockingPort1 then awaitingDocking;
			
			state awaitingDocking;
			accept at when dockingPort1.status == DockingStatus::locked
				then receivingCargo;
			
			state receivingCargo;
			do action receiveCargoAction : ReceiveCargo;
			accept at when receiveCargoAction.inventoryUpdate == "complete"
				then normalOperations;
		}
	}
	
	action def ExecuteLogisticsMission {
		in missionID : MissionID;
		in cargoManifest : CargoManifest;
		in launchSite : String;
		in targetStation : String;
		out missionSuccess : Boolean;
		out deliveredMass : MassValue;
		
		first start;
		
		then action planMission : MissionControl::PlanMission {
			in missionID = missionID;
			in cargoRequirements = cargoManifest;
			in targetOrbit : OrbitParameters;
			out flightPlan;
			out launchWindow;
			out requiredDeltaV;
		}
		
		then action prepareCargo {
			in manifest = cargoManifest;
			out loadedCargo : Cargo;
			out cargoMass : MassValue;
		}
		
		then action launchSequence : LaunchVehicle::Launch {
			in launchWindow = planMission.launchWindow;
			in targetOrbit = planMission.targetOrbit;
			in payloadMass = prepareCargo.cargoMass;
			out launchSuccess;
			out actualOrbit;
		}
		
		then decide launchCheck;
			if launchSequence.launchSuccess then ascentPhase;
			if !launchSequence.launchSuccess then abortMission;
		
		action ascentPhase : LaunchVehicle::AscentToOrbit {
			in currentAltitude : LengthValue;
			in currentVelocity : SpeedValue;
			in targetVelocity : SpeedValue;
			out orbitalInsertionStatus;
			out propellantRemaining;
		}
		
		then action orbitalTransfer : CargoSpacecraft::OrbitalManeuver {
			in requiredDeltaV = planMission.requiredDeltaV;
			in currentOrbit = launchSequence.actualOrbit;
			out newOrbit;
			out propellantUsed;
		}
		
		then action rendezvous : CargoSpacecraft::RendezvousApproach {
			in stationOrbit = planMission.targetOrbit;
			in approachVector : String;
			in safetyDistance = 1000.0[m];
			out rendezvousComplete;
			out finalDistance;
		}
		
		then action dockingApproval : MissionControl::AuthorizeDocking {
			in approachData : String;
			in safetyCheck = rendezvous.rendezvousComplete;
			out dockingClearance;
		}
		
		then decide dockingCheck;
			if dockingApproval.dockingClearance then performDocking;
			if !dockingApproval.dockingClearance then holdPosition;
		
		action performDocking : CargoSpacecraft::ExecuteDocking {
			in alignmentData : String;
			in approachVelocity = 0.1[m/s];
			out dockingSuccess;
			out contactTime;
		}
		then cargoTransferPhase;
		
		action holdPosition;
		then rendezvous;
		
		action cargoTransferPhase : CargoSpacecraft::TransferCargo {
			in cargoToTransfer = prepareCargo.loadedCargo;
			in transferDuration = 7200.0[s];
			out transferComplete;
			out cargoDelivered;
		}
		
		then action stationReceive : SpaceStation::ReceiveCargo {
			in incomingCargo = prepareCargo.loadedCargo;
			in dockingPortID : String;
			out storageAllocation;
			out inventoryUpdate;
		}
		
		then action missionComplete {
			assign missionSuccess := true;
			assign deliveredMass := cargoTransferPhase.cargoDelivered;
		}
		then done;
		
		action abortMission {
			assign missionSuccess := false;
			assign deliveredMass := 0.0[kg];
		}
		then done;
	}
	
	part spaceLogisticsSystem {
		doc /*
			The Space Logistics System provides autonomous cargo delivery and resupply 
			capabilities for orbital space stations and facilities. Its primary function 
			is to transport essential supplies, equipment, and consumables from Earth to 
			orbiting destinations through coordinated launch, orbital transfer, rendezvous, 
			docking, and cargo transfer operations. The system ensures continuous support 
			for crewed space operations by maintaining adequate inventory levels of critical 
			resources including water, food, oxygen, spare parts, and scientific equipment.
		*/
		
		part missionControl : MissionControl {
			perform ExecuteLogisticsMission.planMission;
			perform ExecuteLogisticsMission.dockingApproval;
		}
		
		part launcher : LaunchVehicle {
			perform ExecuteLogisticsMission.launchSequence;
			perform ExecuteLogisticsMission.ascentPhase;
		}
		
		part cargoVehicle : CargoSpacecraft {
			perform ExecuteLogisticsMission.orbitalTransfer;
			perform ExecuteLogisticsMission.rendezvous;
			perform ExecuteLogisticsMission.performDocking;
			perform ExecuteLogisticsMission.cargoTransferPhase;
		}
		
		part station : SpaceStation {
			perform ExecuteLogisticsMission.stationReceive;
			perform action manageResources : SpaceStation::ManageInventory;
		}
		
		connect missionControl.commandPort to launcher.commandPort;
		connect missionControl.telemetryPort to launcher.telemetryPort;
		connect missionControl.commandPort to cargoVehicle.commandPort;
		connect missionControl.telemetryPort to cargoVehicle.telemetryPort;
		connect missionControl.commandPort to station.commandPort;
		connect missionControl.telemetryPort to station.telemetryPort;
		connect launcher.cargoPort to cargoVehicle.cargoPort;
		connect cargoVehicle.dockingPort to station.dockingPort1;
		connect cargoVehicle.cargoPort to station.cargoReceivingPort;
	}
	
	requirement <'SLS-REQ-001'> primaryLogisticsCapability {
		doc /*
			The space logistics system shall deliver cargo to orbital stations 
			with a minimum payload capacity of 3000 kg per mission to support 
			continuous crew operations and scientific activities.
		*/
		
		subject spaceLogisticsSystem;
		
		require constraint {
			spaceLogisticsSystem.cargoVehicle.cargoCapacity >= 3000.0[kg]
		}
	}
	
	requirement <'SLS-REQ-002'> missionReliability {
		doc /*
			The system shall achieve successful cargo delivery with a mission 
			success rate of at least 98% to ensure reliable supply chain operations.
		*/
		
		subject spaceLogisticsSystem;
	}
	
	requirement <'SLS-REQ-003'> rendezvousAccuracy {
		doc /*
			The cargo spacecraft shall achieve rendezvous with the target station 
			within 50 meters positional accuracy to enable safe docking operations.
		*/
		
		subject spaceLogisticsSystem.cargoVehicle;
		
		require constraint {
			spaceLogisticsSystem.cargoVehicle.rendezvousSystem.relativeDistance <= 50.0[m]
		}
	}
	
	requirement <'SLS-REQ-004'> consumablesDelivery {
		doc /*
			Each logistics mission shall deliver sufficient consumables to support 
			station crew operations for a minimum of 90 days based on nominal 
			consumption rates.
		*/
		
		subject spaceLogisticsSystem;
		
		assume constraint {
			spaceLogisticsSystem.station.currentCrewSize <= 6
		}
		
		require constraint {
			spaceLogisticsSystem.cargoVehicle.cargoModule.storedCargo.totalMass >= 
				spaceLogisticsSystem.station.crewModule.dailyWaterConsumption * 90.0 +
				spaceLogisticsSystem.station.crewModule.dailyFoodConsumption * 90.0 +
				spaceLogisticsSystem.station.crewModule.dailyOxygenConsumption * 90.0
		}
	}
	
	requirement <'SLS-REQ-005'> dockingSafety {
		doc /*
			The cargo spacecraft shall maintain approach velocity below 0.15 m/s 
			during final docking phase to prevent damage to station docking interface.
		*/
		
		subject spaceLogisticsSystem.cargoVehicle;
		
		require constraint {
			spaceLogisticsSystem.cargoVehicle.rendezvousSystem.approachRate <= 0.15[m/s]
		}
	}
	
	requirement <'SLS-REQ-006'> cargoEnvironmentalControl {
		doc /*
			The cargo module shall maintain temperature between 15 degC and 25 degC 
			and pressure at 101.3 kPa to preserve perishable supplies and equipment.
		*/
		
		subject spaceLogisticsSystem.cargoVehicle.cargoModule;
		
		require constraint {
			spaceLogisticsSystem.cargoVehicle.cargoModule.temperature >= 288.15[K] and
			spaceLogisticsSystem.cargoVehicle.cargoModule.temperature <= 298.15[K] and
			spaceLogisticsSystem.cargoVehicle.cargoModule.pressure == 101.3[kPa]
		}
	}
}
