package 'Wind Generator System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def WindSpeed :> ISQ::SpeedValue;
	attribute def RotationalSpeed :> ISQ::AngularVelocityValue;
	attribute def ElectricalPower :> ISQ::PowerValue;
	attribute def MechanicalTorque :> ISQ::TorqueValue;
	attribute def BladeAngle :> ISQ::PlaneAngleValue;
	attribute def WindDirection :> ISQ::PlaneAngleValue;
	attribute def Voltage :> ISQ::ElectricPotentialValue;
	attribute def Current :> ISQ::ElectricCurrentValue;
	
	attribute def StartCommand;
	attribute def StopCommand;
	attribute def EmergencyStop;
	
	enum def OperationalState {
		enum idle;
		enum starting;
		enum generating;
		enum stopping;
		enum emergency;
	}
	
	port def WindInputPort {
		in windSpeed : WindSpeed;
		in windDirection : WindDirection;
	}
	
	port def PowerOutputPort {
		out power : ElectricalPower;
		out voltage : Voltage;
		out current : Current;
	}
	
	port def MechanicalPort {
		out torque : MechanicalTorque;
		out rotationalSpeed : RotationalSpeed;
	}
	
	part def RotorBlade {
		attribute bladeLength : ISQ::LengthValue;
		attribute bladeMass : ISQ::MassValue;
		attribute pitchAngle : BladeAngle;
		attribute aerodynamicEfficiency : Real;
	}
	
	part def RotorHub {
		attribute hubDiameter : ISQ::LengthValue;
		attribute hubMass : ISQ::MassValue;
		part blades : RotorBlade[3];
		port mechanicalOutput : MechanicalPort;
	}
	
	part def Gearbox {
		attribute gearRatio : Real;
		attribute efficiency : Real;
		port mechanicalInput : MechanicalPort;
		port mechanicalOutput : MechanicalPort;
	}
	
	part def Generator {
		attribute ratedPower : ElectricalPower;
		attribute efficiency : Real;
		attribute nominalVoltage : Voltage;
		port mechanicalInput : MechanicalPort;
		port electricalOutput : PowerOutputPort;
	}
	
	part def YawSystem {
		attribute currentYawAngle : ISQ::PlaneAngleValue;
		attribute yawSpeed : ISQ::AngularVelocityValue;
		attribute yawMotorPower : ISQ::PowerValue;
	}
	
	part def BrakeSystem {
		attribute brakeTorque : MechanicalTorque;
		attribute brakeEngaged : Boolean;
	}
	
	part def Nacelle {
		attribute nacelleMass : ISQ::MassValue;
		part gearbox : Gearbox;
		part generator : Generator;
		part yawSystem : YawSystem;
		part brakeSystem : BrakeSystem;
	}
	
	part def Tower {
		attribute towerHeight : ISQ::LengthValue;
		attribute towerMass : ISQ::MassValue;
		attribute towerDiameter : ISQ::LengthValue;
	}
	
	part def ControlSystem {
		attribute cutInWindSpeed : WindSpeed;
		attribute ratedWindSpeed : WindSpeed;
		attribute cutOutWindSpeed : WindSpeed;
		attribute targetPower : ElectricalPower;
		attribute currentState : OperationalState;
	}
	
	action def CaptureWindEnergy {
		in windSpeed : WindSpeed;
		in windDirection : WindDirection;
		in bladeAngle : BladeAngle;
		in sweptArea : ISQ::AreaValue;
		in efficiency : Real;
		out aerodynamicTorque : MechanicalTorque;
		out rotorSpeed : RotationalSpeed;
	}
	
	action def TransformTorque {
		in inputTorque : MechanicalTorque;
		in inputSpeed : RotationalSpeed;
		in gearRatio : Real;
		in efficiency : Real;
		out outputTorque : MechanicalTorque;
		out outputSpeed : RotationalSpeed;
	}
	
	action def ConvertToElectricity {
		in mechanicalTorque : MechanicalTorque;
		in rotorSpeed : RotationalSpeed;
		in generatorEfficiency : Real;
		out electricalPower : ElectricalPower;
		out voltage : Voltage;
		out current : Current;
	}
	
	action def AdjustBladePitch {
		in currentWindSpeed : WindSpeed;
		in currentPower : ElectricalPower;
		in targetPower : ElectricalPower;
		in currentPitch : BladeAngle;
		out newPitch : BladeAngle;
	}
	
	action def AlignWithWind {
		in windDirection : WindDirection;
		in currentYawAngle : ISQ::PlaneAngleValue;
		out targetYawAngle : ISQ::PlaneAngleValue;
	}
	
	action def MonitorConditions {
		in windSpeed : WindSpeed;
		in cutInSpeed : WindSpeed;
		in cutOutSpeed : WindSpeed;
		out windSufficient : Boolean;
		out windExcessive : Boolean;
	}
	
	action def GenerateElectricalPower {
		in windSpeed : WindSpeed;
		in windDirection : WindDirection;
		in cutInSpeed : WindSpeed;
		in cutOutSpeed : WindSpeed;
		in targetPower : ElectricalPower;
		out deliveredPower : ElectricalPower;
		
		first start;
		then merge checkWind;
		
		then action monitor : MonitorConditions {
			in windSpeed = GenerateElectricalPower::windSpeed;
			in cutInSpeed = GenerateElectricalPower::cutInSpeed;
			in cutOutSpeed = GenerateElectricalPower::cutOutSpeed;
			out windSufficient;
			out windExcessive;
		}
		
		then decide;
			if monitor.windExcessive then emergencyAction;
			if !monitor.windSufficient then idleAction;
			if monitor.windSufficient & !monitor.windExcessive then activeGeneration;
		
		action activeGeneration {
			first action alignNacelle : AlignWithWind {
				in windDirection = GenerateElectricalPower::windDirection;
				in currentYawAngle;
				out targetYawAngle;
			}
			
			then action captureWind : CaptureWindEnergy {
				in windSpeed = GenerateElectricalPower::windSpeed;
				in windDirection = GenerateElectricalPower::windDirection;
				in bladeAngle;
				in sweptArea;
				in efficiency;
				out aerodynamicTorque;
				out rotorSpeed;
			}
			
			then action transformPower : TransformTorque {
				in inputTorque = captureWind.aerodynamicTorque;
				in inputSpeed = captureWind.rotorSpeed;
				in gearRatio;
				in efficiency;
				out outputTorque;
				out outputSpeed;
			}
			
			then action generatePower : ConvertToElectricity {
				in mechanicalTorque = transformPower.outputTorque;
				in rotorSpeed = transformPower.outputSpeed;
				in generatorEfficiency;
				out electricalPower;
				out voltage;
				out current;
			}
			
			then action adjustPitch : AdjustBladePitch {
				in currentWindSpeed = GenerateElectricalPower::windSpeed;
				in currentPower = generatePower.electricalPower;
				in targetPower = GenerateElectricalPower::targetPower;
				in currentPitch;
				out newPitch;
			}
			
			then assign deliveredPower := generatePower.electricalPower;
		}
		then checkWind;
		
		action idleAction {
			then assign deliveredPower := 0.0 [SI::W];
		}
		then checkWind;
		
		action emergencyAction {
			then assign deliveredPower := 0.0 [SI::W];
		}
		then done;
	}
	
	state def WindGeneratorStateMachine {
		entry; then idle;
		
		state idle {
			entry assign currentPower := 0.0 [SI::W];
		}
		
		transition idle_to_starting
			first idle
			accept startCmd : StartCommand
			then starting;
		
		state starting {
			entry; then releaseBrake;
			state releaseBrake;
			then orientToWind;
			state orientToWind;
			then spinUp;
			state spinUp;
			then synchronized;
			state synchronized;
		}
		
		transition starting_to_generating
			first starting.synchronized
			then generating;
		
		state generating {
			entry; then activeProduction;
			
			state activeProduction;
		}
		
		transition generating_to_stopping
			first generating
			accept stopCmd : StopCommand
			then stopping;
		
		transition generating_to_emergency
			first generating
			accept emergencyStop : EmergencyStop
			then emergency;
		
		state stopping {
			entry; then pitchBlades;
			state pitchBlades;
			then applyBrake;
			state applyBrake;
			then coastDown;
			state coastDown;
		}
		
		transition stopping_to_idle
			first stopping.coastDown
			then idle;
		
		state emergency {
			entry; then emergencyBrake;
			state emergencyBrake;
		}
		
		transition emergency_to_idle
			first emergency
			accept resetCmd : StartCommand
			then idle;
	}
	
	part def WindGenerator {
		doc /* 
			A wind generator system that converts kinetic energy from wind into electrical energy.
			The system captures wind through a rotor assembly, transforms mechanical power through
			a drivetrain, and generates electricity for grid delivery. It operates autonomously
			within safe wind speed ranges and adjusts blade pitch to optimize power output.
		*/
		
		attribute ratedPower : ElectricalPower;
		attribute cutInWindSpeed : WindSpeed;
		attribute ratedWindSpeed : WindSpeed;
		attribute cutOutWindSpeed : WindSpeed;
		
		port windInput : WindInputPort;
		port powerOutput : PowerOutputPort;
		
		part rotor : RotorHub {
			attribute hubDiameter = 3.5 [SI::m];
			attribute hubMass = 18000.0 [SI::kg];
			
			part blades : RotorBlade[3] {
				attribute bladeLength = 50.0 [SI::m];
				attribute bladeMass = 6000.0 [SI::kg];
				attribute pitchAngle = 0.0 [SI::deg];
				attribute aerodynamicEfficiency = 0.45;
			}
		}
		
		part nacelle : Nacelle {
			attribute nacelleMass = 90000.0 [SI::kg];
			
			part gearbox : Gearbox {
				attribute gearRatio = 100.0;
				attribute efficiency = 0.96;
			}
			
			part generator : Generator {
				attribute ratedPower = 3.0 [SI::MW];
				attribute efficiency = 0.97;
				attribute nominalVoltage = 690.0 [SI::V];
			}
			
			part yawSystem : YawSystem {
				attribute yawSpeed = 0.5 [SI::deg_per_s];
				attribute yawMotorPower = 15.0 [SI::kW];
			}
			
			part brakeSystem : BrakeSystem {
				attribute brakeTorque = 60000.0 [SI::N_m];
				attribute brakeEngaged = false;
			}
		}
		
		part tower : Tower {
			attribute towerHeight = 90.0 [SI::m];
			attribute towerMass = 180000.0 [SI::kg];
			attribute towerDiameter = 4.5 [SI::m];
		}
		
		part controlSystem : ControlSystem {
			attribute cutInWindSpeed = 3.0 [SI::m_per_s];
			attribute ratedWindSpeed = 12.0 [SI::m_per_s];
			attribute cutOutWindSpeed = 25.0 [SI::m_per_s];
			attribute targetPower = 3.0 [SI::MW];
			attribute currentState = OperationalState::idle;
		}
		
		connect rotor.mechanicalOutput to nacelle.gearbox.mechanicalInput;
		connect nacelle.gearbox.mechanicalOutput to nacelle.generator.mechanicalInput;
		connect nacelle.generator.electricalOutput to powerOutput;
		
		perform action operate : GenerateElectricalPower {
			in windSpeed = windInput.windSpeed;
			in windDirection = windInput.windDirection;
			in cutInSpeed = controlSystem.cutInWindSpeed;
			in cutOutSpeed = controlSystem.cutOutWindSpeed;
			in targetPower = controlSystem.targetPower;
			out deliveredPower;
		}
		
		binding operate.deliveredPower = powerOutput.power;
		
		exhibit state operationalBehavior : WindGeneratorStateMachine;
	}
	
	part windGeneratorSystem : WindGenerator {
		attribute ratedPower = 3.0 [SI::MW];
		attribute cutInWindSpeed = 3.0 [SI::m_per_s];
		attribute ratedWindSpeed = 12.0 [SI::m_per_s];
		attribute cutOutWindSpeed = 25.0 [SI::m_per_s];
	}
	
	requirement def PowerGenerationRequirement {
		doc /* 
			The wind generator shall convert wind kinetic energy into electrical energy
			with minimum overall system efficiency of 42% at rated wind speed.
		*/
		
		subject generator : WindGenerator;
		
		require constraint systemEfficiency {
			generator.rotor.blades.aerodynamicEfficiency * 
			generator.nacelle.gearbox.efficiency * 
			generator.nacelle.generator.efficiency >= 0.42
		}
	}
	
	requirement def OperationalRangeRequirement {
		doc /* 
			The wind generator shall operate safely and autonomously within defined
			wind speed ranges from cut-in to cut-out velocity.
		*/
		
		subject generator : WindGenerator;
		
		require constraint windSpeedLimits {
			generator.cutInWindSpeed == 3.0 [SI::m_per_s] &&
			generator.ratedWindSpeed == 12.0 [SI::m_per_s] &&
			generator.cutOutWindSpeed == 25.0 [SI::m_per_s]
		}
	}
	
	requirement def RatedPowerRequirement {
		doc /* 
			The wind generator shall deliver rated electrical power output
			at rated wind speed conditions.
		*/
		
		subject generator : WindGenerator;
		
		require constraint powerDelivery {
			generator.ratedPower >= 3.0 [SI::MW]
		}
	}
	
	requirement def SafetyRequirement {
		doc /* 
			The wind generator shall automatically cease operation and engage
			emergency braking when wind speed exceeds cut-out threshold.
		*/
		
		subject generator : WindGenerator;
		
		require constraint emergencyShutdown {
			generator.controlSystem.cutOutWindSpeed == 25.0 [SI::m_per_s]
		}
	}
	
	requirement <'WG-SYS-001'> windGeneratorSystemRequirement {
		doc /* 
			The wind generator system shall autonomously convert kinetic wind energy
			into grid-compatible electrical power through coordinated operation of
			rotor, drivetrain, and generator subsystems while maintaining safe and
			efficient operation across all environmental conditions within the
			operational wind speed envelope.
		*/
		
		subject system : WindGenerator;
		
		assume constraint windResourceAvailability {
			doc /* Wind resource is available within operational range. */
		}
		
		assume constraint gridConnection {
			doc /* Electrical grid connection is available and stable. */
		}
		
		require PowerGenerationRequirement;
		require OperationalRangeRequirement;
		require RatedPowerRequirement;
		require SafetyRequirement;
	}
}
