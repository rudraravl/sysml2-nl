package LutronLightingControlSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def LightLevel {
		attribute value : Real;
		attribute unit : String = "percent";
		assert constraint validRange { 0.0 <= value and value <= 100.0 }
	}
	
	attribute def OccupancyState {
		attribute occupied : Boolean;
	}
	
	attribute def DimmerLevel :> LightLevel;
	
	item def ControlSignal {
		attribute targetLevel : LightLevel;
		attribute timestamp : Real;
	}
	
	item def SensorReading {
		attribute occupancy : OccupancyState;
		attribute ambientLight : LightLevel;
	}
	
	port def ControlPort {
		out item controlSignal : ControlSignal;
	}
	
	port def SensorPort {
		in item sensorData : SensorReading;
	}
	
	port def PowerPort {
		attribute voltage : ISQ::VoltageValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	part def OccupancySensor {
		port sensorOut : SensorPort;
		attribute detectionRange : ISQ::LengthValue;
		attribute sensitivity : Real;
		
		perform action detectOccupancy {
			out reading : SensorReading;
		}
	}
	
	part def AmbientLightSensor {
		port sensorOut : SensorPort;
		attribute measurementRange : LightLevel;
		
		perform action measureLight {
			out lightReading : LightLevel;
		}
	}
	
	part def DimmableLoadController {
		port controlIn : ControlPort;
		port powerOut : PowerPort;
		attribute maxLoad : ISQ::PowerValue;
		attribute currentDimLevel : DimmerLevel;
		
		perform action adjustLoad {
			in targetLevel : LightLevel;
			out actualLevel : LightLevel;
		}
	}
	
	part def CentralProcessor {
		port sensorInput : SensorPort[2..5];
		port controlOutput : ControlPort[1..10];
		
		attribute operatingMode : String;
		attribute scheduledScenes : String[*];
		
		perform action processInputs {
			in sensorData : SensorReading[*];
			out controlCommands : ControlSignal[*];
		}
	}
	
	part def UserInterface {
		attribute displayBrightness : LightLevel;
		attribute buttonCount : Integer;
		
		perform action handleUserInput {
			in buttonPress : Integer;
			out command : ControlSignal;
		}
	}
	
	state def ControllerState {
		entry action initializeSystem;
		
		state off {
			entry action turnOffLoads;
		}
		
		state monitoring {
			entry action startMonitoring;
			
			state idle;
			
			state active {
				do action maintainLighting;
			}
			
			transition idleToActive
				first idle
				then active;
			
			transition activeToIdle
				first active
				then idle;
		}
		
		state adjusting {
			do action adjustLightLevels {
				in targetLevels : LightLevel[*];
			}
		}
		
		transition offToMonitoring
			first off
			then monitoring;
		
		transition monitoringToAdjusting
			first monitoring
			then adjusting;
		
		transition adjustingToMonitoring
			first adjusting
			then monitoring;
		
		transition monitoringToOff
			first monitoring
			then off;
	}
	
	action def AutomatedLightingControl {
		first start;
		
		then merge continuousControl;
		
		then action readSensors {
			out occupancyData : OccupancyState;
			out ambientLightData : LightLevel;
		}
		
		then decide;
			if readSensors.occupancyData.occupied and readSensors.ambientLightData.value < 30.0 
				then calculateOptimalLevel;
			if not readSensors.occupancyData.occupied 
				then setLowLevel;
			if readSensors.occupancyData.occupied and readSensors.ambientLightData.value >= 30.0 
				then maintainCurrentLevel;
		
		action calculateOptimalLevel {
			in ambientLevel : LightLevel = readSensors.ambientLightData;
			out optimalLevel : LightLevel;
		}
		then sendControlSignal;
		
		action setLowLevel {
			out lowLevel : LightLevel;
		}
		then sendControlSignal;
		
		action maintainCurrentLevel {
			out currentLevel : LightLevel;
		}
		then sendControlSignal;
		
		action sendControlSignal {
			in targetLevel : LightLevel;
			out signal : ControlSignal;
		}
		
		then continuousControl;
	}
	
	part def LutronLightingControlSystem;
	
	part lutronSystem : LutronLightingControlSystem {
		attribute systemName : String = "Lutron Automated Lighting Control";
		
		perform action automatedControl[*] ordered references AutomatedLightingControl;
		
		part processor : CentralProcessor {
			attribute operatingMode = "automatic";
			perform automatedControl.readSensors;
			perform automatedControl.calculateOptimalLevel;
			perform automatedControl.setLowLevel;
			perform automatedControl.maintainCurrentLevel;
			perform automatedControl.sendControlSignal;
		}
		
		part occupancySensor1 : OccupancySensor {
			attribute detectionRange = 8.0 [SI::m];
			attribute sensitivity = 0.85;
		}
		
		part lightSensor1 : AmbientLightSensor {
			attribute measurementRange : LightLevel {
				attribute value = 100.0;
			}
		}
		
		part dimmer1 : DimmableLoadController {
			attribute maxLoad = 600.0 [SI::W];
			attribute currentDimLevel : DimmerLevel {
				attribute value = 0.0;
			}
		}
		
		part dimmer2 : DimmableLoadController {
			attribute maxLoad = 1000.0 [SI::W];
			attribute currentDimLevel : DimmerLevel {
				attribute value = 0.0;
			}
		}
		
		part userPanel : UserInterface {
			attribute displayBrightness : LightLevel {
				attribute value = 50.0;
			}
			attribute buttonCount = 6;
		}
		
		connection sensorToProcessor1 : SensorConnection 
			connect occupancySensor1.sensorOut to processor.sensorInput;
		
		connection sensorToProcessor2 : SensorConnection 
			connect lightSensor1.sensorOut to processor.sensorInput;
		
		connection processorToDimmer1 : ControlConnection 
			connect processor.controlOutput to dimmer1.controlIn;
		
		connection processorToDimmer2 : ControlConnection 
			connect processor.controlOutput to dimmer2.controlIn;
	}
	
	connection def SensorConnection {
		end source : SensorPort;
		end destination : SensorPort;
	}
	
	connection def ControlConnection {
		end source : ControlPort;
		end destination : ControlPort;
	}
	
	requirement def EnergyEfficiencyRequirement {
		doc /* The system shall reduce energy consumption by at least 30% compared to manual control. */
		
		subject system : LutronLightingControlSystem;
		
		require constraint energySavings {
			doc /* Energy savings must meet or exceed 30% threshold. */
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The system shall respond to occupancy changes within 500 milliseconds. */
		
		subject processor : CentralProcessor;
		
		attribute maxResponseTime : ISQ::DurationValue = 0.5 [SI::s];
		
		require constraint responseTime {
			doc /* Response time must be less than or equal to maxResponseTime. */
		}
	}
	
	requirement def ReliabilityRequirement {
		doc /* The system shall maintain 99.9% uptime during normal operating conditions. */
		
		subject system : LutronLightingControlSystem;
		
		attribute minimumUptime : Real = 99.9;
		
		require constraint uptimeThreshold {
			doc /* System uptime must meet minimum threshold. */
		}
	}
	
	requirement <'LUTRON-001'> primarySystemRequirement {
		doc /* The Lutron lighting control system shall automatically adjust lighting levels 
		       based on occupancy and ambient light conditions to optimize energy efficiency 
		       and user comfort. */
		
		subject lutronSystem;
		
		assume constraint occupancySensorOperational {
			doc /* Occupancy sensors are functioning and properly calibrated. */
		}
		
		assume constraint ambientLightSensorOperational {
			doc /* Ambient light sensors are functioning and properly calibrated. */
		}
		
		require energyEfficiency : EnergyEfficiencyRequirement {
			subject system = lutronSystem;
		}
		
		require responseTime : ResponseTimeRequirement {
			subject processor = lutronSystem.processor;
		}
		
		require reliability : ReliabilityRequirement {
			subject system = lutronSystem;
		}
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import LutronLightingControlSystem::*;

    part testSubject : OccupancySensor {
        exhibit state sm : ControllerState;
    }

    action orchestrator {
        attribute testAmbientLevel : LightLevel {
            attribute value = 0.0;
            attribute unit = "percent";
        }
        attribute testTargetLevel : LightLevel {
            attribute value = 0.0;
            attribute unit = "percent";
        }
        action actionProbe : AutomatedLightingControl {
            in ambientLevel = testAmbientLevel;
            in targetLevel = testTargetLevel;
        }
        first actionProbe;
    }
}
