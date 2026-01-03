package 'Intelligent Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	item def Fluid {
		attribute density : Real;
		attribute viscosity : Real;
		attribute temperature : Real;
		attribute pressure : Real;
		attribute flowRate : Real;
	}
	
	port def FluidPort {
		out item fluid : Fluid;
	}
	
	attribute def Percentage {
		attribute value : Real;
	}
	
	attribute def RotationalSpeed {
		attribute rpm : Real;
	}
	
	attribute def PowerValue {
		attribute watts : Real;
	}
	
	part def FlowSensor {
		port sensorPort : ~FluidPort;
		out attribute measuredFlowRate : Real;
		out attribute measuredPressure : Real;
		
		action def MeasureFlow {
			in fluidIn : Fluid;
			out flowRate : Real;
			out pressure : Real;
		}
		
		perform action measure : MeasureFlow {
			in fluidIn = sensorPort.fluid;
			out flowRate = measuredFlowRate;
			out pressure = measuredPressure;
		}
	}
	
	part def PressureSensor {
		port sensorPort : ~FluidPort;
		out attribute measuredPressure : Real;
		
		action def MeasurePressure {
			in fluidIn : Fluid;
			out pressure : Real;
		}
		
		perform action measure : MeasurePressure {
			in fluidIn = sensorPort.fluid;
			out pressure = measuredPressure;
		}
	}
	
	part def PumpController {
		in attribute targetFlowRate : Real;
		in attribute currentFlowRate : Real;
		in attribute inletPressure : Real;
		in attribute outletPressure : Real;
		in attribute maxSpeed : Real;
		in attribute minSpeed : Real;
		out attribute commandedSpeed : Real;
		out attribute operatingMode : String;
		
		action def MonitorFlowRate {
			in currentFlow : Real;
			in targetFlow : Real;
			out flowError : Real;
		}
		
		action def CalculateSpeed {
			in flowError : Real;
			in pressureDiff : Real;
			in maxSpd : Real;
			in minSpd : Real;
			out speed : Real;
		}
		
		action def ControlPump {
			first start;
			then merge controlLoop;
			
			action monitor : MonitorFlowRate {
				in currentFlow;
				in targetFlow;
				out flowError;
			}
			
			then action calculate : CalculateSpeed {
				in flowError = monitor.flowError;
				in pressureDiff = outletPressure - inletPressure;
				in maxSpd = maxSpeed;
				in minSpd = minSpeed;
				out speed;
			}
			
			then decide;
				if calculate.flowError > 1.0 then increaseSpeed;
				if calculate.flowError < -1.0 then decreaseSpeed;
				if calculate.flowError >= -1.0 & calculate.flowError <= 1.0 then maintainSpeed;
			
			action increaseSpeed {
				in calculatedSpeed = calculate.speed;
			}
			then controlLoop;
			
			action decreaseSpeed {
				in calculatedSpeed = calculate.speed;
			}
			then controlLoop;
			
			action maintainSpeed {
				in currentSpeed = calculate.speed;
			}
			then controlLoop;
		}
		
		perform action control : ControlPump;
	}
	
	state def PumpOperatingStates {
		in attribute pumpSpeed : Real;
		out attribute mode : String;
		
		entry; then off;
		
		state off;
		accept StartCommand then starting;
		
		state starting;
		accept at when pumpSpeed >= 100.0 then running;
		
		state running;
		accept StopCommand then stopping;
		accept FaultDetected then faulted;
		do action operateAtSpeed {
			in speed = pumpSpeed;
		}
		
		state stopping;
		accept at when pumpSpeed <= 10.0 then off;
		
		state faulted;
		accept ResetCommand then off;
	}
	
	action def PumpFluidAction {
		in fluidIn : Fluid;
		in speed : Real;
		out fluidOut : Fluid;
	}
	
	part def IntelligentPump {
		port fluidInPort : ~FluidPort;
		port fluidOutPort : FluidPort;
		
		attribute targetFlowRate : Real = 75.0;
		attribute currentSpeed : Real;
		attribute maxSpeed : Real = 3600.0;
		attribute minSpeed : Real = 0.0;
		attribute operatingState : String;
		attribute powerConsumption : Real;
		
		part inletFlowSensor : FlowSensor {
			bind sensorPort.fluid = fluidInPort.fluid;
		}
		
		part outletFlowSensor : FlowSensor {
			bind sensorPort.fluid = fluidOutPort.fluid;
		}
		
		part inletPressureSensor : PressureSensor {
			bind sensorPort.fluid = fluidInPort.fluid;
		}
		
		part outletPressureSensor : PressureSensor {
			bind sensorPort.fluid = fluidOutPort.fluid;
		}
		
		part controller : PumpController {
			bind targetFlowRate = IntelligentPump::targetFlowRate;
			bind currentFlowRate = outletFlowSensor.measuredFlowRate;
			bind inletPressure = inletPressureSensor.measuredPressure;
			bind outletPressure = outletPressureSensor.measuredPressure;
			bind maxSpeed = IntelligentPump::maxSpeed;
			bind minSpeed = IntelligentPump::minSpeed;
		}
		
		bind currentSpeed = controller.commandedSpeed;
		bind operatingState = controller.operatingMode;
		
		perform action pumpFluid : PumpFluidAction {
			in fluidIn = fluidInPort.fluid;
			in speed = controller.commandedSpeed;
			out fluidOut = fluidOutPort.fluid;
		}
		
		exhibit state pumpStates : PumpOperatingStates {
			in pumpSpeed = currentSpeed;
			out mode = operatingState;
		}
		
		assert constraint speedLimits {
			currentSpeed >= minSpeed & currentSpeed <= maxSpeed
		}
		
		assert constraint pressureIncrease {
			outletPressureSensor.measuredPressure >= inletPressureSensor.measuredPressure
		}
	}
	
	part def SourceTank {
		port outletPort : FluidPort;
		attribute fluidLevel : Real;
		attribute capacity : Real = 2000.0;
		attribute currentVolume : Real = 1500.0;
		
		item storedFluid : Fluid {
			attribute volume : Real;
		}
		
		flow storedFluid to outletPort.fluid;
		
		assert constraint levelConstraint {
			fluidLevel == currentVolume / capacity * 100.0
		}
	}
	
	part def DestinationTank {
		port inletPort : ~FluidPort;
		attribute fluidLevel : Real;
		attribute capacity : Real = 2000.0;
		attribute currentVolume : Real = 500.0;
		
		item storedFluid : Fluid {
			attribute volume : Real;
		}
		
		flow inletPort.fluid to storedFluid;
		
		assert constraint levelConstraint {
			fluidLevel == currentVolume / capacity * 100.0
		}
		
		assert constraint capacityConstraint {
			currentVolume <= capacity
		}
	}
	
	interface def PumpingInterface {
		end port suppliedBy : FluidPort;
		end port deliveredTo : ~FluidPort;
		connect suppliedBy.fluid to deliveredTo.fluid;
	}
	
	part def PumpingSubsystem {
		part sourceTank : SourceTank;
		
		part intelligentPump : IntelligentPump {
			attribute :>> targetFlowRate = 80.0;
		}
		
		part destinationTank : DestinationTank;
		
		interface sourceInterface : PumpingInterface connect
			suppliedBy ::> sourceTank.outletPort
			to deliveredTo ::> intelligentPump.fluidInPort;
		
		interface destinationInterface : PumpingInterface connect
			suppliedBy ::> intelligentPump.fluidOutPort
			to deliveredTo ::> destinationTank.inletPort;
		
		flow of transferredFluid : Fluid
			from sourceTank.outletPort.fluid
			to intelligentPump.fluidInPort.fluid;
		
		flow of transferredFluid : Fluid
			from intelligentPump.fluidOutPort.fluid
			to destinationTank.inletPort.fluid;
		
		assert constraint flowRateConstraint {
			intelligentPump.outletFlowSensor.measuredFlowRate >= 0.0 &
			intelligentPump.outletFlowSensor.measuredFlowRate <= 150.0
		}
		
		assert constraint pressureBoost {
			intelligentPump.outletPressureSensor.measuredPressure >
			intelligentPump.inletPressureSensor.measuredPressure
		}
	}
	
	requirement def PumpingSystemRequirements {
		doc /* The pumping subsystem shall autonomously transfer fluid from source to destination tank. */
		
		requirement flowRateRequirement {
			doc /* The intelligent pump shall maintain target flow rate within 5% tolerance. */
			
			require constraint {
				abs(intelligentPump.outletFlowSensor.measuredFlowRate - 
					intelligentPump.targetFlowRate) <= 
					0.05 * intelligentPump.targetFlowRate
			}
		}
		
		requirement pressureBoostRequirement {
			doc /* The pump shall increase fluid pressure by at least 30 kPa. */
			
			require constraint {
				intelligentPump.outletPressureSensor.measuredPressure - 
				intelligentPump.inletPressureSensor.measuredPressure >= 30.0
			}
		}
		
		requirement autonomousControlRequirement {
			doc /* The pump shall autonomously adjust speed to maintain target flow rate. */
			
			require constraint {
				intelligentPump.controller.commandedSpeed >= 
					intelligentPump.minSpeed &
				intelligentPump.controller.commandedSpeed <= 
					intelligentPump.maxSpeed
			}
		}
		
		requirement safetyRequirement {
			doc /* The pump shall enter faulted state upon detecting anomalous conditions and stop operation. */
		}
		
		requirement efficiencyRequirement {
			doc /* The pump shall operate within defined speed limits to optimize energy consumption. */
			
			satisfy by intelligentPump.speedLimits;
		}
	}
	
	part pumpingSystem : PumpingSubsystem {
		satisfy systemRequirements : PumpingSystemRequirements by pumpingSystem;
	}
}
