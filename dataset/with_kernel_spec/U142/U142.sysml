package AutomatedAirlockSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def PressureValue :> Real;

	item def EgressCommand;
	item def IngressCommand;
	item def CycleComplete;
	item def DoorLockCmd;
	item def DoorUnlockCmd;
	item def ValveOpenCmd;
	item def ValveCloseCmd;

	port def SystemCmdPort {
		in egress : EgressCommand;
		in ingress : IngressCommand;
		in complete : CycleComplete;
	}

	port def DoorCmdPort {
		out lock : DoorLockCmd;
		out unlock : DoorUnlockCmd;
	}

	port def ValveCmdPort {
		out open : ValveOpenCmd;
		out close : ValveCloseCmd;
	}

	port def PressurePort {
		out pressure : PressureValue;
	}

	part def PressureSensor {
		attribute currentPressure : PressureValue := 101325.0;
		port pressureOut : PressurePort;
	}

	part def Door {
		attribute isLocked : Boolean := true;
		attribute isOpen : Boolean := false;
		port cmdPort : ~DoorCmdPort;

		exhibit state doorStates {
			entry; then Locked;
			state Locked;
			accept DoorUnlockCmd
				do assign isLocked := false
				then Unlocked;
			state Unlocked;
			accept DoorLockCmd
				do assign isLocked := true
				then Locked;
		}
	}

	part def Valve {
		attribute isOpen : Boolean := false;
		port cmdPort : ~ValveCmdPort;

		exhibit state valveStates {
			entry; then Closed;
			state Closed;
			accept ValveOpenCmd
				do assign isOpen := true
				then Open;
			state Open;
			accept ValveCloseCmd
				do assign isOpen := false
				then Closed;
		}
	}

	part def AirlockController {
		attribute habitatPressure : PressureValue := 101325.0;
		attribute vacuumPressure : PressureValue := 0.0;
		port sysCmdPort : SystemCmdPort;
		port innerDoorPort : DoorCmdPort;
		port outerDoorPort : DoorCmdPort;
		port ventValvePort : ValveCmdPort;
		port fillValvePort : ValveCmdPort;
		port sensorPort : ~PressurePort;

		exhibit state controllerStates {
			entry; then Idle;

			state Idle;
			accept EgressCommand then EgressSealing;
			accept IngressCommand then IngressSealing;

			state EgressSealing {
				do send new DoorLockCmd() to innerDoorPort;
			}
			then EgressVenting;

			state EgressVenting {
				do send new ValveOpenCmd() to ventValvePort;
			}
			accept when sensorPort.pressure <= vacuumPressure then EgressReady;

			state EgressReady {
				entry {
					send new ValveCloseCmd() to ventValvePort;
					send new DoorUnlockCmd() to outerDoorPort;
				}
			}
			accept CycleComplete then Idle;

			state IngressSealing {
				do send new DoorLockCmd() to outerDoorPort;
			}
			then IngressPressurizing;

			state IngressPressurizing {
				do send new ValveOpenCmd() to fillValvePort;
			}
			accept when sensorPort.pressure >= habitatPressure then IngressReady;

			state IngressReady {
				entry {
					send new ValveCloseCmd() to fillValvePort;
					send new DoorUnlockCmd() to innerDoorPort;
				}
			}
			accept CycleComplete then Idle;
		}
	}

	part def AirlockChamber {
		attribute internalPressure : PressureValue := 101325.0;
		part innerDoor : Door;
		part outerDoor : Door;
		part ventValve : Valve;
		part fillValve : Valve;
		part pressureSensor : PressureSensor;
		part controller : AirlockController;

		connection innerDoorConn connect controller.innerDoorPort to innerDoor.cmdPort;
		connection outerDoorConn connect controller.outerDoorPort to outerDoor.cmdPort;
		connection ventValveConn connect controller.ventValvePort to ventValve.cmdPort;
		connection fillValveConn connect controller.fillValvePort to fillValve.cmdPort;
		connection sensorConn connect pressureSensor.pressureOut to controller.sensorPort;
	}

	part def Person;

	part airlockSystem : AirlockChamber {
		ref part occupant : Person [0..1];
	}

	requirement def DoorInterlockRequirement {
		doc /* Both doors must never be unlocked or open at the same time,
		     * preventing catastrophic depressurization of the habitat. */
		subject airlock : AirlockChamber;
		assert constraint {
			not (airlock.innerDoor.isLocked == false and airlock.outerDoor.isLocked == false)
		}
	}

	requirement def PressureInterlockRequirement {
		doc /* Doors must remain locked and sealed if there is a significant
		     * pressure difference across them, ensuring structural integrity. */
		subject door : Door;
		attribute pressureDiff : PressureValue;
		assert constraint {
			pressureDiff > 1000.0 implies door.isLocked == true
		}
	}

	requirement def EgressSequenceRequirement {
		doc /* During egress, the inner door shall be sealed and locked before
		     * venting begins, and the outer door shall not unlock until chamber
		     * pressure equals vacuum pressure. */
		subject airlock : AirlockChamber;
		assert constraint {
			airlock.ventValve.isOpen implies airlock.innerDoor.isLocked
		}
	}

	requirement def IngressSequenceRequirement {
		doc /* During ingress, the outer door shall be sealed and locked before
		     * pressurization begins, and the inner door shall not unlock until
		     * chamber pressure equals habitat pressure. */
		subject airlock : AirlockChamber;
		assert constraint {
			airlock.fillValve.isOpen implies airlock.outerDoor.isLocked
		}
	}

	requirement def AutomatedCycleRequirement {
		doc /* The airlock shall execute egress and ingress cycles automatically
		     * upon receiving a command, without manual intervention. */
		subject airlock : AirlockChamber;
		assert constraint {
			airlock.controller.sysCmdPort.egress or airlock.controller.sysCmdPort.ingress
		}
	}
}
