package RotorSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def RotorStatus {
		attribute rotationalSpeed : AngularVelocityValue;
		attribute temperature : ThermodynamicTemperatureValue;
		attribute vibrationLevel : Real;
	}
	
	item def TorqueCommand {
		attribute commandedTorque : TorqueValue;
		attribute timestamp : Real;
	}
	
	item def PowerInput {
		attribute voltage : ElectricPotentialValue;
		attribute current : ElectricCurrentValue;
	}
	
	item def StopCommand;
	
	port def RotorControlPort {
		in item torqueCmd : TorqueCommand;
		out item status : RotorStatus;
	}
	
	port def PowerPort {
		in item powerIn : PowerInput;
	}
	
	port def MechanicalPort {
		out torque : TorqueValue;
		out angularVelocity : AngularVelocityValue;
	}
	
	part def Motor {
		port powerPort : PowerPort;
		port mechanicalOut : MechanicalPort;
		attribute efficiency : Real;
		
		action def ConvertPowerToTorque {
			in power : PowerValue;
			in efficiency : Real;
			out torque : TorqueValue;
		}
	}
	
	part def Rotor {
		attribute mass : MassValue;
		attribute radius : LengthValue;
		attribute momentOfInertia : Real;
		attribute currentSpeed : AngularVelocityValue;
		
		port controlPort : RotorControlPort;
		port mechanicalIn : MechanicalPort;
		
		action def AccelerateRotor {
			in appliedTorque : TorqueValue;
			in inertia : Real;
			in currentAngularVelocity : AngularVelocityValue;
			in deltaTime : TimeValue;
			out newAngularVelocity : AngularVelocityValue;
		}
		
		action def MonitorRotorHealth {
			in speed : AngularVelocityValue;
			out temp : ThermodynamicTemperatureValue;
			out vibration : Real;
		}
	}
	
	part def RotorController {
		port commandPort : RotorControlPort;
		
		attribute targetSpeed : AngularVelocityValue;
		attribute maxTorque : TorqueValue;
		
		action def CalculateTorqueCommand {
			in targetSpeed : AngularVelocityValue;
			in currentSpeed : AngularVelocityValue;
			in maxTorque : TorqueValue;
			out torqueCommand : TorqueValue;
		}
	}
	
	part def Sensor {
		attribute measurementAccuracy : Real;
		
		action def MeasureSpeed {
			in actualSpeed : AngularVelocityValue;
			out measuredSpeed : AngularVelocityValue;
		}
	}
	
	part rotorSystem {
		part motor : Motor {
			attribute :>> efficiency = 0.92;
		}
		
		part rotor : Rotor {
			attribute :>> mass = 15.0[kg];
			attribute :>> radius = 0.25[m];
			attribute :>> momentOfInertia = 0.46875;
			attribute :>> currentSpeed = 0.0[rad/s];
		}
		
		part controller : RotorController {
			attribute :>> targetSpeed = 314.159[rad/s];
			attribute :>> maxTorque = 50.0[N*m];
		}
		
		part speedSensor : Sensor {
			attribute :>> measurementAccuracy = 0.99;
		}
		
		connection motorToRotor connect motor.mechanicalOut to rotor.mechanicalIn;
		connection controllerToRotor connect controller.commandPort to rotor.controlPort;
		
		perform action operateRotor : RotorOperation;
	}
	
	action def RotorOperation {
		first start;
		then merge controlLoop;
		
		action measureCurrentSpeed : Sensor::MeasureSpeed {
			in actualSpeed;
			out measuredSpeed;
		}
		
		then action computeTorque : RotorController::CalculateTorqueCommand {
			in targetSpeed;
			in currentSpeed = measureCurrentSpeed.measuredSpeed;
			in maxTorque;
			out torqueCommand;
		}
		
		then action convertPower : Motor::ConvertPowerToTorque {
			in power;
			in efficiency;
			out torque;
		}
		
		then action accelerate : Rotor::AccelerateRotor {
			in appliedTorque = convertPower.torque;
			in inertia;
			in currentAngularVelocity;
			in deltaTime;
			out newAngularVelocity;
		}
		
		then action monitor : Rotor::MonitorRotorHealth {
			in speed = accelerate.newAngularVelocity;
			out temp;
			out vibration;
		}
		
		then decide;
			if monitor.vibration < 5.0 then controlLoop;
			if monitor.vibration >= 5.0 then shutdown;
		
		action shutdown;
		
		then done;
	}
	
	state def RotorStateMachine {
		in attribute initialSpeed : AngularVelocityValue;
		in attribute targetSpeedRef : AngularVelocityValue;
		attribute stateSpeed : AngularVelocityValue;
		
		entry; then idle;
		
		state idle {
			entry assign stateSpeed := 0.0[rad/s];
		}
		
		transition idle_to_starting
			first idle
			accept torqueCmd : TorqueCommand
			then starting;
		
		state starting {
			entry; then accelerating;
			
			state accelerating;
			
			transition accel_to_operating
				first accelerating
				if stateSpeed >= targetSpeedRef * 0.95
				then operating;
		}
		
		state operating {
			do action maintainSpeed : RotorOperation;
		}
		
		transition operating_to_stopping
			first operating
			accept stopCmd : StopCommand
			then stopping;
		
		state stopping {
			entry assign stateSpeed := 0.0[rad/s];
		}
		
		transition stopping_to_idle
			first stopping
			if stateSpeed <= 0.1[rad/s]
			then idle;
	}
	
	requirement def RotorPerformanceRequirement {
		doc /* The rotor system shall achieve and maintain specified rotational speed. */
		
		subject rotorSubject : Rotor;
		
		require constraint speedAccuracy {
			doc /* Rotor speed shall be within 2% of target speed during steady-state operation. */
		}
		
		require constraint accelerationTime {
			doc /* Rotor shall reach 95% of target speed within 5 seconds from start. */
		}
	}
	
	requirement def RotorSafetyRequirement {
		doc /* The rotor system shall operate safely within defined limits. */
		
		subject rotorSubject : Rotor;
		
		require constraint vibrationLimit {
			doc /* Rotor vibration level shall not exceed 5.0 units during operation. */
		}
		
		require constraint temperatureLimit {
			doc /* Rotor temperature shall not exceed 373.15 K during continuous operation. */
		}
		
		require constraint emergencyShutdown {
			doc /* System shall initiate emergency shutdown if vibration exceeds safe limits. */
		}
	}
	
	requirement <'ROTOR-001'> rotorSystemRequirement : RotorPerformanceRequirement {
		subject rotorSubject = rotorSystem.rotor;
		
		assume constraint powerAvailable {
			doc /* Sufficient electrical power is available to motor. */
		}
		
		require speedAccuracy;
		require accelerationTime;
	}
	
	requirement <'ROTOR-002'> rotorSafetyRequirement : RotorSafetyRequirement {
		subject rotorSubject = rotorSystem.rotor;
		
		require vibrationLimit;
		require temperatureLimit;
		require emergencyShutdown;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import RotorSystem::*;

    part testSubject : Motor {
        exhibit state sm : RotorStateMachine;
    }

    action orchestrator {
        action measureCurrentSpeedProbe : Sensor {
            // TODO(human): unsupported input type for actualSpeed: unknown (missing declared type)
        }
        first measureCurrentSpeedProbe;
    }
}
