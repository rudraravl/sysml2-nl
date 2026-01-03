package 'Diaphragm Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		item def Fluid {
			attribute density : Real;
			attribute viscosity : Real;
			attribute temperature : Real;
		}
		
		attribute def PressureValue :> Real;
		attribute def FlowRateValue :> Real;
		attribute def VolumeValue :> Real;
		attribute def FrequencyValue :> Real;
		attribute def LengthValue :> Real;
		attribute def ForceValue :> Real;
		
		port def FluidPort {
			attribute pressure : PressureValue;
			attribute flowRate : FlowRateValue;
			out item fluidOut : Fluid;
			in item fluidIn : Fluid;
		}
		
		action def OpenValve;
		action def CloseValve;
		action def RetractDiaphragm;
		action def AdvanceDiaphragm;
		action def DrawFluid {
			in inputFluid : Fluid;
			out outputFluid : Fluid;
		}
		action def ExpelFluid {
			in inputFluid : Fluid;
			out outputFluid : Fluid;
		}
		
		part def CheckValve {
			attribute crackingPressure : PressureValue;
			attribute maxFlowRate : FlowRateValue;
			attribute isOpen : Boolean;
			
			port inlet : ~FluidPort;
			port outlet : FluidPort;
			
			state valveStates {
				entry; then closed;
				
				state closed;
				transition closed_to_open
					first closed
					if inlet.pressure > outlet.pressure + crackingPressure
					then open;
				
				state open;
				transition open_to_closed
					first open
					if inlet.pressure <= outlet.pressure
					then closed;
			}
		}
		
		part def Diaphragm {
			attribute material : String;
			attribute thickness : LengthValue;
			attribute maxDeflection : LengthValue;
			attribute cycleLife : Integer;
			attribute currentDeflection : LengthValue;
		}
		
		part def PumpChamber {
			attribute chamberVolume : VolumeValue;
			attribute currentVolume : VolumeValue;
			item containedFluid : Fluid;
		}
		
		action def ActuationCycle {
			first start;
			then retract : RetractDiaphragm;
			then advance : AdvanceDiaphragm;
			then done;
		}
		
		part def PumpActuator {
			attribute actuationType : String;
			attribute strokeLength : LengthValue;
			attribute actuationForce : ForceValue;
			attribute cycleFrequency : FrequencyValue;
			
			perform action actuationCycle : ActuationCycle;
		}
		
		action def IntakeStroke {
			in fluid : Fluid;
			out chamberFluid : Fluid;
			
			first start;
			then action openInletValve : OpenValve;
			then action retractDiaphragm : RetractDiaphragm;
			then action drawFluid : DrawFluid {
				in inputFluid = fluid;
				out outputFluid = chamberFluid;
			}
			then action closeInletValve : CloseValve;
			then done;
		}
		
		action def DischargeStroke {
			in chamberFluid : Fluid;
			out fluid : Fluid;
			
			first start;
			then action openOutletValve : OpenValve;
			then action advanceDiaphragm : AdvanceDiaphragm;
			then action expelFluid : ExpelFluid {
				in inputFluid = chamberFluid;
				out outputFluid = fluid;
			}
			then action closeOutletValve : CloseValve;
			then done;
		}
		
		action def PumpingCycle {
			in inletFluid : Fluid;
			out outletFluid : Fluid;
			
			first start;
			then merge cycleStart;
			
			action intakeStroke : IntakeStroke {
				in fluid = inletFluid;
				out chamberFluid : Fluid;
			}
			
			then dischargeStroke : DischargeStroke {
				in chamberFluid = intakeStroke.chamberFluid;
				out fluid = outletFluid;
			}
			
			then cycleStart;
		}
		
		part def DiaphragmPump {
			attribute strokeVolume : VolumeValue;
			attribute maxPressure : PressureValue;
			attribute operatingFrequency : FrequencyValue;
			attribute efficiency : Real;
			
			port inletPort : ~FluidPort;
			port outletPort : FluidPort;
			
			part diaphragm : Diaphragm;
			part inletValve : CheckValve;
			part outletValve : CheckValve;
			part actuator : PumpActuator;
			part pumpChamber : PumpChamber;
			
			binding diaphragmToChamber bind diaphragm = pumpChamber;
			binding actuatorToDiaphragm bind actuator = diaphragm;
			
			perform action pumpingCycle : PumpingCycle;
			
			state pumpStates {
				entry; then idle;
				
				state idle;
				transition idle_to_running
					first idle
					then running;
				
				state running {
					entry; then intakePhase;
					
					state intakePhase;
					transition intake_to_discharge
						first intakePhase
						then dischargePhase;
					
					state dischargePhase;
					transition discharge_to_intake
						first dischargePhase
						then intakePhase;
				}
				
				transition running_to_idle
					first running
					then idle;
			}
		}
		
		part def FluidReservoir {
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			port outletPort : FluidPort;
			item storedFluid : Fluid;
		}
		
		part def ProcessEquipment {
			attribute requiredPressure : PressureValue;
			attribute requiredFlowRate : FlowRateValue;
			port inletPort : ~FluidPort;
		}
		
		part def PressureSensor {
			attribute measuredPressure : PressureValue;
			attribute accuracy : Real;
		}
		
		part def FlowSensor {
			attribute measuredFlowRate : FlowRateValue;
			attribute accuracy : Real;
		}
		
		requirement def PumpPerformanceRequirement {
			doc /* The pump shall deliver fluid at specified flow rate and pressure */
			
			subject pump : DiaphragmPump;
			
			require constraint flowRateRequirement {
				pump.outletPort.flowRate >= 10.0
			}
			
			require constraint pressureRequirement {
				pump.outletPort.pressure >= 5.0
			}
			
			require constraint efficiencyRequirement {
				pump.efficiency >= 0.75
			}
		}
		
		requirement def ValveReliabilityRequirement {
			doc /* Check valves shall operate reliably with proper cracking pressure */
			
			subject valve : CheckValve;
			
			require constraint crackingPressureRequirement {
				valve.crackingPressure <= 0.5
			}
		}
		
		requirement def DiaphragmLifeRequirement {
			doc /* Diaphragm shall withstand minimum number of cycles */
			
			subject diaphragm : Diaphragm;
			
			require constraint cycleLifeRequirement {
				diaphragm.cycleLife >= 1000000
			}
		}
	}
	
	package Usages {
		part pumpingSystem {
			part sourceReservoir : FluidReservoir {
				attribute :>> capacity = 100.0;
				attribute :>> currentLevel = 75.0;
			}
			
			flow of fluid : Fluid
				from sourceReservoir.outletPort.fluidOut
				to pump.inletPort.fluidIn;
			
			part pump : DiaphragmPump {
				attribute :>> strokeVolume = 0.5;
				attribute :>> maxPressure = 10.0;
				attribute :>> operatingFrequency = 60.0;
				attribute :>> efficiency = 0.80;
				
				part :>> diaphragm {
					attribute :>> material = "PTFE";
					attribute :>> thickness = 2.0;
					attribute :>> maxDeflection = 10.0;
					attribute :>> cycleLife = 2000000;
					attribute :>> currentDeflection = 0.0;
				}
				
				part :>> inletValve {
					attribute :>> crackingPressure = 0.2;
					attribute :>> maxFlowRate = 50.0;
					attribute :>> isOpen = false;
				}
				
				part :>> outletValve {
					attribute :>> crackingPressure = 0.3;
					attribute :>> maxFlowRate = 50.0;
					attribute :>> isOpen = false;
				}
				
				part :>> actuator {
					attribute :>> actuationType = "Pneumatic";
					attribute :>> strokeLength = 25.0;
					attribute :>> actuationForce = 500.0;
					attribute :>> cycleFrequency = 60.0;
				}
				
				part :>> pumpChamber {
					attribute :>> chamberVolume = 1.0;
					attribute :>> currentVolume = 0.5;
				}
				
				flow inletPort.fluidIn to inletValve.inlet.fluidIn;
				flow inletValve.outlet.fluidOut to pumpChamber.containedFluid;
				flow pumpChamber.containedFluid to outletValve.inlet.fluidIn;
				flow outletValve.outlet.fluidOut to outletPort.fluidOut;
				
				perform :>> pumpingCycle {
					in :>> inletFluid = inletPort.fluidIn;
					out :>> outletFluid = outletPort.fluidOut;
				}
			}
			
			flow of fluid : Fluid
				from pump.outletPort.fluidOut
				to processEquipment.inletPort.fluidIn;
			
			part processEquipment : ProcessEquipment {
				attribute :>> requiredPressure = 6.0;
				attribute :>> requiredFlowRate = 15.0;
			}
			
			part inletPressureSensor : PressureSensor {
				attribute :>> measuredPressure = 1.0;
				attribute :>> accuracy = 0.02;
			}
			
			part outletPressureSensor : PressureSensor {
				attribute :>> measuredPressure = 7.0;
				attribute :>> accuracy = 0.02;
			}
			
			part flowSensor : FlowSensor {
				attribute :>> measuredFlowRate = 18.0;
				attribute :>> accuracy = 0.05;
			}
			
			binding inletSensorBinding bind inletPressureSensor.measuredPressure = pump.inletPort.pressure;
			binding outletSensorBinding bind outletPressureSensor.measuredPressure = pump.outletPort.pressure;
			binding flowSensorBinding bind flowSensor.measuredFlowRate = pump.outletPort.flowRate;
		}
		
		requirement pumpPerformance : PumpPerformanceRequirement {
			subject pumpSubject = pumpingSystem.pump;
		}
		
		requirement valveReliability : ValveReliabilityRequirement {
			subject valveSubject = pumpingSystem.pump.inletValve;
		}
		
		requirement diaphragmLife : DiaphragmLifeRequirement {
			subject diaphragmSubject = pumpingSystem.pump.diaphragm;
		}
	}
}
