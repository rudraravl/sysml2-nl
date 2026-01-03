package 'Mud Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Units {
		attribute def PressureUnit;
		attribute def FlowRateUnit;
		attribute def ViscosityUnit;
		attribute def DensityUnit;
		attribute def PowerUnit;
		attribute def SpeedUnit;
	}
	
	package Definitions {
		public import 'Mud Pumping Subsystem'::Units::*;
		
		item def Mud {
			attribute density : Real;
			attribute viscosity : Real;
			attribute solidContent : Real;
			attribute volume : Real;
		}
		
		attribute def PressureValue :> Real;
		attribute def FlowRateValue :> Real;
		attribute def PowerValue :> Real;
		attribute def SpeedValue :> Real;
		attribute def LengthValue :> Real;
		
		port def MudPort {
			out item mudOut : Mud;
			attribute pressure : PressureValue;
			attribute flowRate : FlowRateValue;
		}
		
		port def PowerInputPort {
			in attribute powerIn : PowerValue;
		}
		
		part def MudPit {
			port mudOutlet : MudPort;
			attribute capacity : Real;
			attribute currentLevel : Real;
			item storedMud : Mud {
				attribute :>> volume;
			}
		}
		
		part def SuctionLine {
			port inlet : ~MudPort;
			port outlet : MudPort;
			attribute length : LengthValue;
			attribute diameter : LengthValue;
			attribute pressureDrop : PressureValue;
		}
		
		part def MudPump {
			port suctionPort : ~MudPort;
			port dischargePort : MudPort;
			port powerInput : PowerInputPort;
			
			attribute ratedPressure : PressureValue;
			attribute ratedFlowRate : FlowRateValue;
			attribute efficiency : Real;
			attribute numberOfPistons : Integer;
			attribute strokeLength : LengthValue;
			attribute pistonDiameter : LengthValue;
			attribute operatingSpeed : SpeedValue;
			attribute dischargePressure : PressureValue;
			attribute maxNormalPressure : PressureValue;
			
			part pistonAssembly[numberOfPistons] : PistonAssembly;
			part crankshaft : Crankshaft {
				attribute rotationalSpeed : SpeedValue;
			}
			part fluidEnd : FluidEnd {
				port suctionConnection : ~MudPort;
				port dischargeConnection : MudPort;
			}
			part powerEnd : PowerEnd {
				port driveInput : PowerInputPort;
			}
			
			bind suctionPort = fluidEnd.suctionConnection;
			bind dischargePort = fluidEnd.dischargeConnection;
			bind powerInput = powerEnd.driveInput;
			
			perform action pumpOperation : PumpMud {
				in mudIn = suctionPort.mudOut;
				in power = powerInput.powerIn;
				out mudOut = dischargePort.mudOut;
				out dischargePressure = dischargePort.pressure;
				out dischargeFlow = dischargePort.flowRate;
			}
			
			exhibit state pumpStateMachine : PumpOperationStates;
		}
		
		part def PistonAssembly {
			part piston : Piston {
				attribute diameter : LengthValue;
			}
			part connectingRod : ConnectingRod {
				attribute length : LengthValue;
			}
			part liner : Liner {
				attribute innerDiameter : LengthValue;
			}
			part suctionValve : Valve {
				attribute isOpen : Boolean;
			}
			part dischargeValve : Valve {
				attribute isOpen : Boolean;
			}
			attribute strokePosition : LengthValue;
		}
		
		part def Piston;
		part def ConnectingRod;
		part def Liner;
		part def Valve;
		part def Crankshaft;
		part def FluidEnd;
		part def PowerEnd;
		
		part def DischargeLine {
			port inlet : ~MudPort;
			port outlet : MudPort;
			attribute length : LengthValue;
			attribute diameter : LengthValue;
			attribute maxPressure : PressureValue;
		}
		
		part def Wellbore {
			port mudInlet : ~MudPort;
			attribute depth : LengthValue;
			attribute bottomholePressure : PressureValue;
		}
		
		part def PrimeDriver {
			port powerOutput : ~PowerInputPort;
			attribute ratedPower : PowerValue;
			attribute currentSpeed : SpeedValue;
			attribute fuelConsumption : Real;
		}
		
		action def PumpMud {
			in mudIn : Mud;
			in power : PowerValue;
			out mudOut : Mud;
			out dischargePressure : PressureValue;
			out dischargeFlow : FlowRateValue;
			
			first start;
			then action intake : IntakeMud {
				in fluidIn = mudIn;
				out fluidDrawn : Mud;
			}
			then action pressurize : PressurizeMud {
				in fluidIn = intake.fluidDrawn;
				in appliedPower = power;
				out pressurizedFluid : Mud;
				out pressure : PressureValue;
			}
			then action discharge : DischargeMud {
				in fluidIn = pressurize.pressurizedFluid;
				in pressure = pressurize.pressure;
				out fluidOut : Mud;
				out outPressure : PressureValue;
				out outFlow : FlowRateValue;
			}
			then done;
		}
		
		action def IntakeMud {
			in fluidIn : Mud;
			out fluidDrawn : Mud;
		}
		
		action def PressurizeMud {
			in fluidIn : Mud;
			in appliedPower : PowerValue;
			out pressurizedFluid : Mud;
			out pressure : PressureValue;
		}
		
		action def DischargeMud {
			in fluidIn : Mud;
			in pressure : PressureValue;
			out fluidOut : Mud;
			out outPressure : PressureValue;
			out outFlow : FlowRateValue;
		}
		
		action def MonitorPumpPerformance {
			in currentPressure : PressureValue;
			in currentFlow : FlowRateValue;
			in targetPressure : PressureValue;
			in targetFlow : FlowRateValue;
			out status : String;
		}
		
		action def AdjustPumpSpeed {
			in currentSpeed : SpeedValue;
			in targetFlow : FlowRateValue;
			out newSpeed : SpeedValue;
		}
		
		signal StartCommand;
		signal StopCommand;
		signal EmergencyStop;
		signal Reset;
		
		state def PumpOperationStates {
			in attribute pumpSpeed : SpeedValue;
			in attribute currentDischargePressure : PressureValue;
			in attribute normalPressureLimit : PressureValue;
			
			entry; then idle;
			
			state idle;
			
			transition idle_to_starting
				first idle
				accept StartCommand
				then starting;
			
			state starting;
			
			transition starting_to_running
				first starting
				if pumpSpeed > 0.0
				then running;
			
			state running {
				state normalOperation;
				state highPressureOperation;
				
				transition normal_to_high
					first normalOperation
					if currentDischargePressure > normalPressureLimit
					then highPressureOperation;
				
				transition high_to_normal
					first highPressureOperation
					if currentDischargePressure <= normalPressureLimit
					then normalOperation;
			}
			
			transition running_to_stopping
				first running
				accept StopCommand
				then stopping;
			
			state stopping;
			
			transition stopping_to_idle
				first stopping
				if pumpSpeed == 0.0
				then idle;
			
			state emergency;
			
			transition any_to_emergency
				first running
				accept EmergencyStop
				then emergency;
			
			transition emergency_to_idle
				first emergency
				accept Reset
				then idle;
		}
		
		requirement def PumpPerformanceRequirement {
			subject pump : MudPump;
			
			require constraint {
				pump.dischargePort.pressure >= pump.ratedPressure
			}
			
			require constraint {
				pump.dischargePort.flowRate >= pump.ratedFlowRate
			}
			
			require constraint {
				pump.efficiency >= 0.85
			}
		}
		
		requirement def SystemOperationalRequirement {
			subject system : MudPumpingSystem;
			
			doc /* The mud pumping system shall maintain continuous operation */
			
			require constraint {
				system.mudPump.operatingSpeed > 0.0
			}
		}
		
		requirement def FluidPropertyRequirement {
			subject mud : Mud;
			
			require constraint {
				mud.density >= 800.0 and mud.density <= 2400.0
			}
			
			require constraint {
				mud.viscosity >= 10.0 and mud.viscosity <= 100.0
			}
		}
		
		part def MudPumpingSystem {
			part mudPit : MudPit;
			part suctionLine : SuctionLine;
			part mudPump : MudPump;
			part primeDriver : PrimeDriver;
			part dischargeLine : DischargeLine;
			part wellbore : Wellbore;
		}
	}
	
	package Usages {
		public import 'Mud Pumping Subsystem'::Definitions::*;
		
		part mudPumpingSystem : MudPumpingSystem {
			part :>> mudPit {
				attribute :>> capacity = 60.0;
				attribute :>> currentLevel = 50.0;
				item :>> storedMud {
					attribute :>> volume = 50.0;
					attribute :>> density = 1200.0;
					attribute :>> viscosity = 35.0;
					attribute :>> solidContent = 0.06;
				}
			}
			
			flow of mud : Mud
				from mudPit.mudOutlet.mudOut to suctionLine.inlet.mudOut;
			
			part :>> suctionLine {
				attribute :>> length = 15.0;
				attribute :>> diameter = 0.15;
				attribute :>> pressureDrop = 50000.0;
			}
			
			flow of mud : Mud
				from suctionLine.outlet.mudOut to mudPump.suctionPort.mudOut;
			
			part :>> mudPump {
				attribute :>> ratedPressure = 35000000.0;
				attribute :>> ratedFlowRate = 0.03;
				attribute :>> efficiency = 0.90;
				attribute :>> numberOfPistons = 3;
				attribute :>> strokeLength = 0.305;
				attribute :>> pistonDiameter = 0.152;
				attribute :>> operatingSpeed = 120.0;
				attribute :>> dischargePressure = 35000000.0;
				attribute :>> maxNormalPressure = 36000000.0;
			}
			
			part :>> primeDriver {
				attribute :>> ratedPower = 1500000.0;
				attribute :>> currentSpeed = 1800.0;
				attribute :>> fuelConsumption = 45.0;
			}
			
			bind primeDriver.powerOutput.powerIn = mudPump.powerInput.powerIn;
			
			flow of mud : Mud
				from mudPump.dischargePort.mudOut to dischargeLine.inlet.mudOut;
			
			part :>> dischargeLine {
				attribute :>> length = 3000.0;
				attribute :>> diameter = 0.127;
				attribute :>> maxPressure = 40000000.0;
			}
			
			flow of mud : Mud
				from dischargeLine.outlet.mudOut to wellbore.mudInlet.mudOut;
			
			part :>> wellbore {
				attribute :>> depth = 3000.0;
				attribute :>> bottomholePressure = 30000000.0;
			}
			
			perform action controlLoop {
				first start;
				then merge continueMonitoring;
				
				then action monitor : MonitorPumpPerformance {
					in currentPressure = mudPump.dischargePort.pressure;
					in currentFlow = mudPump.dischargePort.flowRate;
					in targetPressure = mudPump.ratedPressure;
					in targetFlow = mudPump.ratedFlowRate;
					out status;
				}
				
				then decide;
					if monitor.status == "adjust" then adjust;
					if monitor.status == "normal" then continueMonitoring;
				
				action adjust : AdjustPumpSpeed {
					in currentSpeed = mudPump.operatingSpeed;
					in targetFlow = mudPump.ratedFlowRate;
					out newSpeed;
				}
				
				then continueMonitoring;
			}
			
			satisfy requirement pumpPerformanceReq : PumpPerformanceRequirement {
				subject pump = mudPump;
			}
			
			satisfy requirement systemOperationalReq : SystemOperationalRequirement {
				subject system = mudPumpingSystem;
			}
			
			satisfy requirement fluidPropertyReq : FluidPropertyRequirement {
				subject mud = mudPit.storedMud;
			}
		}
	}
}
