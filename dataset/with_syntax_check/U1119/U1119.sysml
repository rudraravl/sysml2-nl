package LightingControlSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def IlluminanceLevel :> Real;
	attribute def OccupancyState :> Boolean;
	attribute def BrightnessLevel :> Real;
	
	enum def LightMode { on; off; auto; }
	
	item def OccupancySignal {
		attribute occupied : OccupancyState;
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def AmbientLightReading {
		attribute illuminance : ISQ::IlluminanceValue;
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def UserInput {
		attribute mode : LightMode;
		attribute manualBrightness : BrightnessLevel;
	}
	
	item def LightCommand {
		attribute targetBrightness : BrightnessLevel;
		attribute timestamp : ISQ::TimeValue;
	}
	
	port def SensorPort {
		out item signal;
	}
	
	port def ControlPort {
		in item command : LightCommand;
	}
	
	port def UserInterfacePort {
		out item input : UserInput;
	}
	
	port def PowerPort {
		attribute voltage : ISQ::VoltageValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	part def OccupancySensor {
		port sensorOut : SensorPort {
			out item signal : OccupancySignal;
		}
		attribute detectionRange : ISQ::LengthValue;
		attribute sensitivity : Real;
		
		action detectPresence {
			out occupancyData : OccupancySignal;
		}
	}
	
	part def LightSensor {
		port sensorOut : SensorPort {
			out item signal : AmbientLightReading;
		}
		attribute measurementRange : ISQ::IlluminanceValue;
		
		action measureLight {
			out lightData : AmbientLightReading;
		}
	}
	
	part def UserPanel {
		port panelOut : UserInterfacePort;
		
		action captureInput {
			out userCommand : UserInput;
		}
	}
	
	part def LightingFixture {
		port controlIn : ControlPort;
		port powerIn : PowerPort;
		attribute maxBrightness : BrightnessLevel;
		attribute currentBrightness : BrightnessLevel;
		attribute powerConsumption : ISQ::PowerValue;
		
		state fixtureStateMachine {
			entry; then off;
			
			state off {
				entry assign currentBrightness := 0.0;
			}
			
			transition off_to_on
				first off
				accept cmd : LightCommand
				if cmd.targetBrightness > 0.0
				then on;
			
			state on {
				entry assign currentBrightness := controlIn.command.targetBrightness;
			}
			
			transition on_to_off
				first on
				accept cmd : LightCommand
				if cmd.targetBrightness == 0.0
				then off;
		}
	}
	
	part def LightingController {
		port occupancyIn : SensorPort;
		port ambientIn : SensorPort;
		port userIn : UserInterfacePort;
		port lightOut : ControlPort;
		
		attribute targetIlluminance : ISQ::IlluminanceValue;
		attribute ambientThreshold : ISQ::IlluminanceValue;
		attribute occupancyTimeout : ISQ::TimeValue;
		attribute currentMode : LightMode;
		
		action def DetermineRequiredBrightness {
			in occupancy : OccupancyState;
			in ambient : ISQ::IlluminanceValue;
			in mode : LightMode;
			in manualLevel : BrightnessLevel;
			in threshold : ISQ::IlluminanceValue;
			out brightness : BrightnessLevel;
		}
		
		action controlLoop {
			first start;
			then merge monitoring;
			
			action monitoring {
				action readOccupancy {
					out occupancySignal : OccupancySignal;
				}
				then action readAmbient {
					out ambientSignal : AmbientLightReading;
				}
				then action readUser {
					out userSignal : UserInput;
				}
				then decide;
					if readUser.userSignal.mode == LightMode::on then manualOn;
					if readUser.userSignal.mode == LightMode::off then manualOff;
					if readUser.userSignal.mode == LightMode::auto then automaticControl;
				
				action manualOn {
					private attribute cmdBrightness := readUser.userSignal.manualBrightness;
				}
				then waitCycle;
				
				action manualOff {
					private attribute cmdBrightness := 0.0;
				}
				then waitCycle;
				
				action automaticControl {
					then decide;
						if readOccupancy.occupancySignal.occupied == false then turnOff;
						if readOccupancy.occupancySignal.occupied == true then evaluateAmbient;
					
					action turnOff {
						private attribute cmdBrightness := 0.0;
					}
					then waitCycle;
					
					action evaluateAmbient {
						then decide;
							if readAmbient.ambientSignal.illuminance >= ambientThreshold then dimLights;
							if readAmbient.ambientSignal.illuminance < ambientThreshold then fullBrightness;
						
						action dimLights {
							private attribute ratio := ambientThreshold / readAmbient.ambientSignal.illuminance;
							private attribute cmdBrightness := ratio * 100.0;
						}
						then waitCycle;
						
						action fullBrightness {
							private attribute cmdBrightness := 100.0;
						}
						then waitCycle;
					}
				}
				
				action waitCycle;
				then monitoring;
			}
		}
	}
	
	part def PowerSupply {
		port powerOut : PowerPort;
		attribute inputVoltage : ISQ::VoltageValue;
		attribute outputVoltage : ISQ::VoltageValue;
		attribute maxCurrent : ISQ::ElectricCurrentValue;
		attribute efficiency : Real;
	}
	
	part lightingControlSystem {
		part occupancySensor : OccupancySensor {
			attribute :>> detectionRange = 8.0 [SI::m];
			attribute :>> sensitivity = 0.85;
		}
		
		part lightSensor : LightSensor {
			attribute :>> measurementRange = 2000.0 [SI::lx];
		}
		
		part userPanel : UserPanel;
		
		part controller : LightingController {
			attribute :>> targetIlluminance = 500.0 [SI::lx];
			attribute :>> ambientThreshold = 300.0 [SI::lx];
			attribute :>> occupancyTimeout = 600.0 [SI::s];
			attribute :>> currentMode = LightMode::auto;
		}
		
		part fixture1 : LightingFixture {
			attribute :>> maxBrightness = 100.0;
			attribute :>> currentBrightness = 0.0;
			attribute :>> powerConsumption = 40.0 [SI::W];
		}
		
		part fixture2 : LightingFixture {
			attribute :>> maxBrightness = 100.0;
			attribute :>> currentBrightness = 0.0;
			attribute :>> powerConsumption = 40.0 [SI::W];
		}
		
		part powerSupply : PowerSupply {
			attribute :>> inputVoltage = 230.0 [SI::V];
			attribute :>> outputVoltage = 24.0 [SI::V];
			attribute :>> maxCurrent = 5.0 [SI::A];
			attribute :>> efficiency = 0.92;
		}
		
		connect occupancySensor.sensorOut to controller.occupancyIn;
		connect lightSensor.sensorOut to controller.ambientIn;
		connect userPanel.panelOut to controller.userIn;
		connect controller.lightOut to fixture1.controlIn;
		connect controller.lightOut to fixture2.controlIn;
		connect powerSupply.powerOut to fixture1.powerIn;
		connect powerSupply.powerOut to fixture2.powerIn;
		
		perform action controller.controlLoop;
	}
	
	requirement def EnergyEfficiencyRequirement {
		doc /* The lighting control system shall minimize energy consumption 
		     by reducing or turning off lights when occupancy is not detected 
		     or when sufficient ambient light is available. */
		
		subject sys : LightingControlSystem::lightingControlSystem;
		
		require constraint energyConstraint {
			attribute maxPowerWhenUnoccupied : ISQ::PowerValue = 5.0 [SI::W];
		}
	}
	
	requirement def OccupancyResponseRequirement {
		doc /* The system shall respond to occupancy changes within a specified time 
		     to ensure timely illumination for occupants. */
		
		subject sys : LightingControlSystem::lightingControlSystem;
		
		attribute maxResponseTime : ISQ::TimeValue = 2.0 [SI::s];
		
		require constraint responseConstraint {
			maxResponseTime <= 2.0 [SI::s]
		}
	}
	
	requirement def IlluminationAdequacyRequirement {
		doc /* The system shall provide adequate illumination levels when the space 
		     is occupied and ambient light is insufficient. */
		
		subject sys : LightingControlSystem::lightingControlSystem;
		
		attribute minIlluminance : ISQ::IlluminanceValue = 400.0 [SI::lx];
		
		require constraint illuminationConstraint {
			minIlluminance >= 400.0 [SI::lx]
		}
	}
	
	requirement def UserControlRequirement {
		doc /* The system shall provide manual override capability allowing users 
		     to control lighting independent of automatic operation. */
		
		subject sys : LightingControlSystem::lightingControlSystem;
	}
	
	requirement <'LCS-SYS-001'> systemRequirements {
		doc /* The lighting control system shall automatically manage illumination 
		     based on occupancy detection and ambient light levels while providing 
		     manual override capability and minimizing energy consumption. */
		
		subject sys : LightingControlSystem::lightingControlSystem;
		
		require energyEff : EnergyEfficiencyRequirement;
		require occupancyResp : OccupancyResponseRequirement;
		require illuminationAdeq : IlluminationAdequacyRequirement;
		require userCtrl : UserControlRequirement;
	}
}
