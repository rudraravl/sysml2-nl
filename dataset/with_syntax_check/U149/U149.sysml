package AspiratorSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PressureValue :> ISQ::PressureValue;
	attribute def VolumetricFlowRateValue :> ISQ::VolumetricFlowRateValue;
	attribute def VolumeValue :> ISQ::VolumeValue;
	attribute def LengthValue :> ISQ::LengthValue;
	
	item def Fluid {
		attribute volume : VolumeValue;
		attribute pressure : PressureValue;
		attribute flowRate : VolumetricFlowRateValue;
	}
	
	port def FluidPort {
		attribute pressure : PressureValue;
		attribute flowRate : VolumetricFlowRateValue;
	}
	
	port def ControlPort {
		attribute commandSignal : Real;
		attribute feedbackSignal : Real;
	}
	
	attribute def StartCommand;
	attribute def StopCommand;
	attribute def EmergencyStop;
	
	part def VenturiTube {
		port motiveInlet : FluidPort;
		port suctionInlet : FluidPort;
		port mixedOutlet : FluidPort;
		
		attribute throatDiameter : LengthValue;
		attribute convergenceAngle : Real;
		
		action def GenerateVacuum {
			in motivePressure : PressureValue;
			in motiveFlow : VolumetricFlowRateValue;
			out suctionPressure : PressureValue;
			out suctionFlow : VolumetricFlowRateValue;
			out mixedFlow : VolumetricFlowRateValue;
		}
	}
	
	part def MotiveFluidSource {
		port outlet : FluidPort;
		
		attribute sourcePressure : PressureValue;
		attribute maxFlowCapacity : VolumetricFlowRateValue;
		
		action def SupplyMotiveFluid {
			in demandFlow : VolumetricFlowRateValue;
			out suppliedPressure : PressureValue;
			out suppliedFlow : VolumetricFlowRateValue;
		}
	}
	
	part def SuctionChamber {
		port inlet : FluidPort;
		port outlet : FluidPort;
		
		attribute chamberVolume : VolumeValue;
		attribute currentPressure : PressureValue;
		attribute accumulatedVolume : VolumeValue;
		
		action def AccumulateFluid {
			in inletPressure : PressureValue;
			in inletFlow : VolumetricFlowRateValue;
			out chamberPressure : PressureValue;
			out totalVolume : VolumeValue;
		}
	}
	
	part def DischargeChamber {
		port inlet : FluidPort;
		port outlet : FluidPort;
		
		attribute dischargePressure : PressureValue;
		
		action def DischargeFluid {
			in inletFlow : VolumetricFlowRateValue;
			in inletPressure : PressureValue;
			out outletPressure : PressureValue;
		}
	}
	
	part def FlowRegulationValve {
		port fluidInlet : FluidPort;
		port fluidOutlet : FluidPort;
		port controlInput : ControlPort;
		
		attribute valvePosition : Real;
		attribute flowCoefficient : Real;
		
		action def RegulateFlow {
			in controlSignal : Real;
			in inletPressure : PressureValue;
			out outletFlow : VolumetricFlowRateValue;
			out actualPosition : Real;
		}
	}
	
	part def VacuumSensor {
		port sensingPort : FluidPort;
		port outputPort : ControlPort;
		
		attribute measuredPressure : PressureValue;
		attribute calibrationOffset : Real;
		
		action def MeasureVacuum {
			in sensedPressure : PressureValue;
			out pressureSignal : Real;
		}
	}
	
	part def AspiratorController {
		port sensorInput : ControlPort;
		port valveOutput : ControlPort;
		
		attribute targetVacuum : PressureValue;
		attribute currentVacuum : PressureValue;
		attribute controlGain : Real;
		
		action def ControlVacuumLevel {
			in sensorFeedback : Real;
			in setpoint : PressureValue;
			out valveCommand : Real;
			
			action computeError {
				in measured : Real;
				in target : PressureValue;
				out errorValue : Real;
			}
			
			then action calculateCommand {
				in error : Real;
				in gain : Real;
				out command : Real;
			}
			
			then action outputCommand {
				in command : Real;
				out signal : Real;
			}
		}
	}
	
	part def Aspirator {
		doc /* An aspirator is a device that uses the Venturi effect to create vacuum 
		       by accelerating a motive fluid through a constricted passage, thereby 
		       drawing in and entraining fluid from a suction source. */
		
		port motiveFluidInput : FluidPort;
		port suctionInput : FluidPort;
		port dischargeOutput : FluidPort;
		port systemControl : ControlPort;
		
		part motiveSource : MotiveFluidSource;
		part regulationValve : FlowRegulationValve;
		part venturiTube : VenturiTube;
		part suctionChamber : SuctionChamber;
		part dischargeChamber : DischargeChamber;
		part vacuumSensor : VacuumSensor;
		part controller : AspiratorController;
		
		connection motiveSupply connect motiveSource.outlet to regulationValve.fluidInlet;
		connection regulatedMotive connect regulationValve.fluidOutlet to venturiTube.motiveInlet;
		connection suctionPath connect suctionChamber.outlet to venturiTube.suctionInlet;
		connection dischargePath connect venturiTube.mixedOutlet to dischargeChamber.inlet;
		connection externalSuction connect suctionInput to suctionChamber.inlet;
		connection externalDischarge connect dischargeChamber.outlet to dischargeOutput;
		connection sensing connect vacuumSensor.sensingPort to suctionChamber.outlet;
		connection feedback connect vacuumSensor.outputPort to controller.sensorInput;
		connection control connect controller.valveOutput to regulationValve.controlInput;
		
		state machine OperationalStates {
			state Idle;
			state Startup;
			state Operating;
			state Shutdown;
			state Emergency;
			
			transition idleToStartup
				first Idle
				accept startCmd : StartCommand
				then Startup;
			
			transition startupToOperating
				first Startup
				then Operating;
			
			transition operatingToShutdown
				first Operating
				accept stopCmd : StopCommand
				then Shutdown;
			
			transition shutdownToIdle
				first Shutdown
				then Idle;
			
			transition anyToEmergency
				accept emergencyCmd : EmergencyStop
				then Emergency;
			
			transition emergencyToIdle
				first Emergency
				accept startCmd : StartCommand
				then Idle;
		}
		
		perform action aspirateFluid {
			in targetVacuumLevel : PressureValue;
			out achievedVacuum : PressureValue;
			out totalSuctionFlow : VolumetricFlowRateValue;
			
			first start;
			
			then merge controlLoop;
			
			then action operationCycle {
				action supplyMotive : motiveSource.SupplyMotiveFluid {
					in demandFlow;
					out suppliedPressure;
					out suppliedFlow;
				}
				
				flow supplyMotive.suppliedPressure to regulateMotiveFlow.inletPressure;
				
				action regulateMotiveFlow : regulationValve.RegulateFlow {
					in controlSignal;
					in inletPressure;
					out outletFlow;
					out actualPosition;
				}
				
				flow regulateMotiveFlow.outletFlow to generateVacuum.motiveFlow;
				
				action generateVacuum : venturiTube.GenerateVacuum {
					in motivePressure;
					in motiveFlow;
					out suctionPressure;
					out suctionFlow;
					out mixedFlow;
				}
				
				flow generateVacuum.suctionPressure to accumulateFluid.inletPressure;
				flow generateVacuum.suctionFlow to accumulateFluid.inletFlow;
				
				action accumulateFluid : suctionChamber.AccumulateFluid {
					in inletPressure;
					in inletFlow;
					out chamberPressure;
					out totalVolume;
				}
				
				flow accumulateFluid.chamberPressure to measureVacuum.sensedPressure;
				
				action measureVacuum : vacuumSensor.MeasureVacuum {
					in sensedPressure;
					out pressureSignal;
				}
				
				flow measureVacuum.pressureSignal to controlVacuum.sensorFeedback;
				
				action controlVacuum : controller.ControlVacuumLevel {
					in sensorFeedback;
					in setpoint = targetVacuumLevel;
					out valveCommand;
				}
				
				flow controlVacuum.valveCommand to regulateMotiveFlow.controlSignal;
				
				action dischargeFluid : dischargeChamber.DischargeFluid {
					in inletFlow = generateVacuum.mixedFlow;
					in inletPressure;
					out outletPressure;
				}
			}
			
			then decide;
				if operationCycle.measureVacuum.pressureSignal > 0.1 then controlLoop;
				if operationCycle.measureVacuum.pressureSignal <= 0.1 then stabilize;
			
			action stabilize {
				assign achievedVacuum := operationCycle.accumulateFluid.chamberPressure;
				assign totalSuctionFlow := operationCycle.generateVacuum.suctionFlow;
			}
			
			then done;
		}
	}
	
	part aspiratorSystem : Aspirator {
		attribute :>> motiveSource.sourcePressure = 500000.0[SI::Pa];
		attribute :>> motiveSource.maxFlowCapacity = 0.1[SI::m3_per_s];
		attribute :>> suctionChamber.chamberVolume = 0.005[SI::m3];
		attribute :>> venturiTube.throatDiameter = 0.01[SI::m];
		attribute :>> controller.controlGain = 0.8;
		
		perform action systemOperation references aspirateFluid {
			in targetVacuumLevel = 80000.0[SI::Pa];
			out achievedVacuum;
			out totalSuctionFlow;
		}
	}
	
	requirement def VacuumGenerationRequirement {
		doc /* The aspirator shall generate and maintain a stable vacuum level 
		       by utilizing the Venturi effect to entrain fluid from the suction source. */
		
		subject aspirator : Aspirator;
	}
	
	requirement def FlowEntrainmentRequirement {
		doc /* The aspirator shall entrain fluid from the suction source at a rate 
		       sufficient to maintain the desired vacuum level. */
		
		subject aspirator : Aspirator;
		
		attribute minimumSuctionFlow : VolumetricFlowRateValue;
	}
	
	requirement def MotiveFluidEfficiencyRequirement {
		doc /* The aspirator shall minimize motive fluid consumption while 
		       maintaining required vacuum performance. */
		
		subject aspirator : Aspirator;
		
		attribute maximumMotiveFlow : VolumetricFlowRateValue;
	}
	
	requirement def ControlStabilityRequirement {
		doc /* The aspirator control system shall maintain stable vacuum regulation 
		       without excessive oscillation. */
		
		subject aspirator : Aspirator;
	}
	
	requirement systemRequirements {
		doc /* The aspirator system shall generate vacuum through Venturi effect, 
		       entrain fluid efficiently, and maintain stable control. */
		
		require vacuumGeneration : VacuumGenerationRequirement {
			subject aspirator = aspiratorSystem;
		}
		
		require flowEntrainment : FlowEntrainmentRequirement {
			subject aspirator = aspiratorSystem;
			attribute :>> minimumSuctionFlow = 0.02[SI::m3_per_s];
		}
		
		require motiveEfficiency : MotiveFluidEfficiencyRequirement {
			subject aspirator = aspiratorSystem;
			attribute :>> maximumMotiveFlow = 0.08[SI::m3_per_s];
		}
		
		require controlStability : ControlStabilityRequirement {
			subject aspirator = aspiratorSystem;
		}
	}
}
