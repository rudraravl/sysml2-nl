package 'Static Pressure System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def StaticPressure :> ISQ::PressureValue;
	attribute def DynamicPressure :> ISQ::PressureValue;
	attribute def TotalPressure :> ISQ::PressureValue;
	attribute def FluidVelocity :> ISQ::SpeedValue;
	attribute def FluidDensity :> ISQ::DensityValue;
	attribute def FluidTemperature :> ISQ::TemperatureValue;
	attribute def VolumeFlowRate :> ISQ::VolumeFlowRateValue;
	
	item def Air {
		attribute density : FluidDensity;
		attribute temperature : FluidTemperature;
		attribute viscosity : Real;
	}
	
	port def StaticPressurePort {
		attribute staticPressure : StaticPressure;
		attribute temperature : FluidTemperature;
		in item airIn : Air;
		out item airOut : Air;
	}
	
	port def PressureDataPort {
		out attribute measuredStaticPressure : StaticPressure;
		out attribute measuredTotalPressure : TotalPressure;
		out attribute measuredTemperature : FluidTemperature;
	}
	
	port def ControlSignalPort {
		in attribute commandedPressure : StaticPressure;
		out attribute actualPressure : StaticPressure;
	}
	
	part def StaticPressureProbe {
		doc /* Senses ambient static air pressure without being affected by airflow velocity. */
		port probePort : StaticPressurePort;
		attribute probeAccuracy : Real;
		attribute responseTime : ISQ::TimeValue;
		
		perform action sensePressure {
			out staticPress : StaticPressure;
			out temp : FluidTemperature;
		}
	}
	
	part def PressureTransmitter {
		doc /* Converts physical pressure measurement to electrical signal for processing. */
		port inputPort : StaticPressurePort;
		port outputPort : PressureDataPort;
		attribute calibrationFactor : Real;
		attribute signalRange : Real;
		
		perform action transmitPressure {
			in physicalPressure : StaticPressure;
			out electricalSignal : Real;
		}
	}
	
	part def PressureRegulator {
		doc /* Maintains static pressure at desired setpoint by controlling flow. */
		port inletPort : StaticPressurePort;
		port outletPort : StaticPressurePort;
		port controlPort : ControlSignalPort;
		attribute setPoint : StaticPressure;
		attribute regulationBand : StaticPressure;
		attribute maxFlowCapacity : VolumeFlowRate;
		
		perform action regulatePressure {
			in measuredPressure : StaticPressure;
			in targetPressure : StaticPressure;
			out adjustedPressure : StaticPressure;
		}
	}
	
	part def PressureVessel {
		doc /* Contains fluid at controlled static pressure for system operation. */
		port vesselPort : StaticPressurePort;
		attribute volume : ISQ::VolumeValue;
		attribute maxPressureRating : StaticPressure;
		attribute currentPressure : StaticPressure;
		
		part containedAir : Air;
	}
	
	part def ControlValve {
		doc /* Modulates flow to adjust static pressure in the system. */
		port valveInlet : StaticPressurePort;
		port valveOutlet : StaticPressurePort;
		attribute valvePosition : Real;
		attribute flowCoefficient : Real;
		
		perform action adjustValve {
			in commandedPosition : Real;
			out actualPosition : Real;
			out resultingFlow : VolumeFlowRate;
		}
	}
	
	action def MeasureStaticPressure {
		in probePressure : StaticPressure;
		in probeTemperature : FluidTemperature;
		out correctedPressure : StaticPressure;
	}
	
	action def CalculatePressureError {
		in measuredPressure : StaticPressure;
		in targetPressure : StaticPressure;
		out pressureError : StaticPressure;
		out errorPercentage : Real;
	}
	
	action def DetermineControlAction {
		in pressureError : StaticPressure;
		in regulationBand : StaticPressure;
		out controlAction : Real;
	}
	
	action def MonitorPressureLimits {
		in currentPressure : StaticPressure;
		in maxPressure : StaticPressure;
		in minPressure : StaticPressure;
		out withinLimits : Boolean;
		out alarmCondition : Boolean;
	}
	
	message StartCommand;
	message StopCommand;
	
	state def StaticPressureSystemStates {
		entry; then initialization;
		
		state initialization {
			entry assign systemPressure := 0.0;
			entry assign valvePosition := 0.0;
		}
		transition initialization_to_standby
			first initialization
			then standby;
		
		state standby {
			do action monitorStandby : MonitorPressureLimits;
		}
		transition standby_to_startup
			first standby
			accept StartCommand
			then startup;
		
		state startup {
			entry; then openingValve;
			
			state openingValve {
				do action openValve;
			}
			transition openingValve_to_pressurizing
				first openingValve
				if valvePosition >= 0.5
				then pressurizing;
			
			state pressurizing {
				do action increasePressure;
			}
			transition pressurizing_to_operational
				first pressurizing
				if systemPressure >= targetPressure * 0.95
				then operational;
		}
		
		state operational {
			entry; then regulating;
			
			state regulating {
				entry; then measuring;
				
				state measuring {
					do action measure : MeasureStaticPressure;
				}
				transition measuring_to_calculating
					first measuring
					then calculating;
				
				state calculating {
					do action calculateError : CalculatePressureError;
				}
				transition calculating_to_adjusting
					first calculating
					then adjusting;
				
				state adjusting {
					do action determineControl : DetermineControlAction;
				}
				transition adjusting_to_measuring
					first adjusting
					then measuring;
			}
			
			transition regulating_to_alarm
				first regulating
				if systemPressure > maxAllowablePressure
				then alarm;
			
			state alarm {
				entry assign alarmActive := true;
				do action emergencyVent;
			}
			transition alarm_to_regulating
				first alarm
				if systemPressure <= maxAllowablePressure
				then regulating;
		}
		
		transition operational_to_shutdown
			first operational
			accept StopCommand
			then shutdown;
		
		state shutdown {
			entry; then venting;
			
			state venting {
				do action ventPressure;
			}
			transition venting_to_standby
				first venting
				if systemPressure <= 0.1
				then standby;
		}
		
		attribute systemPressure : StaticPressure;
		attribute targetPressure : StaticPressure;
		attribute valvePosition : Real;
		attribute maxAllowablePressure : StaticPressure;
		attribute alarmActive : Boolean;
	}
	
	part def StaticPressureSystem {
		doc /* System that measures, monitors, and controls static pressure in a fluid environment 
		       to maintain stable operating conditions for downstream processes or equipment. */
		
		attribute operatingPressure : StaticPressure;
		attribute maxPressure : StaticPressure;
		attribute minPressure : StaticPressure;
		attribute nominalTemperature : FluidTemperature;
		
		port systemInlet : StaticPressurePort;
		port systemOutlet : StaticPressurePort;
		port dataOutput : PressureDataPort;
		
		part primaryProbe : StaticPressureProbe {
			attribute :>> probeAccuracy = 0.005;
			attribute :>> responseTime = 0.05;
		}
		
		part secondaryProbe : StaticPressureProbe {
			attribute :>> probeAccuracy = 0.005;
			attribute :>> responseTime = 0.05;
		}
		
		part transmitter : PressureTransmitter {
			attribute :>> calibrationFactor = 1.0;
			attribute :>> signalRange = 10.0;
		}
		
		part vessel : PressureVessel {
			attribute :>> volume = 0.5;
			attribute :>> maxPressureRating = 500000.0;
		}
		
		part regulator : PressureRegulator {
			attribute :>> setPoint = 101325.0;
			attribute :>> regulationBand = 500.0;
			attribute :>> maxFlowCapacity = 0.1;
		}
		
		part controlValve : ControlValve {
			attribute :>> valvePosition = 0.0;
			attribute :>> flowCoefficient = 1.5;
		}
		
		connection inletToRegulator
			connect systemInlet to regulator.inletPort;
		
		connection regulatorToVessel
			connect regulator.outletPort to vessel.vesselPort;
		
		connection vesselToValve
			connect vessel.vesselPort to controlValve.valveInlet;
		
		connection valveToOutlet
			connect controlValve.valveOutlet to systemOutlet;
		
		connection probeToTransmitter
			connect primaryProbe.probePort to transmitter.inputPort;
		
		connection transmitterToData
			connect transmitter.outputPort to dataOutput;
		
		perform action maintainStaticPressure {
			first start;
			then merge controlLoop;
			
			then action measurePrimary : MeasureStaticPressure {
				in probePressure = primaryProbe.probePort.staticPressure;
				in probeTemperature = primaryProbe.probePort.temperature;
				out correctedPressure;
			}
			
			then action checkLimits : MonitorPressureLimits {
				in currentPressure = measurePrimary.correctedPressure;
				in maxPressure = maxPressure;
				in minPressure = minPressure;
				out withinLimits;
				out alarmCondition;
			}
			
			then decide;
				if checkLimits.alarmCondition then emergencyAction;
				if not checkLimits.withinLimits then correctPressure;
				else controlLoop;
			
			action correctPressure {
				then action calcError : CalculatePressureError {
					in measuredPressure = measurePrimary.correctedPressure;
					in targetPressure = operatingPressure;
					out pressureError;
					out errorPercentage;
				}
				then action determineAction : DetermineControlAction {
					in pressureError = calcError.pressureError;
					in regulationBand = regulator.regulationBand;
					out controlAction;
				}
			}
			then controlLoop;
			
			action emergencyAction;
			then done;
		}
		
		perform state systemBehavior : StaticPressureSystemStates;
	}
	
	requirement def PressureAccuracyRequirement {
		doc /* Static pressure measurement shall be accurate to within specified tolerance. */
		
		subject measuredPressure : StaticPressure;
		
		require constraint accuracyTolerance {
			measuredPressure >= 0.995 * referencePressure and
			measuredPressure <= 1.005 * referencePressure
		}
		
		attribute referencePressure : StaticPressure;
	}
	
	requirement def PressureStabilityRequirement {
		doc /* System shall maintain static pressure within regulation band of setpoint. */
		
		subject systemPressure : StaticPressure;
		
		require constraint stabilityBand {
			systemPressure >= setPoint - regulationBand and
			systemPressure <= setPoint + regulationBand
		}
		
		attribute setPoint : StaticPressure;
		attribute regulationBand : StaticPressure;
	}
	
	requirement def ResponseTimeRequirement {
		doc /* System shall respond to pressure deviations within specified time. */
		
		subject responseTime : ISQ::TimeValue;
		
		require constraint maxResponseTime {
			responseTime <= 1.0
		}
	}
	
	requirement def SafetyPressureLimitRequirement {
		doc /* System shall not exceed maximum safe operating pressure. */
		
		subject operatingPressure : StaticPressure;
		
		require constraint pressureLimit {
			operatingPressure <= maxSafePressure
		}
		
		attribute maxSafePressure : StaticPressure;
	}
	
	requirement <'SPS-REQ-001'> staticPressureSystemRequirement {
		doc /* The static pressure system shall accurately measure, continuously monitor, 
		       and precisely control static pressure within a fluid environment to maintain 
		       stable operating conditions for critical downstream processes and equipment, 
		       ensuring safe and efficient operation across all operating modes. */
		
		subject system : StaticPressureSystem;
		
		require pressureAccuracyReq : PressureAccuracyRequirement {
			redefines measuredPressure = system.primaryProbe.probePort.staticPressure;
		}
		
		require pressureStabilityReq : PressureStabilityRequirement {
			redefines systemPressure = system.vessel.currentPressure;
		}
		
		require systemResponseReq : ResponseTimeRequirement {
			redefines responseTime = system.primaryProbe.responseTime;
		}
		
		require pressureSafetyReq : SafetyPressureLimitRequirement {
			redefines operatingPressure = system.operatingPressure;
		}
		
		assume constraint fluidProperties {
			system.vessel.containedAir.density > 0.0 and
			system.vessel.containedAir.temperature > 0.0
		}
		
		assume constraint systemConfiguration {
			system.regulator.setPoint > 0.0 and
			system.vessel.volume > 0.0
		}
	}
}
