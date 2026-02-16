package BushPumpingSubsystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		item def Fluid {
			attribute density : Real;
			attribute viscosity : Real;
			attribute volume : Real;
		}
		
		attribute def VolumeValue :> Real;
		attribute def VolumeFlowRateValue :> Real;
		attribute def PressureValue :> Real;
		attribute def LengthValue :> Real;
		attribute def ForceValue :> Real;
		
		enum def PumpOperationState {
			enum idle;
			enum upstroke;
			enum downstroke;
			enum priming;
		}
		
		port def FluidInletPort {
			in item fluidIn : Fluid;
			attribute inletPressure : PressureValue;
		}
		
		port def FluidOutletPort {
			out item fluidOut : Fluid;
			attribute outletPressure : PressureValue;
		}
		
		part def WaterSource {
			attribute depth : LengthValue;
			attribute staticWaterLevel : LengthValue;
			port sourcePort : FluidOutletPort;
		}
		
		part def RisingPipe {
			attribute pipeLength : LengthValue;
			attribute pipeDiameter : LengthValue;
			port inletPort : FluidInletPort;
			port outletPort : FluidOutletPort;
		}
		
		part def PumpCylinder {
			attribute cylinderDiameter : LengthValue;
			attribute cylinderLength : LengthValue;
			port inletPort : FluidInletPort;
			port outletPort : FluidOutletPort;
			
			part piston {
				attribute pistonDiameter : LengthValue;
				attribute strokeLength : LengthValue;
				attribute currentPosition : LengthValue;
			}
		}
		
		part def FootValve {
			attribute isOpen : Boolean;
			attribute crackingPressure : PressureValue;
			port upstreamPort : FluidInletPort;
			port downstreamPort : FluidOutletPort;
		}
		
		part def PistonValve {
			attribute isOpen : Boolean;
			attribute crackingPressure : PressureValue;
			port upstreamPort : FluidInletPort;
			port downstreamPort : FluidOutletPort;
		}
		
		part def PumpRod {
			attribute rodLength : LengthValue;
			attribute rodDiameter : LengthValue;
			attribute appliedForce : ForceValue;
		}
		
		part def PumpHandle {
			attribute handleLength : LengthValue;
			attribute mechanicalAdvantage : Real;
			attribute userForce : ForceValue;
		}
		
		part def DischargeSpout {
			port inletPort : FluidInletPort;
			port outletPort : FluidOutletPort;
		}
		
		part def CollectionTank {
			attribute tankCapacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			port inletPort : FluidInletPort;
		}
		
		part def BushPump {
			attribute operatingDepth : LengthValue;
			attribute nominalFlowRate : VolumeFlowRateValue;
			attribute currentState : PumpOperationState;
			
			port fluidInlet : FluidInletPort;
			port fluidOutlet : FluidOutletPort;
			
			part handle : PumpHandle {
				attribute :>> handleLength = 0.5;
				attribute :>> mechanicalAdvantage = 3.5;
			}
			
			part rod : PumpRod {
				attribute :>> rodLength = 25.0;
				attribute :>> rodDiameter = 0.02;
			}
			
			part cylinder : PumpCylinder {
				attribute :>> cylinderDiameter = 0.063;
				attribute :>> cylinderLength = 0.4;
				
				part :>> piston {
					attribute :>> pistonDiameter = 0.062;
					attribute :>> strokeLength = 0.12;
					attribute :>> currentPosition = 0.0;
				}
			}
			
			part footValve : FootValve {
				attribute :>> isOpen = false;
				attribute :>> crackingPressure = 500.0;
			}
			
			part pistonValve : PistonValve {
				attribute :>> isOpen = false;
				attribute :>> crackingPressure = 300.0;
			}
			
			part risingPipe : RisingPipe {
				attribute :>> pipeLength = 25.0;
				attribute :>> pipeDiameter = 0.05;
			}
			
			part spout : DischargeSpout;
			
			bind fluidInlet = footValve.upstreamPort;
			bind fluidOutlet = spout.outletPort;
			
			flow from footValve.downstreamPort.fluidOut to cylinder.inletPort.fluidIn;
			flow from cylinder.outletPort.fluidOut to pistonValve.upstreamPort.fluidIn;
			flow from pistonValve.downstreamPort.fluidOut to risingPipe.inletPort.fluidIn;
			flow from risingPipe.outletPort.fluidOut to spout.inletPort.fluidIn;
		}
		
		action def PrimePumpAction {
			in waterLevel : LengthValue;
			out primed : Boolean;
		}
		
		action def UpstrokeAction {
			in pistonPos : LengthValue;
			out newPistonPos : LengthValue;
			out footValveState : Boolean;
			out pistonValveState : Boolean;
		}
		
		action def DownstrokeAction {
			in pistonPos : LengthValue;
			out newPistonPos : LengthValue;
			out footValveState : Boolean;
			out pistonValveState : Boolean;
		}
		
		action def PumpFluid {
			in targetVolume : VolumeValue;
			out deliveredVolume : VolumeValue;
			
			first start;
			then merge continuePumping;
			
			then action checkPrime : PrimePumpAction {
				in waterLevel;
				out primed;
			}
			
			then decide;
				if checkPrime.primed then pumpingCycle;
				if !checkPrime.primed then continuePumping;
			
			action pumpingCycle {
				first start;
				
				then action upstroke : UpstrokeAction {
					in pistonPos;
					out newPistonPos;
					out footValveState;
					out pistonValveState;
				}
				
				then action downstroke : DownstrokeAction {
					in pistonPos = upstroke.newPistonPos;
					out newPistonPos;
					out footValveState;
					out pistonValveState;
				}
				
				then done;
			}
			
			then decide;
				if deliveredVolume < targetVolume then continuePumping;
				if deliveredVolume >= targetVolume then finish;
			
			action finish;
			then done;
		}
		
		requirement def DepthRequirement {
			doc /* The Bush pump shall operate at depths up to 40 meters. */
			
			subject pump : BushPump;
			
			require constraint {
				pump.operatingDepth <= 40.0
			}
		}
		
		requirement def FlowRateRequirement {
			doc /* The Bush pump shall deliver a minimum flow rate of 12 liters per minute. */
			
			subject pump : BushPump;
			
			require constraint {
				pump.nominalFlowRate >= 12.0
			}
		}
		
		requirement def ValveInterlockRequirement {
			doc /* The foot valve and piston valve shall not be open simultaneously. */
			
			subject pump : BushPump;
			
			require constraint {
				!(pump.footValve.isOpen && pump.pistonValve.isOpen)
			}
		}
	}
	
	package Usages {
		part pumpingSystem {
			part source : WaterSource {
				attribute :>> depth = 30.0;
				attribute :>> staticWaterLevel = 25.0;
			}
			
			part bushPump : BushPump {
				attribute :>> operatingDepth = 25.0;
				attribute :>> nominalFlowRate = 15.0;
				attribute :>> currentState = PumpOperationState::idle;
				
				perform action pumpOperation : PumpFluid {
					in targetVolume = 150.0;
				}
			}
			
			part collectionTank : CollectionTank {
				attribute :>> tankCapacity = 400.0;
				attribute :>> currentLevel = 0.0;
			}
			
			flow of fluid : Fluid
				from source.sourcePort.fluidOut
				to bushPump.fluidInlet.fluidIn;
			
			flow of fluid : Fluid
				from bushPump.fluidOutlet.fluidOut
				to collectionTank.inletPort.fluidIn;
			
			satisfy depthReq : DepthRequirement by bushPump;
			satisfy flowReq : FlowRateRequirement by bushPump;
			satisfy valveReq : ValveInterlockRequirement by bushPump;
		}
	}
}
