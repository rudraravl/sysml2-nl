package 'Station Outlet System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def VoltageLevel;
	attribute def CurrentLevel;
	attribute def PowerLevel;
	attribute def ConnectionStatus;
	
	enumeration def SafetyStatus {
		safe;
		overcurrent;
		groundFault;
	}
	
	item def ElectricalPower {
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute current : ISQ::ElectricCurrentValue;
		attribute frequency : ISQ::FrequencyValue;
	}
	
	item def PlugConnector {
		attribute isConnected : Boolean;
		attribute contactResistance : ISQ::ElectricalResistanceValue;
	}
	
	port def PowerInputPort {
		in item electricalPower : ElectricalPower;
	}
	
	port def PowerOutputPort {
		out item electricalPower : ElectricalPower;
	}
	
	port def ControlPort {
		in attribute enableSignal : Boolean;
		out attribute statusSignal : ConnectionStatus;
	}
	
	part def CircuitBreaker {
		attribute ratedCurrent : ISQ::ElectricCurrentValue;
		attribute tripThreshold : ISQ::ElectricCurrentValue;
		attribute isTripped : Boolean := false;
		
		port powerIn : PowerInputPort;
		port powerOut : PowerOutputPort;
		port control : ControlPort;
	}
	
	part def GroundFaultInterrupter {
		attribute leakageThreshold : ISQ::ElectricCurrentValue;
		attribute responseTime : ISQ::TimeValue;
		attribute isFaulted : Boolean := false;
		
		port powerIn : PowerInputPort;
		port powerOut : PowerOutputPort;
	}
	
	part def VoltageRegulator {
		attribute nominalVoltage : ISQ::ElectricPotentialValue;
		attribute toleranceRange : ISQ::ElectricPotentialValue;
		
		port powerIn : PowerInputPort;
		port powerOut : PowerOutputPort;
	}
	
	part def OutletReceptacle {
		attribute socketType : String;
		attribute maxPowerRating : ISQ::PowerValue;
		
		port powerIn : PowerInputPort;
		port powerOut : PowerOutputPort;
		part connector : PlugConnector;
	}
	
	action def MonitorPower {
		in voltage : ISQ::ElectricPotentialValue;
		in current : ISQ::ElectricCurrentValue;
		out powerLevel : ISQ::PowerValue;
		out safetyStatus : SafetyStatus;
	}
	
	action def DetectOvercurrent {
		in current : ISQ::ElectricCurrentValue;
		in threshold : ISQ::ElectricCurrentValue;
		out isOvercurrent : Boolean;
	}
	
	action def DetectGroundFault {
		in leakageCurrent : ISQ::ElectricCurrentValue;
		in threshold : ISQ::ElectricCurrentValue;
		out isFault : Boolean;
	}
	
	action def TripCircuit {
		in reason : String;
		out circuitState : Boolean;
	}
	
	action def SupplyPower {
		in powerDemand : ISQ::PowerValue;
		in enableSignal : Boolean;
		in currentSafetyStatus : SafetyStatus;
		out deliveredPower : ISQ::PowerValue;
		
		first start;
		then merge checkConditions;
		
		then action monitor : MonitorPower {
			in voltage;
			in current;
			out powerLevel;
			out safetyStatus;
		}
		
		then decide;
			if monitor.safetyStatus == SafetyStatus::safe then regulatePower;
			if monitor.safetyStatus == SafetyStatus::overcurrent then tripForOvercurrent;
			if monitor.safetyStatus == SafetyStatus::groundFault then tripForFault;
		
		action regulatePower {
			then assign deliveredPower := powerDemand;
		}
		then checkConditions;
		
		action tripForOvercurrent : TripCircuit {
			in reason = "Overcurrent detected";
			out circuitState;
		}
		then done;
		
		action tripForFault : TripCircuit {
			in reason = "Ground fault detected";
			out circuitState;
		}
		then done;
	}
	
	state machine def OutletStateMachine {
		initial state Offline;
		
		state Offline;
		
		state Standby {
			entry action initialize;
		}
		
		state Active {
			entry action enablePowerFlow;
			exit action disablePowerFlow;
		}
		
		state Tripped {
			entry action isolatePower;
		}
		
		transition t1 first Offline then Standby;
		transition t2 first Standby then Active;
		transition t3 first Active then Standby;
		transition t4 first Active then Tripped;
		transition t5 first Tripped then Standby;
		transition t6 first Standby then Offline;
	}
	
	part def StationOutlet {
		doc /* 
			A station outlet is an electrical power distribution point that provides 
			safe and regulated electrical power to connected devices at a fixed location.
			The primary function is to deliver controlled AC power while protecting 
			against electrical hazards through integrated safety mechanisms.
		*/
		
		attribute nominalVoltage : ISQ::ElectricPotentialValue := 120.0[SI::V];
		attribute nominalFrequency : ISQ::FrequencyValue := 60.0[SI::Hz];
		attribute maxCurrent : ISQ::ElectricCurrentValue := 15.0[SI::A];
		attribute maxPower : ISQ::PowerValue := 1800.0[SI::W];
		
		port mainPowerIn : PowerInputPort;
		port devicePowerOut : PowerOutputPort;
		port controlInterface : ControlPort;
		
		part breaker : CircuitBreaker {
			attribute ratedCurrent = 15.0[SI::A];
			attribute tripThreshold = 16.0[SI::A];
		}
		
		part gfci : GroundFaultInterrupter {
			attribute leakageThreshold = 0.005[SI::A];
			attribute responseTime = 0.025[SI::s];
		}
		
		part regulator : VoltageRegulator {
			attribute nominalVoltage = 120.0[SI::V];
			attribute toleranceRange = 6.0[SI::V];
		}
		
		part receptacle : OutletReceptacle {
			attribute socketType = "NEMA 5-15R";
			attribute maxPowerRating = 1800.0[SI::W];
		}
		
		connection powerFlow1 connect mainPowerIn to breaker.powerIn;
		connection powerFlow2 connect breaker.powerOut to gfci.powerIn;
		connection powerFlow3 connect gfci.powerOut to regulator.powerIn;
		connection powerFlow4 connect regulator.powerOut to receptacle.powerIn;
		connection powerFlow5 connect receptacle.powerOut to devicePowerOut;
		
		perform action supplyPower : SupplyPower {
			in powerDemand;
			in enableSignal = controlInterface.enableSignal;
			in currentSafetyStatus;
			out deliveredPower;
		}
		
		exhibit state machine behavior : OutletStateMachine;
	}
	
	requirement def SafetyRequirement {
		doc /* The station outlet shall protect against electrical hazards. */
		subject outlet : StationOutlet;
		
		require constraint overcurrentProtection {
			outlet.breaker.tripThreshold <= 1.1 * outlet.maxCurrent
		}
		
		require constraint groundFaultProtection {
			outlet.gfci.leakageThreshold <= 0.006[SI::A] and
			outlet.gfci.responseTime <= 0.030[SI::s]
		}
	}
	
	requirement def PowerQualityRequirement {
		doc /* The station outlet shall deliver stable, regulated power. */
		subject outlet : StationOutlet;
		
		require constraint voltageRegulation {
			outlet.regulator.toleranceRange <= 0.05 * outlet.nominalVoltage
		}
		
		require constraint frequencyStability {
			outlet.nominalFrequency >= 59.5[SI::Hz] and
			outlet.nominalFrequency <= 60.5[SI::Hz]
		}
	}
	
	requirement def CapacityRequirement {
		doc /* The station outlet shall provide adequate power capacity. */
		subject outlet : StationOutlet;
		
		require constraint powerRating {
			outlet.maxPower >= outlet.nominalVoltage * outlet.maxCurrent
		}
		
		require constraint continuousOperation {
			outlet.receptacle.maxPowerRating >= outlet.maxPower
		}
	}
	
	part stationOutletSystem : StationOutlet {
		doc /*
			Primary Function: Provide safe, regulated electrical power to connected 
			devices at a fixed station location with comprehensive protection against 
			electrical hazards including overcurrent and ground faults.
		*/
		
		:>> nominalVoltage = 120.0[SI::V];
		:>> nominalFrequency = 60.0[SI::Hz];
		:>> maxCurrent = 15.0[SI::A];
		:>> maxPower = 1800.0[SI::W];
		
		satisfy safetyReq : SafetyRequirement {
			subject outlet = stationOutletSystem;
		}
		
		satisfy powerQualityReq : PowerQualityRequirement {
			subject outlet = stationOutletSystem;
		}
		
		satisfy capacityReq : CapacityRequirement {
			subject outlet = stationOutletSystem;
		}
	}
}
