package 'Paddle Wheel System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def WaterFlowRate :> ISQ::VolumeFlowRateValue;
	attribute def RotationalSpeed :> ISQ::AngularVelocityValue;
	attribute def WaterDepth :> ISQ::LengthValue;
	attribute def PaddleAngle :> ISQ::PlaneAngleValue;
	attribute def ImmersionDepth :> ISQ::LengthValue;
	attribute def OperatingCommand;
	attribute def ShutdownCommand;
	
	item def WaterFlow {
		attribute flowRate : WaterFlowRate;
		attribute depth : WaterDepth;
		attribute velocity : ISQ::SpeedValue;
		attribute pressure : ISQ::PressureValue;
	}
	
	item def MechanicalPower {
		attribute torque : ISQ::TorqueValue;
		attribute rotationalSpeed : RotationalSpeed;
		attribute power : ISQ::PowerValue;
	}
	
	port def WaterIntakePort {
		in item waterIn : WaterFlow;
	}
	
	port def WaterDischargePort {
		out item waterOut : WaterFlow;
	}
	
	port def MechanicalOutputPort {
		out item mechanicalOut : MechanicalPower;
	}
	
	port def ControlPort {
		in attribute startCmd : OperatingCommand;
		in attribute stopCmd : ShutdownCommand;
	}
	
	part def Paddle {
		attribute length : ISQ::LengthValue;
		attribute width : ISQ::LengthValue;
		attribute angle : PaddleAngle;
		attribute immersionDepth : ImmersionDepth;
		attribute surfaceArea : ISQ::AreaValue;
	}
	
	part def Axle {
		attribute diameter : ISQ::LengthValue;
		attribute length : ISQ::LengthValue;
		attribute material : String;
		attribute maxTorque : ISQ::TorqueValue;
	}
	
	part def Hub {
		attribute diameter : ISQ::LengthValue;
		attribute numberOfPaddleSlots : Integer;
		attribute thickness : ISQ::LengthValue;
	}
	
	part def SupportFrame {
		attribute height : ISQ::LengthValue;
		attribute width : ISQ::LengthValue;
		attribute material : String;
		attribute maxLoad : ISQ::ForceValue;
	}
	
	part def BearingAssembly {
		attribute bearingType : String;
		attribute maxSpeed : RotationalSpeed;
		attribute loadCapacity : ISQ::ForceValue;
	}
	
	part def PaddleWheel {
		attribute wheelDiameter : ISQ::LengthValue;
		attribute numberOfPaddles : Integer;
		attribute currentRotationalSpeed : RotationalSpeed;
		attribute currentTorque : ISQ::TorqueValue;
		attribute efficiency : Real;
		
		port waterIntake : WaterIntakePort;
		port waterDischarge : WaterDischargePort;
		port powerOutput : MechanicalOutputPort;
		port control : ControlPort;
		
		part axle : Axle {
			attribute diameter = 0.35 [SI::m];
			attribute length = 3.0 [SI::m];
			attribute material = "carbon steel";
			attribute maxTorque = 5000.0 [SI::N*SI::m];
		}
		
		part hub : Hub {
			attribute diameter = 1.0 [SI::m];
			attribute numberOfPaddleSlots = numberOfPaddles;
			attribute thickness = 0.15 [SI::m];
		}
		
		part paddles : Paddle[numberOfPaddles] {
			attribute length = (wheelDiameter - hub.diameter) / 2.0;
			attribute width = axle.length * 0.75;
			attribute angle = 15.0 [SI::'°'];
			attribute surfaceArea = length * width;
		}
		
		part supportFrame : SupportFrame {
			attribute height = wheelDiameter * 1.3;
			attribute width = axle.length * 1.2;
			attribute material = "reinforced structural steel";
			attribute maxLoad = 50000.0 [SI::N];
		}
		
		part bearings : BearingAssembly[2] {
			attribute bearingType = "heavy duty roller bearing";
			attribute maxSpeed = 100.0 [SI::rad/SI::s];
			attribute loadCapacity = 25000.0 [SI::N];
		}
	}
	
	action def CaptureWaterFlow {
		in incomingWater : WaterFlow;
		in paddleArea : ISQ::AreaValue;
		out capturedWater : WaterFlow;
		out hydrodynamicForce : ISQ::ForceValue;
	}
	
	action def ConvertFlowToRotation {
		in hydrodynamicForce : ISQ::ForceValue;
		in wheelRadius : ISQ::LengthValue;
		in numberOfPaddles : Integer;
		out generatedTorque : ISQ::TorqueValue;
		out rotationalSpeed : RotationalSpeed;
	}
	
	action def TransmitMechanicalPower {
		in torque : ISQ::TorqueValue;
		in speed : RotationalSpeed;
		out mechanicalPower : MechanicalPower;
	}
	
	action def DischargeProcessedWater {
		in processedWater : WaterFlow;
		out dischargedWater : WaterFlow;
	}
	
	action def MonitorOperatingConditions {
		in currentSpeed : RotationalSpeed;
		in currentTorque : ISQ::TorqueValue;
		in waterFlowRate : WaterFlowRate;
		out operatingStatus : String;
		out safetyAlert : Boolean;
	}
	
	action def OperatePaddleWheelSystem {
		in incomingWaterFlow : WaterFlow;
		in wheelConfiguration : PaddleWheel;
		out outputPower : MechanicalPower;
		out dischargedWater : WaterFlow;
		
		first start;
		then action captureWater : CaptureWaterFlow {
			in incomingWater = incomingWaterFlow;
			in paddleArea = wheelConfiguration.paddles.surfaceArea;
			out capturedWater;
			out hydrodynamicForce;
		}
		then action convertToRotation : ConvertFlowToRotation {
			in hydrodynamicForce = captureWater.hydrodynamicForce;
			in wheelRadius = wheelConfiguration.wheelDiameter / 2.0;
			in numberOfPaddles = wheelConfiguration.numberOfPaddles;
			out generatedTorque;
			out rotationalSpeed;
		}
		then merge continuousOperation;
		action transmitPower : TransmitMechanicalPower {
			in torque = convertToRotation.generatedTorque;
			in speed = convertToRotation.rotationalSpeed;
			out mechanicalPower;
		}
		then action monitorConditions : MonitorOperatingConditions {
			in currentSpeed = convertToRotation.rotationalSpeed;
			in currentTorque = convertToRotation.generatedTorque;
			in waterFlowRate = incomingWaterFlow.flowRate;
			out operatingStatus;
			out safetyAlert;
		}
		then action dischargeWater : DischargeProcessedWater {
			in processedWater = captureWater.capturedWater;
			out dischargedWater;
		}
		then assign outputPower := transmitPower.mechanicalPower;
		then decide;
			if monitorConditions.safetyAlert then emergencyStop;
			if not monitorConditions.safetyAlert then continuousOperation;
		action emergencyStop;
		then done;
	}
	
	state def PaddleWheelOperationalStates {
		entry; then idle;
		
		state idle;
		
		transition idle_to_starting
			first idle
			accept startSignal : OperatingCommand
			then starting;
		
		state starting {
			state initialAcceleration;
			state rampUp;
			
			transition initial_to_ramp
				first initialAcceleration
				then rampUp;
		}
		
		transition starting_to_operating
			first starting
			then operating;
		
		state operating {
			state normalOperation;
			
			state highLoad;
			
			state lowLoad;
			
			transition normal_to_high
				first normalOperation
				then highLoad;
			
			transition high_to_normal
				first highLoad
				then normalOperation;
			
			transition normal_to_low
				first normalOperation
				then lowLoad;
			
			transition low_to_normal
				first lowLoad
				then normalOperation;
		}
		
		transition operating_to_stopping
			first operating
			accept stopSignal : ShutdownCommand
			then stopping;
		
		state stopping {
			state coastDown;
			state brakingApplied;
			
			transition coast_to_brake
				first coastDown
				then brakingApplied;
		}
		
		transition stopping_to_idle
			first stopping
			then idle;
		
		state emergency;
		
		transition any_to_emergency
			first operating
			then emergency;
		
		transition emergency_to_idle
			first emergency
			accept resetCommand : OperatingCommand
			then idle;
	}
	
	part paddleWheelSystem : PaddleWheel {
		attribute wheelDiameter = 5.0 [SI::m];
		attribute numberOfPaddles = 16;
		attribute efficiency = 0.70;
		
		perform action operateSystem : OperatePaddleWheelSystem {
			in incomingWaterFlow;
			in wheelConfiguration = paddleWheelSystem;
			out outputPower;
			out dischargedWater;
		}
		
		exhibit state operationalStates : PaddleWheelOperationalStates;
	}
	
	requirement def <'PWS-REQ-001'> PrimaryFunctionRequirement {
		doc /* The paddle wheel system shall convert the kinetic energy of flowing water 
		       into continuous rotational mechanical power by capturing water flow with 
		       radially-mounted paddles that rotate a central axle. */
		
		subject system : PaddleWheel;
		
		require constraint powerGeneration {
			system.powerOutput.mechanicalOut.power > 0.0 [SI::W]
		}
		
		require constraint continuousRotation {
			system.powerOutput.mechanicalOut.rotationalSpeed > 0.0 [SI::rad/SI::s]
		}
		
		require constraint torqueTransmission {
			system.powerOutput.mechanicalOut.torque > 0.0 [SI::N*SI::m]
		}
	}
	
	requirement def <'PWS-REQ-002'> EfficiencyRequirement {
		doc /* The paddle wheel system shall maintain a minimum mechanical efficiency 
		       of 65% under normal operating conditions with nominal water flow. */
		
		subject system : PaddleWheel;
		
		require constraint minimumEfficiency {
			system.efficiency >= 0.65
		}
	}
	
	requirement def <'PWS-REQ-003'> StructuralIntegrityRequirement {
		doc /* The paddle wheel structure shall withstand continuous operation under 
		       maximum design load without structural failure or excessive deformation. */
		
		subject system : PaddleWheel;
		
		require constraint axleStrength {
			system.axle.maxTorque >= 5000.0 [SI::N*SI::m]
		}
		
		require constraint frameCapacity {
			system.supportFrame.maxLoad >= 50000.0 [SI::N]
		}
		
		require constraint bearingRating {
			system.bearings.loadCapacity >= 25000.0 [SI::N]
		}
	}
	
	requirement def <'PWS-REQ-004'> OperationalSafetyRequirement {
		doc /* The paddle wheel system shall include safety mechanisms to prevent 
		       overspeed and overload conditions that could damage the system. */
		
		subject system : PaddleWheel;
		
		require constraint speedLimit {
			system.currentRotationalSpeed <= 80.0 [SI::rad/SI::s]
		}
		
		require constraint torqueLimit {
			system.currentTorque <= 5500.0 [SI::N*SI::m]
		}
	}
	
	requirement def <'PWS-REQ-005'> WaterFlowRequirement {
		doc /* The paddle wheel system shall operate effectively with water flow rates 
		       between minimum and maximum design values. */
		
		subject system : PaddleWheel;
		
		assume constraint minimumFlow {
			system.waterIntake.waterIn.flowRate >= 0.5 [SI::m^3/SI::s]
		}
		
		assume constraint maximumFlow {
			system.waterIntake.waterIn.flowRate <= 10.0 [SI::m^3/SI::s]
		}
	}
	
	requirement <'PWS-MISSION'> paddleWheelMissionRequirement {
		doc /* The paddle wheel system shall reliably convert flowing water energy into 
		       continuous rotational mechanical power for propulsion, power generation, 
		       or industrial process applications while maintaining structural integrity 
		       and operational safety. */
		
		assume WaterFlowRequirement;
		require PrimaryFunctionRequirement;
		require EfficiencyRequirement;
		require StructuralIntegrityRequirement;
		require OperationalSafetyRequirement;
	}
}
