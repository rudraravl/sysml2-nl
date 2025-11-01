// Define a drone that has the ability to pick up objects from a structure.
package DronePickupSystem {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;
	private import NumericalFunctions::sum;

	//-------------------------------------------------
	// VALUE & ITEM DEFINITIONS
	//-------------------------------------------------
	constant g :> acceleration = 9.807 ['m/s^2'];

	item def Payload {
		attribute mass :> ISQ::mass;
	}

	//-------------------------------------------------
	// INTERFACE DEFINITIONS
	//-------------------------------------------------
	port def GripperPort {
		in gripCommand : Boolean;
		out isSecure : Boolean;
		out gripForce :> force;
	}

	port def PayloadPort {
		in appliedForce :> force;
	}

	interface def GraspInterface {
		end gripperEnd : GripperPort;
		end payloadEnd : PayloadPort;
		flow gripperEnd.gripForce to payloadEnd.appliedForce;
	}

	//-------------------------------------------------
	// COMPONENT DEFINITIONS
	//-------------------------------------------------
	part def Structure {
		part payload : Payload;
		port payloadInterface : PayloadPort;
	}

	part def PropulsionSystem {
		attribute maxThrust :> force;
		attribute mass :> ISQ::mass;
	}

	part def Gripper {
		attribute mass :> ISQ::mass;
		attribute maxGripForce :> force;
		attribute isEngaged : Boolean :> port.isSecure = false;
		port port : GripperPort;
		part heldPayload : Payload[0..1];
	}

	part def Drone {
		attribute baseMass :> ISQ::mass;
		attribute totalMass :> ISQ::mass;

		part propulsion : PropulsionSystem;
		part gripper : Gripper;

		attribute :>> totalMass =
			baseMass + propulsion.mass + gripper.mass + sum(gripper.heldPayload.mass);
	}

	//-------------------------------------------------
	// BEHAVIOR DEFINITIONS
	//-------------------------------------------------
	action def Approach { in target : Structure; }
	action def Align { in target : Payload; }
	action def Grasp { inout gripper : Gripper; inout payload : Payload; }
	action def Lift { in drone : Drone; }
	action def Return { }

	state machine def PickupMission {
		in drone : Drone;
		in structure : Structure;

		initial state Idle;
		transition to Approaching;

		state Approaching {
			do approach : Approach { in target = structure; }
			transition to Aligning on completion;
		}

		state Aligning {
			do align : Align { in target = structure.payload; }
			transition to Grasping on completion;
		}

		state Grasping {
			do grasp : Grasp {
				inout gripper = drone.gripper;
				inout payload = structure.payload;
			}
			entry action {
				drone.gripper.port.gripCommand = true;
			}
			transition to Lifting when drone.gripper.isEngaged;
			transition to Failed when not drone.gripper.isEngaged after 5['s'];
		}

		state Lifting {
			do lift : Lift { in drone = drone; }
			entry action {
				drone.gripper.heldPayload = structure.payload;
			}
			transition to Returning on completion;
		}

		state Returning {
			do return : Return;
			transition to MissionComplete on completion;
		}

		state MissionComplete;
		state Failed;
	}
}

package DronePickupStakeholderReqs {
	import DronePickupSystem::Drone;

	requirement <'REQ-S-1'> AutonomousPickup {
		doc /* The drone system shall be capable of autonomously
		     * picking up a specified payload from a structure. */
		subject drone : Drone;
	}
}

package DronePickupSystemArchitecture {
	import DronePickupSystem::*;
	import DronePickupStakeholderReqs::AutonomousPickup;

	part missionScenario {
		part drone : Drone {
			attribute :>> baseMass = 1.2 [kg];
			part propulsion {
				attribute :>> mass = 0.8 [kg];
				attribute :>> maxThrust = 30 [N];
			}
			part gripper {
				attribute :>> mass = 0.5 [kg];
				attribute :>> maxGripForce = 25 [N];
			}
		}

		part landingPad : Structure {
			part payload {
				attribute :>> mass = 1.0 [kg];
			}
		}

		interface grasp : GraspInterface {
			end gripperEnd :>> drone.gripper.port;
			end payloadEnd :>> landingPad.payloadInterface;
		}

		state machine mission : PickupMission {
			in drone = drone;
			in structure = landingPad;
		}
	}

	satisfy AutonomousPickup by missionScenario.drone;
}

package DronePickupSystemReqs {
	import DronePickupSystemArchitecture::missionScenario as subject;
	import DronePickupSystem::g;
	import RequirementDerivation::*;

	requirement <'REQ-SYS-1'> LiftCapacity {
		doc /* The drone's propulsion system must generate enough thrust
		     * to lift the drone's total mass plus the payload mass,
		     * with a safety factor of 1.5. */
		subject drone :>> subject.drone;
		subject payload :>> subject.landingPad.payload;

		assert constraint {
			drone.propulsion.maxThrust >= (drone.totalMass + payload.mass) * g * 1.5
		}
	}

	requirement <'REQ-SYS-2'> GripStrength {
		doc /* The gripper must be strong enough to securely hold the
		     * payload during flight, with a safety factor of 2.0
		     * against gravitational force. */
		subject gripper :>> subject.drone.gripper;
		subject payload :>> subject.landingPad.payload;

		assert constraint {
			gripper.maxGripForce >= payload.mass * g * 2.0
		}
	}

	#derivation connection {
		end #original ::> DronePickupStakeholderReqs::AutonomousPickup;
		end #derive ::> LiftCapacity;
		end #derive ::> GripStrength;
	}
}
