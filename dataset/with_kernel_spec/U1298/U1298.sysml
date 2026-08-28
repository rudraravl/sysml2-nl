package LawnMowerSystem {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		alias Torque for ISQ::TorqueValue;
		alias Length for ISQ::LengthValue;
		alias Volume for ISQ::VolumeValue;
		alias Mass for ISQ::MassValue;

		item def EngineStart;
		item def EngineOff;
		item def EngageBlades;
		item def DisengageBlades;
		item def OperatorPresent;
		item def BagFull;
		item def EmptyBag;
		item def LawnComplete;
		item def HeightSetting;

		item def Clippings;

		port def DrivePwrPort;
		port def ClutchPort;
		port def ClippingsFlowPort;
		port def SafetySignalPort;
		port def HeightAdjustPort;
		port def BagStatusPort;

		interface def EngineToDeckInterface {
			end drivePwrPort: DrivePwrPort;
			end clutchPort: ClutchPort;
		}

		interface def DeckToBagInterface {
			end clippingsOut: ClippingsFlowPort;
			end clippingsIn: ClippingsFlowPort;
		}

		interface def SafetyControlInterface {
			end safetySignalPort: SafetySignalPort;
		}

		action def GenerateTorque { out engineTorque: Torque; }
		action def SpinBlades { in engineTorque: Torque; out bladeSpeed: Real; }
		action def CutGrass { in bladeSpeed: Real; out clippings: Clippings; }
		action def AdjustHeight { in height: Length; out currentHeight: Length; }
		action def CheckSafety { in operatorPresent: Boolean; out safetyClear: Boolean; }
		action def MonitorBag { in clippings: Clippings; out bagFull: Boolean; }

		part def Engine {
			port drivePwrPort: DrivePwrPort;
			attribute powerOutput: Real;
			perform action 'generate torque': GenerateTorque;
		}

		part def CuttingDeck {
			port clutchPort: ClutchPort;
			port clippingsOut: ClippingsFlowPort;
			attribute cuttingWidth: Length = 53 [cm];
			attribute bladeSpeed: Real;
			perform action 'spin blades': SpinBlades;
			perform action 'cut grass': CutGrass;
		}

		part def HeightAdjuster {
			port heightAdjustPort: HeightAdjustPort;
			attribute minHeight: Length = 25 [mm];
			attribute maxHeight: Length = 100 [mm];
			attribute currentHeight: Length;
			perform action 'adjust height': AdjustHeight;
		}

		part def SafetyInterlock {
			port safetySignalPort: SafetySignalPort;
			attribute operatorPresent: Boolean = false;
			attribute bladesEngaged: Boolean = false;
			perform action 'check safety': CheckSafety;
		}

		part def CollectionBag {
			port clippingsIn: ClippingsFlowPort;
			port bagStatusPort: BagStatusPort;
			attribute capacity: Volume = 60 [L];
			attribute currentVolume: Volume;
			perform action 'monitor bag': MonitorBag;
		}

		state def MowerOperation {
			state settingHeight {
				accept HeightSetting then safetyCheck;
			}
			state safetyCheck {
				accept OperatorPresent then engineStart;
			}
			state engineStart {
				accept EngineStart then bladeEngage;
			}
			state bladeEngage {
				accept EngageBlades then mowing;
			}
			state mowing {
				accept BagFull then paused;
				accept LawnComplete then bladeDisengage;
			}
			state paused {
				accept EmptyBag then mowing;
			}
			state bladeDisengage {
				accept DisengageBlades then engineShutdown;
			}
			state engineShutdown {
				accept EngineOff then done;
			}
			state done;
		}

		part def LawnMower {
			part engine: Engine;
			part cuttingDeck: CuttingDeck;
			part heightAdjuster: HeightAdjuster;
			part safetyInterlock: SafetyInterlock;
			part collectionBag: CollectionBag;

			interface engineToDeck: EngineToDeckInterface
				connect engine.drivePwrPort to cuttingDeck.clutchPort;
			interface deckToBag: DeckToBagInterface
				connect cuttingDeck.clippingsOut to collectionBag.clippingsIn;
		}
	}

	package Usages {
		public import Definitions::*;

		part mower1: LawnMower {
			attribute totalMass: Mass = 30 [kg];

			part :>> engine {
				perform 'generate torque';
			}
			part :>> cuttingDeck {
				attribute :>> cuttingWidth = 53 [cm];
				perform 'spin blades';
				perform 'cut grass';
			}
			part :>> heightAdjuster {
				attribute :>> currentHeight = 50 [mm];
				perform 'adjust height';
			}
			part :>> safetyInterlock {
				perform 'check safety';
			}
			part :>> collectionBag {
				attribute :>> capacity = 60 [L];
				perform 'monitor bag';
			}

			perform mowerOperation: MowerOperation;
		}
	}

	package Requirements {
		public import Definitions::*;
		public import Usages::*;

		requirement def CuttingAccuracyRequirement {
			doc /* The mower shall cut grass to the user-specified height within a tolerance of +/- 5mm. */
			subject mower : LawnMower;
			attribute targetHeight: Length;
			attribute actualHeight: Length;
			require constraint {
				actualHeight >= targetHeight - 5 [mm] and actualHeight <= targetHeight + 5 [mm]
			}
		}

		requirement def SafetyEnforcementRequirement {
			doc /* The blades shall not engage unless the operator is present. */
			subject mower : LawnMower;
			attribute operatorPresent: Boolean;
			attribute bladesEngaged: Boolean;
			require constraint {
				bladesEngaged implies operatorPresent
			}
		}

		requirement def BagCapacityRequirement {
			doc /* The collection bag shall have a capacity of at least 60 liters. */
			subject bag : CollectionBag;
			attribute capacity: Volume;
			require constraint {
				capacity >= 60 [L]
			}
		}

		requirement cuttingAccuracy: CuttingAccuracyRequirement {
			subject :>> mower = mower1;
			attribute :>> targetHeight = 50 [mm];
			attribute :>> actualHeight = mower1.heightAdjuster.currentHeight;
		}

		requirement safetyEnforcement: SafetyEnforcementRequirement {
			subject :>> mower = mower1;
			attribute :>> operatorPresent = mower1.safetyInterlock.operatorPresent;
			attribute :>> bladesEngaged = mower1.cuttingDeck.bladeSpeed > 0;
		}

		requirement bagCapacity: BagCapacityRequirement {
			subject :>> bag = mower1.collectionBag;
			attribute :>> capacity = mower1.collectionBag.capacity;
		}
	}
}
