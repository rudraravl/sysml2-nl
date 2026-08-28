package VehicularAutomationSystem {
	private import ScalarValues::*;

	value def Speed :> Real;
	value def Angle :> Real;
	value def Distance :> Real;

	item def Position3D {
		attribute x : Distance;
		attribute y : Distance;
		attribute z : Distance;
	}

	item def Obstacle {
		attribute classification : String;
		attribute position : Position3D;
		attribute velocity : Position3D;
	}

	item def LaneMarking {
		attribute markingType : String;
		attribute position : Position3D;
	}

	item def TrafficSignal {
		attribute signalType : String;
		attribute signalState : String;
		attribute position : Position3D;
	}

	item def RawSensorData;
	item def FusedSensorData;

	item def EnvironmentModel {
		attribute obstacles : Obstacle[0..*];
		attribute laneMarkings : LaneMarking[0..*];
		attribute trafficSignals : TrafficSignal[0..*];
	}

	item def VehicleState {
		attribute position : Position3D;
		attribute speed : Speed;
		attribute heading : Angle;
	}

	item def TrajectoryPlan {
		attribute waypoints : Position3D[0..*];
		attribute targetSpeed : Speed;
	}

	item def ControlCommand {
		attribute throttle : Real;
		attribute brake : Real;
		attribute steering : Angle;
	}

	item def EmergencyBrakeCommand {
		attribute apply : Boolean;
	}

	item def SafetyAlert {
		attribute alertText : String;
		attribute isCritical : Boolean;
	}

	item def DriverInput {
		attribute destination : String;
		attribute automationLevel : Natural;
		attribute manualOverride : Boolean;
	}

	item def SystemStatus {
		attribute currentMode : String;
		attribute health : String;
	}

	part def PhysicalSensors {
		port rawOutPort {
			out rawOut : RawSensorData;
		}
	}

	part def SensorFusionModule {
		port rawInPort {
			in rawIn : RawSensorData;
		}
		port fusedOutPort {
			out fusedOut : FusedSensorData;
		}
	}

	part def PerceptionModule {
		port fusedInPort {
			in fusedIn : FusedSensorData;
		}
		port envOutPort {
			out envOut : EnvironmentModel;
		}
	}

	part def LocalizationModule {
		port fusedInPort {
			in fusedIn : FusedSensorData;
		}
		port stateOutPort {
			out stateOut : VehicleState;
		}
	}

	part def PlanningModule {
		port envInPort {
			in envIn : EnvironmentModel;
		}
		port stateInPort {
			in stateIn : VehicleState;
		}
		port driverInPort {
			in driverIn : DriverInput;
		}
		port trajOutPort {
			out trajOut : TrajectoryPlan;
		}
	}

	part def ControlModule {
		port trajInPort {
			in trajIn : TrajectoryPlan;
		}
		port stateInPort {
			in stateIn : VehicleState;
		}
		port cmdOutPort {
			out cmdOut : ControlCommand;
		}
	}

	part def ActuationInterface {
		port cmdInPort {
			in cmdIn : ControlCommand;
		}
		port emergInPort {
			in emergIn : EmergencyBrakeCommand;
		}
		port actuationOutPort {
			out actuationOut : ControlCommand;
		}
	}

	part def SafetyMonitor {
		port envInPort {
			in envIn : EnvironmentModel;
		}
		port stateInPort {
			in stateIn : VehicleState;
		}
		port cmdInPort {
			in cmdIn : ControlCommand;
		}
		port emergOutPort {
			out emergOut : EmergencyBrakeCommand;
		}
		port alertOutPort {
			out alertOut : SafetyAlert;
		}
	}

	part def HMI {
		port driverOutPort {
			out driverOut : DriverInput;
		}
		port alertInPort {
			in alertIn : SafetyAlert;
		}
		port statusOutPort {
			out statusOut : SystemStatus;
		}
	}

	part def VehiclePlant {
		port cmdInPort {
			in cmdIn : ControlCommand;
		}
	}

	part def AutonomousVehicle {
		part sensors : PhysicalSensors;
		part sensorFusion : SensorFusionModule;
		part perception : PerceptionModule;
		part localization : LocalizationModule;
		part planning : PlanningModule;
		part control : ControlModule;
		part actuation : ActuationInterface;
		part safetyMonitor : SafetyMonitor;
		part hmi : HMI;
		part vehiclePlant : VehiclePlant;

		attribute powerOn : Boolean;
		attribute automationEngaged : Boolean;
		attribute automationDisengaged : Boolean;
		attribute powerOff : Boolean;
		attribute leadVehicleDetected : Boolean;
		attribute leadVehicleCleared : Boolean;
		attribute laneChangeRequired : Boolean;
		attribute laneChangeComplete : Boolean;
		attribute emergencyBrakeTriggered : Boolean;
		attribute pathClear : Boolean;

		flow rawToFuse of RawSensorData from sensors.rawOutPort.rawOut to sensorFusion.rawInPort.rawIn;
		flow fusedToPerception of FusedSensorData from sensorFusion.fusedOutPort.fusedOut to perception.fusedInPort.fusedIn;
		flow fusedToLocalization of FusedSensorData from sensorFusion.fusedOutPort.fusedOut to localization.fusedInPort.fusedIn;
		flow envToPlanning of EnvironmentModel from perception.envOutPort.envOut to planning.envInPort.envIn;
		flow envToSafety of EnvironmentModel from perception.envOutPort.envOut to safetyMonitor.envInPort.envIn;
		flow stateToPlanning of VehicleState from localization.stateOutPort.stateOut to planning.stateInPort.stateIn;
		flow stateToControl of VehicleState from localization.stateOutPort.stateOut to control.stateInPort.stateIn;
		flow stateToSafety of VehicleState from localization.stateOutPort.stateOut to safetyMonitor.stateInPort.stateIn;
		flow driverToPlanning of DriverInput from hmi.driverOutPort.driverOut to planning.driverInPort.driverIn;
		flow trajToControl of TrajectoryPlan from planning.trajOutPort.trajOut to control.trajInPort.trajIn;
		flow cmdToActuation of ControlCommand from control.cmdOutPort.cmdOut to actuation.cmdInPort.cmdIn;
		flow cmdToSafety of ControlCommand from control.cmdOutPort.cmdOut to safetyMonitor.cmdInPort.cmdIn;
		flow emergToActuation of EmergencyBrakeCommand from safetyMonitor.emergOutPort.emergOut to actuation.emergInPort.emergIn;
		flow alertToHMI of SafetyAlert from safetyMonitor.alertOutPort.alertOut to hmi.alertInPort.alertIn;
		flow actuationToPlant of ControlCommand from actuation.actuationOutPort.actuationOut to vehiclePlant.cmdInPort.cmdIn;

		exhibit vehicleStates {
			state inactive;
			state standby;
			state active {
				state cruising;
				state following;
				state changingLanes;
				state stopping;

				transition from cruising to following when leadVehicleDetected;
				transition from following to cruising when leadVehicleCleared;
				transition from cruising to changingLanes when laneChangeRequired;
				transition from changingLanes to cruising when laneChangeComplete;
				transition from * to stopping when emergencyBrakeTriggered;
				transition from stopping to cruising when pathClear;
			}

			transition from inactive to standby when powerOn;
			transition from standby to active when automationEngaged;
			transition from active to standby when automationDisengaged;
			transition from * to inactive when powerOff;
		}

		requirement safeOperation {
			doc /*
			 * The system shall ensure safe operation by continuously monitoring for hazards
			 * and triggering emergency braking when a collision risk is detected.
			 */
		}

		requirement perceptionAccuracy {
			doc /*
			 * The perception module shall correctly identify and classify all obstacles.
			 */
		}

		requirement driverOverride {
			doc /*
			 * The driver shall be able to override the autonomous system at any time.
			 */
		}
	}

	part autonomousVehicle : AutonomousVehicle;
}
