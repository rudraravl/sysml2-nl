package 'Gear Pump Subsystem Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		item def HydraulicFluid {
			attribute density : Real;
			attribute viscosity : Real;
			attribute temperature : Real;
			attribute volume : Real;
		}
		
		port def FluidPort {
			attribute pressure : Real;
			attribute flowRate : Real;
			in out item fluid : HydraulicFluid;
		}
		
		port def MechanicalShaftPort {
			attribute torque : Real;
			attribute speed : Real;
		}
		
		port def ElectricalPort {
			attribute voltage : Real;
			attribute current : Real;
			attribute power : Real;
		}
		
		port def ControlSignalPort {
			attribute commandSignal : Real;
		}
		
		part def GearPump {
			doc /*
			 * Positive displacement pump using meshing gears to move fluid.
			 * Consists of drive gear and driven gear rotating in opposite directions
			 * within a close-fitting housing.
			 */
			
			attribute displacementPerRevolution : Real;
			attribute maxPressure : Real;
			attribute volumetricEfficiency : Real;
			attribute mechanicalEfficiency : Real;
			attribute numberOfTeeth : Integer;
			attribute gearWidth : Real;
			
			port suctionPort : ~FluidPort;
			port dischargePort : FluidPort;
			port driveShaft : ~MechanicalShaftPort;
			
			part driveGear {
				attribute teeth : Integer;
				attribute rotationSpeed : Real;
			}
			
			part drivenGear {
				attribute teeth : Integer;
				attribute rotationSpeed : Real;
			}
			
			part pumpHousing {
				attribute inletPressure : Real;
				attribute outletPressure : Real;
				attribute clearance : Real;
			}
			
			part shaftSeal {
				attribute leakageRate : Real;
			}
			
			perform action pumpFluid : PumpFluidAction;
			exhibit state operatingStates : GearPumpStates;
		}
		
		part def ElectricMotor {
			doc /*
			 * Electric motor providing rotational power to drive the gear pump.
			 */
			
			attribute ratedPower : Real;
			attribute ratedSpeed : Real;
			attribute ratedVoltage : Real;
			attribute efficiency : Real;
			
			port electricalInput : ~ElectricalPort;
			port outputShaft : MechanicalShaftPort;
			port controlInput : ~ControlSignalPort;
			
			perform action driveShaft : DriveShaftAction;
			exhibit state motorStates : MotorOperatingStates;
		}
		
		part def FluidReservoir {
			doc /*
			 * Storage tank for hydraulic fluid supply and return.
			 */
			
			attribute capacity : Real;
			attribute currentLevel : Real;
			attribute minLevel : Real;
			attribute maxLevel : Real;
			
			port supplyPort : FluidPort;
			port returnPort : ~FluidPort;
			
			item storedFluid : HydraulicFluid {
				attribute :>> volume = currentLevel;
			}
			
			bind supplyPort.fluid = storedFluid;
		}
		
		part def SuctionFilter {
			doc /*
			 * Filters contaminants from fluid entering the pump.
			 */
			
			attribute filtrationRating : Real;
			attribute pressureDrop : Real;
			attribute maxFlowCapacity : Real;
			
			port inletPort : ~FluidPort;
			port outletPort : FluidPort;
		}
		
		part def PressureReliefValve {
			doc /*
			 * Protects system from overpressure by bypassing fluid to reservoir.
			 */
			
			attribute crackingPressure : Real;
			attribute maxFlowCapacity : Real;
			attribute reseatPressure : Real;
			
			port inletPort : ~FluidPort;
			port outletPort : FluidPort;
			
			perform action regulatePressure : PressureRegulationAction;
			exhibit state valveStates : ReliefValveStates;
		}
		
		part def CheckValve {
			doc /*
			 * Prevents reverse flow when pump is stopped.
			 */
			
			attribute crackingPressure : Real;
			
			port inletPort : ~FluidPort;
			port outletPort : FluidPort;
			
			exhibit state valveStates : CheckValveStates;
		}
		
		part def PressureSensor {
			attribute measuredPressure : Real;
			attribute accuracy : Real;
			attribute range : Real;
			
			port sensingPort : ~FluidPort;
			port signalOutput : ControlSignalPort;
		}
		
		part def FlowMeter {
			attribute measuredFlowRate : Real;
			attribute accuracy : Real;
			attribute range : Real;
			
			port sensingPort : ~FluidPort;
			port signalOutput : ControlSignalPort;
		}
		
		part def TemperatureSensor {
			attribute measuredTemperature : Real;
			attribute accuracy : Real;
			
			port sensingPort : ~FluidPort;
			port signalOutput : ControlSignalPort;
		}
		
		part def ControlUnit {
			doc /*
			 * Controls motor operation based on sensor feedback.
			 */
			
			port pressureInput : ~ControlSignalPort;
			port flowInput : ~ControlSignalPort;
			port temperatureInput : ~ControlSignalPort;
			port motorControl : ControlSignalPort;
			port powerOutput : ElectricalPort;
			
			perform action controlPump : PumpControlAction;
		}
		
		action def PumpFluidAction {
			doc /*
			 * Action performed by gear pump to transfer fluid from suction to discharge.
			 */
			
			in suctionFluid : HydraulicFluid;
			in shaftSpeed : Real;
			in displacement : Real;
			in efficiency : Real;
			out dischargeFluid : HydraulicFluid;
			out actualFlowRate : Real;
			
			action captureFluid {
				doc /* Fluid enters gear tooth pockets at suction side */
			}
			
			then action transportFluid {
				doc /* Gears rotate carrying fluid around housing perimeter */
			}
			
			then action dischargeFluidAction {
				doc /* Fluid expelled at discharge as gears mesh */
			}
		}
		
		action def DriveShaftAction {
			in voltage : Real;
			in current : Real;
			in controlSignal : Real;
			out torque : Real;
			out speed : Real;
		}
		
		action def PressureRegulationAction {
			in inletPressure : Real;
			in setPoint : Real;
			out outletPressure : Real;
			out valvePosition : Real;
			
			first start;
			then decide;
				if inletPressure > setPoint then openValve;
				if inletPressure <= setPoint then closeValve;
			
			action openValve {
				doc /* Allow fluid bypass to reservoir */
			}
			
			action closeValve {
				doc /* Block bypass flow */
			}
			
			then done;
		}
		
		action def PumpControlAction {
			in pressureSignal : Real;
			in flowSignal : Real;
			in temperatureSignal : Real;
			out motorCommand : Real;
			
			first start;
			then merge controlLoop;
			then action monitorConditions {
				out currentPressure : Real;
				out currentFlow : Real;
				out currentTemp : Real;
			}
			then decide;
				if monitorConditions.currentPressure < 50.0 then increasePower;
				if monitorConditions.currentPressure > 150.0 then decreasePower;
				if monitorConditions.currentTemp > 80.0 then shutdown;
			
			action increasePower {
				out motorCommand = 1.0;
			}
			then controlLoop;
			
			action decreasePower {
				out motorCommand = 0.5;
			}
			then controlLoop;
			
			action shutdown {
				out motorCommand = 0.0;
			}
			then done;
		}
		
		state def GearPumpStates {
			entry; then idle;
			
			state idle {
				doc /* Pump stationary, no flow */
			}
			
			transition idle_to_priming
				first idle
				if true
				then priming;
			
			state priming {
				doc /* Initial rotation to fill pump with fluid */
			}
			
			transition priming_to_running
				first priming
				if true
				then running;
			
			state running {
				doc /* Normal pumping operation */
				
				state normalFlow {
					doc /* Operating within design parameters */
				}
				
				state cavitation {
					doc /* Insufficient suction pressure causing vapor formation */
				}
				
				transition normal_to_cavitation
					first normalFlow
					if true
					then cavitation;
				
				transition cavitation_to_normal
					first cavitation
					if true
					then normalFlow;
			}
			
			transition running_to_stopping
				first running
				if true
				then stopping;
			
			state stopping {
				doc /* Pump decelerating to stop */
			}
			
			transition stopping_to_idle
				first stopping
				if true
				then idle;
		}
		
		state def MotorOperatingStates {
			entry; then off;
			
			state off {
				doc /* Motor not energized */
			}
			
			transition off_to_starting
				first off
				if true
				then starting;
			
			state starting {
				doc /* Motor accelerating to rated speed */
			}
			
			transition starting_to_running
				first starting
				if true
				then running;
			
			state running {
				doc /* Motor operating at steady state */
			}
			
			transition running_to_stopping
				first running
				if true
				then stopping;
			
			state stopping {
				doc /* Motor decelerating */
			}
			
			transition stopping_to_off
				first stopping
				if true
				then off;
			
			state fault {
				doc /* Motor fault condition */
			}
			
			transition any_to_fault
				first off
				if true
				then fault;
			
			transition fault_to_off
				first fault
				if true
				then off;
		}
		
		state def ReliefValveStates {
			entry; then closed;
			
			state closed {
				doc /* Valve seated, no bypass flow */
			}
			
			transition closed_to_opening
				first closed
				if true
				then opening;
			
			state opening {
				doc /* Valve transitioning to open */
			}
			
			transition opening_to_open
				first opening
				then open;
			
			state open {
				doc /* Valve fully open, bypassing fluid */
			}
			
			transition open_to_closing
				first open
				if true
				then closing;
			
			state closing {
				doc /* Valve transitioning to closed */
			}
			
			transition closing_to_closed
				first closing
				then closed;
		}
		
		state def CheckValveStates {
			entry; then closed;
			
			state closed {
				doc /* Valve preventing reverse flow */
			}
			
			transition closed_to_open
				first closed
				if true
				then open;
			
			state open {
				doc /* Valve allowing forward flow */
			}
			
			transition open_to_closed
				first open
				if true
				then closed;
		}
		
		requirement def FlowRateRequirement {
			doc /*
			 * The pumping subsystem shall deliver minimum specified flow rate
			 * at rated operating conditions.
			 */
			
			attribute requiredFlowRate : Real;
		}
		
		requirement def PressureCapabilityRequirement {
			doc /*
			 * The pumping subsystem shall maintain specified discharge pressure
			 * under rated load conditions.
			 */
			
			attribute requiredPressure : Real;
		}
		
		requirement def EfficiencyRequirement {
			doc /*
			 * The gear pump shall operate at minimum specified overall efficiency.
			 */
			
			attribute minEfficiency : Real;
		}
		
		requirement def SafetyRequirement {
			doc /*
			 * The subsystem shall not exceed maximum rated pressure under any condition.
			 */
		}
		
		requirement def ReliabilityRequirement {
			doc /*
			 * The pumping subsystem shall operate continuously for minimum
			 * specified hours between maintenance.
			 */
			
			attribute minOperatingHours : Real;
		}
		
		part def PumpingSubsystem {
			doc /*
			 * Complete hydraulic pumping subsystem using gear pump technology
			 * for positive displacement fluid transfer.
			 */
			
			part reservoir : FluidReservoir;
			part suctionFilter : SuctionFilter;
			part suctionPressureSensor : PressureSensor;
			part gearPump : GearPump;
			part motor : ElectricMotor;
			part dischargePressureSensor : PressureSensor;
			part flowMeter : FlowMeter;
			part temperatureSensor : TemperatureSensor;
			part checkValve : CheckValve;
			part reliefValve : PressureReliefValve;
			part controller : ControlUnit;
		}
	}
	
	package Usages {
		part pumpingSubsystem : PumpingSubsystem {
			doc /*
			 * Complete hydraulic pumping subsystem using gear pump technology
			 * for positive displacement fluid transfer.
			 */
			
			part redefines reservoir {
				attribute :>> capacity = 200.0;
				attribute :>> currentLevel = 150.0;
				attribute :>> minLevel = 30.0;
				attribute :>> maxLevel = 180.0;
			}
			
			part redefines suctionFilter {
				attribute :>> filtrationRating = 25.0;
				attribute :>> pressureDrop = 0.5;
				attribute :>> maxFlowCapacity = 120.0;
			}
			
			flow reservoir.supplyPort.fluid to suctionFilter.inletPort.fluid;
			
			part redefines suctionPressureSensor {
				attribute :>> accuracy = 0.5;
				attribute :>> range = 10.0;
			}
			
			part redefines gearPump {
				attribute :>> displacementPerRevolution = 63.0;
				attribute :>> maxPressure = 250.0;
				attribute :>> volumetricEfficiency = 0.93;
				attribute :>> mechanicalEfficiency = 0.88;
				attribute :>> numberOfTeeth = 14;
				attribute :>> gearWidth = 32.0;
				
				perform action :>> pumpFluid {
					in :>> suctionFluid = suctionPort.fluid;
					in :>> shaftSpeed = driveShaft.speed;
					in :>> displacement = displacementPerRevolution;
					in :>> efficiency = volumetricEfficiency;
					out :>> dischargeFluid = dischargePort.fluid;
					out :>> actualFlowRate = dischargePort.flowRate;
				}
			}
			
			flow suctionFilter.outletPort.fluid to gearPump.suctionPort.fluid;
			
			interface suctionMonitoring connect
				suctionPressureSensor.sensingPort to gearPump.suctionPort;
			
			part redefines motor {
				attribute :>> ratedPower = 7500.0;
				attribute :>> ratedSpeed = 1450.0;
				attribute :>> ratedVoltage = 480.0;
				attribute :>> efficiency = 0.92;
				
				perform action :>> driveShaft {
					in :>> voltage = electricalInput.voltage;
					in :>> current = electricalInput.current;
					in :>> controlSignal = controlInput.commandSignal;
					out :>> torque = outputShaft.torque;
					out :>> speed = outputShaft.speed;
				}
			}
			
			connect motor.outputShaft to gearPump.driveShaft;
			
			part redefines dischargePressureSensor {
				attribute :>> accuracy = 0.5;
				attribute :>> range = 300.0;
			}
			
			part redefines flowMeter {
				attribute :>> accuracy = 1.0;
				attribute :>> range = 150.0;
			}
			
			part redefines temperatureSensor {
				attribute :>> accuracy = 1.0;
			}
			
			interface dischargeMonitoring connect
				dischargePressureSensor.sensingPort to gearPump.dischargePort;
			
			interface flowMonitoring connect
				flowMeter.sensingPort to gearPump.dischargePort;
			
			interface temperatureMonitoring connect
				temperatureSensor.sensingPort to gearPump.dischargePort;
			
			part redefines checkValve {
				attribute :>> crackingPressure = 0.5;
			}
			
			flow gearPump.dischargePort.fluid to checkValve.inletPort.fluid;
			
			part redefines reliefValve {
				attribute :>> crackingPressure = 210.0;
				attribute :>> maxFlowCapacity = 100.0;
				attribute :>> reseatPressure = 200.0;
				
				perform action :>> regulatePressure {
					in :>> inletPressure = inletPort.pressure;
					in :>> setPoint = crackingPressure;
					out :>> outletPressure = outletPort.pressure;
				}
			}
			
			interface reliefConnection connect
				reliefValve.inletPort to checkValve.outletPort;
			
			flow reliefValve.outletPort.fluid to reservoir.returnPort.fluid;
			
			part redefines controller {
				perform action :>> controlPump {
					in :>> pressureSignal = pressureInput.commandSignal;
					in :>> flowSignal = flowInput.commandSignal;
					in :>> temperatureSignal = temperatureInput.commandSignal;
					out :>> motorCommand = motorControl.commandSignal;
				}
			}
			
			connect dischargePressureSensor.signalOutput to controller.pressureInput;
			connect flowMeter.signalOutput to controller.flowInput;
			connect temperatureSensor.signalOutput to controller.temperatureInput;
			connect controller.motorControl to motor.controlInput;
			connect controller.powerOutput to motor.electricalInput;
			
			satisfy flowReq : FlowRateRequirement {
				attribute :>> requiredFlowRate = 90.0;
			}
			
			satisfy pressureReq : PressureCapabilityRequirement {
				attribute :>> requiredPressure = 150.0;
			}
			
			satisfy efficiencyReq : EfficiencyRequirement {
				attribute :>> minEfficiency = 0.80;
			}
			
			satisfy safetyReq : SafetyRequirement;
			
			satisfy reliabilityReq : ReliabilityRequirement {
				attribute :>> minOperatingHours = 8000.0;
			}
		}
	}
}
