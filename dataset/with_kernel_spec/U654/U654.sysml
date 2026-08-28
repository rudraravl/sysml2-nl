package 'Spacecraft Docking System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	item def Crew;
	item def Resource;

	attribute def Distance :> length;
	attribute def MatingAngle :> angle;
	attribute def ApproachVelocity :> speed;
	attribute def SealPressure :> pressure;
	attribute def TensileLoad :> force;

	attribute def StartDockingSignal;
	attribute def CaptureCommandSignal;
	attribute def AbortSignal;
	attribute def DockingCompleteSignal;
	attribute def VerificationFailedSignal;
	attribute def AlignmentChecked;
	attribute def ManeuverComplete;
	attribute def PullComplete;
	attribute def SealActivated;
	attribute def VerificationComplete;
	attribute def DisengageComplete;

	item def Sealant {
		attribute material : String = "Silicone Elastomer";
	}

	port def DockingPort {
		inout item crew : Crew;
		inout item resource : Resource;
	}

	port def StructuralInterfacePort;

	part def LaserRangefinder {
		attribute measuredDistance : Distance = 0.0 [m];
		attribute measuredAngle : MatingAngle = 0.0 [rad];
		attribute measuredVelocity : ApproachVelocity = 0.0 [m/s];
	}

	part def DockingRing {
		attribute diameter : Distance = 1.2 [m];
	}

	part def MechanicalLatch {
		attribute engaged : Boolean = false;
		attribute preload : TensileLoad = 5000.0 [N];
	}

	part def PressureSeal {
		item sealant : Sealant;
		attribute isActivated : Boolean = false;
		attribute sealPressure : SealPressure = 0.0 [Pa];
		attribute requiredSealPressure : SealPressure = 1.0e5 [Pa];
	}

	part def GuidePetal;

	part def StructuralInterface {
		attribute maxAxialLoad : TensileLoad = 100000.0 [N];
		attribute maxLateralLoad : TensileLoad = 50000.0 [N];
		port structuralPort : StructuralInterfacePort;
	}

	part def SpacecraftModule {
		part structuralInterface : StructuralInterface;
	}

	part def ActiveDockingMechanism {
		port dockingPort : DockingPort;
		port structuralPort : StructuralInterfacePort;

		part rangefinder : LaserRangefinder;
		part activeRing : DockingRing;
		part latches : MechanicalLatch[16];
		part pressureSeal : PressureSeal;
		part structuralInterface : StructuralInterface;

		attribute measuredDistance : Distance = 0.0 [m];
		attribute measuredAngle : MatingAngle = 0.0 [rad];
		attribute measuredVelocity : ApproachVelocity = 0.0 [m/s];
		attribute captureDistance : Distance = 2.0 [m];
		attribute maxAllowedAngle : MatingAngle = 0.05 [rad];
		attribute isAligned : Boolean = false;
		attribute latchesEngaged : Boolean = false;
		attribute sealVerified : Boolean = false;
	}

	part def PassiveDockingAdapter {
		port dockingPort : ~DockingPort;
		part passiveRing : DockingRing;
		part passiveSeal : PressureSeal;
		part guidePetals : GuidePetal[4];
		part structuralInterface : StructuralInterface;
	}

	connection def DockingInterface {
		end active : DockingPort;
		end passive : ~DockingPort;
	}

	connection def StructuralMount {
		end spacecraft : StructuralInterfacePort;
		end mechanism : StructuralInterfacePort;
	}

	connection def RingLink {
		end activeRing : DockingRing;
		end passiveRing : DockingRing;
	}

	action def MeasureAlignment {
		in activeMech : ActiveDockingMechanism;
		assign activeMech.measuredDistance := activeMech.rangefinder.measuredDistance;
		assign activeMech.measuredAngle := activeMech.rangefinder.measuredAngle;
		assign activeMech.measuredVelocity := activeMech.rangefinder.measuredVelocity;
		assign activeMech.isAligned :=
			activeMech.measuredDistance <= activeMech.captureDistance and
			activeMech.measuredAngle <= activeMech.maxAllowedAngle;
	}

	action def CorrectiveManeuver {
		inout activeMech : ActiveDockingMechanism;
		assign activeMech.measuredAngle := activeMech.measuredAngle * 0.5;
		assign activeMech.measuredDistance := activeMech.measuredDistance * 0.9;
	}

	action def EngageLatches {
		inout activeMech : ActiveDockingMechanism;
		assign activeMech.latchesEngaged := true;
	}

	action def PullTogether {
		inout activeMech : ActiveDockingMechanism;
		inout passiveAdapt : PassiveDockingAdapter;
	}

	action def ActivateSeal {
		inout activeMech : ActiveDockingMechanism;
		assign activeMech.pressureSeal.isActivated := true;
		assign activeMech.pressureSeal.sealPressure :=
			activeMech.pressureSeal.requiredSealPressure;
	}

	action def VerifyConnection {
		in activeMech : ActiveDockingMechanism;
		assign activeMech.sealVerified :=
			activeMech.pressureSeal.isActivated and
			activeMech.pressureSeal.sealPressure >=
				activeMech.pressureSeal.requiredSealPressure;
	}

	action def Disengage {
		inout activeMech : ActiveDockingMechanism;
		assign activeMech.latchesEngaged := false;
		assign activeMech.pressureSeal.isActivated := false;
		assign activeMech.pressureSeal.sealPressure := 0.0 [Pa];
		assign activeMech.sealVerified := false;
		assign activeMech.isAligned := false;
	}

	state def DockingProcess;

	requirement def SecurePassagewayReq {
		doc /* The docking system shall create a secure passageway between two spacecraft modules. */
	}

	requirement def RigidConnectionReq {
		doc /* The connection shall be rigid and withstand significant structural loads. */
	}

	requirement def PressurizedTransferReq {
		doc /* The passageway shall be pressurized and airtight to enable crew and resource transfer. */
	}

	requirement def AlignmentToleranceReq {
		doc /* The active mechanism shall correct alignment until distance and angle are within tolerance before capture. */
	}

	requirement def SafetyAbortReq {
		doc /* The system shall abort and safely disengage if alignment is lost or verification fails at any point. */
	}

	part dockingSystem {
		part activeSpacecraft : SpacecraftModule {
			part activeMechanism : ActiveDockingMechanism;
		}
		part passiveSpacecraft : SpacecraftModule {
			part passiveAdapter : PassiveDockingAdapter;
		}

		connection structuralMountActive : StructuralMount
			connect activeSpacecraft.structuralInterface.structuralPort
				to activeSpacecraft.activeMechanism.structuralPort;

		connection structuralMountPassive : StructuralMount
			connect passiveSpacecraft.structuralInterface.structuralPort
				to passiveSpacecraft.passiveAdapter.structuralInterface.structuralPort;

		connection dockingInterface : DockingInterface
			connect activeSpacecraft.activeMechanism.dockingPort
				to passiveSpacecraft.passiveAdapter.dockingPort;

		connection ringLink : RingLink
			connect activeSpacecraft.activeMechanism.activeRing
				to passiveSpacecraft.passiveAdapter.passiveRing;

		flow of Crew
			from activeSpacecraft.activeMechanism.dockingPort.crew
			to passiveSpacecraft.passiveAdapter.dockingPort.crew;
		flow of Resource
			from activeSpacecraft.activeMechanism.dockingPort.resource
			to passiveSpacecraft.passiveAdapter.dockingPort.resource;

		state dockingProcess : DockingProcess {
			in operatingActive : ActiveDockingMechanism = activeSpacecraft.activeMechanism;
			in operatingPassive : PassiveDockingAdapter = passiveSpacecraft.passiveAdapter;

			entry; then idle;

			state idle;
			accept StartDockingSignal then aligning;

			state aligning {
				entry action measureAlignment : MeasureAlignment { in activeMech = operatingActive; }
			}
			accept AlignmentChecked
				if not operatingActive.isAligned
				then correcting;
			accept CaptureCommandSignal
				if operatingActive.isAligned
				then softCapture;
			accept AbortSignal then aborting;

			state correcting {
				entry action correctiveManeuver : CorrectiveManeuver { inout activeMech = operatingActive; }
			}
			accept ManeuverComplete then aligning;
			accept AbortSignal then aborting;

			state softCapture {
				entry action engageLatches : EngageLatches { inout activeMech = operatingActive; }
				do action pullTogether : PullTogether {
					inout activeMech = operatingActive;
					inout passiveAdapt = operatingPassive;
				}
			}
			accept PullComplete then hardCapture;
			accept AbortSignal then aborting;

			state hardCapture {
				entry action activateSeal : ActivateSeal { inout activeMech = operatingActive; }
			}
			accept SealActivated then sealing;
			accept AbortSignal then aborting;

			state sealing {
				entry action verifyConnection : VerifyConnection { in activeMech = operatingActive; }
			}
			accept VerificationComplete
				if operatingActive.sealVerified
				then docked;
			accept VerificationFailedSignal then aborting;
			accept AbortSignal then aborting;

			state docked {
				entry send new DockingCompleteSignal() to operatingActive;
			}
			accept AbortSignal then aborting;

			state aborting {
				entry action disengage : Disengage { inout activeMech = operatingActive; }
			}
			accept DisengageComplete then idle;
		}

		requirement securePassageway : SecurePassagewayReq;
		requirement rigidConnection : RigidConnectionReq;
		requirement pressurizedTransfer : PressurizedTransferReq;
		requirement alignmentTolerance : AlignmentToleranceReq;
		requirement safetyAbort : SafetyAbortReq;

		satisfy securePassageway by activeSpacecraft.activeMechanism;
		satisfy rigidConnection by activeSpacecraft.activeMechanism;
		satisfy pressurizedTransfer by activeSpacecraft.activeMechanism;
		satisfy alignmentTolerance by activeSpacecraft.activeMechanism;
		satisfy safetyAbort by dockingProcess;
	}
}
