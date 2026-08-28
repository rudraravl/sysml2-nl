package BusSupervisoryControlSystem {
	part def VoltageValue :> Real { unit 'V'; }
	part def CurrentValue :> Real { unit 'A'; }
	part def FrequencyValue :> Real { unit 'Hz'; }
	part def DataRateValue :> Real { unit 'kb/s'; }
	part def TimeValue :> Real { unit 'ms'; }
	part def PercentageValue :> Real { unit '%'; }
	part def ErrorCountValue :> Real { unit 'count'; }

	item def BusMessage {
		attribute messageId : Integer;
		attribute priority : Integer;
		attribute payload : String;
		attribute sourceEcuId : Integer;
		attribute destinationEcuId : Integer;
		attribute timestamp : TimeValue;
	}

	item def BusStatus {
		attribute utilization : PercentageValue;
		attribute errorRate : PercentageValue;
		attribute activeNodes : Integer;
		attribute isHealthy : Boolean;
	}

	item def PhysicalLayerReport {
		attribute signalQuality : PercentageValue;
		attribute bitErrorRate : PercentageValue;
		attribute linkUp : Boolean;
	}

	item def PowerStatus {
		attribute outputVoltage : VoltageValue;
		attribute outputCurrent : CurrentValue;
		attribute railStable : Boolean;
	}

	port def EcuCommPort {
		out message : BusMessage;
		in receivedMessage : BusMessage;
	}

	port def BusControllerPort {
		in incomingMessage : BusMessage;
		out outgoingMessage : BusMessage;
		out statusReport : BusStatus;
	}

	port def TransceiverPort {
		in digitalIn : BusMessage;
		out digitalOut : BusMessage;
		out phyReport : PhysicalLayerReport;
	}

	port def PowerPort {
		out powerRail : PowerStatus;
	}

	part def ElectronicControlUnit {
		attribute ecuId : Integer;
		attribute ecuName : String;
		attribute functionDescription : String;
		attribute maxMessageRate : DataRateValue;
		port commPort : EcuCommPort;
		state machine EcuBehavior {
			entry; then Off;
			state Off;
			state Initializing;
			state Active;
			state Sleep;
			transition off_to_init
				first Off
				then Initializing
				if commPort.receivedMessage.messageId == 0;
			transition init_to_active
				first Initializing
				then Active;
			transition active_to_sleep
				first Active
				then Sleep
				if no commPort.receivedMessage in 100[ms];
			transition sleep_to_active
				first Sleep
				then Active
				if commPort.receivedMessage.messageId > 0;
		}
	}

	part def BusController {
		attribute controllerId : Integer;
		attribute arbitrationEnabled : Boolean;
		attribute maxQueueSize : Integer;
		attribute priorityThreshold : Integer;
		port controllerPort : BusControllerPort;
		port powerIn : PowerPort;
		attribute messageQueue : BusMessage[0..*] ordered;
		attribute busUtilization : PercentageValue;
		attribute errorCount : ErrorCountValue;
		state machine ControllerBehavior {
			entry; then Offline;
			state Offline {
				entry action { busUtilization = 0[%]; errorCount = 0[count]; }
			}
			state Initializing {
				entry action { arbitrationEnabled = false; messageQueue.clear(); }
				do action { arbitrationEnabled = true; }
			}
			state Operational {
				entry action { arbitrationEnabled = true; }
				do action {
					if messageQueue.size() > 0 {
						var nextMsg : BusMessage = messageQueue.selectHighestPriority();
						controllerPort.outgoingMessage = nextMsg;
						messageQueue.remove(nextMsg);
						busUtilization = computeUtilization();
					}
				}
			}
			state Degraded {
				entry action { arbitrationEnabled = true; priorityThreshold = 5; }
				do action {
					if errorCount > 100[count] { sendFaultSignal(); }
				}
			}
			state Fault {
				entry action { arbitrationEnabled = false; }
			}
			transition offline_to_init
				first Offline
				then Initializing
				if powerIn.powerRail.railStable == true;
			transition init_to_operational
				first Initializing
				then Operational
				if arbitrationEnabled == true and powerIn.powerRail.outputVoltage >= 5[V];
			transition operational_to_degraded
				first Operational
				then Degraded
				if controllerPort.statusReport.errorRate > 5[%];
			transition degraded_to_operational
				first Degraded
				then Operational
				if controllerPort.statusReport.errorRate < 1[%] and controllerPort.statusReport.isHealthy == true;
			transition degraded_to_fault
				first Degraded
				then Fault
				if errorCount > 200[count];
			transition operational_to_fault
				first Operational
				then Fault
				if powerIn.powerRail.railStable == false;
			transition fault_to_offline
				first Fault
				then Offline
				if resetRequested == true;
		}
	}

	part def BusTransceiver {
		attribute transceiverId : Integer;
		attribute supportedDataRate : DataRateValue;
		attribute impedance : Real;
		port transceiverPort : TransceiverPort;
		port powerIn : PowerPort;
		state machine TransceiverBehavior {
			entry; then PoweredOff;
			state PoweredOff;
			state LinkTraining;
			state Transmitting;
			state Receiving;
			state LinkError;
			transition off_to_training
				first PoweredOff
				then LinkTraining
				if powerIn.powerRail.railStable == true;
			transition training_to_tx
				first LinkTraining
				then Transmitting
				if transceiverPort.phyReport.linkUp == true;
			transition tx_to_rx
				first Transmitting
				then Receiving
				if no transceiverPort.digitalIn in 2[ms];
			transition rx_to_tx
				first Receiving
				then Transmitting
				if transceiverPort.digitalIn.messageId > 0;
			transition any_to_linkerror
				first Transmitting
				then LinkError
				if transceiverPort.phyReport.bitErrorRate > 10[%];
			transition linkerror_to_training
				first LinkError
				then LinkTraining
				if retryCount < 3;
		}
	}

	part def PowerManagementUnit {
		attribute pmuId : Integer;
		attribute nominalVoltage : VoltageValue;
		attribute maxCurrent : CurrentValue;
		attribute switchingFrequency : FrequencyValue;
		attribute efficiency : PercentageValue;
		port powerOutController : PowerPort;
		port powerOutTransceiver : PowerPort;
		port powerOutEcu : PowerPort[0..*];
		state machine PmuBehavior {
			entry; then Shutdown;
			state Shutdown;
			state SoftStart;
			state Regulation;
			state Protection;
			transition shutdown_to_softstart
				first Shutdown
				then SoftStart
				if enableSignal == true;
			transition softstart_to_regulation
				first SoftStart
				then Regulation
				if outputVoltage >= nominalVoltage * 0.95;
			transition regulation_to_protection
				first Regulation
				then Protection
				if outputCurrent > maxCurrent;
			transition protection_to_shutdown
				first Protection
				then Shutdown
				if faultCleared == true;
		}
	}

	part def SupervisoryControlSystem {
		attribute systemId : Integer;
		attribute systemName : String;
		part pmu : PowerManagementUnit {
			attribute nominalVoltage = 12[V];
			attribute maxCurrent = 10[A];
			attribute switchingFrequency = 100[kHz];
		}
		part busController : BusController {
			attribute controllerId = 1;
			attribute maxQueueSize = 64;
		}
		part busTransceiver : BusTransceiver {
			attribute transceiverId = 1;
			attribute supportedDataRate = 500[kb/s];
		}
		part ecus : ElectronicControlUnit[4] {
			part ecu1 : ElectronicControlUnit {
				attribute ecuId = 1;
				attribute ecuName = "EngineControl";
				attribute functionDescription = "Controls engine fuel injection and ignition timing";
				attribute maxMessageRate = 100[kb/s];
			}
			part ecu2 : ElectronicControlUnit {
				attribute ecuId = 2;
				attribute ecuName = "BrakeControl";
				attribute functionDescription = "Manages braking system pressure and ABS modulation";
				attribute maxMessageRate = 80[kb/s];
			}
			part ecu3 : ElectronicControlUnit {
				attribute ecuId = 3;
				attribute ecuName = "BodyControl";
				attribute functionDescription = "Controls lighting, wipers, and comfort features";
				attribute maxMessageRate = 50[kb/s];
			}
			part ecu4 : ElectronicControlUnit {
				attribute ecuId = 4;
				attribute ecuName = "SensorHub";
				attribute functionDescription = "Aggregates and preprocesses sensor data";
				attribute maxMessageRate = 120[kb/s];
			}
		}
		connection : PowerStatus connect pmu.powerOutController to busController.powerIn;
		connection : PowerStatus connect pmu.powerOutTransceiver to busTransceiver.powerIn;
		connection : PowerStatus connect pmu.powerOutEcu to ecus.commPort;
		connection : BusMessage connect ecus.commPort.message to busTransceiver.transceiverPort.digitalIn;
		connection : BusMessage connect busTransceiver.transceiverPort.digitalOut to busController.controllerPort.incomingMessage;
		connection : BusMessage connect busController.controllerPort.outgoingMessage to busTransceiver.transceiverPort.digitalIn;
		connection : PhysicalLayerReport connect busTransceiver.transceiverPort.phyReport to busController.controllerPort.statusReport;
	}

	requirement def CommunicationReliabilityRequirement {
		doc /* The system shall ensure reliable and predictable data exchange between ECUs. */
		subject : system : SupervisoryControlSystem;
		objective {
			doc /* Bus utilization shall remain below 70% under nominal load. */
			constraint { system.busController.busUtilization < 70[%] }
		}
	}

	requirement def FaultToleranceRequirement {
		doc /* The system shall detect communication faults and enter degraded mode for recovery. */
		subject : system : SupervisoryControlSystem;
		objective {
			doc /* Error rate exceeding 5% shall trigger degraded mode within 10 ms. */
			constraint { system.busController.controllerPort.statusReport.errorRate > 5[%] implies system.busController.ControllerBehavior.Degraded.active }
		}
	}

	requirement def PowerStabilityRequirement {
		doc /* The PMU shall provide stable regulated power to all components. */
		subject : pmu : PowerManagementUnit;
		objective {
			doc /* Output voltage shall remain within 5% of nominal during regulation. */
			constraint { pmu.nominalVoltage * 0.95 <= pmu.powerOutController.powerRail.outputVoltage <= pmu.nominalVoltage * 1.05 }
		}
	}

	requirement def PriorityArbitrationRequirement {
		doc /* The bus controller shall arbitrate message transmission by priority. */
		subject : controller : BusController;
		objective {
			doc /* Higher priority messages shall be transmitted before lower priority messages. */
			constraint { controller.messageQueue.isOrderedBy(priority, descending) == true }
		}
	}

	requirement def PhysicalLayerIntegrityRequirement {
		doc /* The transceiver shall monitor signal quality and report physical-layer errors. */
		subject : transceiver : BusTransceiver;
		objective {
			doc /* Bit error rate shall be reported and shall not exceed 10% during operation. */
			constraint { transceiver.transceiverPort.phyReport.bitErrorRate <= 10[%] }
		}
	}

	requirement def StateManagementRequirement {
		doc /* The system shall transition through offline, initialization, operational, degraded, and fault states. */
		subject : system : SupervisoryControlSystem;
		objective {
			doc /* All defined states shall be reachable and transitions shall be deterministic. */
			constraint { system.busController.ControllerBehavior.Offline.reachable and system.busController.ControllerBehavior.Initializing.reachable and system.busController.ControllerBehavior.Operational.reachable and system.busController.ControllerBehavior.Degraded.reachable and system.busController.ControllerBehavior.Fault.reachable }
		}
	}

	requirement CommunicationReliabilitySatisfies : CommunicationReliabilityRequirement {
		satisfy system.busController.busUtilization by system.busController;
	}

	requirement FaultToleranceSatisfies : FaultToleranceRequirement {
		satisfy system.busController.controllerPort.statusReport.errorRate by system.busController;
	}

	requirement PowerStabilitySatisfies : PowerStabilityRequirement {
		satisfy pmu.powerOutController.powerRail.outputVoltage by pmu;
	}

	requirement PriorityArbitrationSatisfies : PriorityArbitrationRequirement {
		satisfy controller.messageQueue by busController;
	}

	requirement PhysicalLayerIntegritySatisfies : PhysicalLayerIntegrityRequirement {
		satisfy transceiver.transceiverPort.phyReport.bitErrorRate by busTransceiver;
	}

	requirement StateManagementSatisfies : StateManagementRequirement {
		satisfy system.busController.ControllerBehavior by system.busController;
	}
}
