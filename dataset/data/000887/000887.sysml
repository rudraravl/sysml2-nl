package 'Hand Pump Subsystem' {
	private import ScalarValues::*;
	
	package Definitions {
		
		attribute def PressureValue :> Real;
		attribute def VolumeValue :> Real;
		attribute def FlowRateValue :> Real;
		attribute def LengthValue :> Real;
		attribute def ForceValue :> Real;
		
		enum def PumpStrokePhase {
			enum upstroke;
			enum downstroke;
			enum idle;
		}
		
		enum def ValveState {
			enum open;
			enum closed;
		}
		
		item def Fluid {
			attribute density : Real;
			attribute viscosity : Real;
			attribute volume : VolumeValue;
		}
		
		port def FluidInletPort {
			attribute pressure : PressureValue;
			in item fluidIn : Fluid;
		}
		
		port def FluidOutletPort {
			attribute pressure : PressureValue;
			out item fluidOut : Fluid;
		}
		
		part def CheckValve {
			attribute crackingPressure : PressureValue;
			attribute currentState : ValveState;
			port inletPort : FluidInletPort;
			port outletPort : FluidOutletPort;
			
			perform action valveControl : ValveControlAction;
		}
		
		action def ValveControlAction {
			in inletPressure : PressureValue;
			in outletPressure : PressureValue;
			in crackingPressure : PressureValue;
			out valveState : ValveState;
			
			first start;
			then decide;
				if inletPressure > outletPressure + crackingPressure then openValve;
				if inletPressure <= outletPressure then closeValve;
			action openValve {
				assign valveState = ValveState::open;
			}
			then done;
			action closeValve {
				assign valveState = ValveState::closed;
			}
			then done;
		}
		
		part def PumpCylinder {
			attribute cylinderDiameter : LengthValue;
			attribute strokeLength : LengthValue;
			attribute currentPosition : LengthValue;
			attribute cylinderVolume : VolumeValue;
			
			port fluidPort : FluidInletPort;
		}
		
		part def PistonAssembly {
			attribute pistonDiameter : LengthValue;
			attribute position : LengthValue;
			attribute velocity : Real;
			attribute currentPhase : PumpStrokePhase;
			
			perform action pistonControl : PistonControlAction;
		}
		
		action def PistonControlAction {
			in command : PumpStrokePhase;
			out velocity : Real;
			out phase : PumpStrokePhase;
			
			first start;
			then decide;
				if command == PumpStrokePhase::upstroke then moveUp;
				if command == PumpStrokePhase::downstroke then moveDown;
				if command == PumpStrokePhase::idle then stopMotion;
			action moveUp {
				assign velocity = 1.0;
				assign phase = PumpStrokePhase::upstroke;
			}
			then done;
			action moveDown {
				assign velocity = -1.0;
				assign phase = PumpStrokePhase::downstroke;
			}
			then done;
			action stopMotion {
				assign velocity = 0.0;
				assign phase = PumpStrokePhase::idle;
			}
			then done;
		}
		
		part def HandleAssembly {
			attribute handleLength : LengthValue;
			attribute handleAngle : Real;
			attribute maxAngle : Real;
			attribute minAngle : Real;
			attribute appliedForce : ForceValue;
		}
		
		part def FluidReservoir {
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			port outletPort : FluidOutletPort;
			
			item storedFluid : Fluid {
				attribute :>> volume = currentLevel;
			}
		}
		
		part def DischargeManifold {
			attribute outputPressure : PressureValue;
			port inletPort : FluidInletPort;
			port dischargePort : FluidOutletPort;
		}
		
		part def HandPump {
			port supplyPort : FluidInletPort;
			port deliveryPort : FluidOutletPort;
			
			part handle : HandleAssembly {
				attribute :>> handleLength = 0.3;
				attribute :>> maxAngle = 90.0;
				attribute :>> minAngle = 0.0;
			}
			
			part piston : PistonAssembly {
				attribute :>> pistonDiameter = 0.05;
			}
			
			part cylinder : PumpCylinder {
				attribute :>> cylinderDiameter = 0.05;
				attribute :>> strokeLength = 0.15;
			}
			
			part inletValve : CheckValve {
				attribute :>> crackingPressure = 5.0;
			}
			
			part outletValve : CheckValve {
				attribute :>> crackingPressure = 10.0;
			}
			
			binding piston.pistonDiameter = cylinder.cylinderDiameter;
			binding piston.position = cylinder.currentPosition;
			
			connect supplyPort to inletValve.inletPort;
			connect inletValve.outletPort to cylinder.fluidPort;
			connect cylinder.fluidPort to outletValve.inletPort;
			connect outletValve.outletPort to deliveryPort;
			
			perform action pumpOperation : PumpingOperation;
		}
		
		action def PumpingOperation {
			in attribute strokePhase : PumpStrokePhase;
			out attribute volumeDisplaced : VolumeValue;
			
			first start;
			then merge cycleStart;
			
			then action upstroke : UpstrokeAction {
				in attribute :>> strokePhase;
				out attribute :>> volumeDisplaced;
			}
			
			then action downstroke : DownstrokeAction {
				in attribute :>> strokePhase;
				out attribute :>> volumeDisplaced;
			}
			
			then decide;
				if continueOperation then cycleStart;
				if stopOperation then complete;
				
			action complete : CompleteOperation;
			then done;
		}
		
		action def UpstrokeAction {
			in attribute strokePhase : PumpStrokePhase;
			out attribute volumeDisplaced : VolumeValue;
			
			action openInletValve;
			then action drawFluid;
			then action closeInletValve;
		}
		
		action def DownstrokeAction {
			in attribute strokePhase : PumpStrokePhase;
			out attribute volumeDisplaced : VolumeValue;
			
			action openOutletValve;
			then action dischargeFluid;
			then action closeOutletValve;
		}
		
		action def CompleteOperation;
		
		requirement def PumpPerformanceRequirement {
			doc /* The hand pump shall deliver minimum flow rate and pressure under specified conditions. */
			
			subject pump : HandPump;
			
			require constraint {
				pump.deliveryPort.pressure >= 100.0
			}
			
			require constraint {
				pump.cylinder.strokeLength >= 0.1
			}
		}
		
		requirement def ValveOperationRequirement {
			doc /* Check valves shall prevent backflow and open at specified cracking pressure. */
			
			subject valve : CheckValve;
			
			require constraint {
				valve.crackingPressure > 0.0 and valve.crackingPressure < 50.0
			}
		}
		
		requirement def ManualOperationRequirement {
			doc /* The pumping subsystem shall be operable manually without external power. */
			
			subject pump : HandPump;
			
			require constraint {
				pump.handle.appliedForce < 200.0
			}
		}
	}
	
	package Usages {
		
		part handPumpingSystem {
			
			part sourceReservoir : Definitions::FluidReservoir {
				attribute :>> capacity = 100.0;
				attribute :>> currentLevel = 75.0;
			}
			
			part mainPump : Definitions::HandPump;
			
			part outputManifold : Definitions::DischargeManifold {
				attribute :>> outputPressure = 150.0;
			}
			
			item workingFluid : Definitions::Fluid {
				attribute :>> density = 1000.0;
				attribute :>> viscosity = 0.001;
			}
			
			flow of workingFluid : Definitions::Fluid
				from sourceReservoir.outletPort.fluidOut
				to mainPump.supplyPort.fluidIn;
			
			flow of workingFluid : Definitions::Fluid
				from mainPump.deliveryPort.fluidOut
				to outputManifold.inletPort.fluidIn;
			
			requirement pumpPerf : Definitions::PumpPerformanceRequirement {
				subject pump = mainPump;
			}
			
			requirement inletValveReq : Definitions::ValveOperationRequirement {
				subject valve = mainPump.inletValve;
			}
			
			requirement outletValveReq : Definitions::ValveOperationRequirement {
				subject valve = mainPump.outletValve;
			}
			
			requirement manualOpReq : Definitions::ManualOperationRequirement {
				subject pump = mainPump;
			}
		}
	}
}
