package 'Water Pumping System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def WaterLevelValue :> Real;
	attribute def FlowControlCommand;
	
	enum def PumpOperatingMode {
		off;
		starting;
		running;
		stopping;
	}
	
	item def Water {
		attribute temperature : ThermodynamicTemperatureValue;
		attribute quality : Real;
	}
	
	port def WaterFlowPort {
		inout item waterStream : Water;
		attribute flowRate : VolumeFlowRateValue;
		attribute pressure : PressureValue;
	}
	
	port def SensorPort {
		out levelReading : LengthValue;
	}
	
	port def ControlPort {
		in commandSignal : FlowControlCommand;
		out statusFeedback : PumpOperatingMode;
	}
	
	part def SourceReservoir {
		attribute capacity : VolumeValue;
		attribute currentVolume : VolumeValue;
		out port outlet : WaterFlowPort;
	}
	
	part def DestinationTank {
		attribute capacity : VolumeValue;
		attribute currentLevel : LengthValue;
		attribute lowLevelThreshold : LengthValue;
		attribute highLevelThreshold : LengthValue;
		in port inlet : WaterFlowPort;
		out port levelSensorPort : SensorPort;
	}
	
	action def TransferWater {
		in sourceFlow : VolumeFlowRateValue;
		in operatingTime : TimeValue;
		out deliveredFlow : VolumeFlowRateValue;
		out volumeTransferred : VolumeValue;
	}
	
	part def WaterPump {
		attribute ratedFlowRate : VolumeFlowRateValue;
		attribute ratedPower : PowerValue;
		attribute efficiency : Real;
		attribute operatingState : PumpOperatingMode;
		in port waterInlet : WaterFlowPort;
		out port waterOutlet : WaterFlowPort;
		in port control : ControlPort;
		
		exhibit state pumpBehavior {
			entry; then idle;
			
			state idle {
				entry assign operatingState := PumpOperatingMode::off;
			}
			accept at idle then starting;
			
			state starting {
				entry assign operatingState := PumpOperatingMode::starting;
			}
			accept at starting then running;
			
			state running {
				entry assign operatingState := PumpOperatingMode::running;
				do action pumpWater : TransferWater {
					in sourceFlow = waterInlet.flowRate;
					out deliveredFlow : VolumeFlowRateValue;
				}
			}
			accept at running then stopping;
			
			state stopping {
				entry assign operatingState := PumpOperatingMode::stopping;
			}
			accept at stopping then idle;
		}
	}
	
	part def LevelSensor {
		attribute accuracy : LengthValue;
		attribute measurementRange : LengthValue;
		in port sensingPoint : SensorPort;
		out port dataOutput : SensorPort;
		
		action def MeasureLevel {
			in tankLevel : LengthValue;
			out measuredLevel : LengthValue;
		}
	}
	
	part def PumpController {
		attribute lowSetpoint : LengthValue;
		attribute highSetpoint : LengthValue;
		attribute hysteresis : LengthValue;
		in port levelInput : SensorPort;
		out port pumpCommand : ControlPort;
		
		perform action controlCycle : ManageWaterLevel;
	}
	
	action def MonitorLevel {
		in tankLevel : LengthValue;
		out currentReading : LengthValue;
	}
	
	action def EvaluateControl {
		in measuredLevel : LengthValue;
		in lowThreshold : LengthValue;
		in highThreshold : LengthValue;
		out pumpShouldRun : Boolean;
	}
	
	action def IssuePumpCommand {
		in shouldActivate : Boolean;
		out command : FlowControlCommand;
	}
	
	action def ManageWaterLevel {
		in lowLimit : LengthValue;
		in highLimit : LengthValue;
		out activePumpCommand : FlowControlCommand;
		
		first start;
		then merge controlLoop;
		
		then action monitorAction : MonitorLevel {
			out currentReading : LengthValue;
		}
		
		then action evaluateAction : EvaluateControl {
			in measuredLevel = monitorAction.currentReading;
			in lowThreshold = lowLimit;
			in highThreshold = highLimit;
			out pumpShouldRun : Boolean;
		}
		
		then decide;
			if evaluateAction.pumpShouldRun then startPump;
			if not evaluateAction.pumpShouldRun then stopPump;
		
		action startPump : IssuePumpCommand {
			in shouldActivate = true;
			out command : FlowControlCommand;
		}
		then assign activePumpCommand := startPump.command;
		then controlLoop;
		
		action stopPump : IssuePumpCommand {
			in shouldActivate = false;
			out command : FlowControlCommand;
		}
		then assign activePumpCommand := stopPump.command;
		then controlLoop;
	}
	
	part def WaterPumpingSystem {
		doc /* 
		The water pumping system automatically transfers water from a source reservoir 
		to a destination tank while maintaining the tank water level within specified 
		operational limits. The system continuously monitors the destination tank level 
		and activates the pump when the level falls below a low threshold, then 
		deactivates it when the level reaches a high threshold, ensuring reliable 
		water supply and preventing overflow.
		*/
		
		part source : SourceReservoir;
		part destination : DestinationTank;
		part transferPump : WaterPump;
		part levelMonitor : LevelSensor;
		part automationController : PumpController;
		
		connect source.outlet to transferPump.waterInlet;
		connect transferPump.waterOutlet to destination.inlet;
		connect destination.levelSensorPort to levelMonitor.sensingPoint;
		connect levelMonitor.dataOutput to automationController.levelInput;
		connect automationController.pumpCommand to transferPump.control;
	}
	
	part waterPumpingSystem : WaterPumpingSystem {
		part redefines source {
			attribute :>> capacity = 50000.0 [L];
			attribute :>> currentVolume = 45000.0 [L];
		}
		
		part redefines destination {
			attribute :>> capacity = 10000.0 [L];
			attribute :>> currentLevel = 1.5 [m];
			attribute :>> lowLevelThreshold = 2.0 [m];
			attribute :>> highLevelThreshold = 8.0 [m];
		}
		
		part redefines transferPump {
			attribute :>> ratedFlowRate = 100.0 [L/min];
			attribute :>> ratedPower = 5.5 [kW];
			attribute :>> efficiency = 0.85;
		}
		
		part redefines levelMonitor {
			attribute :>> accuracy = 0.01 [m];
			attribute :>> measurementRange = 10.0 [m];
		}
		
		part redefines automationController {
			attribute :>> lowSetpoint = destination.lowLevelThreshold;
			attribute :>> highSetpoint = destination.highLevelThreshold;
			attribute :>> hysteresis = 0.1 [m];
		}
	}
	
	requirement def SystemRequirement {
		doc /* Base requirement definition for water pumping system. */
	}
	
	requirement <'WPS-REQ-001'> primaryFunction : SystemRequirement {
		doc /* 
		The water pumping system shall automatically transfer water from a source 
		reservoir to a destination tank, maintaining the destination tank water level 
		between defined low and high thresholds through continuous monitoring and 
		automated pump control.
		*/
		subject waterPumpingSystem;
	}
	
	requirement <'WPS-REQ-002'> levelControl : SystemRequirement {
		doc /* 
		The system shall activate the pump when the destination tank level falls 
		below the low threshold and deactivate the pump when the level reaches 
		the high threshold.
		*/
		subject waterPumpingSystem.automationController;
		
		assume constraint levelBelowLow {
			waterPumpingSystem.destination.currentLevel < 
			waterPumpingSystem.destination.lowLevelThreshold
		}
		
		require constraint pumpActivated {
			waterPumpingSystem.transferPump.operatingState == PumpOperatingMode::running
		}
	}
	
	requirement <'WPS-REQ-003'> flowCapacity : SystemRequirement {
		doc /* 
		The pump shall deliver a minimum flow rate of 100 liters per minute 
		when operating under normal conditions.
		*/
		subject waterPumpingSystem.transferPump;
		
		require constraint minimumFlow {
			waterPumpingSystem.transferPump.ratedFlowRate >= 100.0 [L/min]
		}
	}
	
	requirement <'WPS-REQ-004'> levelMonitoring : SystemRequirement {
		doc /* 
		The level sensor shall continuously monitor the destination tank water 
		level with an accuracy of ±10mm.
		*/
		subject waterPumpingSystem.levelMonitor;
		
		require constraint sensorAccuracy {
			waterPumpingSystem.levelMonitor.accuracy <= 0.01 [m]
		}
	}
	
	requirement <'WPS-REQ-005'> operationalReliability : SystemRequirement {
		doc /* 
		The water pumping system shall operate continuously with 99% uptime 
		to ensure consistent water availability.
		*/
		subject waterPumpingSystem;
	}
	
	requirement systemMission {
		doc /* 
		The water pumping system mission is to provide reliable, automated 
		water transfer and level management.
		*/
		subject waterPumpingSystem;
		
		require primaryFunction;
		require levelControl;
		require flowCapacity;
		require levelMonitoring;
		require operationalReliability;
	}
}
