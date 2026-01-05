package 'Thunderbolt Siren System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ActivationCommand;
	attribute def DeactivationCommand;
	attribute def TestCommand;
	
	attribute def SoundPressureLevel :> Real;
	attribute def SoundPressureLevelUnit;
	
	attribute def RotationSpeed :> ISQ::AngularVelocityValue;
	
	port def ElectricalPort {
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute current : ISQ::ElectricCurrentValue;
		attribute power : ISQ::PowerValue;
	}
	
	port def RotationalPort {
		attribute torque : ISQ::TorqueValue;
		attribute speed : RotationSpeed;
	}
	
	port def AcousticPort {
		attribute soundLevel : SoundPressureLevel;
		attribute frequency : ISQ::FrequencyValue;
	}
	
	port def ControlPort {
		attribute activationSignal : ActivationCommand;
		attribute deactivationSignal : DeactivationCommand;
		attribute testSignal : TestCommand;
	}
	
	connection def PowerConnection {
		end supplier : ElectricalPort;
		end consumer : ElectricalPort;
	}
	
	connection def MechanicalConnection {
		end driver : RotationalPort;
		end driven : RotationalPort;
	}
	
	connection def AcousticConnection {
		end source : AcousticPort;
		end output : AcousticPort;
	}
	
	connection def ControlConnection {
		end controller : ControlPort;
		end controlled : ControlPort;
	}
	
	part def ElectricMotor {
		doc /* High-power electric motor that drives the siren rotor assembly. */
		
		in port powerIn : ElectricalPort;
		in port controlIn : ControlPort;
		out port motorShaft : RotationalPort;
		
		attribute ratedPower : ISQ::PowerValue;
		attribute operatingSpeed : RotationSpeed;
		attribute startupTime : ISQ::TimeValue;
	}
	
	part def RotorAssembly {
		doc /* Rotating horn assembly with multiple ports that generates directional sound. */
		
		in port driveShaft : RotationalPort;
		out port soundOutput : AcousticPort;
		
		attribute hornCount : Integer;
		attribute rotationSpeed : RotationSpeed;
		attribute diameter : ISQ::LengthValue;
	}
	
	part def Chopper {
		doc /* Mechanical chopper that modulates airflow to create the characteristic siren tone. */
		
		in port rotorInput : RotationalPort;
		in port controlIn : ControlPort;
		out port modulatedSound : AcousticPort;
		
		attribute chopperRatio : Real;
		attribute modulationFrequency : ISQ::FrequencyValue;
		attribute slotCount : Integer;
	}
	
	part def PowerSupply {
		doc /* Electrical power supply providing high-current power to the motor. */
		
		in port utilityPower : ElectricalPort;
		out port powerOut : ElectricalPort;
		
		attribute inputVoltage : ISQ::ElectricPotentialValue;
		attribute outputVoltage : ISQ::ElectricPotentialValue;
		attribute maxCurrent : ISQ::ElectricCurrentValue;
	}
	
	part def ControlUnit {
		doc /* Control unit that manages siren activation, operation modes, and safety interlocks. */
		
		in port commandInput : ControlPort;
		out port motorControl : ControlPort;
		out port chopperControl : ControlPort;
		
		attribute currentMode : String;
		attribute operatingState : String;
	}
	
	part def ThunderboltSiren {
		doc /* A Thunderbolt siren is an electromechanical outdoor warning device that produces 
		       high-intensity omnidirectional sound through a rotating multi-horn assembly driven 
		       by an electric motor, with sound modulation achieved through a mechanical chopper 
		       mechanism. The system is designed for emergency alerting and civil defense applications. */
		
		in port externalPower : ElectricalPort;
		in port externalControl : ControlPort;
		out port warningSound : AcousticPort;
		
		part powerSupply : PowerSupply {
			attribute :>> inputVoltage = 240.0 [SI::V];
			attribute :>> outputVoltage = 220.0 [SI::V];
			attribute :>> maxCurrent = 30.0 [SI::A];
		}
		
		part controller : ControlUnit {
			attribute :>> currentMode = "standby";
			attribute :>> operatingState = "idle";
		}
		
		part motor : ElectricMotor {
			attribute :>> ratedPower = 5000.0 [SI::W];
			attribute :>> operatingSpeed = 5000.0;
			attribute :>> startupTime = 8.0 [SI::s];
		}
		
		part rotor : RotorAssembly {
			attribute :>> hornCount = 5;
			attribute :>> rotationSpeed = 5000.0;
			attribute :>> diameter = 0.6 [SI::m];
		}
		
		part chopper : Chopper {
			attribute :>> chopperRatio = 6.0;
			attribute :>> modulationFrequency = 500.0 [SI::Hz];
			attribute :>> slotCount = 6;
		}
		
		connection powerInput : PowerConnection 
			connect externalPower to powerSupply.utilityPower;
		
		connection motorPower : PowerConnection 
			connect powerSupply.powerOut to motor.powerIn;
		
		connection controlInput : ControlConnection
			connect externalControl to controller.commandInput;
		
		connection motorControlLink : ControlConnection
			connect controller.motorControl to motor.controlIn;
		
		connection chopperControlLink : ControlConnection
			connect controller.chopperControl to chopper.controlIn;
		
		connection driveConnection : MechanicalConnection
			connect motor.motorShaft to rotor.driveShaft;
		
		connection chopperDrive : MechanicalConnection
			connect rotor.driveShaft to chopper.rotorInput;
		
		connection soundPath : AcousticConnection
			connect chopper.modulatedSound to rotor.soundOutput;
		
		connection soundOutput : AcousticConnection
			connect rotor.soundOutput to warningSound;
		
		perform action operateSiren;
	}
	
	action def GenerateRotation {
		in powerInput : ISQ::PowerValue;
		in controlSignal : ActivationCommand;
		out rotationalOutput : RotationSpeed;
	}
	
	action def ProduceSound {
		in rotationInput : RotationSpeed;
		out acousticOutput : SoundPressureLevel;
	}
	
	action def ModulateSound {
		in baseSound : SoundPressureLevel;
		in chopperSpeed : RotationSpeed;
		out modulatedOutput : SoundPressureLevel;
		out frequency : ISQ::FrequencyValue;
	}
	
	action operateSiren {
		doc /* The Thunderbolt siren operates by converting electrical power into high-intensity 
		       omnidirectional warning sound through coordinated mechanical rotation and acoustic 
		       modulation, cycling through startup, alert, and shutdown phases. */
		
		first start;
		
		then merge standbyState;
		
		then action waitForActivation {
			accept activationCmd : ActivationCommand;
		}
		
		then action startupSequence {
			doc /* Motor spins up to operating speed over approximately 8 seconds. */
			
			action energizeMotor : GenerateRotation {
				in powerInput : ISQ::PowerValue;
				in controlSignal = waitForActivation::activationCmd;
				out rotationalOutput : RotationSpeed;
			}
			
			then action rampUpSpeed {
				doc /* Motor accelerates rotor assembly to full operating speed. */
			}
		}
		
		then action alertOperation {
			doc /* Siren produces full-intensity modulated warning sound. */
			
			action generateRotation : GenerateRotation {
				in powerInput : ISQ::PowerValue;
				in controlSignal : ActivationCommand;
				out rotationalOutput : RotationSpeed;
			}
			
			flow generateRotation.rotationalOutput to produceBaseSound.rotationInput;
			
			action produceBaseSound : ProduceSound {
				in rotationInput : RotationSpeed;
				out acousticOutput : SoundPressureLevel;
			}
			
			flow produceBaseSound.acousticOutput to modulateWarningSound.baseSound;
			flow generateRotation.rotationalOutput to modulateWarningSound.chopperSpeed;
			
			action modulateWarningSound : ModulateSound {
				in baseSound : SoundPressureLevel;
				in chopperSpeed : RotationSpeed;
				out modulatedOutput : SoundPressureLevel;
				out frequency : ISQ::FrequencyValue;
			}
		}
		
		then decide;
			if alertOperation.modulateWarningSound.modulatedOutput >= 125.0 then continueAlert;
			if alertOperation.modulateWarningSound.modulatedOutput < 125.0 then adjustOperation;
		
		action continueAlert {
			then action checkForDeactivation {
				accept deactivationCmd : DeactivationCommand;
			}
			
			then decide;
				if checkForDeactivation::deactivationCmd != null then shutdownSequence;
				else alertOperation;
		}
		
		action adjustOperation;
		then alertOperation;
		
		action shutdownSequence {
			doc /* Motor coasts down to stop, sound output decreases. */
			
			action deenergizeMotor {
				doc /* Power to motor is cut, allowing controlled spindown. */
			}
			
			then action coastDown {
				doc /* Rotor assembly decelerates to rest over several seconds. */
			}
		}
		
		then standbyState;
	}
	
	requirement <'SR-001'> sirenAcousticPerformance {
		doc /* The Thunderbolt siren shall produce sound pressure levels of at least 125 dB 
		       at 30.48 meters (100 feet) to ensure effective warning coverage over a wide area. */
		
		subject thunderboltSystem : ThunderboltSiren;
		
		require constraint {
			thunderboltSystem.warningSound.soundLevel >= 125.0
		}
	}
	
	requirement <'SR-002'> sirenRotationalSpeed {
		doc /* The rotor assembly shall achieve rotational speeds between 4800 and 5400 RPM 
		       for proper acoustic output and characteristic tone generation. */
		
		subject thunderboltSystem : ThunderboltSiren;
		
		require constraint {
			thunderboltSystem.rotor.rotationSpeed >= 4800.0 and
			thunderboltSystem.rotor.rotationSpeed <= 5400.0
		}
	}
	
	requirement <'SR-003'> sirenStartupTime {
		doc /* The siren shall reach full alert output within 10 seconds of receiving 
		       an activation command to ensure rapid emergency response. */
		
		subject thunderboltSystem : ThunderboltSiren;
		
		require constraint {
			thunderboltSystem.motor.startupTime <= 10.0 [SI::s]
		}
	}
	
	requirement <'SR-004'> sirenModulationFrequency {
		doc /* The chopper mechanism shall produce a modulation frequency between 450 and 550 Hz 
		       to create the distinctive Thunderbolt warning tone. */
		
		subject thunderboltSystem : ThunderboltSiren;
		
		require constraint {
			thunderboltSystem.chopper.modulationFrequency >= 450.0 [SI::Hz] and
			thunderboltSystem.chopper.modulationFrequency <= 550.0 [SI::Hz]
		}
	}
	
	requirement <'SR-005'> sirenPrimaryFunction {
		doc /* The primary function of the Thunderbolt siren system is to generate high-intensity 
		       omnidirectional warning sound for emergency alerting by rotating a multi-horn assembly 
		       driven by an electric motor, with sound modulation achieved through a mechanical chopper 
		       mechanism, providing effective wide-area notification for civil defense and emergency 
		       management applications. */
		
		subject thunderboltSystem : ThunderboltSiren;
		
		assume constraint {
			thunderboltSystem.powerSupply.inputVoltage >= 220.0 [SI::V] and
			thunderboltSystem.powerSupply.inputVoltage <= 240.0 [SI::V]
		}
		
		require sirenAcousticPerformance;
		require sirenRotationalSpeed;
		require sirenStartupTime;
		require sirenModulationFrequency;
	}
	
	part thunderboltSirenSystem : ThunderboltSiren {
		perform action operateSiren;
		
		satisfy sirenPrimaryFunction;
	}
}
