package 'Cooling Tower System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def WaterTemperature :> TemperatureValue;
	attribute def WaterFlowRate :> VolumeFlowRateValue;
	attribute def AirFlowRate :> VolumeFlowRateValue;
	attribute def HumidityRatio :> Real;
	attribute def FanSpeed :> AngularVelocityValue;
	attribute def PumpPressure :> PressureValue;
	attribute def HeatLoad :> PowerValue;
	
	attribute def StartCommand;
	attribute def StopCommand;
	attribute def EmergencyStop;
	
	item def WaterStream {
		attribute temperature : WaterTemperature;
		attribute flowRate : WaterFlowRate;
	}
	
	item def AirStream {
		attribute temperature : WaterTemperature;
		attribute flowRate : AirFlowRate;
		attribute humidity : HumidityRatio;
	}
	
	port def WaterInletPort {
		in item hotWater : WaterStream;
	}
	
	port def WaterOutletPort {
		out item cooledWater : WaterStream;
	}
	
	port def AirInletPort {
		in item ambientAir : AirStream;
	}
	
	port def AirOutletPort {
		out item exhaustAir : AirStream;
	}
	
	part def InducedDraftFan {
		doc /* Draws ambient air through the tower to facilitate evaporative cooling. */
		attribute operatingSpeed : FanSpeed;
		attribute maxSpeed : FanSpeed;
		attribute powerConsumption : PowerValue;
		port airIn : AirInletPort;
		port airOut : AirOutletPort;
	}
	
	part def WaterDistributionSystem {
		doc /* Distributes hot water evenly over the fill media. */
		attribute distributionPressure : PumpPressure;
		attribute nozzleCount : Integer;
		port waterIn : WaterInletPort;
		port waterOut : WaterOutletPort;
	}
	
	part def FillMedia {
		doc /* Provides surface area for water-air contact to maximize heat transfer. */
		attribute surfaceArea : AreaValue;
		attribute thermalEfficiency : Real;
		attribute packingType : String;
	}
	
	part def ColdWaterBasin {
		doc /* Collects and stores cooled water at the base of the tower. */
		attribute capacity : VolumeValue;
		attribute currentLevel : LengthValue;
		attribute minLevel : LengthValue;
		attribute maxLevel : LengthValue;
		port waterIn : WaterInletPort;
		port waterOut : WaterOutletPort;
	}
	
	part def CirculationPump {
		doc /* Circulates cooled water from basin to process and returns hot water. */
		attribute operatingPressure : PumpPressure;
		attribute flowCapacity : WaterFlowRate;
		attribute powerConsumption : PowerValue;
		port suction : WaterInletPort;
		port discharge : WaterOutletPort;
	}
	
	part def TemperatureSensor {
		doc /* Monitors water temperature at inlet and outlet. */
		attribute measuredTemp : WaterTemperature;
		attribute accuracy : TemperatureValue;
	}
	
	part def ControlSystem {
		doc /* Manages tower operation based on temperature and flow conditions. */
		attribute targetOutletTemp : WaterTemperature;
		attribute currentInletTemp : WaterTemperature;
		attribute currentOutletTemp : WaterTemperature;
		attribute fanSpeedCommand : FanSpeed;
		attribute pumpSpeedCommand : Real;
	}
	
	action def MonitorTemperatures {
		in inletTemp : WaterTemperature;
		in outletTemp : WaterTemperature;
		in targetTemp : WaterTemperature;
		out temperatureDelta : WaterTemperature;
		out coolingRequired : Boolean;
	}
	
	action def CalculateFanSpeed {
		in currentOutletTemp : WaterTemperature;
		in targetOutletTemp : WaterTemperature;
		in heatLoad : HeatLoad;
		out commandedFanSpeed : FanSpeed;
	}
	
	action def DistributeWater {
		in hotWaterStream : WaterStream;
		in distributionPressure : PumpPressure;
		out distributedWater : WaterStream;
	}
	
	action def EvaporativeCooling {
		in waterIn : WaterStream;
		in airIn : AirStream;
		in fanSpeed : FanSpeed;
		in fillEfficiency : Real;
		out waterOut : WaterStream;
		out airOut : AirStream;
		out evaporationRate : VolumeFlowRateValue;
	}
	
	action def CollectCooledWater {
		in cooledWaterStream : WaterStream;
		in basinLevel : LengthValue;
		out basinWater : WaterStream;
		out levelStatus : Boolean;
	}
	
	action def PerformCooling {
		doc /* Primary cooling action that orchestrates the heat rejection process. */
		in hotWaterIn : WaterStream;
		in ambientAirIn : AirStream;
		in targetOutletTemp : WaterTemperature;
		in startCmd : StartCommand;
		in stopCmd : StopCommand;
		out cooledWaterOut : WaterStream;
		out exhaustAirOut : AirStream;
		out operatingHistory : WaterStream[*] := ( );
		
		private attribute currentFanSpeed : FanSpeed := 0.0 [rad/s];
		private attribute currentWaterTemp : WaterTemperature;
		
		first start;
		then merge continueCooling;
		
		then action monitor : MonitorTemperatures {
			in inletTemp = hotWaterIn.temperature;
			in outletTemp = currentWaterTemp;
			in targetTemp = targetOutletTemp;
			out temperatureDelta;
			out coolingRequired;
		}
		
		then decide;
			if monitor.coolingRequired then adjustFan;
			if not monitor.coolingRequired then maintainFan;
		
		action adjustFan : CalculateFanSpeed {
			in currentOutletTemp = currentWaterTemp;
			in targetOutletTemp = PerformCooling::targetOutletTemp;
			in heatLoad;
			out commandedFanSpeed;
		}
		then distribute;
		
		action maintainFan : CalculateFanSpeed {
			in currentOutletTemp = currentWaterTemp;
			in targetOutletTemp = PerformCooling::targetOutletTemp;
			in heatLoad;
			out commandedFanSpeed;
		}
		then distribute;
		
		action distribute : DistributeWater {
			in hotWaterStream = hotWaterIn;
			in distributionPressure;
			out distributedWater;
		}
		
		flow distribute.distributedWater to evaporate.waterIn;
		
		action evaporate : EvaporativeCooling {
			in waterIn;
			in airIn = ambientAirIn;
			in fanSpeed = currentFanSpeed;
			in fillEfficiency;
			out waterOut;
			out airOut;
			out evaporationRate;
		}
		
		flow evaporate.waterOut to collect.cooledWaterStream;
		
		action collect : CollectCooledWater {
			in cooledWaterStream;
			in basinLevel;
			out basinWater;
			out levelStatus;
		}
		
		then assign currentWaterTemp := collect.basinWater.temperature;
		then assign cooledWaterOut := collect.basinWater;
		then assign exhaustAirOut := evaporate.airOut;
		then assign currentFanSpeed := adjustFan.commandedFanSpeed;
		then assign operatingHistory := operatingHistory->including(cooledWaterOut);
		then continueCooling;
	}
	
	part def CoolingTower {
		doc /* 
		An evaporative heat rejection device that removes waste heat from water 
		by bringing it into direct contact with ambient air. The primary function 
		is to cool a continuous stream of hot process water through evaporative 
		cooling, where a portion of the water evaporates into the air stream, 
		removing heat from the remaining water which is collected and recirculated.
		*/
		
		port hotWaterInlet : WaterInletPort;
		port cooledWaterOutlet : WaterOutletPort;
		port airIntake : AirInletPort;
		port airExhaust : AirOutletPort;
		
		part fan : InducedDraftFan {
			port redefines airIn connect to airIntake;
			port redefines airOut connect to airExhaust;
		}
		
		part waterDistribution : WaterDistributionSystem {
			port redefines waterIn connect to hotWaterInlet;
		}
		
		part fill : FillMedia;
		
		part basin : ColdWaterBasin;
		
		part pump : CirculationPump {
			port redefines discharge connect to cooledWaterOutlet;
		}
		
		part inletSensor : TemperatureSensor;
		part outletSensor : TemperatureSensor;
		
		part controller : ControlSystem;
		
		connect waterDistribution.waterOut to fill.waterIn;
		connect fill.waterOut to basin.waterIn;
		connect basin.waterOut to pump.suction;
		
		perform action coolingOperation : PerformCooling {
			in hotWaterIn = hotWaterInlet.hotWater;
			in ambientAirIn = airIntake.ambientAir;
			in targetOutletTemp = controller.targetOutletTemp;
			in startCmd;
			in stopCmd;
			out cooledWaterOut = cooledWaterOutlet.cooledWater;
			out exhaustAirOut = airExhaust.exhaustAir;
		}
		
		exhibit state machine TowerOperationStates {
			initial state Idle;
			
			state Idle {
				entry assign controller.fanSpeedCommand = 0.0 [rad/s];
			}
			
			state Startup {
				entry assign controller.fanSpeedCommand = fan.maxSpeed * 0.3;
			}
			
			state NormalOperation {
				entry assign controller.fanSpeedCommand = fan.operatingSpeed;
			}
			
			state HighLoad {
				entry assign controller.fanSpeedCommand = fan.maxSpeed;
			}
			
			state Shutdown {
				entry assign controller.fanSpeedCommand = 0.0 [rad/s];
			}
			
			state Emergency {
				entry assign controller.fanSpeedCommand = 0.0 [rad/s];
			}
			
			transition from Idle to Startup on StartCommand;
			transition from Startup to NormalOperation 
				when outletSensor.measuredTemp <= controller.targetOutletTemp;
			transition from NormalOperation to HighLoad 
				when outletSensor.measuredTemp > controller.targetOutletTemp + 5.0 [K];
			transition from HighLoad to NormalOperation 
				when outletSensor.measuredTemp <= controller.targetOutletTemp;
			transition from NormalOperation to Shutdown on StopCommand;
			transition from HighLoad to Shutdown on StopCommand;
			transition from Startup to Shutdown on StopCommand;
			transition from NormalOperation to Emergency on EmergencyStop;
			transition from HighLoad to Emergency on EmergencyStop;
			transition from Emergency to Idle;
			transition from Shutdown to Idle;
		}
	}
	
	requirement def CoolingCapacityRequirement {
		doc /* The cooling tower shall achieve specified temperature reduction. */
		attribute inletTemp : WaterTemperature;
		attribute outletTemp : WaterTemperature;
		attribute requiredApproach : WaterTemperature;
		
		require constraint {
			(inletTemp - outletTemp) >= requiredApproach
		}
	}
	
	requirement def HeatRejectionRequirement {
		doc /* The cooling tower shall reject specified thermal load. */
		attribute designHeatLoad : PowerValue;
		attribute actualHeatLoad : PowerValue;
		
		require constraint {
			actualHeatLoad >= designHeatLoad
		}
	}
	
	requirement def WaterFlowRequirement {
		doc /* The cooling tower shall maintain design water flow rate. */
		attribute designFlowRate : WaterFlowRate;
		attribute actualFlowRate : WaterFlowRate;
		attribute tolerance : Real;
		
		require constraint {
			actualFlowRate >= designFlowRate * (1.0 - tolerance) and
			actualFlowRate <= designFlowRate * (1.0 + tolerance)
		}
	}
	
	requirement def EfficiencyRequirement {
		doc /* The cooling tower shall operate within energy efficiency limits. */
		attribute maxPowerConsumption : PowerValue;
		attribute actualPowerConsumption : PowerValue;
		
		require constraint {
			actualPowerConsumption <= maxPowerConsumption
		}
	}
	
	requirement def SafetyRequirement {
		doc /* The cooling tower shall maintain safe operating conditions. */
		attribute maxWaterTemp : WaterTemperature;
		attribute minBasinLevel : LengthValue;
	}
	
	requirement coolingTowerSystemRequirements {
		doc /* Top-level requirements for cooling tower system performance and safety. */
		
		require coolingCapacity : CoolingCapacityRequirement;
		require heatRejection : HeatRejectionRequirement;
		require waterFlow : WaterFlowRequirement;
		require efficiency : EfficiencyRequirement;
		require safety : SafetyRequirement;
	}
	
	part industrialCoolingTower : CoolingTower {
		doc /* 
		Industrial cooling tower system for continuous heat rejection from process water.
		Primary Function: Remove waste heat from circulating water through evaporative 
		cooling by bringing hot water into direct contact with ambient air, thereby 
		reducing water temperature to enable reuse in industrial processes, HVAC systems, 
		or power generation applications.
		*/
		
		satisfy coolingTowerSystemRequirements;
	}
}
