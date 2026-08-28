package 'Automated Highway System' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Types {
		item def VehicleStatus {
			attribute position : LengthValue;
			attribute speed : SpeedValue;
			attribute heading : ScalarValues::Real;
		}
		item def RoadConditionData {
			attribute visibility : LengthValue;
			attribute friction : Real;
		}
		item def TrafficData {
			attribute roadConditions : RoadConditionData;
			attribute averageSpeed : SpeedValue;
			attribute vehicleCount : Integer;
		}
		item def DrivingCommand {
			attribute targetSpeed : SpeedValue;
			attribute targetLane : Integer;
			attribute targetSpacing : LengthValue;
		}
		item def EmergencyCommand {
			attribute brake : Boolean;
			attribute targetSpeed : SpeedValue;
		}
		attribute def 'Enter Highway';
		attribute def 'Exit Highway';
		attribute def 'Bad Weather';
		attribute def 'Good Weather';
		attribute def 'Critical Failure';
		attribute def 'System Reset';
	}

	package Components {
		private import Types::*;

		part def ConnectedVehicle {
			attribute automationLevel : Integer = 4;
			port commandPort {
				in drivingCommand : DrivingCommand;
				in emergencyCommand : EmergencyCommand;
			}
			port statusPort {
				out status : VehicleStatus;
			}
			exhibit state 'vehicle control states' : 'Vehicle Control States';
		}
		part def RoadwaySensor {
			port dataPort {
				out trafficData : TrafficData;
			}
			action senseEnvironment {
				out trafficData : TrafficData;
			}
		}
		part def CommunicationNode {
			port vehicleSidePort {
				in vehicleStatus : VehicleStatus;
				out drivingCommand : DrivingCommand;
				out emergencyCommand : EmergencyCommand;
			}
			port controllerSidePort {
				out vehicleStatus : VehicleStatus;
				in drivingCommand : DrivingCommand;
				in emergencyCommand : EmergencyCommand;
			}
			action relayData;
		}
		part def CentralTrafficController {
			port sensorDataPort {
				in trafficData : TrafficData;
			}
			port commandPort {
				out drivingCommand : DrivingCommand;
			}
			exhibit state 'controller operational states' : 'Controller Operational States';
			action computeOptimalFlow {
				in trafficData : TrafficData;
				out drivingCommand : DrivingCommand;
			}
		}
		part def SafetyManagementSystem {
			port sensorDataPort {
				in trafficData : TrafficData;
			}
			port vehicleStatusPort {
				in vehicleStatus : VehicleStatus;
			}
			port emergencyPort {
				out emergencyCommand : EmergencyCommand;
			}
			action detectHazards {
				in trafficData : TrafficData;
				in vehicleStatus : VehicleStatus;
				out emergencyCommand : EmergencyCommand;
			}
		}

		state def 'Vehicle Control States' {
			entry; then manual;
			state manual;
			accept 'Enter Highway'
				then automated;
			state automated;
			accept 'Exit Highway'
				then manual;
		}
		state def 'Controller Operational States' {
			entry; then normal;
			state normal;
			accept 'Bad Weather'
				then reducedCapacity;
			state reducedCapacity;
			accept 'Good Weather'
				then normal;
			accept 'Critical Failure'
				then safeMode;
			state safeMode;
			accept 'System Reset'
				then normal;
		}
	}

	package System {
		private import Types::*;
		private import Components::*;

		part highwaySystem {
			part vehicles : ConnectedVehicle[0..*];
			part sensors : RoadwaySensor[0..*];
			part commNodes : CommunicationNode[0..*];
			part centralController : CentralTrafficController;
			part safetySystem : SafetyManagementSystem;

			flow trafficDataFlow of TrafficData
				from sensors.dataPort.trafficData to centralController.sensorDataPort.trafficData;
			flow safetyTrafficDataFlow of TrafficData
				from sensors.dataPort.trafficData to safetySystem.sensorDataPort.trafficData;

			flow vehicleStatusFlow of VehicleStatus
				from vehicles.statusPort.status to commNodes.vehicleSidePort.vehicleStatus;
			flow relayedStatusFlow of VehicleStatus
				from commNodes.controllerSidePort.vehicleStatus to safetySystem.vehicleStatusPort.vehicleStatus;

			flow commandFlow of DrivingCommand
				from centralController.commandPort.drivingCommand to commNodes.controllerSidePort.drivingCommand;
			flow relayedCommandFlow of DrivingCommand
				from commNodes.vehicleSidePort.drivingCommand to vehicles.commandPort.drivingCommand;

			flow emergencyFlow of EmergencyCommand
				from safetySystem.emergencyPort.emergencyCommand to commNodes.controllerSidePort.emergencyCommand;
			flow relayedEmergencyFlow of EmergencyCommand
				from commNodes.vehicleSidePort.emergencyCommand to vehicles.commandPort.emergencyCommand;
		}
	}

	package Requirements {
		private import Types::*;
		private import Components::*;
		private import System::*;

		requirement def 'Automated Highway System Requirement' {
			subject highwaySystem : System::highwaySystem;
			doc /* The system shall manage and optimize the flow of connected autonomous vehicles on a dedicated roadway. */
		}
		requirement def 'Safety Override Requirement' {
			subject safetySystem : SafetyManagementSystem;
			doc /* The safety system shall issue emergency commands to vehicles when hazardous situations are detected. */
		}
		requirement def 'Operational Modes Requirement' {
			subject centralController : CentralTrafficController;
			doc /* The central controller shall operate in normal, reduced capacity, and safe modes based on environmental and system conditions. */
		}
		requirement def 'Vehicle Automation Requirement' {
			subject vehicles : ConnectedVehicle;
			doc /* Vehicles shall transition between manual and automated control upon entering or exiting the managed highway segment. */
		}
	}
}
