package FlameDetectionSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def FlamePresent;
	attribute def NoFlame;
	
	item def FlameSignature {
		attribute infraredIntensity : Real;
		attribute ultravioletIntensity : Real;
		attribute temperatureReading : TemperatureValue;
		attribute timestamp : Real;
	}
	
	item def AlarmCommand {
		attribute activate : Boolean;
		attribute severity : String;
	}
	
	item def SuppressionCommand {
		attribute engage : Boolean;
		attribute flowRate : Real;
	}
	
	attribute def IRIntensityThreshold :> Real;
	attribute def UVIntensityThreshold :> Real;
	attribute def TempThreshold :> TemperatureValue;
	
	port def SensorOutputPort {
		out signature : FlameSignature;
	}
	
	port def ProcessorInputPort {
		in signature : FlameSignature;
	}
	
	port def AlarmControlPort {
		out command : AlarmCommand;
	}
	
	port def AlarmReceivePort {
		in command : AlarmCommand;
	}
	
	port def SuppressionControlPort {
		out command : SuppressionCommand;
	}
	
	port def SuppressionReceivePort {
		in command : SuppressionCommand;
	}
	
	part def InfraredSensor {
		doc /* Detects infrared radiation characteristic of flames. */
		port output : SensorOutputPort;
		attribute sensitivity : IRIntensityThreshold = 80.0;
		
		action measureIR {
			out irValue : Real;
		}
	}
	
	part def UltravioletSensor {
		doc /* Detects ultraviolet radiation emitted by flames. */
		port output : SensorOutputPort;
		attribute sensitivity : UVIntensityThreshold = 65.0;
		
		action measureUV {
			out uvValue : Real;
		}
	}
	
	part def ThermalSensor {
		doc /* Measures ambient temperature for flame detection. */
		port output : SensorOutputPort;
		attribute range : TempThreshold = 300.0 [K];
		
		action measureTemp {
			out tempValue : TemperatureValue;
		}
	}
	
	part def SignalProcessor {
		doc /* Analyzes sensor data and determines flame presence. */
		port sensorInput : ProcessorInputPort;
		port alarmControl : AlarmControlPort;
		port suppressionControl : SuppressionControlPort;
		
		attribute irThreshold : IRIntensityThreshold = 75.0;
		attribute uvThreshold : UVIntensityThreshold = 60.0;
		attribute tempThreshold : TempThreshold = 393.15 [K];
		
		action def ProcessingBehavior {
			in inputSignature : FlameSignature;
			in irThresh : IRIntensityThreshold;
			in uvThresh : UVIntensityThreshold;
			in tempThresh : TempThreshold;
			out alarmCmd : AlarmCommand;
			out suppressCmd : SuppressionCommand;
			
			first start;
			then decide;
				if (inputSignature.infraredIntensity > irThresh and inputSignature.ultravioletIntensity > uvThresh) 
					or inputSignature.temperatureReading > tempThresh 
				then confirmFlame;
				else noFlame;
			
			action confirmFlame {
				then assign alarmCmd.activate := true;
				then assign alarmCmd.severity := "HIGH";
				then assign suppressCmd.engage := true;
				then assign suppressCmd.flowRate := 50.0;
			}
			then done;
			
			action noFlame {
				then assign alarmCmd.activate := false;
				then assign suppressCmd.engage := false;
			}
			then done;
		}
	}
	
	part def AlarmDevice {
		doc /* Provides audible and visual warning signals. */
		port input : AlarmReceivePort;
		
		attribute audioLevel : Real = 90.0;
		attribute visualIntensity : Real = 100.0;
		attribute isActive : Boolean = false;
		
		action soundAlarm;
		action flashLights;
	}
	
	part def SuppressionActuator {
		doc /* Controls fire suppression mechanism. */
		port input : SuppressionReceivePort;
		
		attribute suppressantCapacity : Real = 100.0;
		attribute currentLevel : Real = 100.0;
		
		action deploySuppressant {
			in flowRate : Real;
			out deployed : Boolean;
		}
	}
	
	action def AnalyzeFlameData {
		in irLevel : Real;
		in uvLevel : Real;
		in tempLevel : TemperatureValue;
		in irThresh : IRIntensityThreshold;
		in uvThresh : UVIntensityThreshold;
		in tempThresh : TempThreshold;
		out flameDetected : Boolean;
	}
	
	action def GenerateAlarmSignal {
		in flameConfirmed : Boolean;
		out alarmCmd : AlarmCommand;
	}
	
	action def InitiateSuppression {
		in flameConfirmed : Boolean;
		out suppressCmd : SuppressionCommand;
	}
	
	part def FlameDetectionSystem {
		doc /* Integrated system for detecting flames and initiating protective responses. */
		
		part irSensor : InfraredSensor {
			attribute :>> sensitivity = 78.0;
		}
		
		part uvSensor : UltravioletSensor {
			attribute :>> sensitivity = 62.0;
		}
		
		part thermalSensor : ThermalSensor {
			attribute :>> range = 623.15 [K];
		}
		
		part processor : SignalProcessor {
			attribute :>> irThreshold = 75.0;
			attribute :>> uvThreshold = 60.0;
			attribute :>> tempThreshold = 388.15 [K];
		}
		
		part alarmUnit : AlarmDevice {
			attribute :>> audioLevel = 95.0;
		}
		
		part suppressionUnit : SuppressionActuator {
			attribute :>> suppressantCapacity = 150.0;
		}
		
		connect irSensor.output to processor.sensorInput;
		connect uvSensor.output to processor.sensorInput;
		connect thermalSensor.output to processor.sensorInput;
		connect processor.alarmControl to alarmUnit.input;
		connect processor.suppressionControl to suppressionUnit.input;
		
		perform action detectAndRespond {
			doc /* Primary system function: continuously monitor environment, detect flames, and activate protective measures. */
			
			first start;
			then merge continuousMonitoring;
			
			then action gatherData {
				out irReading : Real;
				out uvReading : Real;
				out tempReading : TemperatureValue;
			}
			
			then action analyzeSignature : AnalyzeFlameData {
				in irLevel = gatherData.irReading;
				in uvLevel = gatherData.uvReading;
				in tempLevel = gatherData.tempReading;
				in irThresh = processor.irThreshold;
				in uvThresh = processor.uvThreshold;
				in tempThresh = processor.tempThreshold;
				out flameDetected;
			}
			
			then decide;
				if analyzeSignature.flameDetected then respondToFlame;
				else continuousMonitoring;
			
			action respondToFlame {
				first action issueAlarm : GenerateAlarmSignal {
					in flameConfirmed = analyzeSignature.flameDetected;
					out alarmCmd;
				}
				then action engageSuppression : InitiateSuppression {
					in flameConfirmed = analyzeSignature.flameDetected;
					out suppressCmd;
				}
			}
			then continuousMonitoring;
		}
	}
	
	requirement def DetectionPerformanceRequirement {
		doc /* System shall detect flame presence within specified time. */
		
		subject system : FlameDetectionSystem;
		
		require constraint responseTime {
			doc /* Detection and alarm activation shall occur within 3 seconds. */
		}
		
		require constraint reliability {
			doc /* False alarm rate shall not exceed 0.5 percent. */
		}
	}
	
	requirement def SensingCapabilityRequirement {
		doc /* System shall employ multi-spectral sensing for accurate detection. */
		
		subject detectionCapability : FlameDetectionSystem;
		
		require constraint infraredDetection {
			doc /* System shall monitor infrared spectrum continuously. */
		}
		
		require constraint ultravioletDetection {
			doc /* System shall monitor ultraviolet spectrum continuously. */
		}
		
		require constraint thermalDetection {
			doc /* System shall monitor temperature variations continuously. */
		}
	}
	
	requirement def ResponseRequirement {
		doc /* System shall initiate protective actions upon flame detection. */
		
		subject responseCapability : FlameDetectionSystem;
		
		require constraint alarmActivation {
			doc /* Alarm shall activate immediately upon confirmed detection. */
		}
		
		require constraint suppressionActivation {
			doc /* Suppression system shall engage within 5 seconds of detection. */
		}
	}
	
	requirement <'FDS-MAIN-001'> primaryMissionRequirement {
		doc /* The flame detection system shall continuously monitor the protected environment 
		       using multi-spectral sensors, automatically detect the presence of flames through 
		       integrated signal analysis, and immediately activate alarm and suppression systems 
		       to protect personnel and assets. */
		
		assume constraint operatingEnvironment {
			doc /* System operates in ambient conditions from 263.15 K to 323.15 K. */
		}
		
		require DetectionPerformanceRequirement;
		require SensingCapabilityRequirement;
		require ResponseRequirement;
	}
	
	part flameDetectionSystem : FlameDetectionSystem;
	
	satisfy primaryMissionRequirement by flameDetectionSystem;
}
