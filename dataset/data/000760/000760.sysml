package 'SensitiveSkinSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PressureValue :> ISQ::PressureValue;
	attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
	attribute def ForceValue :> ISQ::ForceValue;
	attribute def AreaValue :> ISQ::AreaValue;
	attribute def TimeValue :> ISQ::TimeValue;
	attribute def ElectricPotentialValue :> ISQ::ElectricPotentialValue;
	
	attribute def SpatialCoordinate {
		attribute x : Real;
		attribute y : Real;
	}
	
	item def TactileStimulus {
		attribute pressure : PressureValue;
		attribute temperature : TemperatureValue;
		attribute location : SpatialCoordinate;
		attribute timestamp : TimeValue;
	}
	
	item def ProcessedTactileData {
		attribute contactDetected : Boolean;
		attribute appliedForce : ForceValue;
		attribute contactArea : AreaValue;
		attribute surfaceTemperature : TemperatureValue;
		attribute contactLocation : SpatialCoordinate;
		attribute eventTime : TimeValue;
	}
	
	item def ResponseSignal {
		attribute alertLevel : Integer;
		attribute responseType : String;
		attribute targetLocation : SpatialCoordinate;
	}
	
	port def TactileSensorPort {
		out item tactileOutput : TactileStimulus;
	}
	
	port def ProcessorInputPort {
		in item rawTactileData : TactileStimulus;
	}
	
	port def ProcessorOutputPort {
		out item processedOutput : ProcessedTactileData;
	}
	
	port def ControllerInputPort {
		in item analysisInput : ProcessedTactileData;
	}
	
	port def ControllerOutputPort {
		out item commandOutput : ResponseSignal;
	}
	
	part def TactileSensorCell {
		attribute cellID : Integer;
		attribute position : SpatialCoordinate;
		attribute pressureSensitivity : PressureValue;
		attribute temperatureSensitivity : TemperatureValue;
		
		port sensorOutput : TactileSensorPort;
		
		perform action detectContact {
			out stimulus : TactileStimulus;
		}
	}
	
	part def SensorArray {
		attribute arrayDimensions : Integer[2];
		attribute cellSpacing : ISQ::LengthValue;
		attribute totalCells : Integer;
		
		part cells : TactileSensorCell[*] {
			attribute :>> pressureSensitivity = 5.0 [Pa];
			attribute :>> temperatureSensitivity = 0.1 [K];
		}
		
		port arrayOutput : TactileSensorPort;
		
		perform action aggregateSensorData {
			out aggregatedStimuli : TactileStimulus[*];
		}
	}
	
	part def SignalProcessingUnit {
		attribute samplingRate : Real;
		attribute filterCutoffFrequency : Real;
		attribute noiseThreshold : PressureValue;
		
		port processorInput : ProcessorInputPort;
		port processorOutput : ProcessorOutputPort;
		
		perform action filterAndAnalyze {
			in rawStimuli : TactileStimulus[*];
			out analyzedData : ProcessedTactileData;
		}
	}
	
	part def ResponseController {
		attribute forceThreshold : ForceValue;
		attribute temperatureThreshold : TemperatureValue;
		attribute safetyFactor : Real;
		
		port controlInput : ControllerInputPort;
		port controlOutput : ControllerOutputPort;
		
		perform action evaluateAndRespond {
			in tactileData : ProcessedTactileData;
			out response : ResponseSignal;
		}
	}
	
	part def FlexibleSubstrate {
		attribute materialType : String;
		attribute thickness : ISQ::LengthValue;
		attribute flexibilityIndex : Real;
		attribute totalArea : AreaValue;
		attribute operatingTemperatureRange : TemperatureValue[2];
	}
	
	part def PowerSupply {
		attribute nominalVoltage : ElectricPotentialValue;
		attribute maxCurrent : ISQ::ElectricCurrentValue;
		attribute efficiency : Real;
		
		perform action providePower {
			out powerStatus : Boolean;
		}
	}
	
	part def SensitiveSkin {
		attribute systemID : String;
		attribute totalSensorCount : Integer;
		attribute activeSensingArea : AreaValue;
		attribute operatingVoltage : ElectricPotentialValue;
		attribute responseLatency : TimeValue;
		
		part sensorArray : SensorArray {
			attribute :>> arrayDimensions = (8, 8);
			attribute :>> cellSpacing = 10.0 [mm];
			attribute :>> totalCells = 64;
		}
		
		part processor : SignalProcessingUnit {
			attribute :>> samplingRate = 1000.0;
			attribute :>> filterCutoffFrequency = 100.0;
			attribute :>> noiseThreshold = 1.0 [Pa];
		}
		
		part controller : ResponseController {
			attribute :>> forceThreshold = 2.0 [N];
			attribute :>> temperatureThreshold = 323.15 [K];
			attribute :>> safetyFactor = 1.5;
		}
		
		part substrate : FlexibleSubstrate {
			attribute :>> materialType = "Silicone";
			attribute :>> thickness = 3.0 [mm];
			attribute :>> flexibilityIndex = 0.9;
			attribute :>> totalArea = 0.15 [m^2];
			attribute :>> operatingTemperatureRange = (253.15 [K], 373.15 [K]);
		}
		
		part power : PowerSupply {
			attribute :>> nominalVoltage = 12.0 [V];
			attribute :>> maxCurrent = 3.0 [A];
			attribute :>> efficiency = 0.92;
		}
		
		connection sensorToProcessor connect 
			sensorArray.arrayOutput to processor.processorInput;
		
		connection processorToController connect 
			processor.processorOutput to controller.controlInput;
	}
	
	action def ContinuousTactileMonitoring {
		first start;
		
		then merge monitoringLoop;
		
		then action acquireSensorData {
			out rawStimuli : TactileStimulus[*];
		}
		
		then action processStimuli {
			in stimuli = acquireSensorData.rawStimuli;
			out processedData : ProcessedTactileData;
		}
		
		then decide contactDecision;
			if processedData.contactDetected then evaluateContact;
			if not processedData.contactDetected then monitoringLoop;
		
		action evaluateContact {
			in contactInfo = processStimuli.processedData;
			out requiresResponse : Boolean;
		}
		
		then decide responseDecision;
			if evaluateContact.requiresResponse then generateResponse;
			if not evaluateContact.requiresResponse then monitoringLoop;
		
		action generateResponse {
			in contactData = processStimuli.processedData;
			out responseCommand : ResponseSignal;
		}
		
		then monitoringLoop;
	}
	
	requirement def SensitivityRequirement {
		doc /* The sensitive skin shall detect contact forces as low as 0.5 N across the entire sensing surface. */
		
		subject skin : SensitiveSkin;
		
		require constraint {
			skin.controller.forceThreshold <= 2.0 [N]
		}
	}
	
	requirement def CoverageRequirement {
		doc /* The sensitive skin shall provide continuous tactile coverage over at least 0.1 square meters. */
		
		subject skin : SensitiveSkin;
		
		require constraint {
			skin.activeSensingArea >= 0.1 [m^2]
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The system shall detect and process tactile events within 20 milliseconds. */
		
		subject skin : SensitiveSkin;
		
		require constraint {
			skin.responseLatency <= 0.02 [s]
		}
	}
	
	requirement def TemperatureRangeRequirement {
		doc /* The sensitive skin shall operate reliably across temperatures from -20°C to 100°C. */
		
		subject substrate : FlexibleSubstrate;
		
		require constraint {
			substrate.operatingTemperatureRange[1] <= 253.15 [K] and
			substrate.operatingTemperatureRange[2] >= 373.15 [K]
		}
	}
	
	requirement <'SSR-001'> sensitiveSkinSystemRequirement {
		doc /* The sensitive skin system shall continuously monitor its surface for tactile and thermal stimuli,
		       process sensor data in real-time, detect contact events, and generate appropriate response signals
		       to enable safe and adaptive interaction with objects and environments. */
		
		subject skinSystem : SensitiveSkin;
		
		assume constraint {
			skinSystem.operatingVoltage > 0.0 [V] and
			skinSystem.totalSensorCount > 0
		}
		
		require SensitivityRequirement;
		require CoverageRequirement;
		require ResponseTimeRequirement;
		require TemperatureRangeRequirement;
	}
	
	part sensitiveSkinSystem : SensitiveSkin {
		attribute :>> systemID = "SSS-001";
		attribute :>> totalSensorCount = 64;
		attribute :>> activeSensingArea = 0.15 [m^2];
		attribute :>> operatingVoltage = 12.0 [V];
		attribute :>> responseLatency = 0.015 [s];
		
		perform action tactileMonitoring[*] ordered references ContinuousTactileMonitoring;
		
		satisfy sensitiveSkinSystemRequirement;
	}
}
