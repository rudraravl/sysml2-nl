package HybrotSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def NeuralActivityLevel :> Real;
	attribute def StimulusVoltage :> ElectricPotentialValue;
	attribute def MovementSpeed :> SpeedValue;
	attribute def ProximityDistance :> LengthValue;
	
	item def NeuralSignal {
		attribute activityLevel : NeuralActivityLevel;
		attribute timestamp : TimeValue;
		attribute frequency : FrequencyValue;
	}
	
	item def ElectricalStimulus {
		attribute voltage : StimulusVoltage;
		attribute pulseWidth : TimeValue;
		attribute frequency : FrequencyValue;
	}
	
	item def MotionCommand {
		attribute leftWheelSpeed : MovementSpeed;
		attribute rightWheelSpeed : MovementSpeed;
		attribute duration : TimeValue;
	}
	
	item def EnvironmentalData {
		attribute obstacleDistance : ProximityDistance;
		attribute detectionAngle : Real;
	}
	
	port def NeuralPort {
		out item neuralOutput : NeuralSignal;
		in item stimulusInput : ElectricalStimulus;
	}
	
	port def SensorPort {
		out item sensorData : EnvironmentalData;
	}
	
	port def ActuatorPort {
		in item command : MotionCommand;
	}
	
	port def ProcessingPort {
		in item neuralInput : NeuralSignal;
		out item motorOutput : MotionCommand;
	}
	
	part def BiologicalNeuralNetwork {
		doc /* Living neural tissue cultured on microelectrode array that processes sensory information. */
		
		port neuralInterface : NeuralPort;
		
		attribute neuronCount : Real;
		attribute cultureHealth : Real;
		attribute synapticActivity : NeuralActivityLevel;
		
		perform action processInformation {
			in stimulus : ElectricalStimulus;
			out response : NeuralSignal;
			
			action receiveStimulus {
				in stim : ElectricalStimulus;
			}
			then action generateResponse {
				out signal : NeuralSignal;
			}
		}
	}
	
	part def MicroelectrodeArray {
		doc /* Interface between biological neurons and electronic systems. */
		
		port biologicalSide : NeuralPort;
		port electronicSide : ProcessingPort;
		
		attribute electrodeCount : Real;
		attribute samplingRate : FrequencyValue;
		attribute impedance : Real;
		
		perform action recordActivity {
			in biologicalSignal : NeuralSignal;
			out digitalSignal : NeuralSignal;
		}
		
		perform action deliverStimulation {
			in digitalPattern : ElectricalStimulus;
			out biologicalStimulus : ElectricalStimulus;
		}
	}
	
	part def SignalProcessingUnit {
		doc /* Converts neural signals to motor commands and environmental data to neural stimuli. */
		
		port neuralInput : ProcessingPort;
		port sensorInput : SensorPort;
		port motorOutput : ActuatorPort;
		port stimulusOutput : NeuralPort;
		
		attribute processingLatency : TimeValue;
		attribute adaptationRate : Real;
		
		perform action translateNeuralToMotor {
			in neuralData : NeuralSignal;
			out motorCmd : MotionCommand;
			
			action decodePattern {
				in signal : NeuralSignal;
				out interpretation : Real;
			}
			then action mapToMotion {
				in interpretation : Real;
				out command : MotionCommand;
			}
		}
		
		perform action translateSensorToStimulus {
			in environmentData : EnvironmentalData;
			out stimulus : ElectricalStimulus;
			
			action evaluateProximity {
				in data : EnvironmentalData;
				out urgency : Real;
			}
			then action generateStimulus {
				in urgency : Real;
				out stim : ElectricalStimulus;
			}
		}
	}
	
	part def MobileRoboticPlatform {
		doc /* Physical robotic body with sensors and actuators. */
		
		port motorControl : ActuatorPort;
		port environmentSensing : SensorPort;
		
		attribute currentPosition : LengthValue[2];
		attribute batteryLevel : Real;
		
		part leftMotor {
			attribute speed : MovementSpeed;
		}
		
		part rightMotor {
			attribute speed : MovementSpeed;
		}
		
		part proximitySensors[4] {
			attribute range : ProximityDistance;
			attribute angle : Real;
		}
		
		perform action executeMotion {
			in cmd : MotionCommand;
			out newPosition : LengthValue[2];
			
			action setMotorSpeeds {
				in command : MotionCommand;
			}
			then action updatePosition {
				out position : LengthValue[2];
			}
		}
		
		perform action senseEnvironment {
			out environmentalData : EnvironmentalData;
			
			action readSensors {
				out rawData : EnvironmentalData;
			}
		}
	}
	
	part def LifeSupportSystem {
		doc /* Maintains optimal conditions for biological neural tissue. */
		
		attribute temperature : TemperatureValue;
		attribute pH : Real;
		attribute oxygenLevel : Real;
		attribute nutrientConcentration : Real;
		
		perform action maintainCulture {
			action regulateTemperature {
				out temp : TemperatureValue;
			}
			action balancePH {
				out phLevel : Real;
			}
			action supplyNutrients {
				out nutrientLevel : Real;
			}
			action oxygenate {
				out o2Level : Real;
			}
		}
	}
	
	part def Hybrot {
		doc /* A hybrid biological-robotic system that uses living neural tissue for autonomous navigation and obstacle avoidance. */
		
		part neuralNetwork : BiologicalNeuralNetwork;
		part electrodeInterface : MicroelectrodeArray;
		part processor : SignalProcessingUnit;
		part roboticBody : MobileRoboticPlatform;
		part lifeSupport : LifeSupportSystem;
		
		connection neuralToElectrode connect 
			neuralNetwork.neuralInterface to electrodeInterface.biologicalSide;
		
		connection electrodeToProcessor connect 
			electrodeInterface.electronicSide to processor.neuralInput;
		
		connection processorToMotor connect 
			processor.motorOutput to roboticBody.motorControl;
		
		connection sensorToProcessor connect 
			roboticBody.environmentSensing to processor.sensorInput;
		
		connection processorToStimulus connect 
			processor.stimulusOutput to electrodeInterface.biologicalSide;
	}
	
	requirement def AutonomousNavigationRequirement {
		doc /* The Hybrot shall autonomously navigate its environment using biological neural processing. */
		
		subject system : Hybrot;
		
		require constraint biologicalProcessing {
			doc /* Navigation decisions must be generated by biological neural network. */
			system.neuralNetwork.cultureHealth >= 0.85
		}
		
		require constraint realTimeResponse {
			doc /* System must respond to environmental stimuli within acceptable latency. */
			system.processor.processingLatency <= 100 [SI::s] * 0.001
		}
		
		require constraint continuousOperation {
			doc /* System must maintain continuous sensorimotor loop. */
		}
	}
	
	requirement def ObstacleAvoidanceRequirement {
		doc /* The Hybrot shall detect and avoid obstacles through learned neural responses. */
		
		subject system : Hybrot;
		
		require constraint detectionRange {
			doc /* Obstacles must be detected at safe distance. */
		}
		
		require constraint avoidanceResponse {
			doc /* Neural network must generate appropriate avoidance behavior. */
		}
	}
	
	requirement def BiologicalViabilityRequirement {
		doc /* The Hybrot shall maintain viable biological neural tissue throughout operation. */
		
		subject system : Hybrot;
		
		require constraint cultureHealth {
			doc /* Neural culture must remain healthy and responsive. */
			system.neuralNetwork.cultureHealth >= 0.80
		}
		
		require constraint environmentalControl {
			doc /* Life support must maintain optimal conditions. */
			system.lifeSupport.temperature == 310.15 [SI::K] and
			system.lifeSupport.pH >= 7.2 and
			system.lifeSupport.pH <= 7.6
		}
	}
	
	part hybrot : Hybrot {
		part :>> neuralNetwork {
			:>> neuronCount = 100000;
			:>> cultureHealth = 0.92;
			:>> synapticActivity = 0.75;
		}
		
		part :>> electrodeInterface {
			:>> electrodeCount = 60;
			:>> samplingRate = 20000 [SI::Hz];
			:>> impedance = 50000;
		}
		
		part :>> processor {
			:>> processingLatency = 0.05 [SI::s];
			:>> adaptationRate = 0.05;
		}
		
		part :>> roboticBody {
			:>> currentPosition = (0, 0) [SI::mm];
			:>> batteryLevel = 0.85;
		}
		
		part :>> lifeSupport {
			:>> temperature = 310.15 [SI::K];
			:>> pH = 7.4;
			:>> oxygenLevel = 0.95;
			:>> nutrientConcentration = 0.88;
		}
		
		perform action autonomousNavigation {
			doc /* Primary function: Navigate environment autonomously using biological neural processing. */
			
			first start;
			then action maintainLifeSupport : lifeSupport.maintainCulture;
			then merge continuousLoop;
			then action sense : roboticBody.senseEnvironment {
				out environmentalData;
			}
			then action convertToStimulus : processor.translateSensorToStimulus {
				in environmentData = sense.environmentalData;
				out stimulus;
			}
			then action stimulateNeurons : electrodeInterface.deliverStimulation {
				in digitalPattern = convertToStimulus.stimulus;
				out biologicalStimulus;
			}
			then action neuralProcessing : neuralNetwork.processInformation {
				in stimulus = stimulateNeurons.biologicalStimulus;
				out response;
			}
			then action recordNeural : electrodeInterface.recordActivity {
				in biologicalSignal = neuralProcessing.response;
				out digitalSignal;
			}
			then action convertToMotor : processor.translateNeuralToMotor {
				in neuralData = recordNeural.digitalSignal;
				out motorCmd;
			}
			then action executeMovement : roboticBody.executeMotion {
				in cmd = convertToMotor.motorCmd;
				out newPosition;
			}
			then continuousLoop;
		}
		
		satisfy AutonomousNavigationRequirement by hybrot;
		satisfy ObstacleAvoidanceRequirement by hybrot;
		satisfy BiologicalViabilityRequirement by hybrot;
	}
	
	state def HybrotOperationalStates {
		entry start;
		
		state Initialization {
			entry action initializeSystems;
			
			state CultureStabilization {
				do action stabilizeNeuralCulture;
			}
			then state SystemCalibration {
				do action calibrateSensorsAndActuators;
			}
			
			transition to ActiveNavigation when cultureHealth >= 0.85;
		}
		
		state ActiveNavigation {
			do action autonomousNavigation;
			
			state Exploring {
				do action exploreBehavior;
				transition to Avoiding when obstacleDetected;
			}
			
			state Avoiding {
				do action avoidanceBehavior;
				transition to Exploring when pathClear;
			}
			
			transition to Maintenance when batteryLevel < 0.20 or cultureHealth < 0.80;
		}
		
		state Maintenance {
			state Recharging {
				do action rechargeBattery;
				transition to CultureCare when batteryLevel >= 0.90;
			}
			
			state CultureCare {
				do action refreshCultureMedium;
				transition to Initialization when cultureHealth >= 0.85;
			}
		}
		
		state Emergency {
			entry action emergencyShutdown;
		}
		
		transition from any to Emergency when cultureHealth < 0.50;
	}
}
