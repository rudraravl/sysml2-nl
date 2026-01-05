package 'Karman Cannula System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def VacuumPressure :> ISQ::PressureValue;
	attribute def FlowRate :> ISQ::VolumeFlowRateValue;
	attribute def CannulaDiameter :> ISQ::LengthValue;
	attribute def InsertionDepth :> ISQ::LengthValue;
	attribute def AspirationVolume :> ISQ::VolumeValue;

	item def UterineContents {
		attribute volume :> ISQ::volume;
		attribute density :> ISQ::density;
	}

	port def VacuumPort {
		out vacuumPressure : VacuumPressure;
		in flowRate : FlowRate;
	}

	port def AspirationPort {
		in contents : UterineContents;
		out vacuumPressure : VacuumPressure;
	}

	part def FlexibleCannula {
		doc /* A flexible tubular instrument designed for intrauterine aspiration. */
		attribute outerDiameter : CannulaDiameter = 6.0 [SI::mm];
		attribute innerDiameter : CannulaDiameter = 4.5 [SI::mm];
		attribute length : InsertionDepth = 200.0 [SI::mm];
		attribute material : String = "medical grade plastic";
		port tip : AspirationPort;
		port base : VacuumPort;
	}

	part def ManualVacuumAspirator {
		doc /* A hand-operated vacuum source for generating negative pressure. */
		attribute maxVacuum : VacuumPressure = -70.0 [SI::kPa];
		attribute currentPressure : VacuumPressure;
		port outlet : VacuumPort;
	}

	part def CollectionChamber {
		doc /* A sealed container for collecting aspirated uterine contents. */
		attribute capacity : AspirationVolume = 60.0 [SI::mL];
		attribute currentVolume : AspirationVolume = 0.0 [SI::mL];
		port inlet : VacuumPort;
		port vacuumSource : VacuumPort;
	}

	part def KarmanCannulaSystem {
		doc /* A medical device system for performing manual vacuum aspiration 
		       of the uterine cavity using a flexible cannula and hand-operated 
		       vacuum source. */

		part cannula : FlexibleCannula;
		part aspirator : ManualVacuumAspirator;
		part chamber : CollectionChamber;

		connect aspirator.outlet to chamber.vacuumSource;
		connect chamber.inlet to cannula.base;

		perform action performUterineEvacuation references evacuateUterus;
	}

	action def CreateVacuum {
		doc /* Generate negative pressure in the aspiration system. */
		in targetPressure : VacuumPressure;
		out achievedPressure : VacuumPressure;
	}

	action def PositionCannula {
		doc /* Insert and position the cannula within the uterine cavity. */
		in targetDepth : InsertionDepth;
		out currentDepth : InsertionDepth;
		out positioned : Boolean;
	}

	action def AspirateContents {
		doc /* Remove uterine contents through vacuum-assisted aspiration. */
		in vacuumPressure : VacuumPressure;
		in cannulaDiameter : CannulaDiameter;
		out aspiratedMaterial : UterineContents;
		out currentFlowRate : FlowRate;
	}

	action def MonitorVolume {
		doc /* Monitor the volume of collected material. */
		in collectedVolume : AspirationVolume;
		in chamberCapacity : AspirationVolume;
		out capacityReached : Boolean;
		out procedureComplete : Boolean;
	}

	action def RemoveCannula {
		doc /* Withdraw the cannula from the uterine cavity. */
		in currentDepth : InsertionDepth;
		out withdrawn : Boolean;
	}

	action def ReleaseVacuum {
		doc /* Release the vacuum pressure from the system. */
		in currentPressure : VacuumPressure;
		out released : Boolean;
	}

	action evacuateUterus : PerformUterineEvacuation {
		doc /* Primary function: Evacuate the contents of the uterine cavity 
		       through controlled vacuum aspiration using a flexible cannula. */

		first start;

		then action createVacuum : CreateVacuum {
			in targetPressure = -60.0 [SI::kPa];
			out achievedPressure : VacuumPressure;
		}

		then action positionCannula : PositionCannula {
			in targetDepth = 100.0 [SI::mm];
			out currentDepth : InsertionDepth;
			out positioned : Boolean;
		}

		then merge continueEvacuation;

		then action aspirate : AspirateContents {
			in vacuumPressure = createVacuum.achievedPressure;
			in cannulaDiameter = 6.0 [SI::mm];
			out aspiratedMaterial : UterineContents;
			out currentFlowRate : FlowRate;
		}

		flow aspirate.aspiratedMaterial to monitor.collectedVolume;

		then action monitor : MonitorVolume {
			in collectedVolume : AspirationVolume;
			in chamberCapacity = 60.0 [SI::mL];
			out capacityReached : Boolean;
			out procedureComplete : Boolean;
		}

		then decide;
			if monitor.procedureComplete then removeCannula;
			if !monitor.procedureComplete and !monitor.capacityReached then continueEvacuation;
			if monitor.capacityReached then removeCannula;

		action removeCannula : RemoveCannula {
			in currentDepth = positionCannula.currentDepth;
			out withdrawn : Boolean;
		}

		then action releaseVacuum : ReleaseVacuum {
			in currentPressure = createVacuum.achievedPressure;
			out released : Boolean;
		}

		then done;
	}

	action def PerformUterineEvacuation :> AspirateContents;

	requirement def SafetyRequirement {
		doc /* Safety requirements for Karman cannula system operation. */
		subject system : KarmanCannulaSystem;
	}

	requirement def PerformanceRequirement {
		doc /* Performance requirements for effective uterine evacuation. */
		subject system : KarmanCannulaSystem;
	}

	requirement <'REQ-001'> vacuumPressureLimit : SafetyRequirement {
		doc /* The vacuum pressure shall not exceed -70 kPa to prevent 
		       uterine perforation and tissue trauma. */
		require constraint {
			system.aspirator.currentPressure >= -70.0 [SI::kPa]
		}
	}

	requirement <'REQ-002'> cannulaSizeRange : SafetyRequirement {
		doc /* The cannula outer diameter shall be between 4mm and 12mm 
		       for safe intrauterine insertion. */
		require constraint {
			system.cannula.outerDiameter >= 4.0 [SI::mm] and
			system.cannula.outerDiameter <= 12.0 [SI::mm]
		}
	}

	requirement <'REQ-003'> collectionCapacityLimit : SafetyRequirement {
		doc /* The collection chamber shall not exceed its maximum capacity 
		       to prevent vacuum loss and contamination. */
		require constraint {
			system.chamber.currentVolume <= system.chamber.capacity
		}
	}

	requirement <'REQ-004'> effectiveVacuumGeneration : PerformanceRequirement {
		doc /* The system shall generate sufficient vacuum pressure 
		       (minimum -50 kPa) for effective aspiration. */
		require constraint {
			system.aspirator.maxVacuum <= -50.0 [SI::kPa]
		}
	}

	requirement <'REQ-005'> primaryFunction : PerformanceRequirement {
		doc /* The system shall perform controlled vacuum-assisted evacuation 
		       of uterine contents through a flexible cannula. */
		verify by evacuateUterus;
	}

	part karmanSystem : KarmanCannulaSystem {
		satisfy vacuumPressureLimit;
		satisfy cannulaSizeRange;
		satisfy collectionCapacityLimit;
		satisfy effectiveVacuumGeneration;
		satisfy primaryFunction;

		part cannulaComponent : FlexibleCannula {
			perform evacuateUterus.positionCannula;
			perform evacuateUterus.aspirate;
			perform evacuateUterus.removeCannula;
		}

		part aspiratorComponent : ManualVacuumAspirator {
			perform evacuateUterus.createVacuum;
			perform evacuateUterus.releaseVacuum;
		}

		part chamberComponent : CollectionChamber {
			perform evacuateUterus.monitor;
		}
	}
}
