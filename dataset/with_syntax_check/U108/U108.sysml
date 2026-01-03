package PumpingSubsystemWithThrombosis {
	private import ScalarValues::*;
	private import ISQ::*;
	
	package Definitions {
		
		package Units {
			attribute def PressureUnit;
			attribute def FlowRateUnit;
			attribute def ViscosityUnit;
			attribute def TimeUnit;
			attribute def VolumeUnit;
			
			attribute kPa : PressureUnit;
			attribute LperMin : FlowRateUnit;
			attribute PaS : ViscosityUnit;
			attribute s : TimeUnit;
			attribute L : VolumeUnit;
		}
		
		private import Units::*;
		
		attribute def PressureValue :> Real {
			attribute unit : PressureUnit;
		}
		
		attribute def FlowRateValue :> Real {
			attribute unit : FlowRateUnit;
		}
		
		attribute def ViscosityValue :> Real {
			attribute unit : ViscosityUnit;
		}
		
		attribute def VolumeValue :> Real {
			attribute unit : VolumeUnit;
		}
		
		item def Fluid {
			attribute viscosity : ViscosityValue;
			attribute density : Real;
			attribute temperature : Real;
			attribute volume : VolumeValue;
		}
		
		item def Blood :> Fluid {
			attribute :>> viscosity : ViscosityValue = 0.0035 [PaS];
			attribute :>> density = 1060.0;
			attribute hematocrit : Real;
			attribute oxygenation : Real;
		}
		
		item def Thrombus {
			attribute size : Real;
			attribute adhesionStrength : Real;
			attribute formationRate : Real;
			attribute isOccluding : Boolean;
		}
		
		port def FluidInPort {
			in item fluidIn : Fluid;
			attribute inletPressure : PressureValue;
		}
		
		port def FluidOutPort {
			out item fluidOut : Fluid;
			attribute outletPressure : PressureValue;
			attribute outletFlowRate : FlowRateValue;
		}
		
		part def FluidReservoir {
			port outPort : FluidOutPort;
			attribute capacity : VolumeValue;
			attribute currentVolume : VolumeValue;
			item storedFluid : Fluid;
		}
		
		part def FluidDestination {
			port inPort : FluidInPort;
			attribute receivedVolume : VolumeValue;
			item receivedFluid : Fluid;
		}
		
		part def PressureSensor {
			attribute measuredPressure : PressureValue;
			attribute sensorAccuracy : Real;
			attribute calibrationOffset : Real;
		}
		
		part def FlowRateSensor {
			attribute measuredFlowRate : FlowRateValue;
			attribute sensorAccuracy : Real;
		}
		
		part def ThrombusDetector {
			attribute detectionThreshold : ViscosityValue;
			attribute pressureDropThreshold : PressureValue;
			attribute thrombusDetected : Boolean;
			attribute thrombusLoad : Real;
		}
		
		part def PumpImpeller {
			attribute rotationalSpeed : Real;
			attribute bladeCount : Integer;
			attribute efficiency : Real;
			attribute wearLevel : Real;
		}
		
		part def PumpMotor {
			attribute powerRating : Real;
			attribute currentSpeed : Real;
			attribute voltage : Real;
			attribute isActive : Boolean;
		}
		
		part def PumpChamber {
			port inlet : FluidInPort;
			port outlet : FluidOutPort;
			attribute chamberVolume : VolumeValue;
			attribute wallShearStress : Real;
			item containedFluid : Fluid[0..1];
			item thrombi : Thrombus[0..*];
		}
		
		action def StartPump {
			in targetSpeed : Real;
			out motorActivated : Boolean;
		}
		
		action def StopPump {
			out motorDeactivated : Boolean;
		}
		
		action def PumpFluid {
			in fluidIn : Fluid;
			out fluidOut : Fluid;
			in operatingSpeed : Real;
			out achievedFlowRate : FlowRateValue;
		}
		
		action def MonitorThrombosis {
			in inletPressure : PressureValue;
			in outletPressure : PressureValue;
			in fluidViscosity : ViscosityValue;
			in flowRate : FlowRateValue;
			out thrombusDetected : Boolean;
			out thrombusLoad : Real;
		}
		
		action def ClearThrombosis {
			in thrombusLoad : Real;
			in currentSpeed : Real;
			out newSpeed : Real;
			out clearanceSuccess : Boolean;
		}
		
		action def AdjustFlowRate {
			in targetFlowRate : FlowRateValue;
			in currentFlowRate : FlowRateValue;
			out speedAdjustment : Real;
		}
		
		action def EmergencyShutdown {
			in reason : String;
			out shutdownComplete : Boolean;
		}
		
		state def PumpOperationalStates {
			entry; then idle;
			
			state idle;
			
			transition idle_to_priming
				first idle
				accept StartCommand
				then priming;
			
			state priming;
			
			transition priming_to_operating
				first priming
				then operating;
			
			state operating;
			
			transition operating_to_monitoring
				first operating
				then monitoring;
			
			state monitoring;
			
			transition monitoring_to_thrombusDetected
				first monitoring
				then thrombusDetected;
			
			transition monitoring_to_operating
				first monitoring
				then operating;
			
			state thrombusDetected;
			
			transition thrombusDetected_to_clearing
				first thrombusDetected
				then clearing;
			
			state clearing;
			
			transition clearing_to_operating
				first clearing
				then operating;
			
			transition clearing_to_emergency
				first clearing
				then emergency;
			
			state emergency;
			
			transition emergency_to_stopped
				first emergency
				then stopped;
			
			transition operating_to_stopped
				first operating
				accept StopCommand
				then stopped;
			
			state stopped;
			
			transition stopped_to_idle
				first stopped
				then idle;
		}
		
		part def Pump {
			port inletPort : FluidInPort;
			port outletPort : FluidOutPort;
			
			part motor : PumpMotor;
			part impeller : PumpImpeller;
			part chamber : PumpChamber;
			part detector : ThrombusDetector;
			part inletSensor : PressureSensor;
			part outletSensor : PressureSensor;
			part flowSensor : FlowRateSensor;
			
			attribute nominalFlowRate : FlowRateValue;
			attribute maxPressure : PressureValue;
			attribute thrombusPresent : Boolean;
			attribute operationalStatus : String;
			
			bind chamber.inlet = inletPort;
			bind chamber.outlet = outletPort;
			
			exhibit state operatingStateMachine : PumpOperationalStates;
		}
		
		requirement def FlowRateRequirement {
			subject pump : Pump;
			
			doc /* The pump shall maintain the target flow rate within ±10% tolerance during normal operation */
			
			require constraint {
				pump.nominalFlowRate * 0.9 <= pump.flowSensor.measuredFlowRate and
				pump.flowSensor.measuredFlowRate <= pump.nominalFlowRate * 1.1
			}
		}
		
		requirement def ThrombusDetectionRequirement {
			subject detector : ThrombusDetector;
			
			doc /* The system shall detect thrombosis when viscosity exceeds threshold or pressure drop is abnormal */
			
			require constraint {
				(detector.thrombusLoad > 0.5) implies (detector.thrombusDetected == true)
			}
		}
		
		requirement def ThrombusManagementRequirement {
			subject pump : Pump;
			
			doc /* The pump shall attempt automatic clearance when thrombosis is detected */
			
			require constraint {
				pump.thrombusPresent == true
			}
		}
		
		requirement def SafetyShutdownRequirement {
			subject pump : Pump;
			
			doc /* The pump shall execute emergency shutdown if thrombosis clearance fails */
			
			require constraint {
				pump.motor.isActive == false
			}
		}
	}
	
	package Usages {
		private import Definitions::*;
		private import Units::*;
		
		part pumpingSubsystem {
			
			part sourceReservoir : FluidReservoir {
				attribute :>> capacity = 100.0 [L];
				attribute :>> currentVolume = 85.0 [L];
				
				item :>> storedFluid : Blood {
					attribute :>> viscosity = 0.0035 [PaS];
					attribute :>> density = 1060.0;
					attribute :>> temperature = 310.15;
					attribute :>> volume = 85.0 [L];
					attribute :>> hematocrit = 0.45;
					attribute :>> oxygenation = 0.98;
				}
			}
			
			flow of blood : Blood
				from sourceReservoir.outPort.fluidOut
				to pump.inletPort.fluidIn;
			
			part pump : Pump {
				attribute :>> nominalFlowRate = 5.0 [LperMin];
				attribute :>> maxPressure = 200.0 [kPa];
				attribute :>> thrombusPresent = false;
				attribute :>> operationalStatus = "Ready";
				
				part :>> motor : PumpMotor {
					attribute :>> powerRating = 2000.0;
					attribute :>> currentSpeed = 0.0;
					attribute :>> voltage = 220.0;
					attribute :>> isActive = false;
				}
				
				part :>> impeller : PumpImpeller {
					attribute :>> rotationalSpeed = 0.0;
					attribute :>> bladeCount = 6;
					attribute :>> efficiency = 0.82;
					attribute :>> wearLevel = 0.15;
				}
				
				part :>> chamber : PumpChamber {
					attribute :>> chamberVolume = 0.5 [L];
					attribute :>> wallShearStress = 0.0;
				}
				
				part :>> detector : ThrombusDetector {
					attribute :>> detectionThreshold = 0.008 [PaS];
					attribute :>> pressureDropThreshold = 50.0 [kPa];
					attribute :>> thrombusDetected = false;
					attribute :>> thrombusLoad = 0.0;
				}
				
				part :>> inletSensor : PressureSensor {
					attribute :>> measuredPressure = 101.3 [kPa];
					attribute :>> sensorAccuracy = 0.02;
					attribute :>> calibrationOffset = 0.0;
				}
				
				part :>> outletSensor : PressureSensor {
					attribute :>> measuredPressure = 150.0 [kPa];
					attribute :>> sensorAccuracy = 0.02;
					attribute :>> calibrationOffset = 0.0;
				}
				
				part :>> flowSensor : FlowRateSensor {
					attribute :>> measuredFlowRate = 0.0 [LperMin];
					attribute :>> sensorAccuracy = 0.03;
				}
			}
			
			flow of blood : Blood
				from pump.outletPort.fluidOut
				to destination.inPort.fluidIn;
			
			part destination : FluidDestination {
				attribute :>> receivedVolume = 0.0 [L];
			}
			
			assert requirement flowReq : FlowRateRequirement {
				subject pump = pumpingSubsystem.pump;
			}
			
			assert requirement detectionReq : ThrombusDetectionRequirement {
				subject detector = pumpingSubsystem.pump.detector;
			}
			
			assert requirement managementReq : ThrombusManagementRequirement {
				subject pump = pumpingSubsystem.pump;
			}
			
			assert requirement safetyReq : SafetyShutdownRequirement {
				subject pump = pumpingSubsystem.pump;
			}
		}
	}
}
