package SpecificSpeedSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SpecificSpeedValue :> Real {
		doc /* Specific speed (Ns) is a dimensionless parameter characterizing 
		       turbomachinery performance: Ns = N*sqrt(Q)/H^0.75 where N is 
		       rotational speed (rpm), Q is flow rate (m³/s), H is head (m). */
	}
	
	attribute def RotationalSpeedValue :> AngularVelocityValue;
	attribute def FlowRateValue :> VolumeFlowRateValue;
	attribute def HeadValue :> LengthValue;
	attribute def EfficiencyValue :> Real;
	attribute def PowerValue :> ISQ::PowerValue;
	attribute def TorqueValue :> ISQ::TorqueValue;
	
	item def FluidProperties {
		attribute density : MassDensityValue;
		attribute viscosity : DynamicViscosityValue;
		attribute temperature : ThermodynamicTemperatureValue;
	}
	
	item def PerformanceData {
		attribute specificSpeed : SpecificSpeedValue;
		attribute efficiency : EfficiencyValue;
		attribute flowRate : FlowRateValue;
		attribute head : HeadValue;
		attribute power : PowerValue;
		attribute operatingPoint : String;
	}
	
	item def ControlCommand {
		attribute targetSpeed : RotationalSpeedValue;
		attribute targetFlow : FlowRateValue;
		attribute mode : String;
	}
	
	port def FluidInletPort {
		attribute pressure : PressureValue;
		attribute flowRate : FlowRateValue;
		attribute temperature : ThermodynamicTemperatureValue;
	}
	
	port def FluidOutletPort {
		attribute pressure : PressureValue;
		attribute flowRate : FlowRateValue;
		attribute temperature : ThermodynamicTemperatureValue;
	}
	
	port def PowerInputPort {
		attribute voltage : ElectricPotentialValue;
		attribute current : ElectricCurrentValue;
		attribute frequency : FrequencyValue;
	}
	
	port def MechanicalShaftPort {
		attribute torque : TorqueValue;
		attribute speed : RotationalSpeedValue;
	}
	
	port def SensorPort {
		out measurement : Real;
		out timestamp : Real;
	}
	
	port def ControlInterfacePort {
		in command : ControlCommand;
		out status : PerformanceData;
	}
	
	part def FlowSensor {
		port fluidPort : FluidInletPort;
		port dataOut : SensorPort;
		attribute measuredFlow : FlowRateValue;
		attribute accuracy : Real;
	}
	
	part def PressureSensor {
		port fluidPort : FluidOutletPort;
		port dataOut : SensorPort;
		attribute measuredPressure : PressureValue;
		attribute accuracy : Real;
	}
	
	part def SpeedSensor {
		port shaftPort : MechanicalShaftPort;
		port dataOut : SensorPort;
		attribute measuredSpeed : RotationalSpeedValue;
		attribute accuracy : Real;
	}
	
	part def VariableFrequencyDrive {
		port powerIn : PowerInputPort;
		port controlIn : ControlInterfacePort;
		port powerOut : PowerInputPort;
		attribute outputFrequency : FrequencyValue;
		attribute outputVoltage : ElectricPotentialValue;
		attribute efficiency : EfficiencyValue;
	}
	
	part def ElectricMotor {
		port powerIn : PowerInputPort;
		port shaftOut : MechanicalShaftPort;
		attribute ratedPower : PowerValue;
		attribute ratedSpeed : RotationalSpeedValue;
		attribute efficiency : EfficiencyValue;
		attribute currentSpeed : RotationalSpeedValue;
		attribute currentTorque : TorqueValue;
	}
	
	part def Impeller {
		attribute diameter : LengthValue;
		attribute bladeCount : Integer;
		attribute inletDiameter : LengthValue;
		attribute outletDiameter : LengthValue;
		attribute bladeAngle : Real;
	}
	
	part def Volute {
		attribute inletArea : AreaValue;
		attribute outletArea : AreaValue;
		attribute diffuserAngle : Real;
	}
	
	part def PumpHousing {
		part impeller : Impeller;
		part volute : Volute;
		attribute casingPressureRating : PressureValue;
	}
	
	part def SpecificSpeedController {
		port controlInterface : ControlInterfacePort;
		port vfdControl : ControlInterfacePort;
		
		attribute designSpecificSpeed : SpecificSpeedValue;
		attribute currentSpecificSpeed : SpecificSpeedValue;
		attribute tolerance : Real;
		
		in measuredFlow : FlowRateValue;
		in measuredInletPressure : PressureValue;
		in measuredOutletPressure : PressureValue;
		in measuredSpeed : RotationalSpeedValue;
		
		out speedCommand : RotationalSpeedValue;
		out performanceStatus : PerformanceData;
		
		action calculateHead {
			in inletPressure : PressureValue;
			in outletPressure : PressureValue;
			in density : MassDensityValue;
			out head : HeadValue;
		}
		
		action calculateSpecificSpeed {
			in rotationalSpeed : RotationalSpeedValue;
			in flowRate : FlowRateValue;
			in head : HeadValue;
			out specificSpeed : SpecificSpeedValue;
		}
		
		action determineOptimalSpeed {
			in targetNs : SpecificSpeedValue;
			in currentNs : SpecificSpeedValue;
			in currentFlow : FlowRateValue;
			in currentHead : HeadValue;
			out commandSpeed : RotationalSpeedValue;
		}
		
		action evaluateEfficiency {
			in specificSpeed : SpecificSpeedValue;
			in designNs : SpecificSpeedValue;
			out efficiency : EfficiencyValue;
		}
	}
	
	part def CentrifugalPump {
		doc /* A centrifugal pump system that automatically maintains optimal 
		       specific speed operation for maximum hydraulic efficiency by 
		       continuously monitoring flow, head, and rotational speed, then 
		       adjusting motor speed to match design specific speed characteristics. */
		
		port fluidInlet : FluidInletPort;
		port fluidOutlet : FluidOutletPort;
		port electricalSupply : PowerInputPort;
		port systemControl : ControlInterfacePort;
		
		part vfd : VariableFrequencyDrive {
			port :>> powerIn = electricalSupply;
		}
		
		part motor : ElectricMotor {
			attribute :>> ratedPower = 75000.0 [W];
			attribute :>> ratedSpeed = 314.16 [rad/s];
			attribute :>> efficiency = 0.92;
		}
		
		part housing : PumpHousing {
			part :>> impeller {
				attribute :>> diameter = 0.3 [m];
				attribute :>> bladeCount = 6;
				attribute :>> inletDiameter = 0.15 [m];
				attribute :>> outletDiameter = 0.28 [m];
				attribute :>> bladeAngle = 25.0;
			}
			part :>> volute {
				attribute :>> diffuserAngle = 8.0;
			}
		}
		
		part inletFlowSensor : FlowSensor {
			attribute :>> accuracy = 0.01;
		}
		
		part inletPressureSensor : PressureSensor {
			attribute :>> accuracy = 0.005;
		}
		
		part outletPressureSensor : PressureSensor {
			attribute :>> accuracy = 0.005;
		}
		
		part shaftSpeedSensor : SpeedSensor {
			attribute :>> accuracy = 0.001;
		}
		
		part controller : SpecificSpeedController {
			attribute :>> designSpecificSpeed = 1800.0;
			attribute :>> tolerance = 0.05;
		}
		
		attribute designSpecificSpeed : SpecificSpeedValue = 1800.0;
		attribute operatingFlow : FlowRateValue;
		attribute operatingHead : HeadValue;
		attribute operatingEfficiency : EfficiencyValue;
		
		connection fluidInletConnection connect fluidInlet to inletFlowSensor.fluidPort;
		connection inletPressureConnection connect fluidInlet to inletPressureSensor.fluidPort;
		connection fluidOutletConnection connect fluidOutlet to outletPressureSensor.fluidPort;
		connection vfdPowerConnection connect vfd.powerOut to motor.powerIn;
		connection motorShaftConnection connect motor.shaftOut to shaftSpeedSensor.shaftPort;
		connection controlToVfdConnection connect controller.vfdControl to vfd.controlIn;
		connection systemControlConnection connect systemControl to controller.controlInterface;
	}
	
	action def MonitorSystemPerformance {
		in currentSpeed : RotationalSpeedValue;
		in currentFlow : FlowRateValue;
		in inletPressure : PressureValue;
		in outletPressure : PressureValue;
		out head : HeadValue;
		out specificSpeed : SpecificSpeedValue;
		out efficiency : EfficiencyValue;
	}
	
	action def AdjustOperatingPoint {
		in targetNs : SpecificSpeedValue;
		in currentNs : SpecificSpeedValue;
		in deviation : Real;
		out speedAdjustment : RotationalSpeedValue;
		out controlAction : String;
	}
	
	action def ComputeAbsoluteValue {
		in value : Real;
		out result : Real;
	}
	
	action def OptimizeSpecificSpeed {
		doc /* Primary control action that maintains optimal specific speed 
		       by monitoring hydraulic conditions and adjusting motor speed. */
		
		first start;
		then merge monitoringLoop;
		
		action monitor : MonitorSystemPerformance {
			in currentSpeed;
			in currentFlow;
			in inletPressure;
			in outletPressure;
			out head;
			out specificSpeed;
			out efficiency;
		}
		
		then action calculateDeviation {
			in targetNs : SpecificSpeedValue;
			in actualNs : SpecificSpeedValue = monitor.specificSpeed;
			out deviation : Real;
		}
		
		then action computeAbsDeviation : ComputeAbsoluteValue {
			in value = calculateDeviation.deviation;
			out result;
		}
		
		then decide;
			if calculateDeviation.deviation > 0.05 then increaseSpeed;
			if calculateDeviation.deviation < -0.05 then decreaseSpeed;
			if computeAbsDeviation.result <= 0.05 then maintainSpeed;
		
		action increaseSpeed : AdjustOperatingPoint {
			in targetNs;
			in currentNs = monitor.specificSpeed;
			in deviation = calculateDeviation.deviation;
			out speedAdjustment;
			out controlAction;
		}
		then monitoringLoop;
		
		action decreaseSpeed : AdjustOperatingPoint {
			in targetNs;
			in currentNs = monitor.specificSpeed;
			in deviation = calculateDeviation.deviation;
			out speedAdjustment;
			out controlAction;
		}
		then monitoringLoop;
		
		action maintainSpeed {
			in currentSpeed : RotationalSpeedValue;
			out commandSpeed : RotationalSpeedValue = currentSpeed;
		}
		then monitoringLoop;
	}
	
	state def PumpOperationalStates {
		entry; then stopped;
		
		state stopped {
			entry action assignStoppedSpeed {
				out motorSpeed : RotationalSpeedValue = 0.0 [rad/s];
			}
			entry action assignStoppedFlow {
				out flowRate : FlowRateValue = 0.0 [m^3/s];
			}
		}
		accept StartCommand then initializing;
		
		state initializing {
			entry action assignMinimumSpeed {
				in minimumSpeed : RotationalSpeedValue;
				out motorSpeed : RotationalSpeedValue = minimumSpeed;
			}
			do action primeSystem {
				in minimumSpeed : RotationalSpeedValue;
				out systemReady : Boolean;
			}
		}
		if primeSystem.systemReady then accelerating;
		
		state accelerating {
			do action rampUpSpeed {
				in currentSpeed : RotationalSpeedValue;
				in targetSpeed : RotationalSpeedValue;
				in rampRate : Real;
				out actualSpeed : RotationalSpeedValue;
			}
		}
		if rampUpSpeed.actualSpeed >= designOperatingSpeed then normalOperation;
		
		state normalOperation {
			do action optimizeOperation : OptimizeSpecificSpeed;
			
			state optimizing {
				entry action setControlMode {
					out controlMode : String = "Automatic";
				}
			}
			
			state atDesignPoint {
				entry action setMaxEfficiency {
					in maximumEfficiency : EfficiencyValue;
					out efficiency : EfficiencyValue = maximumEfficiency;
				}
			}
			
			transition from optimizing to atDesignPoint 
				when currentNsDeviationCheck;
			transition from atDesignPoint to optimizing 
				when currentNsDeviationExceeded;
		}
		accept StopCommand then decelerating;
		accept EmergencyStop then emergency;
		accept FlowDemandChange then normalOperation;
		
		state decelerating {
			do action rampDownSpeed {
				in currentSpeed : RotationalSpeedValue;
				in rampRate : Real;
				out actualSpeed : RotationalSpeedValue;
			}
		}
		if rampDownSpeed.actualSpeed <= 0.0 [rad/s] then stopped;
		
		state emergency {
			entry action emergencyStopSpeed {
				out motorSpeed : RotationalSpeedValue = 0.0 [rad/s];
			}
			entry action setAlarmStatus {
				out alarmStatus : String = "Emergency Stop Active";
			}
		}
		accept ResetCommand then stopped;
	}
	
	requirement def SpecificSpeedPerformanceRequirement {
		doc /* The pump shall operate at its design specific speed to maximize 
		       hydraulic efficiency across varying flow and head conditions. */
		
		subject pump : CentrifugalPump;
		
		require constraint specificSpeedTolerance {
			doc /* Actual specific speed shall remain within 5% of design value. */
			pump.controller.currentSpecificSpeed >= 0.95 * pump.designSpecificSpeed and
			pump.controller.currentSpecificSpeed <= 1.05 * pump.designSpecificSpeed
		}
		
		require constraint minimumEfficiency {
			doc /* System efficiency shall exceed 85% at design point. */
			pump.operatingEfficiency >= 0.85
		}
		
		require constraint responseTime {
			doc /* Controller shall adjust speed within 2 seconds of deviation detection. */
		}
	}
	
	requirement def FlowDeliveryRequirement {
		doc /* The pump shall deliver required flow rate within acceptable tolerance. */
		
		subject pump : CentrifugalPump;
		attribute requiredFlow : FlowRateValue;
		
		require constraint flowTolerance {
			pump.operatingFlow >= 0.90 * requiredFlow and
			pump.operatingFlow <= 1.10 * requiredFlow
		}
		
		require constraint flowStability {
			doc /* Flow rate variation shall not exceed 3% during steady-state operation. */
		}
	}
	
	requirement def HeadPressureRequirement {
		doc /* The pump shall maintain required head pressure across operating range. */
		
		subject pump : CentrifugalPump;
		attribute requiredHead : HeadValue;
		
		require constraint headTolerance {
			pump.operatingHead >= 0.92 * requiredHead and
			pump.operatingHead <= 1.08 * requiredHead
		}
		
		require constraint cavitationPrevention {
			doc /* Net positive suction head available shall exceed required NPSH by 20%. */
		}
	}
	
	requirement def SafetyRequirement {
		doc /* The system shall operate safely under all conditions. */
		
		subject pump : CentrifugalPump;
		
		require constraint overpressureProtection {
			doc /* System shall shut down if outlet pressure exceeds 120% of rated value. */
		}
		
		require constraint overtemperatureProtection {
			doc /* System shall shut down if motor temperature exceeds 85°C. */
		}
		
		require constraint emergencyStopResponse {
			doc /* System shall stop within 3 seconds of emergency stop command. */
		}
	}
	
	requirement <'SS-SYS-001'> specificSpeedSystemRequirement {
		doc /* The specific speed control system shall automatically optimize pump 
		       operation by maintaining the design specific speed for maximum efficiency 
		       across varying hydraulic conditions through continuous monitoring and 
		       adaptive speed control. */
		
		subject pumpSystem : CentrifugalPump;
		
		assume constraint operatingRange {
			pumpSystem.operatingFlow >= 0.0 [m^3/s] and 
			pumpSystem.operatingFlow <= 0.15 [m^3/s] and
			pumpSystem.operatingHead >= 0.0 [m] and 
			pumpSystem.operatingHead <= 50.0 [m]
		}
		
		assume constraint fluidProperties {
			doc /* System designed for water at 20°C with density 1000 kg/m³. */
		}
		
		require performanceReq : SpecificSpeedPerformanceRequirement {
			:>> pump = pumpSystem;
		}
		
		require flowReq : FlowDeliveryRequirement {
			:>> pump = pumpSystem;
			:>> requiredFlow = 0.08 [m^3/s];
		}
		
		require headReq : HeadPressureRequirement {
			:>> pump = pumpSystem;
			:>> requiredHead = 30.0 [m];
		}
		
		require safetyReq : SafetyRequirement {
			:>> pump = pumpSystem;
		}
	}
	
	part specificSpeedPumpSystem : CentrifugalPump {
		doc /* Primary function: Automatically maintain optimal specific speed operation 
		       to maximize hydraulic efficiency by continuously monitoring flow rate, 
		       head pressure, and rotational speed, then dynamically adjusting motor 
		       speed through a variable frequency drive to match design specific speed 
		       characteristics for current operating conditions, ensuring peak performance 
		       across varying system demands while preventing cavitation and maintaining 
		       safe operating limits. */
		
		attribute :>> designSpecificSpeed = 1800.0;
		attribute :>> operatingFlow = 0.08 [m^3/s];
		attribute :>> operatingHead = 30.0 [m];
		attribute :>> operatingEfficiency = 0.88;
		
		perform action systemOperation : OptimizeSpecificSpeed;
		
		exhibit state operatingBehavior : PumpOperationalStates;
		
		satisfy specificSpeedSystemRequirement;
	}
}
