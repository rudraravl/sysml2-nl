package 'Bilge Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package ValueTypes {
		attribute def LitersPerMinute :> Real;
		attribute def Meters :> Real;
		attribute def Liters :> Real;
		attribute def Volts :> Real;
		attribute def Amperes :> Real;
		attribute def Watts :> Real;
		attribute def Seconds :> Real;
		
		attribute def FlowRate {
			attribute magnitude : Real;
			attribute unit : LitersPerMinute;
		}
		
		attribute def Length {
			attribute magnitude : Real;
			attribute unit : Meters;
		}
		
		attribute def Volume {
			attribute magnitude : Real;
			attribute unit : Liters;
		}
		
		attribute def Voltage {
			attribute magnitude : Real;
			attribute unit : Volts;
		}
		
		attribute def Current {
			attribute magnitude : Real;
			attribute unit : Amperes;
		}
		
		attribute def Power {
			attribute magnitude : Real;
			attribute unit : Watts;
		}
		
		attribute def Time {
			attribute magnitude : Real;
			attribute unit : Seconds;
		}
	}
	
	package Items {
		private import ValueTypes::*;
		
		item def BilgeWater {
			attribute density : Real;
			attribute temperature : Real;
			attribute volume : Volume;
			attribute contaminantLevel : Real;
		}
	}
	
	package Ports {
		private import Items::*;
		private import ValueTypes::*;
		
		port def FluidInletPort {
			in item waterIn : BilgeWater;
			attribute inletPressure : Real;
			attribute inletFlowRate : FlowRate;
		}
		
		port def FluidOutletPort {
			out item waterOut : BilgeWater;
			attribute outletPressure : Real;
			attribute outletFlowRate : FlowRate;
		}
		
		port def ElectricalPort {
			in attribute voltage : Voltage;
			in attribute current : Current;
			attribute powerDraw : Power;
		}
		
		port def SensorPort {
			out attribute waterLevel : Length;
			out attribute levelAlarm : Boolean;
		}
		
		port def ControlPort {
			in attribute startCommand : Boolean;
			in attribute stopCommand : Boolean;
			out attribute pumpStatus : Boolean;
			out attribute faultStatus : Boolean;
		}
	}
	
	package Components {
		private import Items::*;
		private import Ports::*;
		private import ValueTypes::*;
		
		part def BilgeCompartment {
			attribute capacity : Volume;
			attribute currentLevel : Length;
			attribute highWaterMark : Length;
			attribute lowWaterMark : Length;
			
			port outletPort : FluidOutletPort;
			port sensorPort : SensorPort;
			
			item storedWater : BilgeWater {
				attribute :>> volume : Volume;
			}
			
			bind outletPort.waterOut = storedWater;
			
			assert constraint LevelWithinCapacity {
				doc /* Current water level must not exceed compartment capacity */
				currentLevel.magnitude <= capacity.magnitude
			}
		}
		
		part def FloatSwitch {
			attribute activationLevel : Length;
			attribute deactivationLevel : Length;
			attribute hysteresis : Real;
			
			port sensorInput : ~SensorPort;
			port controlOutput : ControlPort;
			
			state floatSwitchBehavior {
				entry; then inactive;
				
				state inactive {
					entry assign controlOutput.startCommand = false;
				}
				
				transition inactiveToActive
					first inactive
					accept at sensorInput.waterLevel
					if sensorInput.waterLevel.magnitude >= activationLevel.magnitude
					then active;
				
				state active {
					entry assign controlOutput.startCommand = true;
					entry assign sensorInput.levelAlarm = true;
				}
				
				transition activeToInactive
					first active
					accept at sensorInput.waterLevel
					if sensorInput.waterLevel.magnitude <= deactivationLevel.magnitude
					then inactive;
			}
		}
		
		action def PumpFluid {
			in fluidIn : BilgeWater;
			out fluidOut : BilgeWater;
			in flowRate : FlowRate;
			in pressureRise : Real;
		}
		
		part def BilgePump {
			attribute ratedFlowRate : FlowRate;
			attribute maxHead : Length;
			attribute ratedPower : Power;
			attribute efficiency : Real;
			attribute operatingVoltage : Voltage;
			attribute runTime : Time;
			
			port inletPort : FluidInletPort;
			port outletPort : FluidOutletPort;
			port powerPort : ElectricalPort;
			port controlPort : ~ControlPort;
			
			perform action pumpingAction : PumpFluid;
			
			state pumpController {
				entry; then off;
				
				state off {
					entry assign controlPort.pumpStatus = false;
				}
				
				transition offToPriming
					first off
					accept at controlPort.startCommand
					if controlPort.startCommand == true
					then priming;
				
				state priming {
					entry assign controlPort.pumpStatus = true;
					
					do action primePump {
						in duration : Time;
						out primeComplete : Boolean;
					}
				}
				
				transition primingToRunning
					first priming
					if priming.primePump.primeComplete == true
					then running;
				
				transition primingToFault
					first priming
					accept after 15.0
					if priming.primePump.primeComplete == false
					then fault;
				
				state running {
					entry assign controlPort.pumpStatus = true;
					do pumpingAction;
				}
				
				transition runningToOff
					first running
					accept at controlPort.stopCommand
					if controlPort.stopCommand == true
					then off;
				
				transition runningToFault
					first running
					if inletPort.inletPressure < 0.0 | 
					   outletPort.outletPressure > maxHead.magnitude * 10.0
					then fault;
				
				state fault {
					entry assign controlPort.faultStatus = true;
					entry assign controlPort.pumpStatus = false;
				}
				
				transition faultToOff
					first fault
					accept at controlPort.stopCommand
					if controlPort.stopCommand == true
					then off;
			}
			
			assert constraint PowerConsumption {
				doc /* Pump power consumption must not exceed rated power */
				powerPort.powerDraw.magnitude <= ratedPower.magnitude * 1.1
			}
			
			assert constraint FlowRateCapability {
				doc /* Pump must deliver rated flow at specified head */
				outletPort.outletFlowRate.magnitude >= ratedFlowRate.magnitude * 0.9
			}
		}
		
		part def DischargeOutlet {
			attribute dischargeHeight : Length;
			attribute backPressure : Real;
			
			port inletPort : FluidInletPort;
			
			item dischargedWater : BilgeWater;
			
			bind inletPort.waterIn = dischargedWater;
		}
		
		part def PowerSupply {
			attribute nominalVoltage : Voltage;
			attribute maxCurrent : Current;
			attribute capacity : Real;
			
			port powerOutput : ~ElectricalPort;
			
			assert constraint VoltageRegulation {
				doc /* Power supply must maintain voltage within tolerance */
				powerOutput.voltage.magnitude >= nominalVoltage.magnitude * 0.95 &
				powerOutput.voltage.magnitude <= nominalVoltage.magnitude * 1.05
			}
		}
		
		part def BilgePumpingSubsystem {
			part bilgeCompartment : BilgeCompartment {
				attribute :>> capacity.magnitude = 150.0;
				attribute :>> currentLevel.magnitude = 0.0;
				attribute :>> highWaterMark.magnitude = 0.8;
				attribute :>> lowWaterMark.magnitude = 0.15;
			}
			
			part floatSwitch : FloatSwitch {
				bind activationLevel = bilgeCompartment.highWaterMark;
				bind deactivationLevel = bilgeCompartment.lowWaterMark;
				attribute :>> hysteresis = 0.05;
			}
			
			part bilgePump : BilgePump {
				attribute :>> ratedFlowRate.magnitude = 60.0;
				attribute :>> maxHead.magnitude = 4.0;
				attribute :>> ratedPower.magnitude = 120.0;
				attribute :>> efficiency = 0.55;
				attribute :>> operatingVoltage.magnitude = 12.0;
			}
			
			part powerSupply : PowerSupply {
				attribute :>> nominalVoltage.magnitude = 12.0;
				attribute :>> maxCurrent.magnitude = 15.0;
				attribute :>> capacity = 100.0;
			}
			
			part dischargeOutlet : DischargeOutlet {
				attribute :>> dischargeHeight.magnitude = 2.5;
				attribute :>> backPressure = 0.2;
			}
			
			connect bilgeCompartment.sensorPort to floatSwitch.sensorInput;
			connect floatSwitch.controlOutput to bilgePump.controlPort;
			connect powerSupply.powerOutput to bilgePump.powerPort;
			
			flow of water : BilgeWater 
				from bilgeCompartment.outletPort.waterOut 
				to bilgePump.inletPort.waterIn;
			
			flow of water : BilgeWater
				from bilgePump.outletPort.waterOut
				to dischargeOutlet.inletPort.waterIn;
			
			assert constraint SystemFlowCapacity {
				doc /* System must handle minimum required flow rate */
				bilgePump.ratedFlowRate.magnitude >= 50.0
			}
		}
	}
	
	package Requirements {
		private import Components::*;
		private import ValueTypes::*;
		
		requirement def BilgePumpingRequirement {
			doc /*
			 * The bilge pumping subsystem shall automatically remove
			 * accumulated water from the bilge compartment to prevent
			 * flooding and maintain vessel safety.
			 */
			
			subject subsystem : BilgePumpingSubsystem;
			
			require flowCapacityReq : FlowCapacityRequirement;
			require automationReq : AutomationRequirement;
			require reliabilityReq : ReliabilityRequirement;
			require safetyReq : SafetyRequirement;
		}
		
		requirement def FlowCapacityRequirement {
			doc /*
			 * The pump shall deliver minimum flow rate of 50 liters per minute
			 * at maximum discharge head of 4 meters.
			 */
			
			subject pump : BilgePump;
			
			require constraint {
				pump.ratedFlowRate.magnitude >= 50.0 &
				pump.maxHead.magnitude >= 4.0
			}
		}
		
		requirement def AutomationRequirement {
			doc /*
			 * The system shall automatically activate when water level reaches
			 * high water mark and deactivate when level drops to low water mark.
			 */
			
			subject floatSwitch : FloatSwitch;
			subject pump : BilgePump;
		}
		
		requirement def ReliabilityRequirement {
			doc /*
			 * The pump shall operate continuously for minimum 4 hours
			 * without failure under normal operating conditions.
			 */
			
			subject pump : BilgePump;
		}
		
		requirement def SafetyRequirement {
			doc /*
			 * The system shall include fault detection and automatic shutdown
			 * to prevent damage from dry running or overpressure conditions.
			 */
			
			subject pump : BilgePump;
			
			require constraint {
				pump.controlPort.faultStatus == true implies 
				pump.controlPort.pumpStatus == false
			}
		}
	}
	
	package Usages {
		private import Components::*;
		private import Requirements::*;
		private import ValueTypes::*;
		
		part marineBilgeSystem : BilgePumpingSubsystem;
		
		satisfy pumpingReq : BilgePumpingRequirement by marineBilgeSystem {
			subject :>> subsystem = marineBilgeSystem;
		}
		
		action operateBilgeSystem {
			first start;
			then merge monitorLoop;
			
			action monitorLoop {
				out currentLevel : Length;
			}
			
			then decide;
				if monitorLoop.currentLevel.magnitude >= 0.8
					then activatePump;
				if monitorLoop.currentLevel.magnitude < 0.8
					then monitorLoop;
			
			action activatePump;
			
			then pumpWater;
			
			action pumpWater : Components::PumpFluid {
				in :>> fluidIn : Items::BilgeWater;
				out :>> fluidOut : Items::BilgeWater;
				in :>> flowRate.magnitude = 60.0;
				in :>> pressureRise = 39.24;
			}
			
			then checkLevel;
			
			action checkLevel {
				out levelLow : Boolean;
			}
			
			then decide;
				if checkLevel.levelLow == true then deactivatePump;
				if checkLevel.levelLow == false then pumpWater;
			
			action deactivatePump;
			
			then monitorLoop;
		}
	}
}
