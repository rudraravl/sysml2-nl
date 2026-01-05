package SeedCountingMachineSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SeedCount :> Integer;
	attribute def FlowRate :> Real;
	attribute def Sensitivity :> Real;
	
	item def Seed {
		attribute mass :> ISQ::mass;
		attribute diameter :> ISQ::length;
	}
	
	item def StartCommand;
	item def StopCommand;
	item def ResetCommand;
	item def FeedingStarted;
	item def FirstSeedDetected;
	item def TargetCountReached;
	item def ConveyorCleared;
	item def ErrorDetected;
	item def ErrorCleared;
	
	port def SeedFlowPort {
		in item seedInput : Seed[*];
		out item seedOutput : Seed[*];
		attribute flowRate : FlowRate;
	}
	
	port def SensorSignalPort {
		out attribute detectionPulse : Boolean;
		attribute sensitivity : Sensitivity;
	}
	
	port def ControlPort {
		in attribute startCommand : Boolean;
		in attribute stopCommand : Boolean;
		in attribute resetCommand : Boolean;
		out attribute currentCount : SeedCount;
		out attribute systemStatus : String;
	}
	
	port def PowerPort {
		in attribute voltage :> ISQ::voltage;
		in attribute current :> ISQ::electricCurrent;
	}
	
	port def DisplayPort {
		in attribute countValue : SeedCount;
		in attribute statusMessage : String;
	}
	
	part def HopperFeeder {
		doc /* Stores and dispenses seeds onto the conveyor system at a controlled rate. */
		port seedOutput : SeedFlowPort;
		port power : PowerPort;
		attribute capacity :> ISQ::mass;
		attribute dispensingRate : FlowRate;
	}
	
	part def ConveyorBelt {
		doc /* Transports seeds in single file through the detection zone. */
		port seedInput : SeedFlowPort;
		port seedOutput : SeedFlowPort;
		port power : PowerPort;
		attribute speed :> ISQ::speed;
		attribute beltLength :> ISQ::length;
	}
	
	part def OpticalSensor {
		doc /* Detects individual seeds passing through the sensing zone using optical beam interruption. */
		port seedPassage : SeedFlowPort;
		port detectionSignal : SensorSignalPort;
		port power : PowerPort;
		attribute beamWidth :> ISQ::length;
		attribute responseTime :> ISQ::time;
	}
	
	part def CountingController {
		doc /* Processes detection signals and maintains accurate seed count. */
		port sensorInput : SensorSignalPort;
		port controlInterface : ControlPort;
		port displayOutput : DisplayPort;
		port power : PowerPort;
		attribute accumulatedCount : SeedCount := 0;
		attribute targetCount : SeedCount;
		
		perform action countingLogic : ProcessSeedDetection;
	}
	
	part def DisplayUnit {
		doc /* Shows real-time count and system status to operator. */
		port displayInput : DisplayPort;
		port power : PowerPort;
		attribute displayedCount : SeedCount;
		attribute displayedStatus : String;
	}
	
	part def CollectionBin {
		doc /* Collects counted seeds for packaging or further processing. */
		port seedInput : SeedFlowPort;
		attribute binCapacity :> ISQ::mass;
		attribute currentLoad :> ISQ::mass;
	}
	
	action def ProcessSeedDetection {
		doc /* Core counting logic that increments count on each valid seed detection. */
		in detectionSignal : Boolean;
		in resetFlag : Boolean;
		in targetReached : Boolean;
		inout count : SeedCount;
		out status : String;
		
		first start;
		then merge checkCondition;
		then decide;
			if resetFlag then resetCounter;
			if detectionSignal and not resetFlag and not targetReached then incrementCounter;
			if targetReached then haltCounting;
		
		action resetCounter {
			then assign count := 0;
			then assign status := "Reset";
		}
		then checkCondition;
		
		action incrementCounter {
			then assign count := count + 1;
			then assign status := "Counting";
		}
		then checkCondition;
		
		action haltCounting {
			then assign status := "Complete";
		}
		then done;
	}
	
	action def CountSeedBatch {
		doc /* High-level action coordinating the complete seed counting process from feeding to collection. */
		in batchSize : SeedCount;
		out finalCount : SeedCount;
		
		first start;
		then action initializeSystem {
			out systemReady : Boolean;
		}
		then action activateFeeder {
			in ready = initializeSystem.systemReady;
			out seedsDispensing : Boolean;
		}
		then action transportSeeds {
			in dispensing = activateFeeder.seedsDispensing;
			out seedsMoving : Seed[*];
		}
		then action detectAndCount {
			in seeds = transportSeeds.seedsMoving;
			out detectedCount : SeedCount;
		}
		then action verifyCount {
			in counted = detectAndCount.detectedCount;
			in expected = batchSize;
			out verified : Boolean;
		}
		then action collectSeeds {
			in verification = verifyCount.verified;
		}
		then assign finalCount := detectAndCount.detectedCount;
		then done;
	}
	
	state def SeedCountingOperationalStates {
		doc /* State machine governing the operational modes of the seed counting machine. */
		
		entry; then idle;
		
		state idle {
			doc /* System powered but not actively counting. */
		}
		
		state ready {
			doc /* System initialized and awaiting seed flow. */
		}
		
		state feeding {
			doc /* Hopper actively dispensing seeds onto conveyor. */
		}
		
		state counting {
			doc /* Active counting of seeds passing through sensor. */
		}
		
		state completing {
			doc /* Finalizing count and clearing remaining seeds from conveyor. */
		}
		
		state complete {
			doc /* Batch counting finished, displaying final results. */
		}
		
		state error {
			doc /* System fault requiring operator intervention. */
		}
		
		transition idle_to_ready
			first idle
			accept StartCommand
			then ready;
		
		transition ready_to_feeding
			first ready
			accept FeedingStarted
			then feeding;
		
		transition feeding_to_counting
			first feeding
			accept FirstSeedDetected
			then counting;
		
		transition counting_to_completing
			first counting
			accept TargetCountReached
			then completing;
		
		transition completing_to_complete
			first completing
			accept ConveyorCleared
			then complete;
		
		transition complete_to_idle
			first complete
			accept ResetCommand
			then idle;
		
		transition idle_to_error
			first idle
			accept ErrorDetected
			then error;
		
		transition ready_to_error
			first ready
			accept ErrorDetected
			then error;
		
		transition feeding_to_error
			first feeding
			accept ErrorDetected
			then error;
		
		transition counting_to_error
			first counting
			accept ErrorDetected
			then error;
		
		transition completing_to_error
			first completing
			accept ErrorDetected
			then error;
		
		transition complete_to_error
			first complete
			accept ErrorDetected
			then error;
		
		transition error_to_idle
			first error
			accept ErrorCleared
			then idle;
	}
	
	part def SeedCountingMachine;
	
	part seedCountingMachine : SeedCountingMachine {
		doc /* Complete seed counting machine system integrating all subsystems for automated batch counting. */
		
		attribute machineId : String;
		attribute maxThroughput : FlowRate;
		attribute countingAccuracy : Real;
		
		part hopper : HopperFeeder {
			port hopperOut : SeedFlowPort;
			port hopperPower : PowerPort;
		}
		
		part conveyor : ConveyorBelt {
			port conveyorIn : SeedFlowPort;
			port conveyorOut : SeedFlowPort;
			port conveyorPower : PowerPort;
		}
		
		part sensor : OpticalSensor {
			port sensorFlow : SeedFlowPort;
			port sensorSignal : SensorSignalPort;
			port sensorPower : PowerPort;
		}
		
		part controller : CountingController {
			port controllerSensor : SensorSignalPort;
			port controllerControl : ControlPort;
			port controllerDisplay : DisplayPort;
			port controllerPower : PowerPort;
		}
		
		part display : DisplayUnit {
			port displayData : DisplayPort;
			port displayPower : PowerPort;
		}
		
		part bin : CollectionBin {
			port binIn : SeedFlowPort;
		}
		
		connection hopperToConveyor connect hopper.hopperOut to conveyor.conveyorIn;
		connection conveyorToSensor connect conveyor.conveyorOut to sensor.sensorFlow;
		connection sensorToBin connect sensor.sensorFlow to bin.binIn;
		connection sensorToController connect sensor.sensorSignal to controller.controllerSensor;
		connection controllerToDisplay connect controller.controllerDisplay to display.displayData;
		
		perform action batchCounting : CountSeedBatch[*] ordered;
		exhibit state operationalBehavior : SeedCountingOperationalStates;
	}
	
	requirement def AccuracyRequirement {
		doc /* The seed counting system shall achieve a minimum counting accuracy of 99.5 percent for seeds within the specified size range. */
		
		subject machine : SeedCountingMachine;
		
		require constraint accuracyConstraint {
			machine.countingAccuracy >= 0.995
		}
	}
	
	requirement def ThroughputRequirement {
		doc /* The system shall count a minimum of 1200 seeds per minute during continuous operation. */
		
		subject machine : SeedCountingMachine;
		
		require constraint throughputConstraint {
			machine.maxThroughput >= 1200.0
		}
	}
	
	requirement def ReliabilityRequirement {
		doc /* The system shall operate continuously for at least 8 hours without requiring recalibration or maintenance. */
		
		subject machine : SeedCountingMachine;
		
		attribute minimumUptime :> ISQ::time;
		
		require constraint uptimeConstraint {
			minimumUptime >= 8.0
		}
	}
	
	requirement <'SCM-REQ-001'> seedCountingSystemRequirement {
		doc /* The seed counting machine shall accurately count and display the total number of seeds dispensed from the hopper, transported through the detection zone, and collected in the bin, enabling precise batch preparation for agricultural and research applications. */
		
		subject machine : SeedCountingMachine;
		
		assume constraint seedFlowAssumption {
			doc /* Seeds flow individually through the detection zone without overlapping or jamming. */
		}
		
		assume constraint environmentalAssumption {
			doc /* Operating environment is free from excessive dust, moisture, and electromagnetic interference. */
		}
		
		require accuracyReq : AccuracyRequirement;
		require throughputReq : ThroughputRequirement;
		require reliabilityReq : ReliabilityRequirement;
	}
}
