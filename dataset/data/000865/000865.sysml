package 'Divers Pump Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	package Definitions {
		
		attribute def PressureValue :> Real;
		
		attribute def VolumeValue :> Real;
		
		attribute def FlowRateValue :> Real;
		
		attribute def LengthValue :> Real;
		
		attribute def FrequencyValue :> Real;
		
		item def Fluid {
			attribute density : Real;
			attribute viscosity : Real;
			attribute temperature : Real;
			attribute volume : VolumeValue;
			attribute pressure : PressureValue;
		}
		
		enum def PumpState {
			enum idle;
			enum priming;
			enum pumping;
			enum stopping;
			enum fault;
		}
		
		port def FluidInletPort {
			attribute inletPressure : PressureValue;
			in item fluidIn : Fluid;
		}
		
		port def FluidOutletPort {
			attribute outletPressure : PressureValue;
			out item fluidOut : Fluid;
		}
		
		port def ControlPort {
			in attribute startCommand : Boolean;
			in attribute stopCommand : Boolean;
			out attribute currentState : PumpState;
			out attribute flowRate : FlowRateValue;
		}
		
		part def PistonAssembly {
			attribute diameter : LengthValue;
			attribute strokeLength : LengthValue;
			attribute position : LengthValue;
			attribute maxStroke : LengthValue;
		}
		
		part def ValveAssembly {
			attribute isOpen : Boolean;
			attribute crackingPressure : PressureValue;
		}
		
		part def CylinderChamber {
			attribute volume : VolumeValue;
			attribute maxVolume : VolumeValue;
			item containedFluid : Fluid;
		}
		
		part def DriveMechanism {
			attribute power : Real;
			attribute speed : FrequencyValue;
			attribute isActive : Boolean;
		}
		
		part def DiversPump {
			port inlet : FluidInletPort;
			port outlet : FluidOutletPort;
			port control : ControlPort;
			
			attribute ratedFlowRate : FlowRateValue;
			attribute maxPressure : PressureValue;
			attribute currentState : PumpState;
			attribute strokeFrequency : FrequencyValue;
			attribute efficiency : Real;
			
			part piston : PistonAssembly {
				attribute :>> diameter = 0.1;
				attribute :>> strokeLength = 0.15;
				attribute :>> maxStroke = 0.15;
			}
			
			part inletValve : ValveAssembly {
				attribute :>> crackingPressure = 500.0;
			}
			
			part outletValve : ValveAssembly {
				attribute :>> crackingPressure = 1000.0;
			}
			
			part cylinder : CylinderChamber {
				attribute :>> maxVolume = 1.178;
			}
			
			part driveMechanism : DriveMechanism;
		}
		
		part def SourceReservoir {
			port outlet : FluidOutletPort;
			
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			attribute minLevel : VolumeValue;
			
			item storedFluid : Fluid {
				attribute volume : VolumeValue;
			}
		}
		
		part def DestinationVessel {
			port inlet : FluidInletPort;
			
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			
			item receivedFluid : Fluid {
				attribute volume : VolumeValue;
			}
		}
		
		part def PressureSensor {
			attribute measuredPressure : PressureValue;
			attribute accuracy : Real;
		}
		
		part def FlowSensor {
			attribute measuredFlowRate : FlowRateValue;
			attribute totalVolume : VolumeValue;
		}
		
		part def PumpController {
			port commandPort : ControlPort;
			
			attribute targetFlowRate : FlowRateValue;
			attribute enableOperation : Boolean;
			attribute faultDetected : Boolean;
		}
		
		action def PrimePump {
			in pumpRef : DiversPump;
			out isPrimed : Boolean;
			
			first start;
			then action openInlet {
				inout valve : ValveAssembly = pumpRef.inletValve;
				assign valve.isOpen := true;
			}
			then action fillCylinder {
				in fluid : Fluid;
				inout chamber : CylinderChamber = pumpRef.cylinder;
			}
			then action closeInlet {
				inout valve : ValveAssembly = pumpRef.inletValve;
				assign valve.isOpen := false;
			}
			then done;
		}
		
		action def ExecuteIntakeStroke {
			in pumpRef : DiversPump;
			in fluidIn : Fluid;
			
			first start;
			then action openInletValve {
				inout valve : ValveAssembly = pumpRef.inletValve;
				assign valve.isOpen := true;
			}
			then action retractPiston {
				inout piston : PistonAssembly = pumpRef.piston;
			}
			then action closeInletValve {
				inout valve : ValveAssembly = pumpRef.inletValve;
				assign valve.isOpen := false;
			}
			then done;
		}
		
		action def ExecuteDischargeStroke {
			in pumpRef : DiversPump;
			out fluidOut : Fluid;
			
			first start;
			then action openOutletValve {
				inout valve : ValveAssembly = pumpRef.outletValve;
				assign valve.isOpen := true;
			}
			then action advancePiston {
				inout piston : PistonAssembly = pumpRef.piston;
			}
			then action closeOutletValve {
				inout valve : ValveAssembly = pumpRef.outletValve;
				assign valve.isOpen := false;
			}
			then done;
		}
		
		action def ExecutePumpCycle {
			in pumpRef : DiversPump;
			in fluidIn : Fluid;
			out fluidOut : Fluid;
			
			first start;
			then action intakeStroke : ExecuteIntakeStroke {
				in pumpRef = ExecutePumpCycle::pumpRef;
				in fluidIn = ExecutePumpCycle::fluidIn;
			}
			then action dischargeStroke : ExecuteDischargeStroke {
				in pumpRef = ExecutePumpCycle::pumpRef;
				out fluidOut = ExecutePumpCycle::fluidOut;
			}
			then done;
		}
		
		action def MonitorPumpOperation {
			in pumpRef : DiversPump;
			out status : PumpState;
			
			action checkInletPressure {
				in pressure : PressureValue;
				out pressureOK : Boolean;
			}
			
			action checkOutletPressure {
				in pressure : PressureValue;
				out pressureOK : Boolean;
			}
			
			action checkFlowRate {
				in currentFlow : FlowRateValue;
				in targetFlow : FlowRateValue;
				out flowOK : Boolean;
			}
		}
		
		action def ControlPumpOperation {
			in startCmd : Boolean;
			in stopCmd : Boolean;
			inout pump : DiversPump;
			out operationStatus : PumpState;
			
			first start;
			then merge checkCommands;
			
			then decide;
				if startCmd == true and pump.currentState == PumpState::idle 
					then initiatePriming;
				if pump.currentState == PumpState::priming 
					then beginPumping;
				if pump.currentState == PumpState::pumping and stopCmd == false 
					then continuePumping;
				if pump.currentState == PumpState::pumping and stopCmd == true 
					then initiateStop;
				if pump.currentState == PumpState::fault 
					then handleFault;
			
			action initiatePriming : PrimePump {
				in pumpRef = pump;
			}
			then beginPumping;
			
			action beginPumping {
				assign pump.currentState := PumpState::pumping;
				assign pump.driveMechanism.isActive := true;
			}
			then continuePumping;
			
			action continuePumping : ExecutePumpCycle {
				in pumpRef = pump;
			}
			then action monitor : MonitorPumpOperation {
				in pumpRef = pump;
			}
			then checkCommands;
			
			action initiateStop {
				assign pump.currentState := PumpState::stopping;
				assign pump.driveMechanism.isActive := false;
			}
			then finalizeStop;
			
			action finalizeStop {
				assign pump.currentState := PumpState::idle;
			}
			then done;
			
			action handleFault {
				assign pump.driveMechanism.isActive := false;
			}
			then done;
		}
		
		state def PumpOperationStateMachine {
			in ref pump : DiversPump;
			
			entry; then idle;
			
			state idle {
				entry assign pump.driveMechanism.isActive := false;
			}
			
			transition idle_to_priming
				first idle
				accept startSignal : Boolean
				if startSignal == true
				then priming;
			
			state priming {
				entry; then primingAction;
				do action primingAction : PrimePump {
					in pumpRef = pump;
				}
			}
			
			transition priming_to_pumping
				first priming
				if primingAction.isPrimed == true
				then pumping;
			
			state pumping {
				entry assign pump.driveMechanism.isActive := true;
				do action pumpCycle : ExecutePumpCycle {
					in pumpRef = pump;
				}
				do action monitoring : MonitorPumpOperation {
					in pumpRef = pump;
				}
			}
			
			transition pumping_to_stopping
				first pumping
				accept stopSignal : Boolean
				if stopSignal == true
				then stopping;
			
			transition pumping_to_fault
				first pumping
				if monitoring.status == PumpState::fault
				then fault;
			
			state stopping {
				entry assign pump.driveMechanism.isActive := false;
			}
			
			transition stopping_to_idle
				first stopping
				then idle;
			
			state fault {
				entry assign pump.driveMechanism.isActive := false;
			}
			
			transition fault_to_idle
				first fault
				accept resetSignal : Boolean
				if resetSignal == true
				then idle;
		}
	}
	
	package Requirements {
		
		requirement def FlowRateRequirement {
			doc /* The Diver's pump shall deliver fluid at a minimum flow rate of 20 liters per minute. */
			
			subject pump : Definitions::DiversPump;
			
			require constraint {
				pump.ratedFlowRate >= 20.0
			}
		}
		
		requirement def PressureRequirement {
			doc /* The pump shall maintain outlet pressure between 5 and 30 bar during operation. */
			
			subject pump : Definitions::DiversPump;
			
			require constraint {
				pump.maxPressure >= 5.0 and pump.maxPressure <= 30.0
			}
		}
		
		requirement def EfficiencyRequirement {
			doc /* The pump shall operate with a minimum efficiency of 75 percent. */
			
			subject pump : Definitions::DiversPump;
			
			require constraint {
				pump.efficiency >= 0.75
			}
		}
		
		requirement def SafetyRequirement {
			doc /* The pump shall enter fault state when operating parameters exceed safe limits. */
			
			subject pump : Definitions::DiversPump;
		}
		
		requirement def PrimingRequirement {
			doc /* The pump shall complete priming cycle before beginning pumping operation. */
			
			subject pump : Definitions::DiversPump;
		}
	}
	
	package Usages {
		
		part pumpingSubsystem {
			
			part sourceReservoir : Definitions::SourceReservoir {
				attribute :>> capacity = 2000.0;
				attribute :>> currentLevel = 1500.0;
				attribute :>> minLevel = 200.0;
				
				item :>> storedFluid {
					attribute :>> volume = 1500.0;
					attribute :>> pressure = 101325.0;
					attribute :>> temperature = 293.0;
					attribute :>> density = 1000.0;
					attribute :>> viscosity = 0.001;
				}
			}
			
			part diversPump : Definitions::DiversPump {
				attribute :>> ratedFlowRate = 25.0;
				attribute :>> maxPressure = 20.0;
				attribute :>> currentState = Definitions::PumpState::idle;
				attribute :>> strokeFrequency = 60.0;
				attribute :>> efficiency = 0.82;
				
				part :>> driveMechanism {
					attribute :>> power = 1500.0;
					attribute :>> speed = 60.0;
					attribute :>> isActive = false;
				}
				
				exhibit state operationStateMachine : Definitions::PumpOperationStateMachine {
					in ref pump = diversPump;
				}
			}
			
			part destinationVessel : Definitions::DestinationVessel {
				attribute :>> capacity = 1000.0;
				attribute :>> currentLevel = 0.0;
				
				item :>> receivedFluid {
					attribute :>> volume = 0.0;
				}
			}
			
			part inletPressureSensor : Definitions::PressureSensor {
				attribute :>> accuracy = 0.01;
			}
			
			part outletPressureSensor : Definitions::PressureSensor {
				attribute :>> accuracy = 0.01;
			}
			
			part flowSensor : Definitions::FlowSensor {
				attribute :>> totalVolume = 0.0;
			}
			
			part controller : Definitions::PumpController {
				attribute :>> targetFlowRate = 25.0;
				attribute :>> enableOperation = false;
				attribute :>> faultDetected = false;
				
				perform action controlOperation : Definitions::ControlPumpOperation {
					in startCmd = controller.enableOperation;
					in stopCmd = not controller.enableOperation;
					inout pump = diversPump;
					out operationStatus = diversPump.currentState;
				}
			}
			
			flow of fluid : Definitions::Fluid
				from sourceReservoir.outlet.fluidOut
				to diversPump.inlet.fluidIn;
			
			flow of fluid : Definitions::Fluid
				from diversPump.outlet.fluidOut
				to destinationVessel.inlet.fluidIn;
			
			connection controlConnection
				connect controller.commandPort to diversPump.control;
			
			satisfy flowRateReq : Requirements::FlowRateRequirement {
				subject pump = diversPump;
			}
			
			satisfy pressureReq : Requirements::PressureRequirement {
				subject pump = diversPump;
			}
			
			satisfy efficiencyReq : Requirements::EfficiencyRequirement {
				subject pump = diversPump;
			}
			
			satisfy safetyReq : Requirements::SafetyRequirement {
				subject pump = diversPump;
			}
			
			satisfy primingReq : Requirements::PrimingRequirement {
				subject pump = diversPump;
			}
		}
	}
}
