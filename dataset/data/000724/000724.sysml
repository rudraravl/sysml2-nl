package OxygenatorSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def OxygenSaturationPercentage :> Real;
	attribute def CO2ConcentrationLevel :> Real;
	
	item def VenousBlood {
		attribute oxygenSaturation : OxygenSaturationPercentage;
		attribute co2Level : CO2ConcentrationLevel;
		attribute temperature : TemperatureValue;
		attribute flowRate : VolumeFlowRateValue;
		attribute pressure : PressureValue;
	}
	
	item def ArterialBlood {
		attribute oxygenSaturation : OxygenSaturationPercentage;
		attribute co2Level : CO2ConcentrationLevel;
		attribute temperature : TemperatureValue;
		attribute flowRate : VolumeFlowRateValue;
		attribute pressure : PressureValue;
	}
	
	item def OxygenGas {
		attribute purity : Real;
		attribute flowRate : VolumeFlowRateValue;
		attribute pressure : PressureValue;
	}
	
	item def WasteGas {
		attribute co2Concentration : CO2ConcentrationLevel;
		attribute flowRate : VolumeFlowRateValue;
	}
	
	item def PrimeCommand;
	item def StartCommand;
	item def StopCommand;
	item def EmergencyStopCommand;
	
	port def VenousBloodPort {
		in item venousBlood : VenousBlood;
	}
	
	port def ArterialBloodPort {
		out item arterialBlood : ArterialBlood;
	}
	
	port def OxygenGasPort {
		in item oxygenGas : OxygenGas;
	}
	
	port def WasteGasPort {
		out item wasteGas : WasteGas;
	}
	
	port def SensorPort {
		out attribute saturation : OxygenSaturationPercentage;
		out attribute pressure : PressureValue;
		out attribute temperature : TemperatureValue;
		out attribute flowRate : VolumeFlowRateValue;
	}
	
	part def HollowFiberMembrane {
		attribute surfaceArea : AreaValue;
		attribute fiberCount : Integer;
		attribute permeability : Real;
		
		port bloodSide;
		port gasSide;
		
		perform action exchangeGases {
			in venousBlood : VenousBlood;
			in oxygenSupply : OxygenGas;
			out arterialBlood : ArterialBlood;
			out wasteGas : WasteGas;
		}
	}
	
	part def BloodPump {
		attribute rotationSpeed : FrequencyValue;
		attribute maxFlowCapacity : VolumeFlowRateValue;
		
		port inlet : VenousBloodPort;
		port outlet;
		
		perform action pumpBlood {
			in bloodIn : VenousBlood;
			in targetFlow : VolumeFlowRateValue;
			out bloodOut : VenousBlood;
		}
	}
	
	part def HeatExchanger {
		attribute targetTemperature : TemperatureValue;
		attribute heatingPower : PowerValue;
		
		port bloodInlet;
		port bloodOutlet;
		
		perform action regulateTemperature {
			in bloodIn : VenousBlood;
			out bloodOut : VenousBlood;
		}
	}
	
	part def OxygenSaturationSensor {
		port sensorPort : SensorPort;
		
		perform action measureSaturation {
			in blood : ArterialBlood;
			out saturation : OxygenSaturationPercentage;
		}
	}
	
	part def PressureMonitor {
		port sensorPort : SensorPort;
		
		perform action measurePressure {
			in blood : ArterialBlood;
			out pressure : PressureValue;
		}
	}
	
	part def TemperatureMonitor {
		port sensorPort : SensorPort;
		
		perform action measureTemperature {
			in blood : ArterialBlood;
			out temperature : TemperatureValue;
		}
	}
	
	part def FlowRateSensor {
		port sensorPort : SensorPort;
		
		perform action measureFlow {
			in blood : ArterialBlood;
			out flowRate : VolumeFlowRateValue;
		}
	}
	
	part def ControlModule {
		attribute targetSaturation : OxygenSaturationPercentage;
		attribute targetFlowRate : VolumeFlowRateValue;
		attribute targetTemperature : TemperatureValue;
		attribute maxPressureLimit : PressureValue;
		
		perform action regulateSystem {
			in measuredSaturation : OxygenSaturationPercentage;
			in measuredPressure : PressureValue;
			in measuredTemperature : TemperatureValue;
			in measuredFlow : VolumeFlowRateValue;
			out pumpSpeedCommand : FrequencyValue;
			out oxygenFlowCommand : VolumeFlowRateValue;
			out heaterCommand : PowerValue;
			out alarmSignal : Boolean;
		}
	}
	
	part def SafetyValve {
		attribute pressureThreshold : PressureValue;
		
		perform action releaseExcessPressure {
			in systemPressure : PressureValue;
		}
	}
	
	part def GasFlowRegulator {
		attribute maxOxygenFlow : VolumeFlowRateValue;
		
		port oxygenInlet : OxygenGasPort;
		port oxygenOutlet;
		
		perform action regulateOxygenFlow {
			in oxygenIn : OxygenGas;
			in commandedFlow : VolumeFlowRateValue;
			out oxygenOut : OxygenGas;
		}
	}
	
	part oxygenatorSystem {
		doc /* An extracorporeal membrane oxygenation system that removes carbon dioxide 
		        from blood and adds oxygen, serving as an artificial lung for patients 
		        with respiratory failure. */
		
		port venousInlet : VenousBloodPort;
		port arterialOutlet : ArterialBloodPort;
		port oxygenSupply : OxygenGasPort;
		port wasteGasExhaust : WasteGasPort;
		port systemMonitoring : SensorPort;
		
		attribute systemPressure : PressureValue;
		attribute oxygenSaturation : OxygenSaturationPercentage;
		attribute bloodTemperature : TemperatureValue;
		
		part membrane : HollowFiberMembrane {
			attribute :>> surfaceArea = 2.5 [m^2];
			attribute :>> fiberCount = 50000;
			attribute :>> permeability = 0.92;
		}
		
		part pump : BloodPump {
			attribute :>> rotationSpeed = 3000.0 [Hz];
			attribute :>> maxFlowCapacity = 7.0 [L/min];
		}
		
		part heater : HeatExchanger {
			attribute :>> targetTemperature = 310.15 [K];
			attribute :>> heatingPower = 150.0 [W];
		}
		
		part saturationSensor : OxygenSaturationSensor;
		part pressureMonitor : PressureMonitor;
		part temperatureMonitor : TemperatureMonitor;
		part flowSensor : FlowRateSensor;
		
		part controller : ControlModule {
			attribute :>> targetSaturation = 98.0;
			attribute :>> targetFlowRate = 5.0 [L/min];
			attribute :>> targetTemperature = 310.15 [K];
			attribute :>> maxPressureLimit = 53.3 [kPa];
		}
		
		part safetyValve : SafetyValve {
			attribute :>> pressureThreshold = 60.0 [kPa];
		}
		
		part gasRegulator : GasFlowRegulator {
			attribute :>> maxOxygenFlow = 10.0 [L/min];
		}
		
		connection venousIntake connect venousInlet to pump.inlet;
		connection pumpToHeater connect pump.outlet to heater.bloodInlet;
		connection heaterToMembrane connect heater.bloodOutlet to membrane.bloodSide;
		connection membraneToOutlet connect membrane.bloodSide to arterialOutlet;
		
		connection oxygenInput connect oxygenSupply to gasRegulator.oxygenInlet;
		connection regulatedOxygen connect gasRegulator.oxygenOutlet to membrane.gasSide;
		connection wasteOutput connect membrane.gasSide to wasteGasExhaust;
		
		connection saturationMonitoring connect saturationSensor.sensorPort to systemMonitoring;
		connection pressureMonitoring connect pressureMonitor.sensorPort to systemMonitoring;
		connection temperatureMonitoring connect temperatureMonitor.sensorPort to systemMonitoring;
		connection flowMonitoring connect flowSensor.sensorPort to systemMonitoring;
		
		perform action oxygenateBloodContinuously {
			first start;
			then merge continuousLoop;
			
			action receiveVenousBlood {
				in venousBlood : VenousBlood;
			}
			
			then action pumpBloodThrough : pump.pumpBlood {
				in bloodIn = receiveVenousBlood.venousBlood;
				in targetFlow = controller.targetFlowRate;
				out bloodOut;
			}
			
			then action heatBlood : heater.regulateTemperature {
				in bloodIn = pumpBloodThrough.bloodOut;
				out bloodOut;
			}
			
			then action performGasExchange : membrane.exchangeGases {
				in venousBlood = heatBlood.bloodOut;
				in oxygenSupply;
				out arterialBlood;
				out wasteGas;
			}
			
			then action monitorSaturation : saturationSensor.measureSaturation {
				in blood = performGasExchange.arterialBlood;
				out saturation;
			}
			
			then action monitorPressure : pressureMonitor.measurePressure {
				in blood = performGasExchange.arterialBlood;
				out pressure;
			}
			
			then action monitorTemperature : temperatureMonitor.measureTemperature {
				in blood = performGasExchange.arterialBlood;
				out temperature;
			}
			
			then action monitorFlow : flowSensor.measureFlow {
				in blood = performGasExchange.arterialBlood;
				out flowRate;
			}
			
			then action controlSystem : controller.regulateSystem {
				in measuredSaturation = monitorSaturation.saturation;
				in measuredPressure = monitorPressure.pressure;
				in measuredTemperature = monitorTemperature.temperature;
				in measuredFlow = monitorFlow.flowRate;
				out pumpSpeedCommand;
				out oxygenFlowCommand;
				out heaterCommand;
				out alarmSignal;
			}
			
			then decide;
				if controlSystem.measuredSaturation >= controller.targetSaturation and 
				   controlSystem.measuredPressure <= controller.maxPressureLimit then deliverArterialBlood;
				if controlSystem.measuredSaturation < controller.targetSaturation then adjustOxygenFlow;
				if controlSystem.measuredPressure > controller.maxPressureLimit then activateSafety;
			
			action deliverArterialBlood {
				out arterialBlood : ArterialBlood = performGasExchange.arterialBlood;
			}
			then continuousLoop;
			
			action adjustOxygenFlow : gasRegulator.regulateOxygenFlow {
				in oxygenIn;
				in commandedFlow = controlSystem.oxygenFlowCommand;
				out oxygenOut;
			}
			then continuousLoop;
			
			action activateSafety : safetyValve.releaseExcessPressure {
				in systemPressure = controlSystem.measuredPressure;
			}
			then continuousLoop;
		}
	}
	
	state def OxygenatorOperationalStates {
		entry; then standby;
		
		state standby {
			doc /* System is powered but not actively processing blood. */
		}
		
		transition standby_to_priming
			first standby
			accept PrimeCommand
			then priming;
		
		state priming {
			doc /* System is being filled with saline solution to remove air. */
		}
		
		transition priming_to_ready
			first priming
			then ready;
		
		state ready {
			doc /* System is primed and ready to begin blood oxygenation. */
		}
		
		transition ready_to_operating
			first ready
			accept StartCommand
			then operating;
		
		state operating {
			doc /* System is actively oxygenating blood. */
			
			state normalOperation {
				doc /* All parameters within acceptable ranges. */
			}
			
			transition to_lowSaturation
				first normalOperation
				then lowSaturationAlarm;
			
			state lowSaturationAlarm {
				doc /* Oxygen saturation below minimum threshold. */
			}
			
			transition lowSaturation_to_normal
				first lowSaturationAlarm
				then normalOperation;
			
			transition to_highPressure
				first normalOperation
				then highPressureAlarm;
			
			state highPressureAlarm {
				doc /* System pressure exceeds safe operating limit. */
			}
			
			transition highPressure_to_normal
				first highPressureAlarm
				then normalOperation;
			
			transition to_temperatureAnomaly
				first normalOperation
				then temperatureAlarm;
			
			state temperatureAlarm {
				doc /* Blood temperature outside safe range. */
			}
			
			transition temperature_to_normal
				first temperatureAlarm
				then normalOperation;
		}
		
		transition operating_to_standby
			first operating
			accept StopCommand
			then standby;
		
		transition to_emergency
			first operating
			accept EmergencyStopCommand
			then emergencyShutdown;
		
		state emergencyShutdown {
			doc /* Immediate cessation of all operations due to critical failure. */
		}
		then done;
	}
	
	requirement oxygenatorSystemRequirements {
		doc /* The oxygenator system shall provide safe and effective blood oxygenation 
		        for patients requiring respiratory support. */
		
		requirement <'REQ-001'> primaryFunction {
			doc /* The system shall oxygenate venous blood by removing carbon dioxide and 
			        adding oxygen through a semi-permeable membrane, delivering arterial-quality 
			        blood suitable for patient circulation. */
		}
		
		requirement <'REQ-002'> oxygenationEfficiency {
			doc /* The system shall achieve arterial oxygen saturation of at least 95% 
			        in the output blood under normal operating conditions. */
			
			require constraint {
				oxygenatorSystem.oxygenSaturation >= 95.0
			}
		}
		
		requirement <'REQ-003'> bloodFlowCapacity {
			doc /* The system shall maintain blood flow rates between 1.0 and 7.0 liters 
			        per minute to support varying patient requirements. */
			
			require constraint {
				oxygenatorSystem.pump.maxFlowCapacity >= 1.0 [L/min] and
				oxygenatorSystem.pump.maxFlowCapacity <= 7.0 [L/min]
			}
		}
		
		requirement <'REQ-004'> thermalRegulation {
			doc /* The system shall maintain blood temperature at 310.15 K with tolerance 
			        to prevent hypothermia or thermal injury to blood cells. */
			
			require constraint {
				oxygenatorSystem.heater.targetTemperature >= 309.15 [K] and
				oxygenatorSystem.heater.targetTemperature <= 311.15 [K]
			}
		}
		
		requirement <'REQ-005'> pressureSafety {
			doc /* The system shall not exceed maximum operating pressure and 
			        shall activate safety mechanisms if pressure exceeds safe limit. */
			
			require constraint {
				oxygenatorSystem.controller.maxPressureLimit <= 53.3 [kPa] and
				oxygenatorSystem.safetyValve.pressureThreshold <= 60.0 [kPa]
			}
		}
		
		requirement <'REQ-006'> membranePerformance {
			doc /* The hollow fiber membrane shall provide at least 2.5 m² of gas exchange 
			        surface area with minimum 90% gas transfer efficiency. */
			
			require constraint {
				oxygenatorSystem.membrane.surfaceArea >= 2.5 [m^2] and
				oxygenatorSystem.membrane.permeability >= 0.90
			}
		}
		
		requirement <'REQ-007'> continuousMonitoring {
			doc /* The system shall continuously monitor oxygen saturation, pressure, 
			        temperature, and flow rate with real-time feedback to the control module. */
		}
		
		requirement <'REQ-008'> alarmSystem {
			doc /* The system shall generate alarms when critical parameters deviate from 
			        safe operating ranges and initiate appropriate corrective actions. */
		}
	}
}
