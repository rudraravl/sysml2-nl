package 'InjectionPumpingSubsystem' {
	private import ScalarValues::*;
	
	package Definitions {
		
		attribute def PascalUnit;
		attribute def LiterUnit;
		attribute def LiterPerMinuteUnit;
		attribute def CelsiusUnit;
		attribute def RPMUnit;
		attribute def WattUnit;
		
		attribute def PressureValue {
			attribute magnitude : Real;
		}
		
		attribute def VolumeValue {
			attribute magnitude : Real;
		}
		
		attribute def FlowRateValue {
			attribute magnitude : Real;
		}
		
		attribute def TemperatureValue {
			attribute magnitude : Real;
		}
		
		attribute def RotationalSpeedValue {
			attribute magnitude : Real;
		}
		
		attribute def PowerValue {
			attribute magnitude : Real;
		}
		
		enum def PumpOperatingMode {
			enum idle;
			enum priming;
			enum pumping;
			enum flushing;
			enum fault;
		}
		
		enum def ValveState {
			enum open;
			enum closed;
			enum partial;
		}
		
		item def Fluid {
			attribute density : Real;
			attribute viscosity : Real;
			attribute temperature : TemperatureValue;
			attribute volume : VolumeValue;
			attribute contamination : Real;
		}
		
		port def FluidPort {
			out item fluidStream : Fluid;
			attribute pressure : PressureValue;
			attribute flowRate : FlowRateValue;
		}
		
		port def ControlSignalPort {
			in attribute commandedSpeed : RotationalSpeedValue;
			in attribute commandedFlowRate : FlowRateValue;
			out attribute actualSpeed : RotationalSpeedValue;
			out attribute actualFlowRate : FlowRateValue;
			out attribute operatingMode : PumpOperatingMode;
		}
		
		port def PowerSupplyPort {
			in attribute voltage : Real;
			in attribute current : Real;
			attribute power : PowerValue;
		}
		
		part def SupplyReservoir {
			port outlet : FluidPort;
			
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			attribute minOperatingLevel : VolumeValue;
			
			item storedFluid : Fluid {
				attribute :>> volume = currentLevel;
			}
			
			assert constraint levelCheck {
				currentLevel.magnitude >= minOperatingLevel.magnitude
			}
		}
		
		part def InjectionPump {
			port suctionPort : ~FluidPort;
			port dischargePort : FluidPort;
			port controlPort : ControlSignalPort;
			port powerPort : PowerSupplyPort;
			
			attribute ratedPressure : PressureValue;
			attribute ratedFlowRate : FlowRateValue;
			attribute plungerDiameter : Real;
			attribute strokeLength : Real;
			attribute numberOfPlungers : Integer;
			attribute volumetricEfficiency : Real;
			
			part plungerAssembly {
				attribute position : Real;
				attribute velocity : Real;
				attribute acceleration : Real;
			}
			
			part suctionValve {
				attribute state : ValveState;
				attribute openingPressure : PressureValue;
			}
			
			part dischargeValve {
				attribute state : ValveState;
				attribute crackingPressure : PressureValue;
			}
			
			part driveMotor {
				attribute speed : RotationalSpeedValue;
				attribute torque : Real;
				attribute powerConsumption : PowerValue;
			}
			
			part camMechanism {
				attribute rotationAngle : Real;
				attribute liftProfile : Real;
			}
			
			perform action pumpingCycle : InjectionPumpCycle;
			
			exhibit state operatingStateMachine : InjectionPumpStateMachine;
		}
		
		part def DischargeManifold {
			port inlet : ~FluidPort;
			port outlet1 : FluidPort;
			port outlet2 : FluidPort;
			
			attribute internalVolume : VolumeValue;
			attribute internalPressure : PressureValue;
			attribute maxPressure : PressureValue;
			
			item accumulatedFluid : Fluid;
			
			assert constraint pressureSafety {
				internalPressure.magnitude <= maxPressure.magnitude
			}
		}
		
		part def PressureTransducer {
			port measurementPoint : ~FluidPort;
			
			in attribute measuredPressure : PressureValue;
			out attribute pressureSignal : Real;
			attribute calibrationFactor : Real;
			attribute accuracy : Real;
		}
		
		part def FlowMeter {
			port measurementPoint : ~FluidPort;
			
			in attribute measuredFlow : FlowRateValue;
			out attribute flowSignal : Real;
			attribute kFactor : Real;
			attribute rangeability : Real;
		}
		
		part def PumpController {
			port controlInterface : ~ControlSignalPort;
			
			in attribute setpointFlowRate : FlowRateValue;
			in attribute setpointPressure : PressureValue;
			in attribute feedbackPressure : PressureValue;
			in attribute feedbackFlow : FlowRateValue;
			in attribute feedbackSpeed : RotationalSpeedValue;
			
			out attribute commandSpeed : RotationalSpeedValue;
			out attribute commandFlow : FlowRateValue;
			
			attribute proportionalGain : Real;
			attribute integralGain : Real;
			attribute derivativeGain : Real;
			attribute errorIntegral : Real;
			attribute previousError : Real;
			
			perform action controlAlgorithm : PIDControlBehavior;
		}
		
		part def ReliefValve {
			port inlet : ~FluidPort;
			port outlet : FluidPort;
			
			attribute setpointPressure : PressureValue;
			attribute valvePosition : ValveState;
			attribute crackingPressure : PressureValue;
			attribute reseatPressure : PressureValue;
		}
		
		action def InjectionPumpCycle {
			in suctionFluid : Fluid;
			in commandedSpeed : RotationalSpeedValue;
			in dischargePressure : PressureValue;
			in valveCrackingPressure : PressureValue;
			out dischargedFluid : Fluid;
			out achievedFlowRate : FlowRateValue;
			
			first start;
			then merge cycleStart;
			
			then action suctionStroke {
				doc /* Plunger retracts, suction valve opens, fluid enters chamber */
				in fluid = suctionFluid;
			}
			
			then action compressionStroke {
				doc /* Plunger advances, suction valve closes, pressure builds */
			}
			
			then decide;
				if dischargePressure.magnitude >= valveCrackingPressure.magnitude 
					then dischargeStroke;
				if dischargePressure.magnitude < valveCrackingPressure.magnitude 
					then faultCondition;
			
			action dischargeStroke {
				doc /* Discharge valve opens, pressurized fluid exits chamber */
				out fluid = dischargedFluid;
			}
			then cycleStart;
			
			action faultCondition {
				doc /* Abnormal pressure condition detected */
			}
			then done;
		}
		
		action def PIDControlBehavior {
			in setpoint : FlowRateValue;
			in feedback : FlowRateValue;
			in kp : Real;
			in ki : Real;
			in kd : Real;
			out controlOutput : RotationalSpeedValue;
			
			first start;
			then merge controlLoop;
			
			then action calculateError {
				doc /* Compute difference between setpoint and actual flow */
			}
			
			then action computeProportional {
				doc /* Calculate proportional term */
			}
			
			then action computeIntegral {
				doc /* Calculate integral term with anti-windup */
			}
			
			then action computeDerivative {
				doc /* Calculate derivative term */
			}
			
			then action sumTerms {
				doc /* Combine PID terms to generate control signal */
			}
			
			then action limitOutput {
				doc /* Constrain output to safe operating range */
			}
			
			then controlLoop;
		}
		
		state def InjectionPumpStateMachine {
			in suctionPressure : PressureValue;
			in dischargePressure : PressureValue;
			in valveCrackingPressure : PressureValue;
			in maxRatedPressure : PressureValue;
			inout currentMode : PumpOperatingMode;
			
			entry; then idle;
			
			state idle {
				entry action setIdleMode {
					currentMode = PumpOperatingMode::idle;
				}
				do action maintainStandby {
					doc /* Maintain standby state, monitor for start command */
				}
			}
			
			transition idle_to_priming
				first idle
				accept StartCommand
				if suctionPressure.magnitude > 0
				then priming;
			
			state priming {
				entry action setPrimingMode {
					currentMode = PumpOperatingMode::priming;
				}
				do action primePump {
					doc /* Run at low speed to fill pump chamber and purge air */
				}
			}
			
			transition priming_to_pumping
				first priming
				accept PrimingComplete
				if dischargePressure.magnitude > valveCrackingPressure.magnitude
				then pumping;
			
			transition priming_to_fault
				first priming
				accept PrimingTimeout
				then fault;
			
			state pumping {
				entry action setPumpingMode {
					currentMode = PumpOperatingMode::pumping;
				}
				do action normalOperation {
					doc /* Execute injection pump cycle at commanded speed */
				}
			}
			
			transition pumping_to_flushing
				first pumping
				accept FlushCommand
				then flushing;
			
			transition pumping_to_fault
				first pumping
				accept OverPressure
				if dischargePressure.magnitude > maxRatedPressure.magnitude * 1.2
				then fault;
			
			transition pumping_to_idle
				first pumping
				accept StopCommand
				then idle;
			
			state flushing {
				entry action setFlushingMode {
					currentMode = PumpOperatingMode::flushing;
				}
				do action flushSystem {
					doc /* Circulate fluid to clean internal passages */
				}
			}
			
			transition flushing_to_idle
				first flushing
				accept FlushComplete
				then idle;
			
			state fault {
				entry action setFaultMode {
					currentMode = PumpOperatingMode::fault;
				}
				do action handleFault {
					doc /* Shutdown pump, log fault condition, await reset */
				}
			}
			
			transition fault_to_idle
				first fault
				accept ResetCommand
				if suctionPressure.magnitude > 0 and 
				   dischargePressure.magnitude < maxRatedPressure.magnitude
				then idle;
		}
	}
	
	package Requirements {
		requirement def FlowDeliveryRequirement {
			doc /* The injection pump shall deliver fluid at the specified flow rate within tolerance */
			
			subject pump : InjectionPump;
			
			require constraint flowAccuracy {
				abs(pump.dischargePort.flowRate.magnitude - pump.controlPort.commandedFlowRate.magnitude) <= 
				pump.controlPort.commandedFlowRate.magnitude * 0.05
			}
		}
		
		requirement def PressureCapabilityRequirement {
			doc /* The injection pump shall generate discharge pressure up to rated value */
			
			subject pump : InjectionPump;
			
			require constraint pressureCapability {
				pump.dischargePort.pressure.magnitude <= pump.ratedPressure.magnitude and
				pump.dischargePort.pressure.magnitude >= pump.ratedPressure.magnitude * 0.9
			}
		}
		
		requirement def SystemSafetyRequirement {
			doc /* The pumping subsystem shall prevent overpressure conditions */
			
			subject subsystem : PumpingSubsystem;
			
			require constraint overpressureProtection {
				subsystem.reliefValve.setpointPressure.magnitude <= 
				subsystem.injectionPump.ratedPressure.magnitude * 1.1
			}
			
			require constraint reservoirLevel {
				subsystem.supplyReservoir.currentLevel.magnitude >= 
				subsystem.supplyReservoir.minOperatingLevel.magnitude
			}
		}
		
		requirement def ControlStabilityRequirement {
			doc /* The controller shall maintain stable operation without oscillation */
			
			subject controller : PumpController;
			
			require constraint steadyStateError {
				abs(controller.feedbackFlow.magnitude - controller.setpointFlowRate.magnitude) <= 
				controller.setpointFlowRate.magnitude * 0.02
			}
		}
		
		requirement def EfficiencyRequirement {
			doc /* The injection pump shall operate at minimum volumetric efficiency */
			
			subject pump : InjectionPump;
			
			require constraint minEfficiency {
				pump.volumetricEfficiency >= 0.85
			}
		}
	}
	
	package Usages {
		part pumpingSubsystem : PumpingSubsystem {
			
			part supplyReservoir : SupplyReservoir {
				attribute :>> capacity.magnitude = 100.0;
				attribute :>> currentLevel.magnitude = 75.0;
				attribute :>> minOperatingLevel.magnitude = 10.0;
				
				attribute :>> storedFluid.density = 850.0;
				attribute :>> storedFluid.viscosity = 0.005;
				attribute :>> storedFluid.temperature.magnitude = 25.0;
			}
			
			part injectionPump : InjectionPump {
				attribute :>> ratedPressure.magnitude = 20000000.0;
				attribute :>> ratedFlowRate.magnitude = 50.0;
				attribute :>> plungerDiameter = 0.025;
				attribute :>> strokeLength = 0.05;
				attribute :>> numberOfPlungers = 3;
				attribute :>> volumetricEfficiency = 0.92;
				
				part :>> suctionValve {
					attribute :>> openingPressure.magnitude = 50000.0;
				}
				
				part :>> dischargeValve {
					attribute :>> crackingPressure.magnitude = 15000000.0;
				}
				
				part :>> driveMotor {
					attribute :>> speed.magnitude = 1200.0;
					attribute :>> powerConsumption.magnitude = 5000.0;
				}
			}
			
			part dischargeManifold : DischargeManifold {
				attribute :>> internalVolume.magnitude = 2.0;
				attribute :>> maxPressure.magnitude = 25000000.0;
			}
			
			part suctionPressureSensor : PressureTransducer {
				attribute :>> calibrationFactor = 1.0;
				attribute :>> accuracy = 0.01;
			}
			
			part dischargePressureSensor : PressureTransducer {
				attribute :>> calibrationFactor = 1.0;
				attribute :>> accuracy = 0.005;
			}
			
			part dischargeFlowMeter : FlowMeter {
				attribute :>> kFactor = 1000.0;
				attribute :>> rangeability = 10.0;
			}
			
			part controller : PumpController {
				attribute :>> setpointFlowRate.magnitude = 45.0;
				attribute :>> setpointPressure.magnitude = 18000000.0;
				attribute :>> proportionalGain = 0.5;
				attribute :>> integralGain = 0.1;
				attribute :>> derivativeGain = 0.05;
			}
			
			part reliefValve : ReliefValve {
				attribute :>> setpointPressure.magnitude = 22000000.0;
				attribute :>> crackingPressure.magnitude = 21500000.0;
				attribute :>> reseatPressure.magnitude = 20000000.0;
			}
			
			flow of fluid : Fluid
				from supplyReservoir.outlet.fluidStream
				to injectionPump.suctionPort.fluidStream;
			
			flow of fluid : Fluid
				from injectionPump.dischargePort.fluidStream
				to dischargeManifold.inlet.fluidStream;
			
			flow of fluid : Fluid
				from dischargeManifold.inlet.fluidStream
				to reliefValve.inlet.fluidStream;
			
			connect controller.controlInterface to injectionPump.controlPort;
			
			bind suctionPressureSensor.measuredPressure = injectionPump.suctionPort.pressure;
			bind dischargePressureSensor.measuredPressure = injectionPump.dischargePort.pressure;
			bind dischargeFlowMeter.measuredFlow = injectionPump.dischargePort.flowRate;
			
			bind controller.feedbackPressure = dischargePressureSensor.measuredPressure;
			bind controller.feedbackFlow = dischargeFlowMeter.measuredFlow;
			bind controller.feedbackSpeed = injectionPump.driveMotor.speed;
			
			bind controller.commandSpeed = injectionPump.controlPort.commandedSpeed;
			bind controller.commandFlow = injectionPump.controlPort.commandedFlowRate;
			
			satisfy flowReq : FlowDeliveryRequirement {
				subject pump = injectionPump;
			}
			
			satisfy pressureReq : PressureCapabilityRequirement {
				subject pump = injectionPump;
			}
			
			satisfy safetyReq : SystemSafetyRequirement {
				subject subsystem = pumpingSubsystem;
			}
			
			satisfy controlReq : ControlStabilityRequirement {
				subject controller = pumpingSubsystem.controller;
			}
			
			satisfy efficiencyReq : EfficiencyRequirement {
				subject pump = injectionPump;
			}
		}
	}
	
	part def PumpingSubsystem {
		part supplyReservoir : SupplyReservoir;
		part injectionPump : InjectionPump;
		part dischargeManifold : DischargeManifold;
		part suctionPressureSensor : PressureTransducer;
		part dischargePressureSensor : PressureTransducer;
		part dischargeFlowMeter : FlowMeter;
		part controller : PumpController;
		part reliefValve : ReliefValve;
	}
}
