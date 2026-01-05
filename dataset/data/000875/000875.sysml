package 'Fire Pumping Subsystem' {
	private import ScalarValues::*;
	
	package Definitions {
		attribute def PressureValue :> Real;
		attribute def FlowRateValue :> Real;
		attribute def VolumeValue :> Real;
		attribute def TemperatureValue :> Real;
		attribute def PowerValue :> Real;
		attribute def SpeedValue :> Real;
		
		enum def PressureUnit {
			enum psi;
			enum bar;
			enum kPa;
		}
		
		enum def FlowRateUnit {
			enum gpm;
			enum lpm;
			enum m3h;
		}
		
		enum def PumpState {
			enum off;
			enum priming;
			enum running;
			enum shutdown;
			enum fault;
		}
		
		item def Water {
			attribute temperature : TemperatureValue;
			attribute density : Real;
			attribute volume : VolumeValue;
		}
		
		port def FluidInletPort {
			attribute pressure : PressureValue;
			attribute flowRate : FlowRateValue;
			in item waterIn : Water;
		}
		
		port def FluidOutletPort {
			attribute pressure : PressureValue;
			attribute flowRate : FlowRateValue;
			out item waterOut : Water;
		}
		
		port def PowerInputPort {
			attribute voltage : Real;
			attribute current : Real;
			attribute power : PowerValue;
		}
		
		port def ControlPort {
			in attribute startCommand : Boolean;
			in attribute stopCommand : Boolean;
			out attribute status : PumpState;
			out attribute alarmSignal : Boolean;
		}
		
		interface def FluidConnection {
			end port source : FluidOutletPort;
			end port destination : FluidInletPort;
		}
		
		part def WaterSupplySource {
			port outlet : FluidOutletPort;
			attribute sourceCapacity : VolumeValue;
			attribute staticPressure : PressureValue;
		}
		
		part def DischargeManifold {
			port inlet : FluidInletPort;
			attribute requiredPressure : PressureValue;
			attribute requiredFlowRate : FlowRateValue;
			attribute numberOfOutlets : Integer;
		}
		
		part def FirePump {
			attribute ratedFlowRate : FlowRateValue;
			attribute ratedDischargePressure : PressureValue;
			attribute minSuctionPressure : PressureValue;
			attribute maxSuctionPressure : PressureValue;
			attribute efficiency : Real;
			attribute currentState : PumpState;
			
			port suctionPort : FluidInletPort;
			port dischargePort : FluidOutletPort;
			port powerInput : PowerInputPort;
			port control : ControlPort;
			
			part impeller {
				attribute diameter : Real;
				attribute rotationalSpeed : SpeedValue;
				attribute numberOfVanes : Integer;
			}
			
			part motor {
				attribute ratedPower : PowerValue;
				attribute voltage : Real;
				attribute motorEfficiency : Real;
			}
			
			part shaft {
				attribute torque : Real;
				attribute speed : SpeedValue;
			}
			
			part casing {
				attribute maxAllowablePressure : PressureValue;
				attribute material : String;
			}
			
			part sealAssembly {
				attribute leakageRate : FlowRateValue;
			}
		}
		
		part def PressureSensor {
			in attribute measuredPressure : PressureValue;
			out attribute pressureReading : PressureValue;
			attribute accuracy : Real;
			attribute range : PressureValue;
		}
		
		part def FlowSensor {
			in attribute measuredFlow : FlowRateValue;
			out attribute flowReading : FlowRateValue;
			attribute accuracy : Real;
			attribute range : FlowRateValue;
		}
		
		part def PumpController {
			port controlInterface : ControlPort;
			
			in attribute suctionPressureReading : PressureValue;
			in attribute dischargePressureReading : PressureValue;
			in attribute flowRateReading : FlowRateValue;
			
			out attribute motorCommand : Boolean;
			
			attribute pressureSetpoint : PressureValue;
			attribute flowSetpoint : FlowRateValue;
			attribute lowSuctionAlarmThreshold : PressureValue;
			attribute highDischargeAlarmThreshold : PressureValue;
		}
		
		action def PrimePump {
			in suctionPressure : PressureValue;
			in minRequired : PressureValue;
			out primingComplete : Boolean;
			out primingFailed : Boolean;
		}
		
		action def StartMotor {
			in startSignal : Boolean;
			out motorRunning : Boolean;
		}
		
		action def MonitorOperation {
			in suctionPressure : PressureValue;
			in dischargePressure : PressureValue;
			in flowRate : FlowRateValue;
			out operationNormal : Boolean;
			out faultDetected : Boolean;
		}
		
		action def ShutdownPump {
			in stopSignal : Boolean;
			out shutdownComplete : Boolean;
		}
		
		action def FirePumpOperation {
			in startCmd : Boolean;
			in stopCmd : Boolean;
			in suctionPress : PressureValue;
			in dischargePress : PressureValue;
			in flow : FlowRateValue;
			in minSuctionPress : PressureValue;
			out pumpStatus : PumpState;
			
			first start;
			
			then action checkStart : StartMotor {
				in startSignal = startCmd;
				out motorRunning;
			}
			
			then decide;
				if checkStart.motorRunning then primeAction;
				if !checkStart.motorRunning then shutdownAction;
			
			action primeAction : PrimePump {
				in suctionPressure = suctionPress;
				in minRequired = minSuctionPress;
				out primingComplete;
				out primingFailed;
			}
			
			then decide;
				if primeAction.primingComplete then merge operateLoop;
				if primeAction.primingFailed then shutdownAction;
			
			merge operateLoop;
			
			then action monitor : MonitorOperation {
				in suctionPressure = suctionPress;
				in dischargePressure = dischargePress;
				in flowRate = flow;
				out operationNormal;
				out faultDetected;
			}
			
			then decide;
				if monitor.operationNormal & !stopCmd then operateLoop;
				if monitor.faultDetected | stopCmd then shutdownAction;
			
			action shutdownAction : ShutdownPump {
				in stopSignal = stopCmd | monitor.faultDetected;
				out shutdownComplete;
			}
			
			then done;
		}
		
		state def FirePumpStateMachine {
			entry; then idle;
			
			state idle;
			
			accept at idle
				if startCommand
				then priming;
			
			state priming;
			
			accept at priming
				if primingSuccess
				then running;
			
			accept at priming
				if primingFailure
				then fault;
			
			state running;
			
			accept at running
				if stopCommand
				then shutdown;
			
			accept at running
				if faultCondition
				then fault;
			
			state shutdown;
			
			accept at shutdown
				if shutdownComplete
				then idle;
			
			state fault;
			
			accept at fault
				if resetCommand
				then idle;
		}
		
		requirement def FlowCapabilityRequirement {
			doc /* The fire pump shall deliver the rated flow rate at rated discharge pressure. */
			
			subject pump : FirePump;
			
			require constraint {
				pump.dischargePort.flowRate >= pump.ratedFlowRate * 0.95 &
				pump.dischargePort.pressure >= pump.ratedDischargePressure
			}
		}
		
		requirement def SuctionRequirement {
			doc /* The fire pump shall operate within specified suction pressure limits. */
			
			subject pump : FirePump;
			
			require constraint {
				pump.suctionPort.pressure >= pump.minSuctionPressure &
				pump.suctionPort.pressure <= pump.maxSuctionPressure
			}
		}
		
		requirement def StartupTimeRequirement {
			doc /* The fire pump shall reach rated pressure within 30 seconds of start command. */
			
			subject pump : FirePump;
			
			attribute startupTime : Real;
			
			require constraint {
				startupTime <= 30.0
			}
		}
		
		requirement def ReliabilityRequirement {
			doc /* The pumping subsystem shall maintain continuous operation under rated conditions. */
			
			subject subsystem : PumpingSubsystem;
			
			attribute meanTimeBetweenFailure : Real;
			
			require constraint {
				meanTimeBetweenFailure >= 8760.0
			}
		}
	}
	
	package Usages {
		import Definitions::*;
		
		part pumpingSubsystem : PumpingSubsystem {
			part waterSource : WaterSupplySource {
				attribute :>> sourceCapacity = 500000.0;
				attribute :>> staticPressure = 40.0;
				
				port redefines outlet {
					attribute :>> pressure = 40.0;
					out item redefines waterOut : Water {
						attribute :>> temperature = 20.0;
						attribute :>> density = 1000.0;
					}
				}
			}
			
			interface sourceConnection : FluidConnection
				connect source ::> waterSource.outlet
				to destination ::> firePump.suctionPort;
			
			flow of water : Water
				from waterSource.outlet.waterOut
				to firePump.suctionPort.waterIn;
			
			part firePump : FirePump {
				attribute :>> ratedFlowRate = 1500.0;
				attribute :>> ratedDischargePressure = 150.0;
				attribute :>> minSuctionPressure = 20.0;
				attribute :>> maxSuctionPressure = 80.0;
				attribute :>> efficiency = 0.82;
				
				part :>> impeller {
					attribute :>> diameter = 14.0;
					attribute :>> rotationalSpeed = 1750.0;
					attribute :>> numberOfVanes = 6;
				}
				
				part :>> motor {
					attribute :>> ratedPower = 100.0;
					attribute :>> voltage = 480.0;
					attribute :>> motorEfficiency = 0.92;
				}
				
				perform action operation : FirePumpOperation {
					in startCmd = control.startCommand;
					in stopCmd = control.stopCommand;
					in suctionPress = suctionPort.pressure;
					in dischargePress = dischargePort.pressure;
					in flow = dischargePort.flowRate;
					in minSuctionPress = minSuctionPressure;
					out pumpStatus = currentState;
				}
			}
			
			flow of water : Water
				from firePump.dischargePort.waterOut
				to dischargeManifold.inlet.waterIn;
			
			part dischargeManifold : DischargeManifold {
				attribute :>> requiredPressure = 125.0;
				attribute :>> requiredFlowRate = 1250.0;
				attribute :>> numberOfOutlets = 4;
			}
			
			interface dischargeConnection : FluidConnection
				connect source ::> firePump.dischargePort
				to destination ::> dischargeManifold.inlet;
			
			part suctionSensor : PressureSensor {
				attribute :>> accuracy = 0.5;
				attribute :>> range = 100.0;
				bind measuredPressure = firePump.suctionPort.pressure;
			}
			
			part dischargeSensor : PressureSensor {
				attribute :>> accuracy = 0.5;
				attribute :>> range = 300.0;
				bind measuredPressure = firePump.dischargePort.pressure;
			}
			
			part flowMeter : FlowSensor {
				attribute :>> accuracy = 1.0;
				attribute :>> range = 2000.0;
				bind measuredFlow = firePump.dischargePort.flowRate;
			}
			
			part controller : PumpController {
				attribute :>> pressureSetpoint = 130.0;
				attribute :>> flowSetpoint = 1500.0;
				attribute :>> lowSuctionAlarmThreshold = 15.0;
				attribute :>> highDischargeAlarmThreshold = 200.0;
				
				bind suctionPressureReading = suctionSensor.pressureReading;
				bind dischargePressureReading = dischargeSensor.pressureReading;
				bind flowRateReading = flowMeter.flowReading;
			}
			
			connect controller.controlInterface to firePump.control;
			
			part powerSupply {
				port powerOut : PowerInputPort {
					attribute :>> voltage = 480.0;
					attribute :>> power = 125.0;
				}
			}
			
			connect powerSupply.powerOut to firePump.powerInput;
			
			satisfy flowReq : FlowCapabilityRequirement {
				subject pump = firePump;
			}
			
			satisfy suctionReq : SuctionRequirement {
				subject pump = firePump;
			}
			
			satisfy startupReq : StartupTimeRequirement {
				subject pump = firePump;
			}
			
			satisfy reliabilityReq : ReliabilityRequirement {
				subject subsystem = pumpingSubsystem;
			}
		}
		
		part def PumpingSubsystem {
			part waterSource : WaterSupplySource;
			part firePump : FirePump;
			part dischargeManifold : DischargeManifold;
			part suctionSensor : PressureSensor;
			part dischargeSensor : PressureSensor;
			part flowMeter : FlowSensor;
			part controller : PumpController;
		}
	}
}
