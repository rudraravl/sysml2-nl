package SmartOutletSystem {
	import ScalarValues::*;
	import ISQ::*;
	import ISQElectromagnetism::*;

	// ---- Value Types ----
	value def VoltageValue :> Real { unit 'V'; }
	value def CurrentValue :> Real { unit 'A'; }
	value def PowerValue :> Real { unit 'W'; }
	value def FrequencyValue :> Real { unit 'Hz'; }
	value def ResistanceValue :> Real { unit 'ohm'; }
	value def LeakageCurrent :> Real { unit 'mA'; }

	// ---- Item Types ----
	item def AC_Power {
		attribute rmsVoltage : VoltageValue;
		attribute rmsCurrent : CurrentValue;
		attribute frequency : FrequencyValue;
		attribute activePower : PowerValue;
	}

	item def FaultSignal {
		attribute faultType : String;
		attribute severity : Real;
	}

	item def ResetCommand;
	item def StatusReport {
		attribute state : String;
		attribute measuredVoltage : VoltageValue;
		attribute measuredCurrent : CurrentValue;
	}

	// ---- Port Definitions ----
	port def PowerInPort {
		in item power : AC_Power;
	}
	port def PowerOutPort {
		out item power : AC_Power;
	}
	port def FaultOutPort {
		out item fault : FaultSignal;
	}
	port def ControlPort {
		in item reset : ResetCommand;
		out item status : StatusReport;
	}

	// ---- Circuit Breaker ----
	part def CircuitBreaker {
		attribute ratedCurrent : CurrentValue = 15 [A];
		attribute tripThreshold : CurrentValue = 15.5 [A];
		attribute responseTime : Real = 0.01 [s];

		port powerIn : PowerInPort;
		port powerOut : PowerOutPort;
		port faultOut : FaultOutPort;

		attribute tripped : Boolean = false;

		action def MonitorCurrent {
			in current : CurrentValue;
			out trip : Boolean;
		}

		state def BreakerStates {
			entry; then Closed;
			state Closed;
			state Open;
			transition Closed_to_Open
				first Closed
				then Open
				if powerIn.power.rmsCurrent > tripThreshold;
			transition Open_to_Closed
				first Open
				then Closed
				if !tripped;
		}

		state machine breakerStateMachine : BreakerStates;

		execute breakerStateMachine;
	}

	// ---- GFCI ----
	part def GFCI {
		attribute leakageThreshold : LeakageCurrent = 5 [mA];
		attribute responseTime : Real = 0.025 [s];
		attribute faultDetected : Boolean = false;

		port powerIn : PowerInPort;
		port powerOut : PowerOutPort;
		port faultOut : FaultOutPort;

		action def CompareCurrents {
			in lineCurrent : CurrentValue;
			in neutralCurrent : CurrentValue;
			out leakage : LeakageCurrent;
			out fault : Boolean;
		}

		state def GFCIStates {
			entry; then Monitoring;
			state Monitoring;
			state Tripped;
			transition Monitoring_to_Tripped
				first Monitoring
				then Tripped
				if faultDetected;
			transition Tripped_to_Monitoring
				first Tripped
				then Monitoring
				if !faultDetected;
		}

		state machine gfciStateMachine : GFCIStates;

		execute gfciStateMachine;
	}

	// ---- Voltage Regulator ----
	part def VoltageRegulator {
		attribute nominalVoltage : VoltageValue = 120 [V];
		attribute tolerance : VoltageValue = 5 [V];
		attribute minVoltage : VoltageValue = nominalVoltage - tolerance;
		attribute maxVoltage : VoltageValue = nominalVoltage + tolerance;
		attribute efficiency : Real = 0.97;

		port powerIn : PowerInPort;
		port powerOut : PowerOutPort;

		action def RegulateVoltage {
			in inputVoltage : VoltageValue;
			out outputVoltage : VoltageValue;
		}

		state def RegulatorStates {
			entry; then Regulating;
			state Regulating;
			state Bypass;
			transition Regulating_to_Bypass
				first Regulating
				then Bypass
				if powerIn.power.rmsVoltage > maxVoltage or powerIn.power.rmsVoltage < minVoltage;
			transition Bypass_to_Regulating
				first Bypass
				then Regulating
				if powerIn.power.rmsVoltage >= minVoltage and powerIn.power.rmsVoltage <= maxVoltage;
		}

		state machine regulatorStateMachine : RegulatorStates;

		execute regulatorStateMachine;
	}

	// ---- Outlet Receptacle ----
	part def OutletReceptacle {
		attribute receptacleType : String = "NEMA 5-15R";
		attribute ratedVoltage : VoltageValue = 120 [V];
		attribute ratedCurrent : CurrentValue = 15 [A];
		attribute pinCount : Integer = 3;

		port powerIn : PowerInPort;
		port deviceConnection : PowerOutPort;

		attribute deviceConnected : Boolean = false;
	}

	// ---- Smart Outlet System ----
	part def SmartOutlet {
		attribute systemId : String;
		attribute location : String;
		attribute firmwareVersion : String = "1.0.0";

		port mainsInput : PowerInPort;
		port deviceOutput : PowerOutPort;
		port controlInterface : ControlPort;
		port faultIndicator : FaultOutPort;

		part circuitBreaker : CircuitBreaker;
		part gfci : GFCI;
		part voltageRegulator : VoltageRegulator;
		part receptacle : OutletReceptacle;

		connection def PowerFlow {
			end source : PowerOutPort;
			end destination : PowerInPort;
		}

		connection mainsToBreaker : PowerFlow
			connect mainsInput::power to circuitBreaker.powerIn::power;
		connection breakerToGFCI : PowerFlow
			connect circuitBreaker.powerOut::power to gfci.powerIn::power;
		connection gfciToRegulator : PowerFlow
			connect gfci.powerOut::power to voltageRegulator.powerIn::power;
		connection regulatorToReceptacle : PowerFlow
			connect voltageRegulator.powerOut::power to receptacle.powerIn::power;
		connection receptacleToDevice : PowerFlow
			connect receptacle.deviceConnection::power to deviceOutput::power;

		connection breakerFault : PowerFlow
			connect circuitBreaker.faultOut::fault to faultIndicator::fault;
		connection gfciFault : PowerFlow
			connect gfci.faultOut::fault to faultIndicator::fault;

		state def OutletStates {
			entry; then Offline;

			state Offline {
				entry action sendStatus { controlInterface.status.state = "Offline"; }
			}

			state Standby {
				entry action sendStatus { controlInterface.status.state = "Standby"; }
			}

			state Active {
				entry action sendStatus { controlInterface.status.state = "Active"; }
			}

			state Tripped {
				entry action sendStatus { controlInterface.status.state = "Tripped"; }
			}

			transition Offline_to_Standby
				first Offline
				then Standby
				if mainsInput.power.rmsVoltage > 0 [V];

			transition Standby_to_Active
				first Standby
				then Active
				if receptacle.deviceConnected == true;

			transition Active_to_Standby
				first Active
				then Standby
				if receptacle.deviceConnected == false;

			transition Standby_to_Offline
				first Standby
				then Offline
				if mainsInput.power.rmsVoltage == 0 [V];

			transition Active_to_Tripped
				first Active
				then Tripped
				if circuitBreaker.tripped == true or gfci.faultDetected == true;

			transition Standby_to_Tripped
				first Standby
				then Tripped
				if circuitBreaker.tripped == true or gfci.faultDetected == true;

			transition Tripped_to_Standby
				first Tripped
				then Standby
				if controlInterface.reset != null and circuitBreaker.tripped == false and gfci.faultDetected == false;
		}

		state machine outletStateMachine : OutletStates;

		execute outletStateMachine;
	}

	// ---- Requirements ----
	requirement def SafetyRequirement {
		doc "The smart outlet shall protect connected devices and users from electrical hazards.";
	}

	requirement OvercurrentProtection : SafetyRequirement {
		doc "The circuit breaker shall trip when current exceeds 15.5 A.";
		subject circuitBreaker.tripThreshold;
		predicate { circuitBreaker.tripThreshold <= 15.5 [A]; }
	}

	requirement GroundFaultProtection : SafetyRequirement {
		doc "The GFCI shall cut power within 25 ms when leakage current exceeds 5 mA.";
		subject gfci.leakageThreshold;
		predicate { gfci.leakageThreshold <= 5 [mA] and gfci.responseTime <= 0.025 [s]; }
	}

	requirement VoltageRegulationRequirement {
		doc "The voltage regulator shall maintain output voltage within 120 V +/- 5 V.";
		subject voltageRegulator.nominalVoltage;
		predicate {
			voltageRegulator.nominalVoltage == 120 [V] and
			voltageRegulator.tolerance <= 5 [V];
		}
	}

	requirement ReceptacleComplianceRequirement {
		doc "The outlet receptacle shall be a NEMA 5-15R type rated for 120 V and 15 A.";
		subject receptacle.receptacleType;
		predicate {
			receptacle.receptacleType == "NEMA 5-15R" and
			receptacle.ratedVoltage == 120 [V] and
			receptacle.ratedCurrent == 15 [A];
		}
	}

	requirement StateManagementRequirement {
		doc "The smart outlet shall operate in Offline, Standby, Active, or Tripped states.";
		subject outletStateMachine;
		predicate {
			outletStateMachine.states.includes("Offline") and
			outletStateMachine.states.includes("Standby") and
			outletStateMachine.states.includes("Active") and
			outletStateMachine.states.includes("Tripped");
		}
	}

	requirement PowerIsolationRequirement {
		doc "In the Tripped state, the outlet shall isolate mains power from the receptacle.";
		subject outletStateMachine;
		predicate {
			outletStateMachine.currentState == "Tripped" implies
			receptacle.powerIn.power.rmsVoltage == 0 [V];
		}
	}

	// ---- Satisfaction ----
	satisfy OvercurrentProtection by SmartOutlet::circuitBreaker;
	satisfy GroundFaultProtection by SmartOutlet::gfci;
	satisfy VoltageRegulationRequirement by SmartOutlet::voltageRegulator;
	satisfy ReceptacleComplianceRequirement by SmartOutlet::receptacle;
	satisfy StateManagementRequirement by SmartOutlet::outletStateMachine;
	satisfy PowerIsolationRequirement by SmartOutlet::outletStateMachine;
}
