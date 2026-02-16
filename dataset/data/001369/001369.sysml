package 'Biorobotics System' {
	private import ISQ::*;
	private import ScalarValues::*;
	
	attribute def NeuralSignal;
	attribute def MotorCommand;
	attribute def SensorFeedback;
	attribute def SafetyStatus;
	
	item def BioelectricData {
		attribute amplitude : ElectricPotentialValue;
		attribute frequency : FrequencyValue;
		attribute timestamp : TimeValue;
	}
	
	item def ProprioceptiveData {
		attribute jointAngle : DimensionOneValue;
		attribute jointVelocity : AngularVelocityValue;
		attribute appliedForce : ForceValue;
	}
	
	port def NeuralInterfacePort {
		out bioSignal : BioelectricData;
		in stimulation : ElectricPotentialValue;
	}
	
	port def ActuatorPort {
		in command : MotorCommand;
		out feedback : ProprioceptiveData;
	}
	
	port def PowerPort {
		in voltage : ElectricPotentialValue;
		in current : ElectricCurrentValue;
	}
	
	part def NeuralSensor {
		port neuralOut : NeuralInterfacePort;
		port power : PowerPort;
		attribute samplingRate : FrequencyValue = 1000.0;
		attribute signalGain : Real = 100.0;
		
		action def AcquireNeuralSignal {
			out bioData : BioelectricData;
		}
	}
	
	part def SignalProcessor {
		port neuralIn : NeuralInterfacePort;
		port power : PowerPort;
		attribute processingLatency : TimeValue = 0.005;
		
		action def FilterSignal {
			in rawSignal : BioelectricData;
			out filteredSignal : BioelectricData;
		}
		
		action def ExtractIntent {
			in filteredSignal : BioelectricData;
			out motorIntent : MotorCommand;
		}
	}
	
	part def ControlUnit {
		port power : PowerPort;
		attribute controlFrequency : FrequencyValue = 200.0;
		
		state def ControlStateMachine {
			entry; then Initialization;
			state Initialization;
			accept at Initialization then Standby;
			state Standby;
			accept at Standby then ActiveControl;
			state ActiveControl;
			accept at ActiveControl then SafetyMode;
			state SafetyMode;
			accept at SafetyMode then Standby;
			accept at ActiveControl then Standby;
			accept at Standby then Shutdown;
			state Shutdown;
		}
		
		action def ComputeControl {
			in motorIntent : MotorCommand;
			in sensorFeedback : ProprioceptiveData;
			out actuatorCommand : MotorCommand;
		}
	}
	
	part def BionicActuator {
		port actuatorPort : ActuatorPort;
		port power : PowerPort;
		attribute maxTorque : TorqueValue = 50.0;
		attribute maxVelocity : AngularVelocityValue = 3.14159;
		attribute responseTime : TimeValue = 0.010;
		
		action def GenerateTorque {
			in command : MotorCommand;
			out torque : TorqueValue;
		}
		
		action def MeasurePosition {
			out position : ProprioceptiveData;
		}
	}
	
	part def PowerManagement {
		port powerOut : PowerPort[*];
		attribute batteryCapacity : Real = 5000.0;
		attribute outputVoltage : ElectricPotentialValue = 24.0;
		attribute remainingCharge : Real = 1.0;
	}
	
	part def SafetyMonitor {
		port power : PowerPort;
		attribute maxForceThreshold : ForceValue = 100.0;
		attribute maxVelocityThreshold : AngularVelocityValue = 3.49066;
		
		action def MonitorSafety {
			in feedback : ProprioceptiveData;
			out status : SafetyStatus;
		}
	}
	
	requirement def FunctionalRequirement;
	requirement def PerformanceRequirement;
	requirement def SafetyRequirement;
	
	requirement <'FR-1'> neuralControlCapability : FunctionalRequirement {
		doc /* The system shall translate neural signals into coordinated limb movements 
		       to restore motor function for individuals with limb loss or paralysis. */
	}
	
	requirement <'PR-1'> responseLatency : PerformanceRequirement {
		doc /* The end-to-end latency from neural signal acquisition to actuator response 
		       shall not exceed 50 milliseconds. */
		subject bioroboticProsthesis;
	}
	
	requirement <'PR-2'> torqueCapability : PerformanceRequirement {
		doc /* Each actuator shall provide a minimum peak torque of 50 N·m 
		       to enable functional grasping and manipulation tasks. */
		subject bioroboticProsthesis.actuator;
	}
	
	requirement <'SR-1'> forceLimiting : SafetyRequirement {
		doc /* The system shall limit applied forces to below 100 N to prevent 
		       injury to the user or damage to objects. */
		subject bioroboticProsthesis.safetyMonitor;
	}
	
	action def NeurallyControlledMovement {
		in deltaT : TimeValue;
		out movementHistory : ProprioceptiveData[*] := ( );
		
		private attribute currentPosition : ProprioceptiveData;
		
		first start;
		then merge controlLoop;
		
		then action acquireSignal : NeuralSensor::AcquireNeuralSignal {
			out bioData;
		}
		
		then action filterSignal : SignalProcessor::FilterSignal {
			in rawSignal = acquireSignal.bioData;
			out filteredSignal;
		}
		
		then action extractIntent : SignalProcessor::ExtractIntent {
			in filteredSignal = filterSignal.filteredSignal;
			out motorIntent;
		}
		
		then action computeControl : ControlUnit::ComputeControl {
			in motorIntent = extractIntent.motorIntent;
			in sensorFeedback = currentPosition;
			out actuatorCommand;
		}
		
		then action generateTorque : BionicActuator::GenerateTorque {
			in command = computeControl.actuatorCommand;
			out torque;
		}
		
		then action measurePosition : BionicActuator::MeasurePosition {
			out position;
		}
		
		then action monitorSafety : SafetyMonitor::MonitorSafety {
			in feedback = measurePosition.position;
			out status;
		}
		
		then assign currentPosition := measurePosition.position;
		then assign movementHistory := movementHistory->including(currentPosition);
		then controlLoop;
	}
	
	part bioroboticProsthesis {
		doc /* A neurally-controlled bionic limb system that interprets bioelectric signals 
		       from residual nerves or muscles to command robotic actuators, providing 
		       intuitive motor control and proprioceptive feedback to restore natural 
		       limb function for amputees or paralyzed individuals. */
		
		part neuralSensor : NeuralSensor;
		part signalProcessor : SignalProcessor;
		part controller : ControlUnit;
		part actuator : BionicActuator[5];
		part powerSystem : PowerManagement;
		part safetyMonitor : SafetyMonitor;
		
		connect neuralSensor.neuralOut to signalProcessor.neuralIn;
		
		connect powerSystem.powerOut[1] to neuralSensor.power;
		connect powerSystem.powerOut[2] to signalProcessor.power;
		connect powerSystem.powerOut[3] to controller.power;
		connect powerSystem.powerOut[4] to safetyMonitor.power;
		
		perform action neuralControl[*] ordered : NeurallyControlledMovement {
			in deltaT = 0.005;
			out movementHistory;
		}
		
		part neuralSensor {
			perform neuralControl.acquireSignal;
		}
		
		part signalProcessor {
			perform neuralControl.filterSignal;
			perform neuralControl.extractIntent;
		}
		
		part controller {
			perform neuralControl.computeControl;
		}
		
		part actuator {
			perform neuralControl.generateTorque;
			perform neuralControl.measurePosition;
		}
		
		part safetyMonitor {
			perform neuralControl.monitorSafety;
		}
		
		satisfy neuralControlCapability;
		satisfy responseLatency;
		satisfy torqueCapability;
		satisfy forceLimiting;
	}
}
