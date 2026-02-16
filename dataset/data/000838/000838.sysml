package 'Metering Pump Subsystem' {
	private import ScalarValues::*;
	
	package Definitions {
		item def Fluid {
			attribute density : Real;
			attribute viscosity : Real;
			attribute temperature : Real;
		}
		
		attribute def FlowRate {
			attribute value : Real;
			attribute unit : String = "L/min";
		}
		
		attribute def Pressure {
			attribute value : Real;
			attribute unit : String = "bar";
		}
		
		attribute def Volume {
			attribute value : Real;
			attribute unit : String = "L";
		}
		
		attribute def StrokeRate {
			attribute value : Real;
			attribute unit : String = "strokes/min";
		}
		
		port def FluidInPort {
			attribute inletPressure : Pressure;
			in item fluidIn : Fluid;
		}
		
		port def FluidOutPort {
			attribute outletPressure : Pressure;
			attribute flowRate : FlowRate;
			out item fluidOut : Fluid;
		}
		
		part def SupplyTank {
			port outlet : FluidOutPort;
			attribute capacity : Volume;
			attribute currentLevel : Volume;
			
			item storedFluid : Fluid {
				attribute volume : Volume;
			}
		}
		
		part def ReceivingVessel {
			port inlet : FluidInPort;
			attribute capacity : Volume;
			attribute currentLevel : Volume;
			
			item receivedFluid : Fluid {
				attribute volume : Volume;
			}
		}
		
		part def MeteringPump {
			port suctionPort : FluidInPort;
			port dischargePort : FluidOutPort;
			
			attribute strokeVolume : Volume;
			attribute strokeRate : StrokeRate;
			attribute efficiency : Real;
			attribute maxPressure : Pressure;
			attribute targetFlowRate : FlowRate;
			attribute actualFlowRate : FlowRate;
			attribute suctionPressureStable : Boolean;
			attribute flowDeviationDetected : Boolean;
			attribute flowStabilized : Boolean;
			attribute pressureExceeded : Boolean;
			attribute cavitationDetected : Boolean;
			
			part pumpHead {
				part piston;
				part cylinder;
				part suctionValve;
				part dischargeValve;
			}
			
			part motor {
				attribute speed : StrokeRate;
				attribute power : Real;
			}
			
			part controller {
				attribute setpoint : FlowRate;
				attribute feedback : FlowRate;
				attribute controlSignal : Real;
			}
			
			perform action meteringOperation : MeteringOperation;
			exhibit state operatingState : PumpOperatingStates;
		}
		
		part def FlowSensor {
			port measurementPort : ~FluidOutPort;
			attribute measuredFlow : FlowRate;
		}
		
		action def MeteringOperation {
			in fluidInput : Fluid;
			in setpointFlow : FlowRate;
			out fluidOutput : Fluid;
			out deliveredFlow : FlowRate;
			
			first start;
			then action initializePump : InitializePump;
			then merge controlLoop;
			
			action monitorFlow : MonitorFlow {
				out currentFlow : FlowRate;
			}
			then decide;
				if monitorFlow.currentFlow.value < setpointFlow.value then increaseRate;
				if monitorFlow.currentFlow.value > setpointFlow.value then decreaseRate;
			
			action increaseRate : AdjustStrokeRate {
				in adjustment = 5.0;
			}
			then controlLoop;
			
			action decreaseRate : AdjustStrokeRate {
				in adjustment = -5.0;
			}
			then controlLoop;
			
			merge controlLoop;
			then action pumpStroke : ExecutePumpStroke {
				in fluidIn = fluidInput;
				out fluidOut = fluidOutput;
			}
			then monitorFlow;
		}
		
		action def InitializePump;
		action def MonitorFlow {
			out currentFlow : FlowRate;
		}
		action def AdjustStrokeRate {
			in adjustment : Real;
		}
		action def ExecutePumpStroke {
			in fluidIn : Fluid;
			out fluidOut : Fluid;
		}
		action def PrimePump;
		action def StartMetering;
		action def MeteringCycle;
		action def TriggerAlarm;
		action def ShutdownPump;
		
		state def PumpOperatingStates {
			entry; then idle;
			
			state idle;
			
			transition idle_to_priming
				first idle
				then priming;
			
			state priming {
				entry action primePump : PrimePump;
			}
			
			transition priming_to_running
				first priming
				then running;
			
			state running {
				entry action startMetering : StartMetering;
				do action meteringCycle : MeteringCycle;
				
				state normalOperation;
				state flowAdjustment;
				
				transition normalOperation_to_flowAdjustment
					first normalOperation
					then flowAdjustment;
				
				transition flowAdjustment_to_normalOperation
					first flowAdjustment
					then normalOperation;
			}
			
			transition running_to_alarm
				first running
				then alarm;
			
			transition running_to_stopped
				first running
				then stopped;
			
			state alarm {
				entry action triggerAlarm : TriggerAlarm;
				entry action shutdownPump : ShutdownPump;
			}
			
			transition alarm_to_stopped
				first alarm
				then stopped;
			
			state stopped;
			
			transition stopped_to_idle
				first stopped
				then idle;
		}
		
		requirement def MeteringPumpRequirements {
			doc /* Requirements for metering pump subsystem performance and safety */
			
			requirement flowAccuracyReq {
				doc /* The pump shall maintain flow rate within ±2% of setpoint under steady-state conditions */
				attribute tolerance : Real = 0.02;
			}
			
			requirement pressureRangeReq {
				doc /* The pump shall operate at discharge pressures up to 150 bar */
				attribute maxOperatingPressure : Pressure;
			}
			
			requirement repeatabilityReq {
				doc /* The pump shall provide flow repeatability within ±1% */
				attribute repeatabilityTolerance : Real = 0.01;
			}
			
			requirement responseTimeReq {
				doc /* The pump shall reach target flow rate within 10 seconds of setpoint change */
				attribute maxResponseTime : Real = 10.0;
			}
			
			requirement cavitationPreventionReq {
				doc /* The pump shall prevent cavitation by maintaining minimum suction pressure */
				attribute minSuctionPressure : Pressure;
			}
		}
		
		interface def FluidTransferInterface {
			end port sourcePort : FluidOutPort;
			end port destinationPort : FluidInPort;
		}
		
		part def PumpingSubsystem {
			part supplyTank : SupplyTank;
			part meteringPump : MeteringPump;
			part flowSensor : FlowSensor;
			part receivingVessel : ReceivingVessel;
		}
	}
	
	package Usages {
		import Definitions::*;
		
		part pumpingSystem : PumpingSubsystem {
			part redefines supplyTank {
				attribute redefines capacity {
					attribute redefines value = 500.0;
					attribute redefines unit = "L";
				}
				attribute redefines currentLevel {
					attribute redefines value = 400.0;
					attribute redefines unit = "L";
				}
			}
			
			flow of transferFluid : Fluid
				from supplyTank.outlet.fluidOut
				to meteringPump.suctionPort.fluidIn;
			
			part redefines meteringPump {
				attribute redefines strokeVolume {
					attribute redefines value = 0.25;
					attribute redefines unit = "L";
				}
				attribute redefines strokeRate {
					attribute redefines value = 120.0;
					attribute redefines unit = "strokes/min";
				}
				attribute redefines efficiency = 0.95;
				attribute redefines maxPressure {
					attribute redefines value = 150.0;
					attribute redefines unit = "bar";
				}
				attribute redefines targetFlowRate {
					attribute redefines value = 28.5;
					attribute redefines unit = "L/min";
				}
			}
			
			part redefines flowSensor {
				bind measurementPort.fluidOut = meteringPump.dischargePort.fluidOut;
			}
			
			flow of deliverFluid : Fluid
				from meteringPump.dischargePort.fluidOut
				to receivingVessel.inlet.fluidIn;
			
			part redefines receivingVessel {
				attribute redefines capacity {
					attribute redefines value = 1000.0;
					attribute redefines unit = "L";
				}
				attribute redefines currentLevel {
					attribute redefines value = 50.0;
					attribute redefines unit = "L";
				}
			}
			
			interface supplyToMeteringPump : FluidTransferInterface
				connect sourcePort ::> supplyTank.outlet
				to destinationPort ::> meteringPump.suctionPort;
			
			interface meteringPumpToReceiving : FluidTransferInterface
				connect sourcePort ::> meteringPump.dischargePort
				to destinationPort ::> receivingVessel.inlet;
			
			requirement systemRequirements : MeteringPumpRequirements {
				requirement redefines flowAccuracyReq;
				requirement redefines pressureRangeReq {
					attribute redefines maxOperatingPressure {
						attribute redefines value = 150.0;
						attribute redefines unit = "bar";
					}
				}
				requirement redefines repeatabilityReq;
				requirement redefines responseTimeReq;
				requirement redefines cavitationPreventionReq {
					attribute redefines minSuctionPressure {
						attribute redefines value = 0.5;
						attribute redefines unit = "bar";
					}
				}
			}
		}
	}
}
