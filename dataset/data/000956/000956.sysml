package 'Water Well Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	package Definitions {
		item def Water {
			attribute temperature : ThermodynamicTemperatureValue;
			attribute pressure : PressureValue;
			attribute flowRate : VolumeFlowRateValue;
		}
		
		port def WaterPort {
			out item water : Water;
		}
		
		part def WellCasing {
			attribute depth : LengthValue;
			attribute diameter : LengthValue;
			attribute staticWaterLevel : LengthValue;
			port waterSource : WaterPort;
		}
		
		part def WellPump {
			attribute ratedPower : PowerValue;
			attribute maxFlowRate : VolumeFlowRateValue;
			attribute maxHead : LengthValue;
			attribute efficiency : Real;
			attribute motorCurrent : ElectricCurrentValue;
			attribute maxCurrent : ElectricCurrentValue;
			attribute isRunning : Boolean default false;
			
			port waterInlet : ~WaterPort;
			port waterOutlet : WaterPort;
			port powerInput;
			
			perform action pumpOperation : PumpWater;
			
			state pumpStateMachine : PumpControlStateMachine;
		}
		
		part def PressureTank {
			attribute capacity : VolumeValue;
			attribute currentVolume : VolumeValue;
			attribute maxPressure : PressureValue;
			attribute currentPressure : PressureValue;
			attribute preChargePressure : PressureValue;
			
			port waterInlet : ~WaterPort;
			port waterOutlet : WaterPort;
			
			item storedWater : Water {
				attribute volume : VolumeValue;
			}
		}
		
		part def PressureSwitch {
			attribute cutInPressure : PressureValue;
			attribute cutOutPressure : PressureValue;
			attribute measuredPressure : PressureValue;
			
			port sensorPort;
			port controlPort;
		}
		
		part def CheckValve {
			attribute crackingPressure : PressureValue;
			attribute isOpen : Boolean default false;
			
			port upstream : ~WaterPort;
			port downstream : WaterPort;
		}
		
		part def FlowMeter {
			attribute measuredFlowRate : VolumeFlowRateValue;
			attribute totalVolume : VolumeValue;
			
			port measurementPort;
		}
		
		part def ControlPanel {
			attribute cutInSetpoint : PressureValue;
			attribute cutOutSetpoint : PressureValue;
			attribute manualOverride : Boolean default false;
			
			port pressureInput;
			port pumpControl;
			port statusOutput;
			
			perform action controlLogic : MonitorAndControl;
		}
		
		action def PumpWater {
			in waterIn : Water;
			in powerInput : PowerValue;
			in headRequired : LengthValue;
			in efficiency : Real;
			out waterOut : Water;
			out actualFlowRate : VolumeFlowRateValue;
			out powerConsumed : PowerValue;
		}
		
		action def MonitorAndControl {
			in currentPressure : PressureValue;
			in cutInPressure : PressureValue;
			in cutOutPressure : PressureValue;
			in manualOverride : Boolean;
			out pumpStartCommand : Boolean;
			out pumpStopCommand : Boolean;
			
			first start;
			then merge continueMonitoring;
			then action checkPressure {
				in pressure = currentPressure;
				in cutIn = cutInPressure;
				in cutOut = cutOutPressure;
				in override = manualOverride;
				out shouldStart : Boolean;
				out shouldStop : Boolean;
			}
			then decide;
				if checkPressure.shouldStart or checkPressure.override then startPump;
				if checkPressure.shouldStop and not checkPressure.override then stopPump;
			action startPump {
				out pumpStartCommand = true;
				out pumpStopCommand = false;
			}
			then continueMonitoring;
			action stopPump {
				out pumpStartCommand = false;
				out pumpStopCommand = true;
			}
			then continueMonitoring;
		}
		
		state def PumpControlStateMachine {
			entry; then idle;
			
			state idle;
			
			state priming;
			
			state running;
			
			state fault;
			
			transition idleToPriming
				first idle
				accept startCommand
				then priming;
			
			transition primingToRunning
				first priming
				accept primingComplete
				then running;
			
			transition primingToFault
				first priming
				accept primingTimeout
				then fault;
			
			transition runningToIdle
				first running
				accept stopCommand
				then idle;
			
			transition runningToFault
				first running
				accept overCurrent
				then fault;
			
			transition faultToIdle
				first fault
				accept resetCommand
				then idle;
		}
		
		interface def WaterInterface {
			end port supplierPort : WaterPort;
			end port consumerPort : ~WaterPort;
			
			flow of water : Water
				from supplierPort.water to consumerPort.water;
		}
		
		requirement def PumpingSystemRequirements {
			subject pumpingSystem : WellPumpingSubsystem;
			
			require flowCapacityRequirement {
				doc /* The pumping subsystem shall deliver a minimum flow rate of 75 liters per minute. */
				attribute minFlowRate : VolumeFlowRateValue = 75.0 [L/min];
				require constraint {
					pumpingSystem.pump.maxFlowRate >= minFlowRate
				}
			}
			
			require pressureMaintenanceRequirement {
				doc /* The system shall maintain pressure between 207 kPa and 345 kPa. */
				require constraint {
					pumpingSystem.controller.cutInSetpoint >= 207.0 [kPa] and
					pumpingSystem.controller.cutOutSetpoint <= 345.0 [kPa]
				}
			}
			
			require efficiencyRequirement {
				doc /* The pump shall operate at minimum 70% efficiency. */
				require constraint {
					pumpingSystem.pump.efficiency >= 0.70
				}
			}
			
			require safetyRequirement {
				doc /* The pump shall shut down if motor current exceeds rated maximum. */
				require constraint {
					pumpingSystem.pump.motorCurrent <= pumpingSystem.pump.maxCurrent
				}
			}
		}
		
		part def WellPumpingSubsystem {
			port systemOutlet : WaterPort;
			
			part well : WellCasing {
				attribute :>> depth = 150.0 [m];
				attribute :>> diameter = 0.15 [m];
				attribute :>> staticWaterLevel = 45.0 [m];
			}
			
			part pump : WellPump {
				attribute :>> ratedPower = 1500.0 [W];
				attribute :>> maxFlowRate = 80.0 [L/min];
				attribute :>> maxHead = 120.0 [m];
				attribute :>> efficiency = 0.75;
				attribute :>> maxCurrent = 15.0 [A];
				
				perform action :>> pumpOperation : PumpWater {
					in waterIn = waterInlet.water;
					in powerInput = ratedPower;
					in headRequired = well.depth - well.staticWaterLevel;
					in efficiency = pump.efficiency;
					out waterOut = waterOutlet.water;
				}
			}
			
			part suctionValve : CheckValve {
				attribute :>> crackingPressure = 5.0 [kPa];
			}
			
			part dischargeValve : CheckValve {
				attribute :>> crackingPressure = 10.0 [kPa];
			}
			
			part pressureTank : PressureTank {
				attribute :>> capacity = 80.0 [L];
				attribute :>> currentVolume = 40.0 [L];
				attribute :>> maxPressure = 345.0 [kPa];
				attribute :>> currentPressure = 276.0 [kPa];
				attribute :>> preChargePressure = 172.0 [kPa];
			}
			
			part pressureSwitch : PressureSwitch {
				attribute :>> cutInPressure = 207.0 [kPa];
				attribute :>> cutOutPressure = 345.0 [kPa];
				attribute :>> measuredPressure = pressureTank.currentPressure;
			}
			
			part flowMeter : FlowMeter {
				attribute :>> measuredFlowRate = pump.pumpOperation.actualFlowRate;
				attribute :>> totalVolume = 0.0 [L];
			}
			
			part controller : ControlPanel {
				attribute :>> cutInSetpoint = 207.0 [kPa];
				attribute :>> cutOutSetpoint = 345.0 [kPa];
				
				perform action :>> controlLogic : MonitorAndControl {
					in currentPressure = pressureSwitch.measuredPressure;
					in cutInPressure = controller.cutInSetpoint;
					in cutOutPressure = controller.cutOutSetpoint;
					in manualOverride = controller.manualOverride;
					out pumpStartCommand = pump.isRunning;
				}
			}
			
			interface wellToSuction : WaterInterface connect
				supplierPort ::> well.waterSource to
				consumerPort ::> suctionValve.upstream;
			
			interface suctionToPump : WaterInterface connect
				supplierPort ::> suctionValve.downstream to
				consumerPort ::> pump.waterInlet;
			
			interface pumpToDischarge : WaterInterface connect
				supplierPort ::> pump.waterOutlet to
				consumerPort ::> dischargeValve.upstream;
			
			interface dischargeToTank : WaterInterface connect
				supplierPort ::> dischargeValve.downstream to
				consumerPort ::> pressureTank.waterInlet;
			
			bind pressureTank.waterOutlet = systemOutlet;
			
			connection pressureSensing connect
				pressureSwitch.sensorPort to pressureTank;
			
			connection flowMeasurement connect
				flowMeter.measurementPort to pump.waterOutlet;
			
			connection pressureMonitoring connect
				controller.pressureInput to pressureSwitch.sensorPort;
			
			connection pumpControl connect
				controller.pumpControl to pump.powerInput;
		}
	}
	
	package Usages {
		part wellPumpingSystem : Definitions::WellPumpingSubsystem {
			satisfy systemRequirements : Definitions::PumpingSystemRequirements {
				subject pumpingSystem = wellPumpingSystem;
			}
		}
	}
}
