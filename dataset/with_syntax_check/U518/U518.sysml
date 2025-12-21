package 'Hydraulic Pumping Subsystem' {
	private import ScalarValues::*;
	
	package Definitions {
		attribute def Pressure;
		attribute def FlowRate;
		attribute def Volume;
		attribute def Temperature;
		attribute def RotationalSpeed;
		attribute def Torque;
		attribute def Power;
		attribute def Efficiency;
		
		item def HydraulicFluid {
			attribute temperature : Temperature;
			attribute density : Real;
			attribute viscosity : Real;
		}
		
		port def HydraulicInPort {
			attribute pressure : Pressure;
			in item fluid : HydraulicFluid;
		}
		
		port def HydraulicOutPort {
			attribute pressure : Pressure;
			out item fluid : HydraulicFluid;
		}
		
		port def MechanicalPort {
			attribute torque : Torque;
			attribute speed : RotationalSpeed;
		}
		
		part def Reservoir {
			port outletPort : HydraulicOutPort;
			port returnPort : HydraulicInPort;
			attribute capacity : Volume;
			attribute currentLevel : Volume;
			item storedFluid : HydraulicFluid {
				attribute volume : Volume;
			}
			assert constraint levelConstraint {
				currentLevel <= capacity
			}
		}
		
		part def HydraulicPump {
			port inletPort : HydraulicInPort;
			port outletPort : HydraulicOutPort;
			port drivePort : MechanicalPort;
			attribute displacement : Volume;
			attribute volumetricEfficiency : Efficiency;
			attribute mechanicalEfficiency : Efficiency;
			attribute ratedPressure : Pressure;
			attribute maxSpeed : RotationalSpeed;
			
			perform action pumpFluid : PumpFluid {
				in fluidIn = inletPort.fluid;
				out fluidOut = outletPort.fluid;
				in inputSpeed = drivePort.speed;
				in inputTorque = drivePort.torque;
			}
			
			exhibit state pumpState : PumpStateMachine;
			
			assert constraint pressureIncrease {
				outletPort.pressure > inletPort.pressure
			}
		}
		
		part def ElectricMotor {
			port shaftPort : ~MechanicalPort;
			attribute ratedPower : Power;
			attribute commandSpeed : RotationalSpeed;
			attribute maxTorque : Torque;
			attribute currentSpeed : RotationalSpeed;
		}
		
		part def PressureReliefValve {
			port inletPort : HydraulicInPort;
			port outletPort : HydraulicOutPort;
			attribute crackingPressure : Pressure;
			attribute isOpen : Boolean;
			
			assert constraint safetyLimit {
				inletPort.pressure <= crackingPressure * 1.1
			}
		}
		
		part def FluidConsumer {
			port supplyPort : HydraulicInPort;
			port returnPort : HydraulicOutPort;
			attribute requiredFlowRate : FlowRate;
			attribute requiredPressure : Pressure;
		}
		
		part def PressureSensor {
			attribute measuredPressure : Pressure;
			attribute accuracy : Real;
		}
		
		part def FlowSensor {
			attribute measuredFlowRate : FlowRate;
			attribute accuracy : Real;
		}
		
		action def PumpFluid {
			in fluidIn : HydraulicFluid;
			in inputSpeed : RotationalSpeed;
			in inputTorque : Torque;
			out fluidOut : HydraulicFluid;
			out outputFlowRate : FlowRate;
			out outputPressure : Pressure;
			
			first start;
			then action calculateFlow {
				in speed : RotationalSpeed;
				in disp : Volume;
				in volEff : Efficiency;
				out flowRate : FlowRate;
			}
			then action calculatePressure {
				in torqueIn : Torque;
				in mechEff : Efficiency;
				in dispVol : Volume;
				out pressureOut : Pressure;
			}
			then action transferFluid {
				in fluid : HydraulicFluid;
				in flow : FlowRate;
				out dischargedFluid : HydraulicFluid;
			}
			then done;
		}
		
		action def MonitorPressure {
			in sensorReading : Pressure;
			out currentPressure : Pressure;
		}
		
		action def ControlPumpSpeed {
			in requiredPressure : Pressure;
			in measuredPressure : Pressure;
			in currentSpeed : RotationalSpeed;
			inout commandSpeed : RotationalSpeed;
			
			first start;
			then merge regulate;
			then action checkPressure {
				in required : Pressure;
				in measured : Pressure;
				out error : Real;
			}
			then decide;
				if checkPressure.error > 0 then increaseSpeed;
				if checkPressure.error <= 0 then maintainSpeed;
			action increaseSpeed {
				out newSpeed : RotationalSpeed;
			}
			then regulate;
			action maintainSpeed;
			then done;
		}
		
		state def PumpStateMachine {
			entry; then idle;
			
			state idle;
			transition idle_to_starting
				first idle
				then starting;
			
			state starting;
			transition starting_to_running
				first starting
				then running;
			
			state running;
			transition running_to_stopping
				first running
				then stopping;
			
			transition running_to_fault
				first running
				then faulted;
			
			state stopping;
			transition stopping_to_idle
				first stopping
				then idle;
			
			state faulted;
			transition fault_to_idle
				first faulted
				then idle;
		}
		
		interface def HydraulicSupplyInterface {
			end port supplierPort : HydraulicOutPort;
			end port consumerPort : HydraulicInPort;
		}
		
		interface def HydraulicReturnInterface {
			end port sourcePort : HydraulicOutPort;
			end port sinkPort : HydraulicInPort;
		}
		
		requirement def FlowDeliveryRequirement {
			doc /* The subsystem shall deliver hydraulic fluid at the specified flow rate. */
			subject pump : HydraulicPump;
			attribute requiredFlowRate : FlowRate;
			require constraint flowCapability {
				pump.pumpFluid.outputFlowRate >= requiredFlowRate
			}
		}
		
		requirement def PressureRequirement {
			doc /* The subsystem shall maintain minimum operating pressure. */
			subject pump : HydraulicPump;
			attribute minimumPressure : Pressure;
			require constraint pressureCapability {
				pump.outletPort.pressure >= minimumPressure
			}
		}
		
		requirement def SafetyRequirement {
			doc /* The subsystem shall include overpressure protection. */
			subject valve : PressureReliefValve;
			require constraint overpressureProtection {
				valve.crackingPressure > 0
			}
		}
	}
	
	package Usages {
		private import Definitions::*;
		
		part pumpingSubsystem {
			part reservoir : Reservoir {
				attribute capacity = 100.0;
				attribute currentLevel = 80.0;
				item storedFluid {
					attribute volume = 80.0;
					attribute temperature = 40.0;
					attribute density = 850.0;
					attribute viscosity = 0.032;
				}
			}
			
			part pump : HydraulicPump {
				attribute displacement = 0.05;
				attribute volumetricEfficiency = 0.92;
				attribute mechanicalEfficiency = 0.88;
				attribute ratedPressure = 210.0;
				attribute maxSpeed = 1800.0;
			}
			
			part motor : ElectricMotor {
				attribute ratedPower = 22000.0;
				attribute commandSpeed = 1500.0;
				attribute maxTorque = 140.0;
				attribute currentSpeed = 1500.0;
			}
			
			part reliefValve : PressureReliefValve {
				attribute crackingPressure = 250.0;
				attribute isOpen = false;
			}
			
			part consumer : FluidConsumer {
				attribute requiredFlowRate = 75.0;
				attribute requiredPressure = 200.0;
			}
			
			part outletPressureSensor : PressureSensor {
				attribute accuracy = 0.5;
			}
			
			part flowSensor : FlowSensor {
				attribute accuracy = 1.0;
			}
			
			interface reservoirToInlet : HydraulicSupplyInterface
				connect supplierPort ::> reservoir.outletPort
				to consumerPort ::> pump.inletPort;
			
			flow of hydraulicFluid : HydraulicFluid
				from reservoir.outletPort.fluid to pump.inletPort.fluid;
			
			interface pumpToConsumer : HydraulicSupplyInterface
				connect supplierPort ::> pump.outletPort
				to consumerPort ::> consumer.supplyPort;
			
			flow of hydraulicFluidOut : HydraulicFluid
				from pump.outletPort.fluid to consumer.supplyPort.fluid;
			
			interface consumerToReservoir : HydraulicReturnInterface
				connect sourcePort ::> consumer.returnPort
				to sinkPort ::> reservoir.returnPort;
			
			flow of hydraulicFluidReturn : HydraulicFluid
				from consumer.returnPort.fluid to reservoir.returnPort.fluid;
			
			interface reliefToReservoir : HydraulicReturnInterface
				connect sourcePort ::> reliefValve.outletPort
				to sinkPort ::> reservoir.returnPort;
			
			flow of hydraulicFluidRelief : HydraulicFluid
				from reliefValve.outletPort.fluid to reservoir.returnPort.fluid;
			
			bind pump.drivePort.torque = motor.shaftPort.torque;
			bind pump.drivePort.speed = motor.shaftPort.speed;
			bind outletPressureSensor.measuredPressure = pump.outletPort.pressure;
			bind flowSensor.measuredFlowRate = pump.pumpFluid.outputFlowRate;
			
			connection reliefConnection
				connect pump.outletPort to reliefValve.inletPort;
			
			perform action monitorPressure : MonitorPressure {
				in sensorReading = outletPressureSensor.measuredPressure;
			}
			
			perform action controlSpeed : ControlPumpSpeed {
				in requiredPressure = consumer.requiredPressure;
				in measuredPressure = monitorPressure.currentPressure;
				in currentSpeed = motor.currentSpeed;
				inout commandSpeed = motor.commandSpeed;
			}
			
			assert constraint flowCalculation {
				pump.pumpFluid.outputFlowRate == 
					pump.displacement * pump.drivePort.speed * pump.volumetricEfficiency
			}
			
			assert constraint pressureCalculation {
				pump.pumpFluid.outputPressure == 
					(pump.drivePort.torque * pump.mechanicalEfficiency) / pump.displacement
			}
			
			assert constraint flowMeetsRequirement {
				flowSensor.measuredFlowRate >= consumer.requiredFlowRate
			}
			
			assert constraint pressureMeetsRequirement {
				outletPressureSensor.measuredPressure >= consumer.requiredPressure
			}
			
			assert constraint safetyProtection {
				pump.outletPort.pressure <= reliefValve.crackingPressure
			}
		}
		
		requirement flowDelivery : FlowDeliveryRequirement {
			subject pump = pumpingSubsystem.pump;
			attribute requiredFlowRate = 75.0;
		}
		
		requirement pressureDelivery : PressureRequirement {
			subject pump = pumpingSubsystem.pump;
			attribute minimumPressure = 200.0;
		}
		
		requirement systemSafety : SafetyRequirement {
			subject valve = pumpingSubsystem.reliefValve;
		}
	}
}
