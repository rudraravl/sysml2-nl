package 'Projectile Launch System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package 'Definitions' {
		item def Projectile {
			attribute mass: MassValue;
			attribute diameter: LengthValue;
		}

		part def Frame {
			attribute material: String = "Aluminum Alloy 7075";
			attribute yieldStrength: PressureValue;
			attribute crossSectionArea: AreaValue;
		}

		part def ElasticCord {
			attribute stiffness: Real;
			attribute restLength: LengthValue;
			attribute maxElongation: LengthValue;
			attribute storedEnergy: EnergyValue;
		}

		part def Pouch {
			attribute capacity: MassValue;
			port projectilePort {
				in item projectile: Projectile;
			}
		}

		part def SafetyLock {
			attribute isEngaged: Boolean;
		}

		part def TriggerMechanism {
			attribute isReleased: Boolean;
			part safetyLock: SafetyLock;
			port releasePort {
				in item releaseCmd: ReleaseCommand;
			}
		}

		part def ProjectileLauncher {
			port cmdPort {
				in item loadCmd: LoadCommand;
				in item drawCmd: DrawCommand;
				in item aimCmd: AimCommand;
				in item releaseCmd: ReleaseCommand;
				in item resetCmd: ResetCommand;
				out item statusReport: StatusReport;
			}
			port launchPort {
				out item launchedProjectile: Projectile;
			}

			part body: Frame;
			part cord1: ElasticCord;
			part cord2: ElasticCord;
			part pouch: Pouch;
			part trigger: TriggerMechanism;
		}

		item def LoadCommand;
		item def DrawCommand;
		item def AimCommand;
		item def ReleaseCommand;
		item def ResetCommand;
		item def StatusReport {
			attribute currentState: String;
			attribute velocity: SpeedValue;
			attribute energyStored: EnergyValue;
		}

		action def LoadProjectile;
		action def DrawCords;
		action def AimLauncher;
		action def ReleaseTrigger;
		action def LaunchProjectile;
		action def ResetSystem;

		requirement def StructuralIntegrityRequirement {
			doc /* The frame shall withstand maximum cord tension without failure. */
			subject frame : Frame;
			attribute maxTension: ForceValue;
			require constraint {
				frame.yieldStrength * frame.crossSectionArea >= maxTension
			}
		}

		requirement def EnergyStorageRequirement {
			doc /* The elastic system shall store sufficient energy for long-range launches. */
			subject launcher : ProjectileLauncher;
			attribute minEnergy: EnergyValue;
			require constraint {
				(launcher.cord1.storedEnergy + launcher.cord2.storedEnergy) >= minEnergy
			}
		}

		requirement def SafetyRequirement {
			doc /* The trigger shall not release unless safety lock is disengaged. */
			subject trigger : TriggerMechanism;
			require constraint {
				trigger.isReleased implies (not trigger.safetyLock.isEngaged)
			}
		}
	}

	package 'Usages' {
		public import 'Definitions'::*;

		part launcher : ProjectileLauncher {
			part :>> body : Frame {
				attribute :>> yieldStrength = 503 [MPa];
				attribute :>> crossSectionArea = 0.001 [m^2];
			}
			part :>> cord1 : ElasticCord {
				attribute :>> stiffness = 800.0;
				attribute :>> restLength = 0.30 [m];
				attribute :>> maxElongation = 0.50 [m];
				attribute :>> storedEnergy = 100.0 [J];
			}
			part :>> cord2 : ElasticCord {
				attribute :>> stiffness = 800.0;
				attribute :>> restLength = 0.30 [m];
				attribute :>> maxElongation = 0.50 [m];
				attribute :>> storedEnergy = 100.0 [J];
			}
			part :>> pouch : Pouch {
				attribute :>> capacity = 0.5 [kg];
			}
			part :>> trigger : TriggerMechanism {
				attribute :>> isReleased = false;
				part :>> safetyLock : SafetyLock {
					attribute :>> isEngaged = true;
				}
			}

			connect cord1 to pouch;
			connect cord2 to pouch;
			connect trigger to pouch;

			state launchStateMachine {
				state ready;
				state loading;
				state drawn;
				state aimed;
				state launching;
				state fault;

				transition 'ready_to_loading' from ready to loading when cmdPort.loadCmd->notEmpty();
				transition 'loading_to_drawn' from loading to drawn when cmdPort.drawCmd->notEmpty();
				transition 'drawn_to_aimed' from drawn to aimed when cmdPort.aimCmd->notEmpty();
				transition 'aimed_to_launching' from aimed to launching when cmdPort.releaseCmd->notEmpty() and not trigger.safetyLock.isEngaged;
				transition 'launching_to_ready' from launching to ready;
				transition 'ready_to_fault' from ready to fault;
				transition 'loading_to_fault' from loading to fault;
				transition 'drawn_to_fault' from drawn to fault;
				transition 'aimed_to_fault' from aimed to fault;
				transition 'fault_to_ready' from fault to ready when cmdPort.resetCmd->notEmpty();
			}
		}

		part 'standard projectile' : Projectile {
			attribute :>> mass = 0.2 [kg];
			attribute :>> diameter = 0.03 [m];
		}

		requirement <'1.1'> frameIntegrity : StructuralIntegrityRequirement {
			subject frame : Frame;
			attribute :>> maxTension = 4000 [N];
		}

		requirement <'2.1'> energyStorage : EnergyStorageRequirement {
			subject launcher : ProjectileLauncher;
			attribute :>> minEnergy = 150 [J];
		}

		requirement <'3.1'> safetyLock : SafetyRequirement {
			subject trigger : TriggerMechanism;
		}
	}
}
