package 'Valvulotome System' {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;

	value def ForceValue :> Real;
	value def LengthValue :> Real;
	value def RotationalSpeed :> Real;
	value def AngleValue :> Real;

	item def Blood;
	item def ValveLeaflet;
	item def VeinWall;

	port def MechanicalControlPort {
		out attribute deployCommand : Boolean;
		out attribute retractCommand : Boolean;
		in attribute forceFeedback : ForceValue;
	}

	port def TorqueTransferPort {
		out attribute rotationalSpeed : RotationalSpeed;
		in attribute reactionForce : ForceValue;
	}

	port def BladeDeploymentPort {
		out attribute deployCommand : Boolean;
		in attribute bladePosition : LengthValue;
	}

	port def BloodFlowPort {
		in item blood : Blood;
	}

	port def TissueInteractionPort {
		ref item leaflet : ValveLeaflet;
		ref item veinWall : VeinWall;
	}

	part def HandleAssembly {
		attribute gripDiameter : LengthValue = 30;
		attribute leverTravel : LengthValue = 15;
		attribute maxDeploymentForce : ForceValue = 500;
		attribute maxSafeForce : ForceValue = 300;
		port controlPort : MechanicalControlPort;
		port deploymentPort : BladeDeploymentPort;
		port torqueOutputPort : TorqueTransferPort;
	}

	part def CatheterShaft {
		attribute length : LengthValue = 800;
		attribute outerDiameter : LengthValue = 4;
		attribute flexibility : Real = 0.85;
		port proximalControlPort : ~MechanicalControlPort;
		port distalControlPort : MechanicalControlPort;
		port proximalTorquePort : ~TorqueTransferPort;
		port distalTorquePort : TorqueTransferPort;
		port proximalDeploymentPort : ~BladeDeploymentPort;
		port distalDeploymentPort : BladeDeploymentPort;
	}

	part def RotationalMechanism {
		attribute maxSpeed : RotationalSpeed = 2000;
		attribute currentSpeed : RotationalSpeed;
		port torqueInputPort : ~TorqueTransferPort;
		port bladeDrivePort : TorqueTransferPort;
		port controlInputPort : ~MechanicalControlPort;
		port forceSensorPort : ~MechanicalControlPort;
	}

	part def CuttingBlade {
		attribute bladeLength : LengthValue = 3;
		attribute bladeWidth : LengthValue = 1.5;
		attribute cuttingEdgeAngle : AngleValue = 30;
		attribute deployed : Boolean = false;
		attribute deployedPosition : LengthValue;
		port deploymentPort : ~BladeDeploymentPort;
		port drivePort : ~TorqueTransferPort;
		port tissuePort : TissueInteractionPort;
		port bloodPort : BloodFlowPort;
	}

	part def Valvulotome {
		part handle : HandleAssembly;
		part shaft : CatheterShaft;
		part rotMech : RotationalMechanism;
		part blade : CuttingBlade;

		connect handle.controlPort to shaft.proximalControlPort;
		connect shaft.distalControlPort to rotMech.controlInputPort;
		connect rotMech.forceSensorPort to shaft.distalControlPort;
		connect handle.torqueOutputPort to shaft.proximalTorquePort;
		connect shaft.distalTorquePort to rotMech.torqueInputPort;
		connect rotMech.bladeDrivePort to blade.drivePort;
		connect handle.deploymentPort to shaft.proximalDeploymentPort;
		connect shaft.distalDeploymentPort to blade.deploymentPort;
	}

	action def PerformValvulotomy {
		in item targetLeaflet : ValveLeaflet;
		out attribute incisionComplete : Boolean;

		action insertCatheter {
			out attribute positioned : Boolean;
		}
		action deployBlade {
			in attribute positioned : Boolean;
			out attribute deployed : Boolean;
		}
		action activateRotation {
			in attribute deployed : Boolean;
			out attribute cutting : Boolean;
		}
		action inciseLeaflet {
			in item leaflet : ValveLeaflet;
			in attribute speed : RotationalSpeed;
			out attribute incisionComplete : Boolean;
			out attribute appliedForce : ForceValue;
		}
		action verifyBloodFlow {
			in item blood : Blood;
			out attribute flowImproved : Boolean;
		}
		action retractBlade {
			out attribute retracted : Boolean;
		}
		action withdrawDevice {
			out attribute withdrawn : Boolean;
		}

		first insertCatheter then deployBlade then activateRotation then inciseLeaflet then verifyBloodFlow then retractBlade then withdrawDevice;
	}

	state def ValvulotomeOperationalStates {
		state standby;
		state navigating;
		state positioned;
		state bladeDeployed;
		state cutting;
		state verifying;
		state bladeRetracted;
		state withdrawn;

		transition first standby then navigating;
		transition navigating then positioned;
		transition positioned then bladeDeployed;
		transition bladeDeployed then cutting;
		transition cutting then verifying;
		transition verifying then bladeRetracted;
		transition bladeRetracted then withdrawn;
	}

	requirement def SafetyRequirement {
		doc /* The device must not perforate the vein wall during operation. */
	}

	requirement def ForceFeedbackRequirement {
		doc /* The system shall provide real-time force feedback to prevent accidental damage. */
		subject appliedForce : ForceValue;
		subject maxSafeForce : ForceValue;
		constraint { appliedForce <= maxSafeForce }
	}

	requirement def BladeContainmentRequirement {
		doc /* The cutting blade shall remain retracted during navigation. */
		subject bladeDeployed : Boolean;
		subject navigationActive : Boolean;
		constraint { navigationActive implies not bladeDeployed }
	}

	requirement def RotationalControlRequirement {
		doc /* The rotational mechanism shall spin at a controlled speed. */
		subject currentSpeed : RotationalSpeed;
		subject maxSpeed : RotationalSpeed;
		constraint { currentSpeed <= maxSpeed }
	}

	requirement def BloodFlowImprovementRequirement {
		doc /* After incision, blood flow shall be verified to have improved. */
		subject flowImproved : Boolean;
		constraint { flowImproved }
	}

	part valvulotome : Valvulotome {
		perform action performProcedure : PerformValvulotomy;
		exhibit state operationalState : ValvulotomeOperationalStates;
	}

	requirement safetyReq : SafetyRequirement;
	requirement forceFeedbackReq : ForceFeedbackRequirement;
	requirement bladeContainmentReq : BladeContainmentRequirement;
	requirement rotationalControlReq : RotationalControlRequirement;
	requirement bloodFlowImprovementReq : BloodFlowImprovementRequirement;

	satisfy safetyReq by valvulotome;
	satisfy forceFeedbackReq by valvulotome.handle;
	satisfy bladeContainmentReq by valvulotome.blade;
	satisfy rotationalControlReq by valvulotome.rotMech;
	satisfy bloodFlowImprovementReq by valvulotome;
}
