package SumpPumpingSubsystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		attribute def VolumeValue :> Real;
		attribute def FlowRateValue :> Real;
		attribute def PressureValue :> Real;
		attribute def PowerValue :> Real;
		attribute def LengthValue :> Real;
		attribute def LevelValue :> Real;
		
		item def Fluid {
			attribute density : Real;
			attribute volume : VolumeValue;
		}
		
		port def FluidPort {
			out item fluid : Fluid;
		}
		
		part def SumpBasin {
			port outletPort : FluidPort;
			attribute capacity : VolumeValue;
			attribute currentLevel : LevelValue;
			attribute highLevelThreshold : LevelValue;
			attribute lowLevelThreshold : LevelValue;
			
			item storedFluid : Fluid {
				attribute :>> volume : VolumeValue;
			}
		}
		
		part def SumpPump {
			port inletPort : ~FluidPort;
			port dischargePort : FluidPort;
			
			attribute ratedPower : PowerValue;
			attribute maxFlowRate : FlowRateValue;
			attribute maxDischargeHead : PressureValue;
			attribute isOperating : Boolean;
			
			part motor {
				attribute power : PowerValue;
				attribute efficiency : Real;
			}
			
			part impeller {
				attribute diameter : LengthValue;
			}
			
			part checkValve {
				attribute isOpen : Boolean;
			}
			
			part floatSwitch {
				attribute activationLevel : LevelValue;
				attribute deactivationLevel : LevelValue;
				attribute isActivated : Boolean;
			}
		}
		
		part def DischargePipe {
			port inletPort : ~FluidPort;
			port outletPort : FluidPort;
			
			attribute length : LengthValue;
			attribute diameter : LengthValue;
			attribute material : String;
		}
		
		part def DischargePoint {
			port inletPort : ~FluidPort;
		}
		
		action def MonitorLevel {
			in currentLevel : LevelValue;
			in highThreshold : LevelValue;
			in lowThreshold : LevelValue;
			out activatePump : Boolean;
			out deactivatePump : Boolean;
		}
		
		action def PumpFluid {
			in fluidIn : Fluid;
			out fluidOut : Fluid;
			in flowRate : FlowRateValue;
		}
		
		state def SumpPumpControlStates {
			in currentLevel : LevelValue;
			in highThreshold : LevelValue;
			in lowThreshold : LevelValue;
			
			entry; then off;
			
			state off;
			
			transition off_to_monitoring
				first off
				accept LevelCheck
				then monitoring;
			
			state monitoring {
				do action checkLevel : MonitorLevel {
					in currentLevel = SumpPumpControlStates::currentLevel;
					in highThreshold = SumpPumpControlStates::highThreshold;
					in lowThreshold = SumpPumpControlStates::lowThreshold;
				}
			}
			
			transition monitoring_to_pumping
				first monitoring
				if checkLevel.activatePump
				then pumping;
			
			transition monitoring_to_off
				first monitoring
				if !checkLevel.activatePump && !checkLevel.deactivatePump
				then off;
			
			state pumping {
				do action pumpAction : PumpFluid;
			}
			
			transition pumping_to_monitoring
				first pumping
				accept LevelCheck
				then monitoring;
			
			transition pumping_to_off
				first pumping
				if checkLevel.deactivatePump
				then off;
		}
	}
	
	package Requirements {
		requirement def AutomaticOperation {
			doc /* The sump pump shall automatically activate when fluid level 
			       reaches the high threshold and deactivate when level drops 
			       to the low threshold. */
			
			subject pump : Definitions::SumpPump;
			
			requirement activationReq {
				doc /* Pump shall activate at high level threshold. */
				require constraint {
					pump.floatSwitch.isActivated implies pump.isOperating
				}
			}
			
			requirement deactivationReq {
				doc /* Pump shall deactivate at low level threshold. */
				require constraint {
					!pump.floatSwitch.isActivated implies !pump.isOperating
				}
			}
		}
		
		requirement def FlowCapacity {
			doc /* The sump pump shall maintain minimum flow rate capacity. */
			
			subject pump : Definitions::SumpPump;
			attribute minFlowRate : Definitions::FlowRateValue;
			
			require constraint {
				pump.maxFlowRate >= minFlowRate
			}
		}
		
		requirement def BackflowPrevention {
			doc /* The system shall prevent backflow when pump is not operating. */
			
			subject pump : Definitions::SumpPump;
			
			require constraint {
				pump.checkValve.isOpen == pump.isOperating
			}
		}
	}
	
	package Usages {
		part sumpPumpingSystem {
			part sumpBasin : Definitions::SumpBasin {
				attribute :>> capacity = 150.0;
				attribute :>> highLevelThreshold = 0.75;
				attribute :>> lowLevelThreshold = 0.25;
				attribute :>> currentLevel = 0.30;
				
				item :>> storedFluid {
					attribute :>> volume = 45.0;
					attribute :>> density = 1000.0;
				}
			}
			
			flow of fluid : Definitions::Fluid
				from sumpBasin.outletPort.fluid
				to sumpPump.inletPort.fluid;
			
			part sumpPump : Definitions::SumpPump {
				attribute :>> ratedPower = 500.0;
				attribute :>> maxFlowRate = 60.0;
				attribute :>> maxDischargeHead = 40000.0;
				attribute :>> isOperating = false;
				
				part :>> motor {
					attribute :>> power = 500.0;
					attribute :>> efficiency = 0.85;
				}
				
				part :>> impeller {
					attribute :>> diameter = 0.12;
				}
				
				part :>> checkValve {
					attribute :>> isOpen = false;
				}
				
				part :>> floatSwitch {
					attribute :>> activationLevel = 0.75;
					attribute :>> deactivationLevel = 0.25;
					attribute :>> isActivated = false;
				}
				
				perform action pumpingAction : Definitions::PumpFluid {
					in fluidIn = inletPort.fluid;
					out fluidOut = dischargePort.fluid;
					in flowRate = maxFlowRate;
				}
				
				exhibit state controlStateMachine : Definitions::SumpPumpControlStates {
					in currentLevel = sumpBasin.currentLevel;
					in highThreshold = sumpBasin.highLevelThreshold;
					in lowThreshold = sumpBasin.lowLevelThreshold;
				}
			}
			
			flow of fluid : Definitions::Fluid
				from sumpPump.dischargePort.fluid
				to dischargePipe.inletPort.fluid;
			
			part dischargePipe : Definitions::DischargePipe {
				attribute :>> length = 4.5;
				attribute :>> diameter = 0.05;
				attribute :>> material = "PVC";
			}
			
			flow of fluid : Definitions::Fluid
				from dischargePipe.outletPort.fluid
				to dischargePoint.inletPort.fluid;
			
			part dischargePoint : Definitions::DischargePoint;
			
			bind sumpPump.floatSwitch.isActivated = 
				(sumpBasin.currentLevel >= sumpBasin.highLevelThreshold);
			
			action pumpControl {
				first start;
				then merge monitoringLoop;
				
				then action monitor : Definitions::MonitorLevel {
					in currentLevel = sumpBasin.currentLevel;
					in highThreshold = sumpBasin.highLevelThreshold;
					in lowThreshold = sumpBasin.lowLevelThreshold;
					out activatePump : Boolean;
					out deactivatePump : Boolean;
				}
				
				then decide;
					if monitor.activatePump then activatePump;
					if monitor.deactivatePump then deactivatePump;
					if !monitor.activatePump && !monitor.deactivatePump then monitoringLoop;
				
				action activatePump {
					assign sumpPump.isOperating = true;
					assign sumpPump.checkValve.isOpen = true;
				}
				then monitoringLoop;
				
				action deactivatePump {
					assign sumpPump.isOperating = false;
					assign sumpPump.checkValve.isOpen = false;
				}
				then monitoringLoop;
			}
			
			satisfy requirement autoOpReq : Requirements::AutomaticOperation {
				subject sumpPump;
			}
			
			satisfy requirement flowReq : Requirements::FlowCapacity {
				subject sumpPump;
				attribute :>> minFlowRate = 50.0;
			}
			
			satisfy requirement backflowReq : Requirements::BackflowPrevention {
				subject sumpPump;
			}
		}
	}
}
