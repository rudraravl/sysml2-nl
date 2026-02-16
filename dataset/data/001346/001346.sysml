package 'Artificial Muscle System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ActivationVoltage :> ISQ::ElectricPotentialValue;
	attribute def ActivationCurrent :> ISQ::ElectricCurrentValue;
	attribute def ContractionLevel :> Real;
	attribute def ActivationCommand;
	attribute def DeactivationCommand;
	
	item def ElectroactivePolymerFiber {
		attribute maxContraction : ContractionLevel;
		attribute responseTime : ISQ::TimeValue;
		attribute nominalVoltage : ActivationVoltage;
		attribute restLength : ISQ::LengthValue;
	}
	
	item def HighVoltagePowerSupply {
		attribute outputVoltage : ActivationVoltage;
		attribute maxCurrent : ActivationCurrent;
		attribute efficiency : Real;
	}
	
	item def MicrocontrollerUnit {
		attribute processingFrequency : ISQ::FrequencyValue;
		attribute pwmResolution : Real;
	}
	
	item def ForceSensor {
		attribute sensitivity : Real;
		attribute maxForce : ISQ::ForceValue;
	}
	
	item def MechanicalLoad {
		attribute mass : ISQ::MassValue;
		attribute inertia : Real;
	}
	
	port def PowerPort {
		attribute voltage : ActivationVoltage;
		attribute current : ActivationCurrent;
	}
	
	port def MechanicalPort {
		attribute force : ISQ::ForceValue;
		attribute displacement : ISQ::LengthValue;
		attribute velocity : ISQ::SpeedValue;
	}
	
	port def ControlPort {
		attribute pwmSignal : ActivationVoltage;
		attribute dutyCycle : Real;
	}
	
	port def SensorPort {
		attribute forceReading : ISQ::ForceValue;
		attribute positionReading : ISQ::LengthValue;
	}
	
	part def ArtificialMuscleActuator {
		port powerInput : PowerPort;
		port controlInput : ControlPort;
		port mechanicalOutput : MechanicalPort;
		port sensorOutput : SensorPort;
		
		attribute currentContraction : ContractionLevel;
		attribute currentForce : ISQ::ForceValue;
		attribute currentLength : ISQ::LengthValue;
		
		perform action actuate;
	}
	
	action def ApplyElectricalStimulation {
		in voltage : ActivationVoltage;
		in current : ActivationCurrent;
		in pwmDutyCycle : Real;
		out effectiveVoltage : ActivationVoltage;
	}
	
	action def ContractFiber {
		in effectiveVoltage : ActivationVoltage;
		in currentLength : ISQ::LengthValue;
		in restLength : ISQ::LengthValue;
		out contractionLevel : ContractionLevel;
		out newLength : ISQ::LengthValue;
	}
	
	action def GenerateMechanicalForce {
		in contractionLevel : ContractionLevel;
		in fiberLength : ISQ::LengthValue;
		in loadMass : ISQ::MassValue;
		out outputForce : ISQ::ForceValue;
		out displacement : ISQ::LengthValue;
	}
	
	action def MeasureState {
		in currentForce : ISQ::ForceValue;
		in currentLength : ISQ::LengthValue;
		out forceReading : ISQ::ForceValue;
		out positionReading : ISQ::LengthValue;
	}
	
	action def RelaxFiber {
		in currentContraction : ContractionLevel;
		in currentLength : ISQ::LengthValue;
		in restLength : ISQ::LengthValue;
		out relaxationLevel : ContractionLevel;
		out recoveredLength : ISQ::LengthValue;
	}
	
	action def ControlledActuation {
		in activationCmd : ActivationCommand;
		in deactivationCmd : DeactivationCommand;
		in supplyVoltage : ActivationVoltage;
		in supplyCurrent : ActivationCurrent;
		in targetForce : ISQ::ForceValue;
		out actualForce : ISQ::ForceValue;
		out actualDisplacement : ISQ::LengthValue;
		
		attribute restLength : ISQ::LengthValue := 100.0 [SI::mm];
		attribute currentLength : ISQ::LengthValue := restLength;
		attribute currentContraction : ContractionLevel := 0.0;
		attribute loadMass : ISQ::MassValue := 0.5 [SI::kg];
		
		first start;
		then merge waitForActivation;
		
		accept activation : ActivationCommand;
		then action applyStimulation : ApplyElectricalStimulation {
			in voltage = supplyVoltage;
			in current = supplyCurrent;
			in pwmDutyCycle : Real := 0.75;
			out effectiveVoltage : ActivationVoltage;
		}
		
		then action contract : ContractFiber {
			in effectiveVoltage = applyStimulation.effectiveVoltage;
			in currentLength = ControlledActuation.currentLength;
			in restLength = ControlledActuation.restLength;
			out contractionLevel : ContractionLevel;
			out newLength : ISQ::LengthValue;
		}
		
		then assign currentContraction := contract.contractionLevel;
		then assign currentLength := contract.newLength;
		
		then action generateForce : GenerateMechanicalForce {
			in contractionLevel = contract.contractionLevel;
			in fiberLength = contract.newLength;
			in loadMass = ControlledActuation.loadMass;
			out outputForce : ISQ::ForceValue;
			out displacement : ISQ::LengthValue;
		}
		
		then action measure : MeasureState {
			in currentForce = generateForce.outputForce;
			in currentLength = contract.newLength;
			out forceReading : ISQ::ForceValue;
			out positionReading : ISQ::LengthValue;
		}
		
		then decide;
			if measure.forceReading >= targetForce then maintainContraction;
			if measure.forceReading < targetForce then waitForActivation;
		
		action maintainContraction {
			then accept deactivation : DeactivationCommand;
		}
		then relaxMuscle;
		
		action relaxMuscle : RelaxFiber {
			in currentContraction = ControlledActuation.currentContraction;
			in currentLength = ControlledActuation.currentLength;
			in restLength = ControlledActuation.restLength;
			out relaxationLevel : ContractionLevel;
			out recoveredLength : ISQ::LengthValue;
		}
		
		then assign currentContraction := relaxMuscle.relaxationLevel;
		then assign currentLength := relaxMuscle.recoveredLength;
		then waitForActivation;
	}
	
	part artificialMuscleSystem : ArtificialMuscleActuator {
		doc /*
		 * An artificial muscle system that converts electrical energy into mechanical work
		 * through electroactive polymer actuation. The system receives electrical stimulation
		 * and contracts to generate controlled force and displacement, mimicking biological
		 * muscle behavior for robotic, prosthetic, and automation applications.
		 */
		
		perform action actuate : ControlledActuation {
			in activationCmd : ActivationCommand;
			in deactivationCmd : DeactivationCommand;
			in supplyVoltage = powerSupply.outputVoltage;
			in supplyCurrent = powerSupply.maxCurrent;
			in targetForce : ISQ::ForceValue := 250.0 [SI::N];
			out actualForce : ISQ::ForceValue;
			out actualDisplacement : ISQ::LengthValue;
		}
		
		part polymerFiber : ElectroactivePolymerFiber {
			attribute maxContraction : ContractionLevel = 0.35;
			attribute responseTime : ISQ::TimeValue = 80.0 [SI::s];
			attribute nominalVoltage : ActivationVoltage = 2500.0 [SI::V];
			attribute restLength : ISQ::LengthValue = 100.0 [SI::mm];
		}
		
		part powerSupply : HighVoltagePowerSupply {
			attribute outputVoltage : ActivationVoltage = 2500.0 [SI::V];
			attribute maxCurrent : ActivationCurrent = 1.5 [SI::A];
			attribute efficiency : Real = 0.88;
		}
		
		part controller : MicrocontrollerUnit {
			attribute processingFrequency : ISQ::FrequencyValue = 120.0 [SI::Hz];
			attribute pwmResolution : Real = 12.0;
			perform actuate.applyStimulation;
		}
		
		part forceSensor : ForceSensor {
			attribute sensitivity : Real = 0.01;
			attribute maxForce : ISQ::ForceValue = 500.0 [SI::N];
			perform actuate.measure;
		}
		
		part mechanicalLoad : MechanicalLoad {
			attribute mass : ISQ::MassValue = 0.5 [SI::kg];
			attribute inertia : Real = 0.002;
			perform actuate.generateForce;
		}
		
		port powerInput : PowerPort {
			attribute voltage : ActivationVoltage;
			attribute current : ActivationCurrent;
		}
		
		port controlInput : ControlPort {
			attribute pwmSignal : ActivationVoltage;
			attribute dutyCycle : Real;
		}
		
		port mechanicalOutput : MechanicalPort {
			attribute force : ISQ::ForceValue;
			attribute displacement : ISQ::LengthValue;
			attribute velocity : ISQ::SpeedValue;
		}
		
		port sensorOutput : SensorPort {
			attribute forceReading : ISQ::ForceValue;
			attribute positionReading : ISQ::LengthValue;
		}
		
		connect powerSupply.outputVoltage to powerInput.voltage;
		connect powerSupply.maxCurrent to powerInput.current;
		connect controller.pwmResolution to controlInput.dutyCycle;
		connect actuate.actualForce to mechanicalOutput.force;
		connect actuate.actualDisplacement to mechanicalOutput.displacement;
		connect forceSensor.maxForce to sensorOutput.forceReading;
	}
	
	requirement def PerformanceRequirement {
		attribute requiredForce : ISQ::ForceValue;
		attribute requiredContraction : ContractionLevel;
		attribute requiredResponseTime : ISQ::TimeValue;
		attribute requiredEfficiency : Real;
	}
	
	requirement <'AMS-REQ-001'> forceOutputRequirement : PerformanceRequirement {
		doc /*
		 * The artificial muscle system shall generate a minimum output force of 250 N
		 * when fully activated at nominal operating voltage to support typical load requirements.
		 */
		attribute requiredForce : ISQ::ForceValue = 250.0 [SI::N];
		
		require constraint {
			artificialMuscleSystem.forceSensor.maxForce >= requiredForce
		}
	}
	
	requirement <'AMS-REQ-002'> contractionRangeRequirement : PerformanceRequirement {
		doc /*
		 * The artificial muscle system shall achieve a minimum contraction of 30% of its
		 * resting length to provide sufficient actuation range for practical applications.
		 */
		attribute requiredContraction : ContractionLevel = 0.30;
		
		require constraint {
			artificialMuscleSystem.polymerFiber.maxContraction >= requiredContraction
		}
	}
	
	requirement <'AMS-REQ-003'> responseTimeRequirement : PerformanceRequirement {
		doc /*
		 * The artificial muscle system shall respond to activation commands within 100 ms
		 * to enable dynamic motion control and real-time actuation.
		 */
		attribute requiredResponseTime : ISQ::TimeValue = 100.0 [SI::s];
		
		require constraint {
			artificialMuscleSystem.polymerFiber.responseTime <= requiredResponseTime
		}
	}
	
	requirement <'AMS-REQ-004'> efficiencyRequirement : PerformanceRequirement {
		doc /*
		 * The artificial muscle system shall maintain a minimum energy conversion efficiency
		 * of 85% to minimize power consumption and heat generation during operation.
		 */
		attribute requiredEfficiency : Real = 0.85;
		
		require constraint {
			artificialMuscleSystem.powerSupply.efficiency >= requiredEfficiency
		}
	}
	
	requirement <'AMS-SYS-MISSION'> systemMissionRequirement {
		doc /*
		 * The artificial muscle system shall convert electrical energy into controlled
		 * mechanical actuation by contracting electroactive polymer fibers in response to
		 * electrical stimulation, generating precise force and displacement outputs for
		 * robotic manipulation, prosthetic devices, and industrial automation applications.
		 */
		
		require forceOutputRequirement;
		require contractionRangeRequirement;
		require responseTimeRequirement;
		require efficiencyRequirement;
	}
}
