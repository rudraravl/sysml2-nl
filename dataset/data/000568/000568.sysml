package CerebralShuntSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def IntracranialPressure :> ISQ::PressureValue {
		attribute :>> num : Real;
		attribute :>> mRef : PressureUnit;
	}
	
	attribute def CSFFlowRate :> ISQ::VolumeFlowRateValue {
		attribute :>> num : Real;
		attribute :>> mRef : VolumeFlowRateUnit;
	}
	
	attribute def CSFVolume :> ISQ::VolumeValue {
		attribute :>> num : Real;
		attribute :>> mRef : VolumeUnit;
	}
	
	attribute def CatheterLength :> ISQ::LengthValue {
		attribute :>> num : Real;
		attribute :>> mRef : LengthUnit;
	}
	
	enum def ValveState {
		enum closed;
		enum open;
		enum partiallyOpen;
	}
	
	enum def SystemStatus {
		enum normal;
		enum draining;
		enum blocked;
		enum malfunction;
	}
	
	item def CerebrospinalFluid {
		attribute pressure : IntracranialPressure;
		attribute volume : CSFVolume;
	}
	
	port def CSFPort {
		attribute pressure : IntracranialPressure;
		attribute flowRate : CSFFlowRate;
	}
	
	part def VentricularCatheter {
		doc /* Proximal catheter inserted into brain ventricle to collect excess CSF */
		port inlet : CSFPort;
		port outlet : CSFPort;
		attribute length : CatheterLength;
		attribute innerDiameter : ISQ::LengthValue;
	}
	
	part def PressureRegulatingValve {
		doc /* One-way valve that opens when CSF pressure exceeds threshold */
		port inlet : CSFPort;
		port outlet : CSFPort;
		attribute openingPressure : IntracranialPressure;
		attribute closingPressure : IntracranialPressure;
		attribute currentState : ValveState;
		
		perform action regulateFlow : RegulateCSFFlow;
	}
	
	part def DistalCatheter {
		doc /* Distal catheter that drains CSF to target body cavity */
		port inlet : CSFPort;
		port outlet : CSFPort;
		attribute length : CatheterLength;
		attribute innerDiameter : ISQ::LengthValue;
	}
	
	part def CSFReservoir {
		doc /* Optional reservoir for CSF sampling and pressure monitoring */
		port inlet : CSFPort;
		port outlet : CSFPort;
		attribute capacity : CSFVolume;
		attribute currentVolume : CSFVolume;
	}
	
	action def MeasurePressure {
		in ventricularPort : CSFPort;
		out measuredPressure : IntracranialPressure;
	}
	
	action def OpenValve {
		in valve : PressureRegulatingValve;
		out newState : ValveState;
	}
	
	action def CloseValve {
		in valve : PressureRegulatingValve;
		out newState : ValveState;
	}
	
	action def DrainCSF {
		in inletPort : CSFPort;
		in outletPort : CSFPort;
		in flowRate : CSFFlowRate;
		out drainedVolume : CSFVolume;
	}
	
	action def RegulateCSFFlow {
		in inletPressure : IntracranialPressure;
		in outletPressure : IntracranialPressure;
		in openingThreshold : IntracranialPressure;
		in closingThreshold : IntracranialPressure;
		out valveState : ValveState;
		out outputFlowRate : CSFFlowRate;
		
		first start;
		then decide;
			if inletPressure.num > openingThreshold.num then openValveAction;
			if inletPressure.num <= closingThreshold.num then closeValveAction;
		
		action openValveAction {
			then assign valveState := ValveState::open;
			then assign outputFlowRate := 20.0;
		}
		
		action closeValveAction {
			then assign valveState := ValveState::closed;
			then assign outputFlowRate := 0.0;
		}
		
		then done;
	}
	
	action def ManageIntracranialPressure {
		doc /* Primary function: continuously monitor and drain excess CSF to maintain safe intracranial pressure */
		
		in targetPressure : IntracranialPressure;
		in maxPressure : IntracranialPressure;
		out currentFlowRate : CSFFlowRate;
		out systemStatus : SystemStatus;
		
		private attribute pressure : IntracranialPressure;
		
		first start;
		then merge monitorLoop;
		
		then action measurePressure : MeasurePressure {
			in ventricularPort;
			out measuredPressure;
		}
		
		then assign pressure := measurePressure.measuredPressure;
		
		then decide;
			if pressure.num > maxPressure.num then activateDrainage;
			if pressure.num <= targetPressure.num then maintainClosedState;
		
		action activateDrainage {
			first action openValveAction : OpenValve {
				in valve;
				out newState;
			}
			then action drainFluid : DrainCSF {
				in inletPort;
				in outletPort;
				in flowRate;
				out drainedVolume;
			}
			then assign currentFlowRate := drainFluid.drainedVolume.num / 60.0;
			then assign systemStatus := SystemStatus::draining;
		}
		then monitorLoop;
		
		action maintainClosedState {
			first action closeValveAction : CloseValve {
				in valve;
				out newState;
			}
			then assign currentFlowRate := 0.0;
			then assign systemStatus := SystemStatus::normal;
		}
		then monitorLoop;
	}
	
	state def ShuntOperationalStates {
		entry; then idle;
		
		state idle {
			entry assign status := SystemStatus::normal;
		}
		
		transition idle_to_draining
			first idle
			accept pressureHigh : IntracranialPressure
			if pressureHigh.num > 15.0
			then draining;
		
		state draining {
			entry assign status := SystemStatus::draining;
			do action drainCSF : DrainCSF;
		}
		
		transition draining_to_idle
			first draining
			accept pressureNormal : IntracranialPressure
			if pressureNormal.num <= 10.0
			then idle;
		
		transition any_to_blocked
			first idle, draining
			accept blockageDetected : Boolean
			if blockageDetected
			then blocked;
		
		state blocked {
			entry assign status := SystemStatus::blocked;
		}
		
		transition blocked_to_idle
			first blocked
			accept blockageCleared : Boolean
			if blockageCleared
			then idle;
		
		attribute status : SystemStatus;
	}
	
	part def CerebralShunt {
		doc /* Medical device that drains excess cerebrospinal fluid from brain ventricles to relieve intracranial pressure */
		
		port proximalPort : CSFPort {
			doc /* Connection to brain ventricle */
		}
		
		port distalPort : CSFPort {
			doc /* Connection to drainage cavity (peritoneum, atrium, or pleura) */
		}
		
		part ventricularCatheter : VentricularCatheter {
			port inlet : CSFPort;
			port outlet : CSFPort;
			attribute :>> length = 10.0 [cm];
			attribute :>> innerDiameter = 1.5 [mm];
		}
		
		part valve : PressureRegulatingValve {
			port inlet : CSFPort;
			port outlet : CSFPort;
			attribute :>> openingPressure {
				attribute :>> num = 10.0;
			}
			attribute :>> closingPressure {
				attribute :>> num = 8.0;
			}
			attribute :>> currentState = ValveState::closed;
		}
		
		part reservoir : CSFReservoir {
			port inlet : CSFPort;
			port outlet : CSFPort;
			attribute :>> capacity {
				attribute :>> num = 2.0;
			}
			attribute :>> currentVolume {
				attribute :>> num = 0.0;
			}
		}
		
		part distalCatheter : DistalCatheter {
			port inlet : CSFPort;
			port outlet : CSFPort;
			attribute :>> length = 40.0 [cm];
			attribute :>> innerDiameter = 2.0 [mm];
		}
		
		connect proximalPort to ventricularCatheter.inlet;
		connect ventricularCatheter.outlet to reservoir.inlet;
		connect reservoir.outlet to valve.inlet;
		connect valve.outlet to distalCatheter.inlet;
		connect distalCatheter.outlet to distalPort;
		
		perform action managePressure : ManageIntracranialPressure {
			in targetPressure {
				attribute :>> num = 10.0;
			}
			in maxPressure {
				attribute :>> num = 15.0;
			}
			out currentFlowRate;
			out systemStatus;
		}
		
		exhibit state operationalBehavior : ShuntOperationalStates;
	}
	
	part shuntSystem : CerebralShunt;
	
	requirement def SafetyRequirement;
	requirement def PerformanceRequirement;
	requirement def ReliabilityRequirement;
	
	requirement <'SHNT-001'> maintainSafePressure : PerformanceRequirement {
		doc /* The shunt system shall maintain intracranial pressure within safe physiological range (5-15 mmHg) */
		
		subject shuntSystem;
		
		require constraint {
			shuntSystem.managePressure.targetPressure.num >= 5.0 and
			shuntSystem.managePressure.maxPressure.num <= 15.0
		}
	}
	
	requirement <'SHNT-002'> preventOverdrainage : SafetyRequirement {
		doc /* The shunt system shall prevent excessive CSF drainage that could cause intracranial hypotension */
		
		subject shuntSystem;
		
		require constraint {
			shuntSystem.managePressure.currentFlowRate.num <= 20.0
		}
	}
	
	requirement <'SHNT-003'> continuousOperation : ReliabilityRequirement {
		doc /* The shunt system shall operate continuously without external power */
		
		subject shuntSystem;
	}
	
	requirement <'SHNT-004'> biocompatibility : SafetyRequirement {
		doc /* All shunt components in contact with CSF shall be biocompatible */
		
		subject shuntSystem;
		
		require constraint {
			shuntSystem.ventricularCatheter.innerDiameter.num > 0.0 and
			shuntSystem.distalCatheter.innerDiameter.num > 0.0
		}
	}
	
	requirement primaryMission {
		doc /* The cerebral shunt system shall drain excess cerebrospinal fluid from brain ventricles to relieve elevated intracranial pressure in hydrocephalus patients */
		
		subject shuntSystem;
		
		require maintainSafePressure;
		require preventOverdrainage;
		require continuousOperation;
		require biocompatibility;
	}
}
