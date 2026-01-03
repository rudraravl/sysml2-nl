package 'Follower Plate Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	package Domain {
		item def Fluid {
			attribute viscosity : Real;
			attribute density : Real;
			attribute temperature : Real;
		}
		
		attribute def PressureUnit;
		attribute def VolumeUnit;
		attribute def FlowRateUnit;
		attribute def ForceUnit;
		attribute def VelocityUnit;
		attribute def LengthUnit;
		
		value def PressureValue {
			attribute magnitude : Real;
			attribute unit : PressureUnit;
		}
		
		value def VolumeValue {
			attribute magnitude : Real;
			attribute unit : VolumeUnit;
		}
		
		value def FlowRateValue {
			attribute magnitude : Real;
			attribute unit : FlowRateUnit;
		}
		
		value def ForceValue {
			attribute magnitude : Real;
			attribute unit : ForceUnit;
		}
		
		value def VelocityValue {
			attribute magnitude : Real;
			attribute unit : VelocityUnit;
		}
		
		value def LengthValue {
			attribute magnitude : Real;
			attribute unit : LengthUnit;
		}
	}
	
	package Definitions {
		public import Domain::*;
		
		port def FluidPort {
			out item fluid : Fluid;
			attribute pressure : PressureValue;
			attribute flowRate : FlowRateValue;
		}
		
		port def ControlPort {
			in attribute commandedVelocity : VelocityValue;
			out attribute actualPosition : LengthValue;
			out attribute status : String;
		}
		
		port def PowerPort {
			in attribute voltage : Real;
			in attribute current : Real;
		}
		
		part def FollowerPlate {
			attribute diameter : LengthValue;
			attribute thickness : LengthValue;
			attribute position : LengthValue;
			attribute maxTravel : LengthValue;
			
			part seal {
				attribute material : String;
				attribute compressionRatio : Real;
			}
		}
		
		part def PumpCylinder {
			attribute innerDiameter : LengthValue;
			attribute length : LengthValue;
			attribute currentVolume : VolumeValue;
			attribute maxVolume : VolumeValue;
		}
		
		part def CheckValve {
			attribute crackingPressure : PressureValue;
			attribute maxFlowRate : FlowRateValue;
			attribute isOpen : Boolean;
		}
		
		part def LinearActuator {
			port powerIn : ~PowerPort;
			port controlIn : ~ControlPort;
			attribute maxForce : ForceValue;
			attribute maxVelocity : VelocityValue;
			attribute currentVelocity : VelocityValue;
		}
		
		message IntakeCompleteEvent;
		message DischargeCompleteEvent;
		message StartCommand;
		message PrimingCompleteEvent;
		message StopCommand;
		message FaultDetected;
		
		part def FollowerPlatePump {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			port controlPort : ControlPort;
			port powerPort : PowerPort;
			
			part cylinder : PumpCylinder {
				attribute :>> innerDiameter = cylinderDiameter;
				attribute cylinderDiameter : LengthValue {
					attribute :>> magnitude = 150.0;
				}
				attribute :>> length = cylinderLength;
				attribute cylinderLength : LengthValue {
					attribute :>> magnitude = 300.0;
				}
				attribute :>> maxVolume = maxVol;
				attribute maxVol : VolumeValue {
					attribute :>> magnitude = 5.3;
				}
			}
			
			part followerPlate : FollowerPlate {
				attribute :>> diameter = plateDiameter;
				attribute plateDiameter : LengthValue {
					attribute :>> magnitude = 149.5;
				}
				attribute :>> thickness = plateThickness;
				attribute plateThickness : LengthValue {
					attribute :>> magnitude = 12.0;
				}
				attribute :>> maxTravel = maxTravelDist;
				attribute maxTravelDist : LengthValue {
					attribute :>> magnitude = 300.0;
				}
				
				part :>> seal {
					attribute :>> material = "PTFE";
					attribute :>> compressionRatio = 0.2;
				}
			}
			
			part inletValve : CheckValve {
				attribute :>> crackingPressure = inletCrack;
				attribute inletCrack : PressureValue {
					attribute :>> magnitude = 0.3;
				}
				attribute :>> maxFlowRate = inletMaxFlow;
				attribute inletMaxFlow : FlowRateValue {
					attribute :>> magnitude = 120.0;
				}
			}
			
			part outletValve : CheckValve {
				attribute :>> crackingPressure = outletCrack;
				attribute outletCrack : PressureValue {
					attribute :>> magnitude = 0.5;
				}
				attribute :>> maxFlowRate = outletMaxFlow;
				attribute outletMaxFlow : FlowRateValue {
					attribute :>> magnitude = 120.0;
				}
			}
			
			part actuator : LinearActuator {
				attribute :>> maxForce = actMaxForce;
				attribute actMaxForce : ForceValue {
					attribute :>> magnitude = 8000.0;
				}
				attribute :>> maxVelocity = actMaxVel;
				attribute actMaxVel : VelocityValue {
					attribute :>> magnitude = 0.6;
				}
			}
			
			connect actuator.powerIn to powerPort;
			connect actuator.controlIn to controlPort;
			
			perform action pumpOperation : PumpFluid {
				in attribute :>> inletPressure = fluidInPort.pressure;
				in attribute :>> commandedVelocity = controlPort.commandedVelocity;
				out attribute :>> outletPressure = fluidOutPort.pressure;
				out attribute :>> volumeDisplaced = cylinder.currentVolume;
			}
			
			exhibit state pumpStateMachine : PumpOperationStates;
		}
		
		part def FluidReservoir {
			port fluidOutPort : FluidPort;
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			item storedFluid : Fluid {
				attribute :>> viscosity = 85.0;
				attribute :>> density = 920.0;
				attribute :>> temperature = 25.0;
			}
		}
		
		part def DischargeManifold {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			attribute manifoldPressure : PressureValue;
		}
		
		part def PressureSensor {
			port sensingPort : ~FluidPort;
			out attribute pressureReading : PressureValue;
		}
		
		part def FlowSensor {
			port sensingPort : ~FluidPort;
			out attribute flowReading : FlowRateValue;
		}
		
		part def PumpController {
			port controlOut : ~ControlPort;
			in attribute targetFlowRate : FlowRateValue;
			in attribute measuredPressure : PressureValue;
			in attribute measuredFlow : FlowRateValue;
			out attribute commandVelocity : VelocityValue;
		}
		
		action def PumpFluid {
			in attribute inletPressure : PressureValue;
			in attribute commandedVelocity : VelocityValue;
			out attribute outletPressure : PressureValue;
			out attribute volumeDisplaced : VolumeValue;
			
			action intakeStroke {
				in attribute plateVelocity : VelocityValue;
				out attribute fluidDrawn : VolumeValue;
			}
			
			action dischargeStroke {
				in attribute plateVelocity : VelocityValue;
				in attribute cylinderVolume : VolumeValue;
				out attribute fluidExpelled : VolumeValue;
			}
		}
		
		state def PumpOperationStates {
			entry; then idle;
			
			state idle {
				entry action idleEntry;
			}
			
			state priming {
				entry action primingEntry;
			}
			
			state pumping {
				entry; then intake;
				
				state intake {
					entry action intakeEntry;
				}
				
				state discharge {
					entry action dischargeEntry;
				}
				
				transition intakeToDischarge
					first intake
					accept IntakeCompleteEvent
					then discharge;
				
				transition dischargeToIntake
					first discharge
					accept DischargeCompleteEvent
					then intake;
			}
			
			state fault {
				entry action faultEntry;
			}
			
			transition idleToPriming
				first idle
				accept StartCommand
				then priming;
			
			transition primingToPumping
				first priming
				accept PrimingCompleteEvent
				then pumping;
			
			transition pumpingToIdle
				first pumping
				accept StopCommand
				then idle;
			
			transition anyToFault
				first idle
				accept FaultDetected
				then fault;
		}
		
		requirement def PumpPerformanceRequirement {
			subject pump : FollowerPlatePump;
			
			require constraint flowRateConstraint {
				pump.fluidOutPort.flowRate.magnitude >= 20.0 and
				pump.fluidOutPort.flowRate.magnitude <= 100.0
			}
			
			require constraint pressureConstraint {
				pump.fluidOutPort.pressure.magnitude >= 2.0 and
				pump.fluidOutPort.pressure.magnitude <= 40.0
			}
		}
		
		requirement def ReliabilityRequirement {
			subject pump : FollowerPlatePump;
			
			require constraint positionConstraint {
				pump.followerPlate.position.magnitude >= 0.0 and
				pump.followerPlate.position.magnitude <= pump.followerPlate.maxTravel.magnitude
			}
		}
		
		requirement def FluidCompatibilityRequirement {
			subject pump : FollowerPlatePump;
			
			require constraint viscosityConstraint {
				pump.fluidInPort.fluid.viscosity >= 10.0 and
				pump.fluidInPort.fluid.viscosity <= 500.0
			}
			
			require constraint temperatureConstraint {
				pump.fluidInPort.fluid.temperature >= -10.0 and
				pump.fluidInPort.fluid.temperature <= 80.0
			}
		}
	}
	
	package Usages {
		public import Definitions::*;
		
		part pumpingSubsystem {
			part reservoir : FluidReservoir {
				attribute :>> capacity = reservoirCapacity;
				attribute reservoirCapacity : VolumeValue {
					attribute :>> magnitude = 200.0;
				}
				attribute :>> currentLevel = reservoirLevel;
				attribute reservoirLevel : VolumeValue {
					attribute :>> magnitude = 180.0;
				}
			}
			
			part followerPlatePump : FollowerPlatePump;
			
			part dischargeManifold : DischargeManifold {
				attribute :>> manifoldPressure = manifoldPress;
				attribute manifoldPress : PressureValue {
					attribute :>> magnitude = 0.0;
				}
			}
			
			part pressureSensor : PressureSensor {
				attribute :>> pressureReading = pressReading;
				attribute pressReading : PressureValue {
					attribute :>> magnitude = 0.0;
				}
			}
			
			part flowSensor : FlowSensor {
				attribute :>> flowReading = flowRead;
				attribute flowRead : FlowRateValue {
					attribute :>> magnitude = 0.0;
				}
			}
			
			part controller : PumpController {
				attribute :>> targetFlowRate = targetFlow;
				attribute targetFlow : FlowRateValue {
					attribute :>> magnitude = 60.0;
				}
				attribute :>> measuredPressure = pressureSensor.pressureReading;
				attribute :>> measuredFlow = flowSensor.flowReading;
				attribute :>> commandVelocity = cmdVel;
				attribute cmdVel : VelocityValue {
					attribute :>> magnitude = 0.3;
				}
			}
			
			flow of hydraulicFluid : Fluid
				from reservoir.fluidOutPort.fluid
				to followerPlatePump.fluidInPort.fluid;
			
			flow of hydraulicFluid : Fluid
				from followerPlatePump.fluidOutPort.fluid
				to dischargeManifold.fluidInPort.fluid;
			
			connect pressureSensor.sensingPort to dischargeManifold.fluidOutPort;
			connect flowSensor.sensingPort to dischargeManifold.fluidOutPort;
			connect controller.controlOut to followerPlatePump.controlPort;
			
			requirement pumpPerformanceReq : PumpPerformanceRequirement {
				subject pump = followerPlatePump;
			}
			
			requirement pumpReliabilityReq : ReliabilityRequirement {
				subject pump = followerPlatePump;
			}
			
			requirement pumpFluidCompatReq : FluidCompatibilityRequirement {
				subject pump = followerPlatePump;
			}
		}
	}
}
