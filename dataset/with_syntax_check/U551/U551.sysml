package 'Reciprocating Pump Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		attribute def Pressure :> Real;
		attribute def FlowRate :> Real;
		attribute def Frequency :> Real;
		attribute def StrokeLength :> LengthValue;
		attribute def PistonDiameter :> LengthValue;
		attribute def Angle :> Real;
		
		item def Fluid {
			attribute density : Real;
			attribute viscosity : Real;
			attribute temperature : TemperatureValue;
			attribute volume : VolumeValue;
		}
		
		port def FluidPort {
			attribute pressure : Pressure;
			attribute flowRate : FlowRate;
			out item fluidOut : Fluid;
			in item fluidIn : Fluid;
		}
		
		part def Piston {
			attribute diameter : PistonDiameter;
			attribute position : LengthValue;
			attribute velocity : Real;
			attribute acceleration : Real;
		}
		
		part def Cylinder {
			attribute bore : PistonDiameter;
			attribute strokeLength : StrokeLength;
			attribute currentVolume : VolumeValue;
			port inletPort : FluidPort;
			port outletPort : FluidPort;
		}
		
		part def CheckValve {
			attribute isOpen : Boolean;
			attribute crackingPressure : Pressure;
			port inPort : FluidPort;
			port outPort : FluidPort;
		}
		
		part def Crankshaft {
			attribute rotationSpeed : Frequency;
			attribute crankRadius : LengthValue;
			attribute angle : Angle;
			attribute torque : Real;
		}
		
		part def ConnectingRod {
			attribute length : LengthValue;
			attribute compressionLoad : Real;
		}
		
		part def ReciprocatingPump {
			port suctionPort : FluidPort;
			port dischargePort : FluidPort;
			
			attribute operatingFrequency : Frequency;
			attribute maxPressure : Pressure;
			attribute nominalFlowRate : FlowRate;
			attribute efficiency : Real;
			attribute displacement : VolumeValue;
			
			part crankshaft : Crankshaft;
			part connectingRod : ConnectingRod;
			part piston : Piston;
			part cylinder : Cylinder;
			part inletValve : CheckValve;
			part outletValve : CheckValve;
			
			bind suctionPort.fluidIn = inletValve.inPort.fluidIn;
			bind inletValve.outPort.fluidOut = cylinder.inletPort.fluidIn;
			bind cylinder.outletPort.fluidOut = outletValve.inPort.fluidIn;
			bind outletValve.outPort.fluidOut = dischargePort.fluidOut;
		}
		
		part def SupplyTank {
			port outletPort : FluidPort;
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			item storedFluid : Fluid;
		}
		
		part def ReceivingTank {
			port inletPort : FluidPort;
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			item receivedFluid : Fluid;
		}
		
		part def PressureGauge {
			attribute measuredPressure : Pressure;
		}
		
		part def FlowMeter {
			attribute measuredFlowRate : FlowRate;
		}
		
		action def SuctionStroke {
			in pistonPosition : LengthValue;
			in pistonVelocity : Real;
			in cylinderVolume : VolumeValue;
			out inletValveOpen : Boolean;
			out outletValveOpen : Boolean;
			out fluidDrawn : Fluid;
			out volumeChange : VolumeValue;
		}
		
		action def DischargeStroke {
			in pistonPosition : LengthValue;
			in pistonVelocity : Real;
			in cylinderVolume : VolumeValue;
			in fluidInCylinder : Fluid;
			out inletValveOpen : Boolean;
			out outletValveOpen : Boolean;
			out fluidDischarged : Fluid;
			out volumeChange : VolumeValue;
		}
		
		action def RotateCrank {
			in rotationSpeed : Frequency;
			in currentAngle : Angle;
			in crankRadius : LengthValue;
			in rodLength : LengthValue;
			out newAngle : Angle;
			out pistonPosition : LengthValue;
			out pistonVelocity : Real;
		}
		
		action def PumpCycle {
			in operatingSpeed : Frequency;
			in suctionFluid : Fluid;
			out dischargedFluid : Fluid;
			
			first start;
			then merge continueOperation;
			
			then action rotateCrank : RotateCrank {
				in rotationSpeed = operatingSpeed;
			}
			
			then decide;
				if rotateCrank.pistonVelocity < 0.0 then suctionPhase;
				if rotateCrank.pistonVelocity >= 0.0 then dischargePhase;
			
			action suctionPhase : SuctionStroke {
				in pistonPosition = rotateCrank.pistonPosition;
				in pistonVelocity = rotateCrank.pistonVelocity;
				out fluidDrawn = suctionFluid;
			}
			then continueOperation;
			
			action dischargePhase : DischargeStroke {
				in pistonPosition = rotateCrank.pistonPosition;
				in pistonVelocity = rotateCrank.pistonVelocity;
				out fluidDischarged = dischargedFluid;
			}
			then continueOperation;
		}
		
		signal def StartCommand;
		signal def StopCommand;
		
		state def PumpOperationStates {
			in operatingFrequency : Frequency;
			in crankshaft : Crankshaft;
			in inletValve : CheckValve;
			in outletValve : CheckValve;
			in piston : Piston;
			
			entry; then idle;
			
			state idle {
				entry assign crankshaft.rotationSpeed := 0.0;
			}
			
			transition idle_to_starting
				first idle
				accept StartCommand
				then starting;
			
			state starting {
				entry assign crankshaft.rotationSpeed := operatingFrequency;
			}
			
			transition starting_to_running
				first starting
				if crankshaft.rotationSpeed >= operatingFrequency
				then running;
			
			state running {
				state suctionActive {
					entry assign inletValve.isOpen := true;
					entry assign outletValve.isOpen := false;
				}
				
				state dischargeActive {
					entry assign inletValve.isOpen := false;
					entry assign outletValve.isOpen := true;
				}
				
				transition suction_to_discharge
					first suctionActive
					if piston.velocity >= 0.0
					then dischargeActive;
				
				transition discharge_to_suction
					first dischargeActive
					if piston.velocity < 0.0
					then suctionActive;
			}
			
			transition running_to_stopping
				first running
				accept StopCommand
				then stopping;
			
			state stopping {
				entry assign crankshaft.rotationSpeed := 0.0;
			}
			
			transition stopping_to_idle
				first stopping
				if crankshaft.rotationSpeed <= 0.0
				then idle;
		}
		
		requirement def MinimumFlowRateRequirement {
			subject pump : ReciprocatingPump;
			attribute requiredFlowRate : FlowRate;
			
			require constraint {
				pump.nominalFlowRate >= requiredFlowRate
			}
		}
		
		requirement def MaximumPressureRequirement {
			subject pump : ReciprocatingPump;
			attribute maxAllowablePressure : Pressure;
			
			require constraint {
				pump.maxPressure <= maxAllowablePressure
			}
		}
		
		requirement def MinimumEfficiencyRequirement {
			subject pump : ReciprocatingPump;
			attribute requiredEfficiency : Real;
			
			require constraint {
				pump.efficiency >= requiredEfficiency
			}
		}
		
		requirement def FluidCompatibilityRequirement {
			subject fluid : Fluid;
			
			require constraint viscosityRange {
				fluid.viscosity >= 0.5 and fluid.viscosity <= 150.0
			}
			
			require constraint temperatureRange {
				fluid.temperature >= 263.15[K] and fluid.temperature <= 393.15[K]
			}
		}
	}
	
	package Usages {
		import Definitions::*;
		
		part reciprocatingPumpAssembly : ReciprocatingPump {
			attribute :>> operatingFrequency = 60.0;
			attribute :>> maxPressure = 150.0;
			attribute :>> nominalFlowRate = 20.0;
			attribute :>> efficiency = 0.85;
			attribute :>> displacement = 0.5[L];
			
			part :>> crankshaft {
				attribute :>> rotationSpeed = 60.0;
				attribute :>> crankRadius = 0.05[m];
				attribute :>> angle = 0.0;
				attribute :>> torque = 50.0;
			}
			
			part :>> connectingRod {
				attribute :>> length = 0.15[m];
				attribute :>> compressionLoad = 0.0;
			}
			
			part :>> piston {
				attribute :>> diameter = 0.08[m];
				attribute :>> position = 0.0[m];
				attribute :>> velocity = 0.0;
				attribute :>> acceleration = 0.0;
			}
			
			part :>> cylinder {
				attribute :>> bore = 0.08[m];
				attribute :>> strokeLength = 0.10[m];
				attribute :>> currentVolume = 0.0[L];
			}
			
			part :>> inletValve {
				attribute :>> isOpen = false;
				attribute :>> crackingPressure = 0.5;
			}
			
			part :>> outletValve {
				attribute :>> isOpen = false;
				attribute :>> crackingPressure = 1.0;
			}
			
			perform action pumpingOperation : PumpCycle {
				in operatingSpeed = operatingFrequency;
				in suctionFluid = suctionPort.fluidIn;
				out dischargedFluid = dischargePort.fluidOut;
			}
			
			exhibit state operationControl : PumpOperationStates {
				in operatingFrequency = reciprocatingPumpAssembly.operatingFrequency;
				in crankshaft = reciprocatingPumpAssembly.crankshaft;
				in inletValve = reciprocatingPumpAssembly.inletValve;
				in outletValve = reciprocatingPumpAssembly.outletValve;
				in piston = reciprocatingPumpAssembly.piston;
			}
		}
		
		part pumpingSubsystem {
			part supplyTank : SupplyTank {
				attribute :>> capacity = 2000.0[L];
				attribute :>> currentLevel = 1500.0[L];
				
				item :>> storedFluid : Fluid {
					attribute :>> density = 1000.0;
					attribute :>> viscosity = 1.0;
					attribute :>> temperature = 293.15[K];
					attribute :>> volume = 1500.0[L];
				}
			}
			
			part pump : ReciprocatingPump :> reciprocatingPumpAssembly;
			
			part receivingTank : ReceivingTank {
				attribute :>> capacity = 2000.0[L];
				attribute :>> currentLevel = 0.0[L];
			}
			
			part suctionPressureGauge : PressureGauge {
				attribute :>> measuredPressure = 0.0;
			}
			
			part dischargePressureGauge : PressureGauge {
				attribute :>> measuredPressure = 0.0;
			}
			
			part dischargeFlowMeter : FlowMeter {
				attribute :>> measuredFlowRate = 0.0;
			}
			
			flow of transferFluid : Fluid
				from supplyTank.outletPort.fluidOut
				to pump.suctionPort.fluidIn;
			
			flow of pumpedFluid : Fluid
				from pump.dischargePort.fluidOut
				to receivingTank.inletPort.fluidIn;
			
			bind suctionPressureGauge.measuredPressure = pump.suctionPort.pressure;
			bind dischargePressureGauge.measuredPressure = pump.dischargePort.pressure;
			bind dischargeFlowMeter.measuredFlowRate = pump.dischargePort.flowRate;
		}
		
		requirement minFlowRate : MinimumFlowRateRequirement {
			subject pump = pumpingSubsystem.pump;
			attribute :>> requiredFlowRate = 15.0;
		}
		
		requirement maxPressure : MaximumPressureRequirement {
			subject pump = pumpingSubsystem.pump;
			attribute :>> maxAllowablePressure = 200.0;
		}
		
		requirement minEfficiency : MinimumEfficiencyRequirement {
			subject pump = pumpingSubsystem.pump;
			attribute :>> requiredEfficiency = 0.75;
		}
		
		requirement fluidCompatibility : FluidCompatibilityRequirement {
			subject fluid = pumpingSubsystem.supplyTank.storedFluid;
		}
		
		assert constraint massConservation {
			pumpingSubsystem.supplyTank.currentLevel + 
			pumpingSubsystem.receivingTank.currentLevel <= 
			pumpingSubsystem.supplyTank.capacity
		}
		
		assert constraint pressureSafety {
			pumpingSubsystem.dischargePressureGauge.measuredPressure <= 
			pumpingSubsystem.pump.maxPressure
		}
	}
}
