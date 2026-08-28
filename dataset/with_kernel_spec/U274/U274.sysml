package KarmanCannulaSystem {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;
	private import ScalarValues::String;
	public import Definitions::*;
	public import Usages::*;
	public import Requirements::*;

	package Definitions {
		unit def mmHg;
		unit def mL;
		unit def mm;
		unit def cm;

		item def UterineContents {
			attribute volume : Real = 0.0 [mL];
		}

		item def Vacuum {
			attribute pressure : Real = 0.0 [mmHg];
		}

		port def FluidPort {
			out item contents : UterineContents;
			in item vacuum : Vacuum;
		}

		port def VacuumPort {
			out item vacuum : Vacuum;
		}

		part def Uterus {
			port cervicalPort : FluidPort;
			item contents : UterineContents;
		}

		part def FlexibleCannula {
			attribute length : Real = 20 [cm];
			attribute tipOuterDiameter : Real = 4 [mm];
			attribute material : String = "medical-grade flexible plastic";
			port tipPort : ~FluidPort;
			port basePort : FluidPort;
		}

		part def ManualVacuumAspirator {
			attribute strokeVolume : Real = 15 [mL];
			attribute maxVacuumPressure : Real = 300 [mmHg];
			port aspiratorPort : VacuumPort;
		}

		part def CollectionChamber {
			attribute capacity : Real = 500 [mL];
			attribute currentVolume : Real = 0.0 [mL];
			attribute internalPressure : Real = 0.0 [mmHg];
			port aspiratorConnectionPort : ~VacuumPort;
			port cannulaConnectionPort : ~FluidPort;
			item collectedContents : UterineContents;
		}

		connection def AspiratorToChamberConnection {
			end aspiratorEnd : VacuumPort;
			end chamberEnd : VacuumPort;
		}

		connection def ChamberToCannulaConnection {
			end chamberEnd : FluidPort;
			end cannulaEnd : FluidPort;
		}

		connection def CannulaToUterusConnection {
			end cannulaEnd : FluidPort;
			end uterusEnd : FluidPort;
		}

		action def AspirationProcedure {
			action 'create vacuum';
			then action 'position cannula';
			then action 'apply vacuum and suction';
			then action 'check completion';
		}

		action def GenerateVacuum {
			out vacuum : Vacuum;
		}

		action def AspirateContents {
			in contents : UterineContents;
			out aspirated : UterineContents;
		}

		action def CollectContents {
			in aspirated : UterineContents;
			out collected : UterineContents;
		}

		state def AspirationStateMachine {
			state 'Idle';
			state 'VacuumCreated';
			state 'CannulaPositioned';
			state 'Aspirating';
			state 'Complete';

			transition from 'Idle' to 'VacuumCreated';
			transition from 'VacuumCreated' to 'CannulaPositioned';
			transition from 'CannulaPositioned' to 'Aspirating';
			transition from 'Aspirating' to 'Complete';
		}
	}

	package Requirements {
		requirement def SafetyPressureLimit {
			attribute maxAllowedPressure : Real = 300 [mmHg];
			subject aspirator : ManualVacuumAspirator;
			constraint pressureConstraint { aspirator.maxVacuumPressure <= maxAllowedPressure }
		}

		requirement def ChamberCapacityLimit {
			attribute maxChamberVolume : Real = 500 [mL];
			subject chamber : CollectionChamber;
			constraint volumeConstraint { chamber.currentVolume <= chamber.capacity }
		}
	}

	package Usages {
		part systemContext {
			part aspirator : ManualVacuumAspirator {
				perform action generateVacuumAction : GenerateVacuum {
					out vacuum = aspiratorPort.vacuum;
				}
			}

			part chamber : CollectionChamber {
				perform action collectContentsAction : CollectContents {
					in aspirated = cannulaConnectionPort.contents;
					out collected = collectedContents;
				}
			}

			part cannula : FlexibleCannula {
				perform action aspirateContentsAction : AspirateContents {
					in contents = tipPort.contents;
					out aspirated = basePort.contents;
				}
			}

			part uterus : Uterus;

			connection aspiratorToChamber : AspiratorToChamberConnection
				connect aspirator.aspiratorPort to chamber.aspiratorConnectionPort;

			connection chamberToCannula : ChamberToCannulaConnection
				connect chamber.cannulaConnectionPort to cannula.basePort;

			connection cannulaToUterus : CannulaToUterusConnection
				connect cannula.tipPort to uterus.cervicalPort;

			flow of contents : UterineContents
				from uterus.cervicalPort.contents to cannula.tipPort.contents;

			flow of contents : UterineContents
				from cannula.basePort.contents to chamber.cannulaConnectionPort.contents;

			flow of vacuum : Vacuum
				from aspirator.aspiratorPort.vacuum to chamber.aspiratorConnectionPort.vacuum;

			flow of vacuum : Vacuum
				from chamber.cannulaConnectionPort.vacuum to cannula.basePort.vacuum;

			flow of vacuum : Vacuum
				from cannula.tipPort.vacuum to uterus.cervicalPort.vacuum;

			perform action procedure : AspirationProcedure;

			state machine aspirationStates : AspirationStateMachine;

			requirement safetyPressure : SafetyPressureLimit;
			requirement capacityLimit : ChamberCapacityLimit;
		}
	}
}
