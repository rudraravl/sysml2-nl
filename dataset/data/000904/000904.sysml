package 'Injector System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def InjectionCommand {
		attribute pulseWidth : TimeValue;
		attribute timing : TimeValue;
	}
	
	attribute def SystemStatus {
		attribute isActive : Boolean;
		attribute cycleCount : Integer;
		attribute totalVolumeDelivered : VolumeValue;
	}
	
	value def FluidPressure :> PressureValue;
	value def FluidVolume :> VolumeValue;
	value def FluidFlowRate :> VolumeFlowRateValue;
	value def InjectionDuration :> TimeValue;
	
	item def Fluid {
		attribute density : MassDensityValue;
		attribute viscosity : DynamicViscosityValue;
		attribute temperature : TemperatureValue;
	}
	
	port def FluidPort {
		in item fluid : Fluid;
		attribute pressure : FluidPressure;
		attribute flowRate : FluidFlowRate;
	}
	
	port def ControlPort {
		in attribute command : InjectionCommand;
		out attribute status : SystemStatus;
	}
	
	part def FluidReservoir {
		attribute capacity : FluidVolume;
		attribute currentLevel : FluidVolume;
		attribute supplyPressure : FluidPressure;
		port fluidOut : FluidPort;
		
		action supplyFluid {
			in requestedFlow : FluidFlowRate;
			out deliveredFluid : Fluid;
			out outputPressure : FluidPressure;
		}
	}
	
	part def PressureRegulator {
		attribute targetPressure : FluidPressure;
		attribute regulationAccuracy : Real;
		port fluidIn : FluidPort;
		port fluidOut : FluidPort;
		
		action regulatePressure {
			in inputPressure : FluidPressure;
			in setpoint : FluidPressure;
			out outputPressure : FluidPressure;
		}
	}
	
	part def InjectorValve {
		attribute nominalFlowRate : FluidFlowRate;
		attribute responseTime : TimeValue;
		attribute orificeArea : AreaValue;
		port fluidIn : FluidPort;
		port fluidOut : FluidPort;
		port control : ControlPort;
		
		state valveStateMachine {
			entry; then idle;
			
			state idle {
				entry assign control.status.isActive := false;
			}
			
			state priming {
				entry assign control.status.isActive := false;
			}
			
			state injecting {
				entry assign control.status.isActive := true;
				entry assign control.status.cycleCount := control.status.cycleCount + 1;
			}
			
			state purging {
				entry assign control.status.isActive := false;
			}
			
			transition idleToPriming
				first idle
				accept cmd : InjectionCommand
				then priming;
			
			transition primingToInjecting
				first priming
				then injecting;
			
			transition injectingToPurging
				first injecting
				then purging;
			
			transition purgingToIdle
				first purging
				then idle;
		}
	}
	
	part def FlowMeter {
		attribute measurementAccuracy : Real;
		attribute calibrationFactor : Real;
		port fluidIn : FluidPort;
		
		action measureFlow {
			in actualFlow : FluidFlowRate;
			out measurement : FluidFlowRate;
		}
	}
	
	part def InjectionController {
		attribute injectionPulseWidth : InjectionDuration;
		attribute injectionFrequency : FrequencyValue;
		attribute targetVolume : FluidVolume;
		port controlOut : ControlPort;
		port feedbackIn : FluidPort;
		
		action calculateInjectionParameters {
			in targetVol : FluidVolume;
			in measuredFlow : FluidFlowRate;
			out pulseDuration : InjectionDuration;
			out timing : TimeValue;
		}
		
		action generateCommand {
			in duration : InjectionDuration;
			in timing : TimeValue;
			out cmd : InjectionCommand;
		}
	}
	
	part def DeliveryNozzle {
		attribute nozzleType : String;
		attribute sprayAngle : AngleValue;
		port fluidIn : FluidPort;
		
		action atomizeFluid {
			in incomingFluid : Fluid;
			in pressure : FluidPressure;
			out sprayPattern : Fluid;
		}
	}
	
	action def MeasureFluidFlow {
		in flowRate : FluidFlowRate;
		in calibration : Real;
		out measurement : FluidFlowRate;
	}
	
	action def ControlInjectionCycle {
		in targetVolume : FluidVolume;
		in currentFlowRate : FluidFlowRate;
		out injectionCommand : InjectionCommand;
	}
	
	action def RegulateSupplyPressure {
		in sourcePressure : FluidPressure;
		in targetPressure : FluidPressure;
		out regulatedPressure : FluidPressure;
	}
	
	action def ExecuteInjection {
		in command : InjectionCommand;
		in supplyPressure : FluidPressure;
		in fluid : Fluid;
		out deliveredVolume : FluidVolume;
		out actualFlowRate : FluidFlowRate;
	}
	
	action def AtomizeAndDeliver {
		in pressurizedFluid : Fluid;
		in pressure : FluidPressure;
		out deliveredSpray : Fluid;
	}
	
	part def InjectorSystem {
		attribute operatingPressure : FluidPressure;
		attribute targetInjectionVolume : FluidVolume;
		attribute operatingTemperature : TemperatureValue;
		
		part reservoir : FluidReservoir {
			attribute :>> capacity = 10.0;
			attribute :>> currentLevel = 8.5;
			attribute :>> supplyPressure = 400.0;
		}
		
		part regulator : PressureRegulator {
			attribute :>> targetPressure = operatingPressure;
			attribute :>> regulationAccuracy = 0.99;
		}
		
		part valve : InjectorValve {
			attribute :>> nominalFlowRate = 200.0;
			attribute :>> responseTime = 0.003;
		}
		
		part flowMeter : FlowMeter {
			attribute :>> measurementAccuracy = 0.98;
			attribute :>> calibrationFactor = 1.02;
		}
		
		part controller : InjectionController {
			attribute :>> targetVolume = targetInjectionVolume;
			attribute :>> injectionFrequency = 60.0;
		}
		
		part nozzle : DeliveryNozzle {
			attribute :>> nozzleType = "conical";
			attribute :>> sprayAngle = 45.0;
		}
		
		connect reservoir.fluidOut to regulator.fluidIn;
		connect regulator.fluidOut to valve.fluidIn;
		connect valve.fluidOut to flowMeter.fluidIn;
		connect flowMeter.fluidIn to nozzle.fluidIn;
		connect controller.controlOut to valve.control;
		
		perform action executeInjectionCycle {
			first start;
			then action regulatePressure : RegulateSupplyPressure {
				in sourcePressure = reservoir.supplyPressure;
				in targetPressure = operatingPressure;
				out regulatedPressure;
			}
			then action measureFlow : MeasureFluidFlow {
				in flowRate = valve.nominalFlowRate;
				in calibration = flowMeter.calibrationFactor;
				out measurement;
			}
			then action controlInjection : ControlInjectionCycle {
				in targetVolume = targetInjectionVolume;
				in currentFlowRate = measureFlow.measurement;
				out injectionCommand;
			}
			then action executeInject : ExecuteInjection {
				in command = controlInjection.injectionCommand;
				in supplyPressure = regulatePressure.regulatedPressure;
				in fluid;
				out deliveredVolume;
				out actualFlowRate;
			}
			then action atomize : AtomizeAndDeliver {
				in pressurizedFluid = executeInject.fluid;
				in pressure = regulatePressure.regulatedPressure;
				out deliveredSpray;
			}
			then done;
		}
	}
	
	requirement def InjectorPerformanceRequirement {
		doc /* The injector shall deliver precise fluid volumes with high repeatability and accuracy. */
		
		attribute requiredAccuracy : Real;
		attribute requiredResponseTime : TimeValue;
		attribute requiredFlowRate : FluidFlowRate;
	}
	
	requirement def InjectorReliabilityRequirement {
		doc /* The injector shall operate reliably over extended service life with minimal maintenance. */
		
		attribute minimumCycles : Integer;
		attribute maximumLeakage : FluidFlowRate;
		attribute serviceLife : TimeValue;
	}
	
	requirement def InjectorSafetyRequirement {
		doc /* The injector shall operate safely within specified pressure and temperature limits. */
		
		attribute maximumPressure : FluidPressure;
		attribute maximumTemperature : TemperatureValue;
	}
	
	requirement <'INJ-PERF-001'> injectorFlowAccuracy : InjectorPerformanceRequirement {
		doc /* The injector system shall maintain flow rate measurement accuracy within 2% of nominal value. */
		
		attribute :>> requiredAccuracy = 0.98;
		
		require constraint {
			injectorSystemInstance.flowMeter.measurementAccuracy >= requiredAccuracy
		}
	}
	
	requirement <'INJ-PERF-002'> injectorResponseTime : InjectorPerformanceRequirement {
		doc /* The injector valve shall open and close within 3 milliseconds of command receipt. */
		
		attribute :>> requiredResponseTime = 0.003;
		
		require constraint {
			injectorSystemInstance.valve.responseTime <= requiredResponseTime
		}
	}
	
	requirement <'INJ-REL-001'> injectorDurability : InjectorReliabilityRequirement {
		doc /* The injector shall complete at least 5 million injection cycles without failure. */
		
		attribute :>> minimumCycles = 5000000;
		attribute :>> maximumLeakage = 0.05;
		attribute :>> serviceLife = 10000.0;
	}
	
	requirement <'INJ-SAFE-001'> injectorPressureSafety : InjectorSafetyRequirement {
		doc /* The injector system shall operate safely at pressures up to 500 kPa and temperatures up to 120 degrees Celsius. */
		
		attribute :>> maximumPressure = 500.0;
		attribute :>> maximumTemperature = 120.0;
		
		require constraint {
			injectorSystemInstance.operatingPressure <= maximumPressure and
			injectorSystemInstance.operatingTemperature <= maximumTemperature
		}
	}
	
	requirement <'INJ-SYS-001'> injectorSystemMission {
		doc /* The injector system shall precisely meter, control, and deliver specified quantities of fluid on demand through atomization and spray delivery. */
		
		require injectorFlowAccuracy;
		require injectorResponseTime;
		require injectorDurability;
		require injectorPressureSafety;
	}
	
	part injectorSystemInstance : InjectorSystem {
		attribute :>> operatingPressure = 350.0;
		attribute :>> targetInjectionVolume = 5.0;
		attribute :>> operatingTemperature = 85.0;
		
		satisfy injectorSystemMission by injectorSystemInstance;
	}
}
