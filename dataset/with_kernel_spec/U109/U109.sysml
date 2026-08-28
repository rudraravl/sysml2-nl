package 'Gastric Decompression System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	item def GastricFluid;
	item def SalineSolution;
	item def Air;

	attribute def PressureInMmHg :> Real;
	attribute def VolumeInMl :> Real;

	requirement SafeSuctionPressure {
		doc /* The system shall maintain suction pressure between 40 and 80 mmHg. */
	}
	requirement VentPatency {
		doc /* The vent lumen shall remain open to atmospheric pressure to prevent stomach lining injury. */
	}
	requirement IrrigationClearing {
		doc /* If the vent lumen becomes blocked, the system shall automatically perform an irrigation cycle. */
	}

	port def SuctionPort {
		out item gastricFluid : GastricFluid;
		in item air : Air;
	}
	port def IrrigationPort {
		in item saline : SalineSolution;
	}
	port def SuctionConnectionPort {
		in item gastricFluid : GastricFluid;
		out item air : Air;
	}
	port def IrrigationConnectionPort {
		out item saline : SalineSolution;
	}

	part def ReplogleTube {
		port suctionPort : SuctionPort;
		port irrigationPort : IrrigationPort;
		part suctionLumen {
			attribute diameter :> length;
		}
		part ventLumen {
			attribute diameter :> length;
			attribute isBlocked : Boolean;
		}
		part stomachEnd {
			part suctionOpenings [1..*];
			part ventOpening [1];
		}
		assert constraint { suctionLumen.diameter > ventLumen.diameter }
	}

	part def SuctionApparatus {
		port suctionConnectionPort : SuctionConnectionPort;
		part pressureRegulator {
			attribute suctionPressure : PressureInMmHg;
			assert constraint { suctionPressure >= 40 and suctionPressure <= 80 }
		}
		part collectionContainer {
			attribute capacity : VolumeInMl;
			item collectedFluid : GastricFluid [0..*];
		}
	}

	part def IrrigationSystem {
		port irrigationConnectionPort : IrrigationConnectionPort;
		attribute flushVolume : VolumeInMl;
		action flushTube;
	}

	connection def SuctionConnection {
		end : SuctionPort;
		end : SuctionConnectionPort;
	}
	connection def IrrigationConnection {
		end : IrrigationPort;
		end : IrrigationConnectionPort;
	}

	state machine def DecompressionStateMachine {
		state Idle;
		state NormalOperation;
		state VentBlocked;
		state Irrigating;

		transition first Idle then NormalOperation;
		transition first NormalOperation then VentBlocked;
		transition first VentBlocked then Irrigating;
		transition first Irrigating then NormalOperation;
	}

	part def GastricDecompressionSystem {
		part replogleTube : ReplogleTube;
		part suctionApparatus : SuctionApparatus;
		part irrigationSystem : IrrigationSystem;

		connection : SuctionConnection connect replogleTube.suctionPort to suctionApparatus.suctionConnectionPort;
		connection : IrrigationConnection connect replogleTube.irrigationPort to irrigationSystem.irrigationConnectionPort;

		exhibit DecompressionStateMachine;

		satisfy SafeSuctionPressure by suctionApparatus.pressureRegulator;
		satisfy VentPatency by replogleTube.ventLumen;
		satisfy IrrigationClearing by irrigationSystem;
	}
}
