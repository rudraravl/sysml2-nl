package 'Entertainment Robot System' {
	private import ScalarValues::*;
	private import SI::*;
	
	attribute def BatteryLevel :> Real;
	attribute def SoundLevel :> Real;
	attribute def MotionSpeed :> Real;
	attribute def Duration :> Real;
	attribute def EngagementScore :> Real;
	
	enum def RobotState {
		enum idle;
		enum performing;
		enum interacting;
		enum charging;
		enum error;
	}
	
	enum def PerformanceMode {
		enum dance;
		enum music;
		enum storytelling;
		enum comedy;
	}
	
	item def PowerSupply {
		attribute voltage : Real;
		attribute current : Real;
	}
	
	item def AudioSignal {
		attribute frequency : Real;
		attribute amplitude : Real;
	}
	
	item def MotionCommand {
		attribute velocity : MotionSpeed;
		attribute direction : Real;
	}
	
	item def SensorReading {
		attribute timestamp : Real;
		attribute value : Real;
	}
	
	port def PowerPort {
		in item powerIn : PowerSupply;
		out attribute batteryStatus : BatteryLevel;
	}
	
	port def AudioPort {
		out item audioOut : AudioSignal;
		in attribute volumeControl : SoundLevel;
	}
	
	port def MotionPort {
		out item motionCmd : MotionCommand;
		in attribute speedLimit : MotionSpeed;
	}
	
	port def SensorPort {
		in item sensorData : SensorReading;
		out attribute detectionFlag : Boolean;
	}
	
	action def MonitorAudience {
		out audiencePresent : Boolean;
		out engagementLevel : EngagementScore;
	}
	
	action def PerformDance {
		in choreography : String;
		in tempo : MotionSpeed;
		out danceComplete : Boolean;
	}
	
	action def PlayMusic {
		in track : String;
		in volume : SoundLevel;
		out musicComplete : Boolean;
	}
	
	action def TellStory {
		in narrative : String;
		in expression : Real;
		out storyComplete : Boolean;
	}
	
	action def PerformComedy {
		in routine : String;
		out comedyComplete : Boolean;
	}
	
	action def CheckBatteryLevel {
		out currentLevel : BatteryLevel;
		out lowBattery : Boolean;
	}
	
	action def NavigateToCharger {
		in chargerLocation : Real;
		out arrived : Boolean;
	}
	
	action def InitiateCharging {
		out chargingActive : Boolean;
	}
	
	action def PerformEntertainment {
		in mode : PerformanceMode;
		in duration : Duration;
		
		first start;
		then action checkBattery : CheckBatteryLevel;
		then decide;
			if checkBattery.lowBattery then navigateCharge;
			if !checkBattery.lowBattery then monitorAudience;
		
		action monitorAudience : MonitorAudience;
		then decide;
			if monitorAudience.audiencePresent then selectPerformance;
			if !monitorAudience.audiencePresent then start;
		
		action selectPerformance {
			then decide;
				if mode == PerformanceMode::dance then danceAction;
				if mode == PerformanceMode::music then musicAction;
				if mode == PerformanceMode::storytelling then storyAction;
				if mode == PerformanceMode::comedy then comedyAction;
		}
		
		action danceAction : PerformDance {
			in choreography = "routine_alpha";
			in tempo = 1.5;
		}
		then checkBattery;
		
		action musicAction : PlayMusic {
			in track = "entertainment_suite";
			in volume = 75.0;
		}
		then checkBattery;
		
		action storyAction : TellStory {
			in narrative = "adventure_tale";
			in expression = 0.85;
		}
		then checkBattery;
		
		action comedyAction : PerformComedy {
			in routine = "standup_set";
		}
		then checkBattery;
		
		action navigateCharge {
			action navigate : NavigateToCharger {
				in chargerLocation = 0.0;
			}
			then action charge : InitiateCharging;
			then start;
		}
		
		then done;
	}
	
	part def BatterySystem {
		port powerPort : PowerPort;
		attribute capacity : Real;
		attribute currentCharge : BatteryLevel;
		attribute minCharge : BatteryLevel = 15.0;
		
		action checkBattery : CheckBatteryLevel;
	}
	
	part def SensorSystem {
		port sensorPort : SensorPort;
		attribute range : Real;
		attribute sensitivity : Real;
		
		action detectAudience : MonitorAudience;
	}
	
	part def AudioSystem {
		port audioPort : AudioPort;
		attribute maxVolume : SoundLevel;
		attribute currentVolume : SoundLevel;
		
		action playAudio : PlayMusic;
		action speakNarrative : TellStory;
	}
	
	part def MotionSystem {
		port motionPort : MotionPort;
		attribute maxSpeed : MotionSpeed;
		attribute currentSpeed : MotionSpeed;
		
		action executeMotion : PerformDance;
		action navigate : NavigateToCharger;
	}
	
	part def ChargingStation {
		port powerOutput : PowerPort;
		attribute chargingRate : Real;
		attribute location : Real;
	}
	
	part def EntertainmentRobot {
		attribute robotState : RobotState;
		attribute operationTime : Duration;
		
		port powerInterface : PowerPort;
		port audioInterface : AudioPort;
		port motionInterface : MotionPort;
		port sensorInterface : SensorPort;
		
		part battery : BatterySystem {
			attribute :>> capacity = 5000.0;
			attribute :>> currentCharge = 100.0;
			connect powerPort to powerInterface;
		}
		
		part sensors : SensorSystem {
			attribute :>> range = 5.0;
			attribute :>> sensitivity = 0.9;
			connect sensorPort to sensorInterface;
		}
		
		part audio : AudioSystem {
			attribute :>> maxVolume = 85.0;
			attribute :>> currentVolume = 70.0;
			connect audioPort to audioInterface;
		}
		
		part motion : MotionSystem {
			attribute :>> maxSpeed = 2.0;
			attribute :>> currentSpeed = 0.0;
			connect motionPort to motionInterface;
		}
		
		perform action primaryTask : PerformEntertainment;
	}
	
	state def EntertainmentRobotBehavior {
		entry action initialize;
		
		state idle {
			entry action standby;
			do action monitorForAudience : MonitorAudience;
		}
		
		state performing {
			entry action startShow;
			
			state dancing {
				do action executeDance : PerformDance {
					in choreography = "main_routine";
					in tempo = 1.2;
				}
			}
			
			state playingMusic {
				do action playTrack : PlayMusic {
					in track = "show_music";
					in volume = 75.0;
				}
			}
			
			state telling {
				do action narrate : TellStory {
					in narrative = "story_content";
					in expression = 0.8;
				}
			}
			
			state joking {
				do action performJokes : PerformComedy {
					in routine = "comedy_routine";
				}
			}
			
			exit action endShow;
		}
		
		state interacting {
			do action respondToAudience : MonitorAudience;
		}
		
		state charging {
			entry action dockToCharger;
			do action recharge : InitiateCharging;
			exit action undock;
		}
		
		state error {
			entry action logError;
			do action diagnostics;
		}
		
		transition idleToPerforming
			first idle
			accept at startTime
			then performing;
		
		transition performingToInteracting
			first performing
			accept at interactionTime
			then interacting;
		
		transition interactingToPerforming
			first interacting
			accept at resumeTime
			then performing;
		
		transition anyToCharging
			first idle
			accept at chargeTime
			then charging;
		
		transition chargingToIdle
			first charging
			accept at chargeComplete
			then idle;
		
		transition anyToError
			first performing
			accept at errorTime
			then error;
		
		transition errorToIdle
			first error
			accept at recoveryTime
			then idle;
	}
	
	package LogicalModel {
		action def ProvideEntertainment;
		action def ExecutePrimaryTask;
		
		part def EntertainmentProvider;
		
		action provideEntertainment : ProvideEntertainment {
			action executePrimaryTask : ExecutePrimaryTask;
		}
		
		part entertainmentProvider : EntertainmentProvider {
			perform provideEntertainment.executePrimaryTask;
		}
	}
	
	package PhysicalModel {
		private import LogicalModel::*;
		
		part def RoboticEntertainmentSystem {
			part robot : EntertainmentRobot;
			part charger : ChargingStation;
		}
		
		part roboticSystem : RoboticEntertainmentSystem {
			part :>> robot : EntertainmentRobot {
				attribute :>> robotState = RobotState::idle;
				attribute :>> operationTime = 0.0;
				
				perform action :>> primaryTask : PerformEntertainment {
					in mode = PerformanceMode::dance;
					in duration = 300.0;
				}
				
				state behavior : EntertainmentRobotBehavior;
			}
			
			part :>> charger : ChargingStation {
				attribute :>> chargingRate = 50.0;
				attribute :>> location = 10.0;
			}
			
			connect robot.powerInterface to charger.powerOutput;
		}
		
		allocation def LogicalToPhysicalAllocation {
			end logical : EntertainmentProvider;
			end physical : RoboticEntertainmentSystem;
		}
		
		allocation systemAllocation : LogicalToPhysicalAllocation
			allocate entertainmentProvider to roboticSystem {
				allocate entertainmentProvider.executePrimaryTask 
					to roboticSystem.robot.primaryTask;
			}
	}
	
	requirement def PrimaryTaskRequirement {
		doc /* The robotic system shall perform its primary task using an entertainment robot. */
		
		subject robotSystem : PhysicalModel::RoboticEntertainmentSystem;
		
		require constraint entertainmentCapability {
			doc /* The robot shall provide entertainment through multiple performance modes. */
			robotSystem.robot.audio.maxVolume <= 85.0 and
			robotSystem.robot.motion.maxSpeed <= 2.0
		}
		
		require constraint autonomousOperation {
			doc /* The robot shall operate autonomously including battery management. */
			robotSystem.robot.battery.capacity >= 4000.0 and
			robotSystem.robot.battery.minCharge >= 10.0
		}
		
		require constraint safetyCompliance {
			doc /* The robot shall operate within safe sound and motion limits. */
			robotSystem.robot.audio.maxVolume <= 85.0
		}
	}
	
	requirement primaryTaskReq : PrimaryTaskRequirement {
		subject robotSystem = PhysicalModel::roboticSystem;
	}
	
	verification def VerifyEntertainmentTask {
		subject testRobot : EntertainmentRobot;
		
		objective verifyPrimaryTask {
			doc /* Verify robot successfully performs entertainment task. */
		}
		
		return verdict : Boolean;
	}
	
	verification entertainmentVerification : VerifyEntertainmentTask {
		subject testRobot :> PhysicalModel::roboticSystem.robot;
	}
	
	individual def TestSystem :> PhysicalModel::RoboticEntertainmentSystem;
	individual def TestRobot1 :> EntertainmentRobot;
	individual def TestRobot2 :> EntertainmentRobot;
	
	individual testSystem : TestSystem :> PhysicalModel::roboticSystem {
		timeslice test1 {
			perform action :>> robot.primaryTask {
				in :>> mode = PerformanceMode::dance;
				in :>> duration = 180.0;
			}
		}
		then timeslice test2 {
			perform action :>> robot.primaryTask {
				in :>> mode = PerformanceMode::music;
				in :>> duration = 240.0;
			}
		}
		then timeslice test3 {
			perform action :>> robot.primaryTask {
				in :>> mode = PerformanceMode::storytelling;
				in :>> duration = 300.0;
			}
		}
	}
}
