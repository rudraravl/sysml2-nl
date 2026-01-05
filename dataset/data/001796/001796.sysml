package InductorEnergyStorageSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	
	attribute def InductanceValue :> ISQ::InductanceValue {
		attribute :>> num : Real;
	}
	
	attribute def CurrentValue :> ISQ::CurrentValue {
		attribute :>> num : Real;
	}
	
	attribute def VoltageValue :> ISQ::VoltageValue {
		attribute :>> num : Real;
	}
	
	attribute def ResistanceValue :> ISQ::ResistanceValue {
		attribute :>> num : Real;
	}
	
	attribute def MagneticFluxValue :> ISQ::MagneticFluxValue {
		attribute :>> num : Real;
	}
	
	attribute def EnergyValue :> ISQ::EnergyValue {
		attribute :>> num : Real;
	}
	
	attribute def TimeValue :> ISQ::DurationValue {
		attribute :>> num : Real;
	}
	
	port def ElectricalPort {
		attribute voltage : VoltageValue;
		attribute current : CurrentValue;
	}
	
	item def ElectricalSignal {
		attribute voltage : VoltageValue;
		attribute current : CurrentValue;
		attribute timestamp : TimeValue;
	}
	
	part def InductorCore {
		attribute coreMaterial : String;
		attribute permeability : Real;
		attribute crossSectionalArea : ISQ::AreaValue;
		attribute effectiveLength : ISQ::LengthValue;
	}
	
	part def Winding {
		attribute numberOfTurns : Integer;
		attribute wireDiameter : ISQ::LengthValue;
		attribute wireResistance : ResistanceValue;
	}
	
	part def Inductor {
		attribute inductance : InductanceValue;
		attribute dcResistance : ResistanceValue;
		attribute maxCurrent : CurrentValue;
		attribute saturationCurrent : CurrentValue;
		
		port terminal1 : ElectricalPort;
		port terminal2 : ElectricalPort;
		
		part core : InductorCore;
		part winding : Winding;
		
		attribute storedEnergy : EnergyValue;
		attribute magneticFlux : MagneticFluxValue;
		attribute currentThroughInductor : CurrentValue;
	}
	
	action def MonitorCurrent {
		in currentInput : CurrentValue;
		out currentLevel : CurrentValue;
		out changeRate : Real;
	}
	
	action def CalculateInducedVoltage {
		in inductance : InductanceValue;
		in currentChangeRate : Real;
		out inducedVoltage : VoltageValue;
	}
	
	action def UpdateMagneticField {
		in current : CurrentValue;
		in inductance : InductanceValue;
		out flux : MagneticFluxValue;
		out energy : EnergyValue;
	}
	
	action def GenerateBackEMF {
		in changeRate : Real;
		in inductance : InductanceValue;
		out backEMF : VoltageValue;
	}
	
	action def EnergyStorage {
		in inductance : InductanceValue;
		in currentInput : CurrentValue;
		out storedEnergy : EnergyValue;
		out magneticFlux : MagneticFluxValue;
		
		first start;
		then merge monitoringLoop;
		
		then action monitor : MonitorCurrent {
			in currentInput;
			out currentLevel;
			out changeRate;
		}
		
		then action updateField : UpdateMagneticField {
			in current = monitor.currentLevel;
			in inductance;
			out flux;
			out energy;
		}
		
		then assign storedEnergy := updateField.energy;
		then assign magneticFlux := updateField.flux;
		
		then decide;
			if monitor.changeRate != 0.0 then generateEMF;
			if monitor.changeRate == 0.0 then maintainField;
		
		action generateEMF : GenerateBackEMF {
			in changeRate = monitor.changeRate;
			in inductance;
			out backEMF;
		}
		then monitoringLoop;
		
		action maintainField;
		then monitoringLoop;
	}
	
	action def CurrentOpposition {
		in inductance : InductanceValue;
		in currentInput : CurrentValue;
		out inducedVoltage : VoltageValue;
		
		first start;
		then action detectChange : MonitorCurrent {
			in currentInput;
			out currentLevel;
			out changeRate;
		}
		then action calculateVoltage : CalculateInducedVoltage {
			in inductance;
			in currentChangeRate = detectChange.changeRate;
			out inducedVoltage;
		}
		then assign inducedVoltage := calculateVoltage.inducedVoltage;
		then done;
	}
	
	state def InductorOperatingStates {
		entry; then idle;
		
		state idle;
		
		transition idle_to_charging
			first idle
			accept CurrentApplied
			then charging;
		
		state charging;
		
		transition charging_to_steady
			first charging
			accept SteadyStateReached
			then steadyState;
		
		state steadyState;
		
		transition steady_to_discharging
			first steadyState
			accept CurrentRemoved
			then discharging;
		
		state discharging;
		
		transition discharging_to_idle
			first discharging
			accept EnergyDepleted
			then idle;
		
		transition charging_to_saturated
			first charging
			accept SaturationReached
			then saturated;
		
		state saturated;
		
		transition saturated_to_steady
			first saturated
			accept CurrentReduced
			then steadyState;
	}
	
	part def PowerSupply {
		port output : ElectricalPort;
		attribute outputVoltage : VoltageValue;
		attribute maxCurrent : CurrentValue;
	}
	
	part def LoadResistor {
		port input : ElectricalPort;
		attribute resistance : ResistanceValue;
		attribute powerDissipation : ISQ::PowerValue;
	}
	
	part def CurrentSensor {
		port measurementPoint : ElectricalPort;
		attribute measuredCurrent : CurrentValue;
		attribute accuracy : Real;
	}
	
	part inductorSystem : Inductor {
		attribute :>> inductance : InductanceValue {
			attribute :>> num = 0.001;
		}
		attribute :>> dcResistance : ResistanceValue {
			attribute :>> num = 0.05;
		}
		attribute :>> maxCurrent : CurrentValue {
			attribute :>> num = 10.0;
		}
		attribute :>> saturationCurrent : CurrentValue {
			attribute :>> num = 8.0;
		}
		
		part :>> core : InductorCore {
			attribute :>> coreMaterial = "Ferrite";
			attribute :>> permeability = 2500.0;
		}
		
		part :>> winding : Winding {
			attribute :>> numberOfTurns = 100;
		}
		
		exhibit state behavior : InductorOperatingStates;
	}
	
	part inductorCircuit {
		part supply : PowerSupply {
			attribute :>> outputVoltage : VoltageValue {
				attribute :>> num = 12.0;
			}
			attribute :>> maxCurrent : CurrentValue {
				attribute :>> num = 5.0;
			}
		}
		
		part inductor : Inductor :> inductorSystem;
		
		part load : LoadResistor {
			attribute :>> resistance : ResistanceValue {
				attribute :>> num = 10.0;
			}
		}
		
		part sensor : CurrentSensor {
			attribute :>> accuracy = 0.01;
		}
		
		connect supply.output to inductor.terminal1;
		connect inductor.terminal2 to load.input;
		connect inductor.terminal2 to sensor.measurementPoint;
	}
	
	requirement def InductorFunctionalRequirement {
		doc /* The inductor shall store energy in a magnetic field when current flows through it. */
		
		subject inductor : Inductor;
		
		require constraint energyStorageConstraint {
			doc /* Energy stored must equal 0.5 * L * I^2 */
		}
	}
	
	requirement def CurrentOppositionRequirement {
		doc /* The inductor shall oppose changes in current by generating back EMF proportional to the rate of change. */
		
		subject inductor : Inductor;
		
		require constraint backEMFConstraint {
			doc /* Induced voltage must equal L * dI/dt */
		}
	}
	
	requirement def SaturationRequirement {
		doc /* The inductor core shall not saturate below the maximum rated current. */
		
		subject inductor : Inductor;
		
		require constraint saturationConstraint {
			inductor.saturationCurrent.num >= inductor.maxCurrent.num
		}
	}
	
	requirement <'IND-001'> inductorSystemRequirement {
		doc /* The inductor system shall provide energy storage and current smoothing functionality by storing energy in a magnetic field and opposing rapid changes in current flow. */
		
		subject system : Inductor = inductorSystem;
		
		assume constraint operatingConditions {
			doc /* System operates within rated current and temperature limits. */
		}
		
		require energyStorageReq : InductorFunctionalRequirement {
			subject inductor = system;
		}
		
		require currentOppositionReq : CurrentOppositionRequirement {
			subject inductor = system;
		}
		
		require saturationReq : SaturationRequirement {
			subject inductor = system;
		}
	}
	
	occurrence def InductorOperation {
		ref part system :>> inductorCircuit;
		
		message powerApplied of ElectricalSignal
			from system.supply.output to system.inductor.terminal1;
		
		then message steadyStateCurrent of ElectricalSignal
			from system.inductor.terminal2 to system.load.input;
	}
}
