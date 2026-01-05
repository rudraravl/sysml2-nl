package AutomotiveSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def VehicleSpeed :> ISQ::SpeedValue;
	attribute def EngineRPM :> Real;
	attribute def FuelLevel :> Real;
	attribute def ThrottlePosition :> Real;
	attribute def BrakePressure :> ISQ::PressureValue;
	attribute def SteeringAngle :> Real;
	attribute def TorqueValue :> ISQ::TorqueValue;
	
	item def ThrottleCommand {
		attribute position : ThrottlePosition;
	}
	
	item def BrakeCommand {
		attribute pressure : BrakePressure;
	}
	
	item def SteeringCommand {
		attribute angle : SteeringAngle;
	}
	
	item def FuelCommand {
		attribute fuelFlowRate : ISQ::VolumeFlowRateValue;
	}
	
	item def PowerOutput {
		attribute power : ISQ::PowerValue;
		attribute torque : TorqueValue;
	}
	
	port def ControlInputPort {
		in item throttleReceived : ThrottleCommand;
		in item brakeReceived : BrakeCommand;
		in item steeringReceived : SteeringCommand;
	}
	
	port def SensorOutputPort {
		out item speedSent : VehicleSpeed;
		out item rpmSent : EngineRPM;
		out item fuelLevelSent : FuelLevel;
	}
	
	port def PowertrainPort {
		in item fuelCommandReceived : FuelCommand;
		out item powerSent : PowerOutput;
	}
	
	part def Driver {
		out item throttleCommandSent : ThrottleCommand;
		out item brakeCommandSent : BrakeCommand;
		out item steeringCommandSent : SteeringCommand;
	}
	
	part def Accelerator {
		in item throttleReceived : ThrottleCommand;
		out item throttleProcessed : ThrottleCommand;
	}
	
	part def BrakePedal {
		in item brakeReceived : BrakeCommand;
		out item brakeProcessed : BrakeCommand;
	}
	
	part def SteeringWheel {
		in item steeringReceived : SteeringCommand;
		out item steeringProcessed : SteeringCommand;
	}
	
	part def EngineControlUnit {
		in item throttleInput : ThrottleCommand;
		in item currentSpeed : VehicleSpeed;
		in item currentRPM : EngineRPM;
		out item fuelCommandSent : FuelCommand;
		
		action calculateFuelCommand {
			in throttle : ThrottlePosition;
			in speed : VehicleSpeed;
			in rpm : EngineRPM;
			out fuelCmd : FuelCommand;
			
			first start;
			then action computeFlow {
				in throttlePos = throttle;
				in engineRPM = rpm;
				out flowRate : ISQ::VolumeFlowRateValue;
			}
			then assign fuelCmd.fuelFlowRate := computeFlow.flowRate;
			then done;
		}
	}
	
	part def Engine {
		in item fuelCommandReceived : FuelCommand;
		out item powerGenerated : PowerOutput;
		out item rpmSent : EngineRPM;
		
		attribute currentRPM : EngineRPM;
		attribute maxPower : ISQ::PowerValue;
		attribute fuelConsumptionRate : ISQ::VolumeFlowRateValue;
		
		action def StartEngine;
		action def IncreaseThrottle;
		action def DecreaseThrottle;
		action def ShutDown;
		
		state engineState {
			entry; then off;
			
			state off;
			transition off_to_idling
				first off
				accept StartEngine
				then idling;
			
			state idling;
			transition idling_to_running
				first idling
				accept IncreaseThrottle
				then running;
			transition idling_to_off
				first idling
				accept ShutDown
				then off;
			
			state running;
			transition running_to_idling
				first running
				if currentRPM <= 1000.0
				accept DecreaseThrottle
				then idling;
			transition running_to_off
				first running
				accept ShutDown
				then off;
		}
	}
	
	part def Transmission {
		in item powerInput : PowerOutput;
		out item powerOutput : PowerOutput;
		
		attribute currentGear : Integer;
		attribute gearRatio : Real;
		
		action transferPower {
			in inputPower : PowerOutput;
			out outputPower : PowerOutput;
			
			first start;
			then action applyGearRatio {
				in power = inputPower.power;
				in torque = inputPower.torque;
				in ratio = gearRatio;
				out adjustedTorque : TorqueValue;
			}
			then assign outputPower.torque := applyGearRatio.adjustedTorque;
			then assign outputPower.power := inputPower.power;
			then done;
		}
	}
	
	part def Wheel {
		in item driveForce : ISQ::ForceValue;
		in item brakeForce : ISQ::ForceValue;
		out item rotationalSpeed : ISQ::AngularSpeedValue;
		
		attribute wheelRadius : ISQ::LengthValue;
		attribute wheelMass : ISQ::MassValue;
	}
	
	part def BrakeSystem {
		in item brakeCommandReceived : BrakeCommand;
		out item brakeForceSent : ISQ::ForceValue;
		
		attribute maxBrakeForce : ISQ::ForceValue;
		
		action applyBrakes {
			in brakeCmd : BrakeCommand;
			out brakeForce : ISQ::ForceValue;
			
			first start;
			then decide;
				if brakeCmd.pressure > 0.0 [SI::Pa] then generateForce;
				if brakeCmd.pressure <= 0.0 [SI::Pa] then noForce;
			action generateForce {
				out force : ISQ::ForceValue;
			}
			then assign brakeForce := generateForce.force;
			then done;
			action noForce {
				out force : ISQ::ForceValue;
			}
			then assign brakeForce := 0.0 [SI::N];
			then done;
		}
	}
	
	part def SteeringSystem {
		in item steeringCommandReceived : SteeringCommand;
		out item wheelAngleSent : SteeringAngle;
		
		attribute steeringRatio : Real;
		attribute maxSteeringAngle : SteeringAngle;
	}
	
	part def Speedometer {
		in item wheelSpeed : ISQ::AngularSpeedValue;
		out item vehicleSpeedSent : VehicleSpeed;
		
		action calculateSpeed {
			in wheelAngularSpeed : ISQ::AngularSpeedValue;
			in wheelRadius : ISQ::LengthValue;
			out vehicleSpeed : VehicleSpeed;
			
			first start;
			then action compute {
				in angularSpeed = wheelAngularSpeed;
				in radius = wheelRadius;
				out linearSpeed : VehicleSpeed;
			}
			then assign vehicleSpeed := compute.linearSpeed;
			then done;
		}
	}
	
	part def FuelTank {
		out item fuelLevelSent : FuelLevel;
		
		attribute capacity : ISQ::VolumeValue;
		attribute currentLevel : FuelLevel;
		
		action def ConsumeFuel;
		action def Refuel;
		
		state fuelState {
			entry; then full;
			
			state full;
			transition full_to_normal
				first full
				if currentLevel < 0.9
				accept ConsumeFuel
				then normal;
			
			state normal;
			transition normal_to_low
				first normal
				if currentLevel < 0.2
				accept ConsumeFuel
				then low;
			transition normal_to_full
				first normal
				if currentLevel >= 0.9
				accept Refuel
				then full;
			
			state low;
			transition low_to_normal
				first low
				if currentLevel >= 0.2
				accept Refuel
				then normal;
			transition low_to_empty
				first low
				if currentLevel <= 0.0
				accept ConsumeFuel
				then empty;
			
			state empty;
			transition empty_to_low
				first empty
				accept Refuel
				then low;
		}
	}
	
	part def Automobile {
		attribute vehicleMass : ISQ::MassValue;
		attribute maxSpeed : VehicleSpeed;
		attribute currentSpeed : VehicleSpeed;
		
		part accelerator : Accelerator;
		part brakePedal : BrakePedal;
		part steeringWheel : SteeringWheel;
		part ecu : EngineControlUnit;
		part engine : Engine {
			attribute maxPower = 150.0 [SI::kW];
		}
		part transmission : Transmission {
			attribute currentGear = 1;
			attribute gearRatio = 3.5;
		}
		part frontLeftWheel : Wheel {
			attribute wheelRadius = 0.35 [SI::m];
		}
		part frontRightWheel : Wheel {
			attribute wheelRadius = 0.35 [SI::m];
		}
		part rearLeftWheel : Wheel {
			attribute wheelRadius = 0.35 [SI::m];
		}
		part rearRightWheel : Wheel {
			attribute wheelRadius = 0.35 [SI::m];
		}
		part brakeSystem : BrakeSystem {
			attribute maxBrakeForce = 8000.0 [SI::N];
		}
		part steeringSystem : SteeringSystem {
			attribute steeringRatio = 16.0;
		}
		part speedometer : Speedometer;
		part fuelTank : FuelTank {
			attribute capacity = 60.0 [SI::L];
			attribute currentLevel = 0.8;
		}
		
		connection throttleConnection connect accelerator.throttleProcessed to ecu.throttleInput;
		connection speedFeedback connect speedometer.vehicleSpeedSent to ecu.currentSpeed;
		connection rpmFeedback connect engine.rpmSent to ecu.currentRPM;
		connection fuelCommandConnection connect ecu.fuelCommandSent to engine.fuelCommandReceived;
		connection enginePowerConnection connect engine.powerGenerated to transmission.powerInput;
		connection brakeConnection connect brakePedal.brakeProcessed to brakeSystem.brakeCommandReceived;
		connection brakingFrontLeft connect brakeSystem.brakeForceSent to frontLeftWheel.brakeForce;
		connection brakingFrontRight connect brakeSystem.brakeForceSent to frontRightWheel.brakeForce;
		connection brakingRearLeft connect brakeSystem.brakeForceSent to rearLeftWheel.brakeForce;
		connection brakingRearRight connect brakeSystem.brakeForceSent to rearRightWheel.brakeForce;
		connection steeringConnection connect steeringWheel.steeringProcessed to steeringSystem.steeringCommandReceived;
		connection wheelSpeedConnection connect frontLeftWheel.rotationalSpeed to speedometer.wheelSpeed;
		
		action def IgnitionOn;
		action def EngineRunning;
		action def AcceleratorPressed;
		action def IgnitionOff;
		action def BrakeApplied;
		action def EmergencyStop;
		action def VehicleStopped;
		action def EngineOff;
		
		state vehicleOperationalState {
			entry; then parked;
			
			state parked;
			transition parked_to_starting
				first parked
				accept IgnitionOn
				then starting;
			
			state starting;
			transition starting_to_idling
				first starting
				accept EngineRunning
				then idling;
			
			state idling;
			transition idling_to_driving
				first idling
				accept AcceleratorPressed
				then driving;
			transition idling_to_shuttingDown
				first idling
				accept IgnitionOff
				then shuttingDown;
			
			state driving;
			transition driving_to_idling
				first driving
				if currentSpeed == 0.0 [SI::km/SI::h]
				accept BrakeApplied
				then idling;
			transition driving_to_emergencyBraking
				first driving
				accept EmergencyStop
				then emergencyBraking;
			
			state emergencyBraking;
			transition emergencyBraking_to_parked
				first emergencyBraking
				accept VehicleStopped
				then parked;
			
			state shuttingDown;
			transition shuttingDown_to_parked
				first shuttingDown
				accept EngineOff
				then parked;
		}
		
		perform action transportPassengers[*] ordered;
	}
	
	action def AccelerateVehicle {
		in throttleInput : ThrottlePosition;
		in currentSpeed : VehicleSpeed;
		out newSpeed : VehicleSpeed;
		
		first start;
		then action receiveThrottle {
			in throttle = throttleInput;
		}
		then action computeFuel {
			in throttle = receiveThrottle.throttle;
			out fuelCommand : FuelCommand;
		}
		then action generatePower {
			in fuel = computeFuel.fuelCommand;
			out power : PowerOutput;
		}
		then action applyPower {
			in power = generatePower.power;
			in speed = currentSpeed;
			out acceleratedSpeed : VehicleSpeed;
		}
		then assign newSpeed := applyPower.acceleratedSpeed;
		then done;
	}
	
	action def BrakeVehicle {
		in brakeInput : BrakePressure;
		in currentSpeed : VehicleSpeed;
		out finalSpeed : VehicleSpeed;
		
		first start;
		then action applyBrakes {
			in brakePressure = brakeInput;
			in speed = currentSpeed;
			out deceleratedSpeed : VehicleSpeed;
		}
		then assign finalSpeed := applyBrakes.deceleratedSpeed;
		then done;
	}
	
	action def DriveAutomobile {
		in targetSpeed : VehicleSpeed;
		out actualSpeed : VehicleSpeed;
		
		first start;
		then merge controlLoop;
		then action monitorSpeed {
			out currentSpeed : VehicleSpeed;
		}
		then decide;
			if monitorSpeed.currentSpeed < targetSpeed then accelerate;
			if monitorSpeed.currentSpeed >= targetSpeed then maintain;
		action accelerate : AccelerateVehicle {
			in throttleInput = 0.7;
			in currentSpeed = monitorSpeed.currentSpeed;
			out newSpeed;
		}
		then controlLoop;
		action maintain {
			out maintainedSpeed : VehicleSpeed;
		}
		then assign actualSpeed := monitorSpeed.currentSpeed;
		then done;
	}
	
	part automobile : Automobile {
		attribute vehicleMass = 1500.0 [SI::kg];
		attribute maxSpeed = 200.0 [SI::km/SI::h];
		perform action transportPassengers[*] references driveOperation;
	}
	
	part driver : Driver;
	
	occurrence def AutomotiveOperation {
		ref part :>> driver;
		ref part vehicle :>> automobile;
		
		message throttleMessage of ThrottleCommand
			from driver.throttleCommandSent to vehicle.accelerator.throttleReceived;
		then message brakeMessage of BrakeCommand
			from driver.brakeCommandSent to vehicle.brakePedal.brakeReceived;
		then message steeringMessage of SteeringCommand
			from driver.steeringCommandSent to vehicle.steeringWheel.steeringReceived;
		then message speedSensorMessage of VehicleSpeed
			from vehicle.speedometer.vehicleSpeedSent to vehicle.ecu.currentSpeed;
		then message fuelLevelMessage of FuelLevel
			from vehicle.fuelTank.fuelLevelSent to driver;
	}
	
	occurrence driveOperation : AutomotiveOperation;
	
	requirement def SafetyRequirement;
	requirement def PerformanceRequirement;
	requirement def EfficiencyRequirement;
	
	requirement <'AUTO-REQ-001'> vehicleMassRequirement : PerformanceRequirement {
		doc /* The total mass of the automobile shall not exceed 2000 kg to ensure adequate performance and fuel efficiency. */
		
		subject vehicle : Automobile;
		
		require constraint {
			vehicle.vehicleMass <= 2000.0 [SI::kg]
		}
	}
	
	requirement <'AUTO-REQ-002'> maxSpeedRequirement : PerformanceRequirement {
		doc /* The automobile shall achieve a maximum speed of at least 180 km/h on level road surface. */
		
		subject vehicle : Automobile;
		
		require constraint {
			vehicle.maxSpeed >= 180.0 [SI::km/SI::h]
		}
	}
	
	requirement <'AUTO-REQ-003'> brakingRequirement : SafetyRequirement {
		doc /* The brake system shall provide sufficient force to decelerate the vehicle safely from maximum speed. */
		
		subject vehicle : Automobile;
		
		require constraint {
			vehicle.brakeSystem.maxBrakeForce >= 8000.0 [SI::N]
		}
	}
	
	requirement <'AUTO-REQ-004'> fuelCapacityRequirement : EfficiencyRequirement {
		doc /* The fuel tank shall have sufficient capacity to provide a minimum range of 500 km under normal driving conditions. */
		
		subject vehicle : Automobile;
		
		require constraint {
			vehicle.fuelTank.capacity >= 50.0 [SI::L]
		}
	}
	
	requirement transportationMission {
		doc /* The automobile shall safely and efficiently transport passengers and cargo from origin to destination under normal operating conditions. */
		
		assume constraint driverPresent {
			doc /* A qualified driver must be present to operate the vehicle. */
		}
		
		assume constraint fuelAvailable {
			doc /* Sufficient fuel must be available in the tank for the intended journey. */
		}
		
		assume constraint roadConditions {
			doc /* Road conditions must be suitable for vehicle operation. */
		}
		
		require vehicleMassRequirement;
		require maxSpeedRequirement;
		require brakingRequirement;
		require fuelCapacityRequirement;
	}
}
