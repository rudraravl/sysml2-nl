package AptarGroupDispensingSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ViscosityValue :> ISQ::DynamicViscosityValue;
	attribute def PressureValue :> ISQ::PressureValue;
	attribute def VolumeFlowRateValue :> ISQ::VolumeFlowRateValue;
	attribute def ForceValue :> ISQ::ForceValue;
	attribute def TorqueValue :> ISQ::TorqueValue;
	attribute def AngleValue :> ISQ::PlaneAngleValue;
	
	item def Product {
		attribute viscosity : ViscosityValue;
		attribute volume : VolumeValue;
		attribute temperature : ThermodynamicTemperatureValue;
	}
	
	item def DispensingDose {
		attribute doseVolume : VolumeValue;
		attribute product : Product;
	}
	
	port def ProductInputPort {
		in item productIn : Product;
	}
	
	port def ProductOutputPort {
		out item productOut : Product;
	}
	
	port def ActuationPort {
		in attribute actuationForce : ForceValue;
		out attribute actuationResponse : Boolean;
	}
	
	port def PressureMonitorPort {
		out attribute measuredPressure : PressureValue;
	}
	
	part def ProductReservoir {
		doc /* Container that stores the product to be dispensed. */
		
		port productOutput : ProductOutputPort;
		
		attribute totalCapacity : VolumeValue;
		attribute currentLevel : VolumeValue;
		attribute minimumLevel : VolumeValue;
		
		state def ReservoirState {
			entry; then checkLevel;
			
			state checkLevel;
			transition toFull
				first checkLevel
				accept when currentLevel >= totalCapacity * 0.9
				then full;
			transition toNormal
				first checkLevel
				accept when currentLevel >= minimumLevel and currentLevel < totalCapacity * 0.9
				then normal;
			transition toLow
				first checkLevel
				accept when currentLevel < minimumLevel
				then low;
			
			state full {
				doc /* Reservoir is at or near capacity. */
			}
			
			state normal {
				doc /* Reservoir has adequate product level. */
			}
			
			state low {
				doc /* Reservoir level is below minimum threshold. */
			}
		}
	}
	
	part def PumpAssembly {
		doc /* Mechanical pump that draws product from reservoir and pressurizes it for dispensing. */
		
		port actuationInput : ActuationPort;
		port productIntake : ProductInputPort;
		port productDischarge : ProductOutputPort;
		port pressureMonitor : PressureMonitorPort;
		
		attribute chamberVolume : VolumeValue;
		attribute maxPressure : PressureValue;
		attribute currentPressure : PressureValue;
		attribute strokeCount : Integer;
		
		perform action executePumpCycle {
			first start;
			then merge continuePumping;
			then intakePhase;
			then compressionPhase;
			then dischargePhase;
			then decide;
				if strokeCount < requiredStrokes then continuePumping;
				if strokeCount >= requiredStrokes then done;
			
			action intakePhase {
				doc /* Draw product into pump chamber. */
				in force : ForceValue = actuationInput::actuationForce;
				out productDrawn : Product;
			}
			
			action compressionPhase {
				doc /* Pressurize product in chamber. */
				in productToCompress : Product = intakePhase.productDrawn;
				out pressurizedProduct : Product;
				out pressure : PressureValue;
			}
			
			action dischargePhase {
				doc /* Expel pressurized product from chamber. */
				in productToDispense : Product = compressionPhase.pressurizedProduct;
				out dispensedProduct : Product;
			}
		}
	}
	
	part def ValveSystem {
		doc /* Controls product flow and prevents backflow. */
		
		port productInput : ProductInputPort;
		port productOutput : ProductOutputPort;
		
		attribute openingPressureThreshold : PressureValue;
		attribute closingPressureThreshold : PressureValue;
		attribute leakageRate : VolumeFlowRateValue;
		
		state def ValveOperationState {
			entry; then sealed;
			
			state sealed {
				doc /* Valve is closed, no product flow. */
			}
			transition sealedToOpening
				first sealed
				accept at openingPressureThreshold
				then opening;
			
			state opening {
				doc /* Valve is transitioning to open position. */
			}
			transition openingToFullyOpen
				first opening
				then fullyOpen;
			
			state fullyOpen {
				doc /* Valve is fully open, product flows freely. */
			}
			transition fullyOpenToClosing
				first fullyOpen
				accept at closingPressureThreshold
				then closing;
			
			state closing {
				doc /* Valve is transitioning to closed position. */
			}
			transition closingToSealed
				first closing
				then sealed;
		}
	}
	
	part def ActuatorMechanism {
		doc /* User-activated mechanism that drives the pump. */
		
		port userInterface : ActuationPort;
		port pumpDrive : ActuationPort;
		
		attribute actuationAngle : AngleValue;
		attribute requiredTorque : TorqueValue;
		attribute maxTorque : TorqueValue;
		
		perform action translateUserInput {
			in userForce : ForceValue = userInterface::actuationForce;
			out pumpForce : ForceValue;
			out response : Boolean;
		}
	}
	
	part def NozzleAssembly {
		doc /* Atomizes and directs product into desired spray pattern. */
		
		port productInput : ProductInputPort;
		
		attribute orificeSize : LengthValue;
		attribute sprayAngle : AngleValue;
		attribute dropletSize : LengthValue;
		attribute flowRate : VolumeFlowRateValue;
		
		perform action atomizeProduct {
			in productToAtomize : Product;
			out sprayedDose : DispensingDose;
		}
		
		state def NozzleState {
			entry; then idle;
			
			state idle {
				doc /* No product flow through nozzle. */
			}
			transition idleToSpraying
				first idle
				accept when flowRate > 0.0
				then spraying;
			
			state spraying {
				doc /* Product is being atomized and dispensed. */
			}
			transition sprayingToIdle
				first spraying
				accept when flowRate <=
