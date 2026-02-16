package 'Pumping Subsystem Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import NumericalFunctions::*;

	package Definitions {
		item def Fluid {
			attribute temperature : ThermodynamicTemperatureValue;
			attribute pressure : PressureValue;
			attribute density : MassValue;
			attribute viscosity : DynamicViscosityValue;
			attribute volume : VolumeValue;
		}

		attribute def EfficiencyValue :> Real;
		attribute def VolumeFlowRateValue :> Real;
		attribute def RotationalSpeedValue :> Real;
		attribute def TorqueValue :> Real;
		attribute def DensityValue :> Real;
		attribute def DynamicViscosityValue :> Real;

		port def FluidInPort {
			attribute inletPressure : PressureValue;
			attribute inletTemperature : ThermodynamicTemperatureValue;
			in item fluidIn : Fluid;
		}

		port def FluidOutPort {
			attribute outletPressure : PressureValue;
			attribute outletTemperature : ThermodynamicTemperatureValue;
			out item fluidOut : Fluid;
		}

		port def PowerPort {
			attribute voltage : Real;
			attribute current : Real;
			attribute powerDraw : PowerValue;
		}

		state def MotorStates {
			entry; then stopped;

			state stopped {
				doc /* Motor is not running. */
			}

			state starting {
				doc /* Motor is accelerating to operating speed. */
			}

			state running {
				doc /* Motor is operating at steady state. */
			}

			state stopping {
				doc /* Motor is decelerating. */
			}

			state faulted {
				doc /* Motor has encountered a fault. */
			}

			transition stopped_to_starting
				first stopped
				accept startSignal
				then starting;

			transition starting_to_running
				first starting
				accept speedReached
				then running;

			transition running_to_stopping
				first running
				accept stopSignal
				then stopping;

			transition stopping_to_stopped
				first stopping
				accept speedZero
				then stopped;

			transition running_to_faulted
				first running
				accept faultDetected
				then faulted;

			transition faulted_to_stopped
				first faulted
				accept faultCleared
				then stopped;
		}

		part def ElectricMotor {
			attribute ratedPower : PowerValue;
			attribute currentPower : PowerValue;
			attribute rotationalSpeed : RotationalSpeedValue;
			attribute motorEfficiency : EfficiencyValue;
			attribute outputTorque : TorqueValue;

			port powerInput : PowerPort;

			exhibit state motorStates : MotorStates;
		}

		part def Impeller {
			attribute diameter : LengthValue;
			attribute numberOfBlades : Integer;
			attribute rotationalSpeed : RotationalSpeedValue;
			attribute material : String;
			attribute bladeAngle : Real;

			calc hydraulicPower {
				in flowRate : VolumeFlowRateValue;
				in pressureRise : PressureValue;
				return power : PowerValue = flowRate * pressureRise;
			}
		}

		part def PumpCasing {
			attribute inletDiameter : LengthValue;
			attribute outletDiameter : LengthValue;
			attribute material : String;
			attribute maxPressureRating : PressureValue;
			attribute volumetricCapacity : VolumeValue;

			port fluidInletPort : FluidInPort;
			port fluidOutletPort : FluidOutPort;
		}

		part def MagneticBearingAssembly {
			doc /*
			 * Magnetic bearings eliminate mechanical contact and seals,
			 * enabling glandless operation with no leakage.
			 */
			attribute bearingType : String = "Active Magnetic Bearing";
			attribute maxRadialLoad : ForceValue;
			attribute maxAxialLoad : ForceValue;
			attribute operatingTemperature : ThermodynamicTemperatureValue;
			attribute powerConsumption : PowerValue;
		}

		part def FlowSensor {
			attribute measuredFlowRate : VolumeFlowRateValue;
			attribute accuracy : Real;
			attribute responseTime : TimeValue;

			port sensingPort : FluidInPort;
		}

		part def PressureSensor {
			attribute measuredPressure : PressureValue;
			attribute accuracy : Real;
			attribute responseTime : TimeValue;

			port sensingPort : FluidInPort;
		}

		part def TemperatureSensor {
			attribute measuredTemperature : ThermodynamicTemperatureValue;
			attribute accuracy : Real;
			attribute responseTime : TimeValue;
		}

		part def PumpController {
			attribute targetFlowRate : VolumeFlowRateValue;
			attribute currentFlowRate : VolumeFlowRateValue;
			attribute targetSpeed : RotationalSpeedValue;
			attribute currentSpeed : RotationalSpeedValue;
			attribute controlMode : String;

			action controlSpeed {
				in targetFlow : VolumeFlowRateValue;
				in actualFlow : VolumeFlowRateValue;
				out speedCommand : RotationalSpeedValue;
			}

			action monitorPerformance {
				in flowRate : VolumeFlowRateValue;
				in pressure : PressureValue;
				in power : PowerValue;
				out efficiency : EfficiencyValue;
			}
		}

		state def PumpOperatingStates {
			entry; then idle;

			state idle {
				doc /* Pump is powered but not circulating fluid. */
			}

			state priming {
				doc /* Pump is filling with fluid and purging air. */
			}

			state normalOperation {
				doc /* Pump is operating at design conditions. */
				entry action maintainFlow;
			}

			state highDemand {
				doc /* Pump is operating at increased capacity. */
				entry action increaseSpeed;
			}

			state lowDemand {
				doc /* Pump is operating at reduced capacity. */
				entry action decreaseSpeed;
			}

			state cavitation {
				doc /* Pump has detected cavitation conditions. */
				entry action reducePressure;
			}

			state shutdown {
				doc /* Pump is shutting down. */
				entry action rampDown;
			}

			state fault {
				doc /* Pump has encountered a fault. */
				entry action emergencyStop;
			}

			transition idle_to_priming
				first idle
				accept startCommand
				then priming;

			transition priming_to_normal
				first priming
				accept primingComplete
				then normalOperation;

			transition normal_to_high
				first normalOperation
				accept demandIncrease
				then highDemand;

			transition high_to_normal
				first highDemand
				accept demandNormal
				then normalOperation;

			transition normal_to_low
				first normalOperation
				accept demandDecrease
				then lowDemand;

			transition low_to_normal
				first lowDemand
				accept demandNormal
				then normalOperation;

			transition normal_to_cavitation
				first normalOperation
				accept cavitationDetected
				then cavitation;

			transition cavitation_to_normal
				first cavitation
				accept cavitationCleared
				then normalOperation;

			transition to_shutdown
				first normalOperation
				accept stopCommand
				then shutdown;

			transition shutdown_to_idle
				first shutdown
				accept shutdownComplete
				then idle;

			transition to_fault
				first normalOperation
				accept faultCondition
				then fault;

			transition fault_to_idle
				first fault
				accept faultCleared
				then idle;
		}

		action def CirculateFluid {
			doc /*
			 * Primary action to circulate fluid through the pump.
			 */
			in fluidIn : Fluid;
			out fluidOut : Fluid;
			in requiredPressureRise : PressureValue;
			in requiredFlowRate : VolumeFlowRateValue;

			action drawFluid {
				doc /* Draw fluid into pump inlet. */
			}

			action accelerateFluid {
				doc /* Impeller accelerates fluid and increases pressure. */
			}

			action dischargeFluid {
				doc /* Discharge pressurized fluid through outlet. */
			}

			succession drawFluid then accelerateFluid then dischargeFluid;
		}

		part def HighEfficiencyGlandlessCirculatingPump {
			doc /*
			 * High efficiency glandless circulating pump using magnetic bearings
			 * to eliminate shaft seals and prevent fluid leakage. Designed for
			 * continuous operation with minimal maintenance requirements.
			 */

			attribute overallEfficiency : EfficiencyValue;
			attribute currentFlowRate : VolumeFlowRateValue;
			attribute pressureRise : PressureValue;
			attribute powerConsumption : PowerValue;
			attribute isGlandless : Boolean = true;
			attribute operatingSpeed : RotationalSpeedValue;
			attribute maxFlowRate : VolumeFlowRateValue;
			attribute maxPressureRise : PressureValue;

			port inletPort : FluidInPort;
			port outletPort : FluidOutPort;
			port electricalPort : PowerPort;

			part motor : ElectricMotor {
				attribute :>> ratedPower = 3000.0[W];
				attribute :>> motorEfficiency = 0.93;
			}

			part impeller : Impeller {
				attribute :>> diameter = 0.12[m];
				attribute :>> numberOfBlades = 5;
				attribute :>> material = "Stainless Steel 316L";
				attribute :>> bladeAngle = 25.0;
			}

			part casing : PumpCasing {
				attribute :>> inletDiameter = 0.05[m];
				attribute :>> outletDiameter = 0.05[m];
				attribute :>> material = "Stainless Steel 316L";
				attribute :>> maxPressureRating = 1500000.0[Pa];
			}

			part magneticBearings : MagneticBearingAssembly {
				attribute :>> maxRadialLoad = 800.0[N];
				attribute :>> maxAxialLoad = 400.0[N];
				attribute :>> powerConsumption = 50.0[W];
			}

			part controller : PumpController {
				attribute :>> targetFlowRate = 0.04;
				attribute :>> controlMode = "Variable Speed";
			}

			part inletFlowSensor : FlowSensor {
				attribute :>> accuracy = 0.015;
				attribute :>> responseTime = 0.5[s];
			}

			part outletPressureSensor : PressureSensor {
				attribute :>> accuracy = 0.01;
				attribute :>> responseTime = 0.3[s];
			}

			part temperatureSensor : TemperatureSensor {
				attribute :>> accuracy = 0.5;
				attribute :>> responseTime = 1.0[s];
			}

			connection casingInlet connect casing.fluidInletPort to inletPort;
			connection casingOutlet connect casing.fluidOutletPort to outletPort;
			connection motorPower connect motor.powerInput to electricalPort;

			bind impeller.rotationalSpeed = motor.rotationalSpeed;
			bind impeller.rotationalSpeed = operatingSpeed;

			calc efficiency {
				in flowRate : VolumeFlowRateValue = currentFlowRate;
				in deltaP : PressureValue = pressureRise;
				in power : PowerValue = powerConsumption;
				return eff : EfficiencyValue = (flowRate * deltaP) / power;
			}

			exhibit state operatingStates : PumpOperatingStates;

			perform action circulateFluid : CirculateFluid {
				in :>> fluidIn = inletPort.fluidIn;
				out :>> fluidOut = outletPort.fluidOut;
				in :>> requiredPressureRise = pressureRise;
				in :>> requiredFlowRate = currentFlowRate;
			}
		}

		part def FluidReservoir {
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			attribute fluidType : String;

			port outletPort : FluidOutPort;
		}

		part def HeatExchanger {
			attribute coolingCapacity : PowerValue;
			attribute inletTemperature : ThermodynamicTemperatureValue;
			attribute outletTemperature : ThermodynamicTemperatureValue;

			port primaryInlet : FluidInPort;
			port primaryOutlet : FluidOutPort;
		}

		requirement def HighEfficiencyRequirement {
			doc /*
			 * The pump must maintain high hydraulic efficiency
			 * across its operating range.
			 */
			attribute requiredEfficiency : EfficiencyValue;
			require constraint { requiredEfficiency >= 0.85 }
		}

		requirement def GlandlessDesignRequirement {
			doc /*
			 * The pump must be glandless (sealless) to eliminate
			 * fluid leakage and reduce maintenance.
			 */
			attribute hasGland : Boolean;
			require constraint { hasGland == false }
		}

		requirement def FlowRateRequirement {
			doc /*
			 * The pump must deliver the specified flow rate range.
			 */
			attribute minFlowRate : VolumeFlowRateValue;
			attribute maxFlowRate : VolumeFlowRateValue;
			attribute nominalFlowRate : VolumeFlowRateValue;

			require constraint flowRateRange {
				minFlowRate >= 0.0 and maxFlowRate <= 0.1
			}
		}

		requirement def PressureRiseRequirement {
			doc /*
			 * The pump must generate the required pressure rise.
			 */
			attribute minPressureRise : PressureValue;
			attribute maxPressureRise : PressureValue;

			require constraint pressureRange {
				minPressureRise >= 50000.0[Pa] and maxPressureRise <= 200000.0[Pa]
			}
		}

		requirement def PowerConsumptionRequirement {
			doc /*
			 * The pump power consumption must not exceed limits.
			 */
			attribute maxPowerConsumption : PowerValue;

			require constraint powerLimit {
				maxPowerConsumption <= 5000.0[W]
			}
		}

		requirement def ContinuousOperationRequirement {
			doc /*
			 * The pump must support continuous operation.
			 */
			attribute minOperatingTime : TimeValue;
			attribute continuousOperation : Boolean;

			require constraint {
				continuousOperation == true and minOperatingTime >= 8760.0[h]
			}
		}
	}

	package Usages {
		part pumpingSubsystem {
			doc /*
			 * Complete pumping subsystem with high efficiency glandless
			 * circulating pump, reservoir, heat exchanger, and control system.
			 */

			requirement highEfficiencyReq : Definitions::HighEfficiencyRequirement {
				attribute :>> requiredEfficiency = 0.87;
			}

			requirement glandlessReq : Definitions::GlandlessDesignRequirement {
				attribute :>> hasGland = false;
			}

			requirement flowRateReq : Definitions::FlowRateRequirement {
				attribute :>> minFlowRate = 0.01;
				attribute :>> maxFlowRate = 0.08;
				attribute :>> nominalFlowRate = 0.04;
			}

			requirement pressureReq : Definitions::PressureRiseRequirement {
				attribute :>> minPressureRise = 80000.0[Pa];
				attribute :>> maxPressureRise = 150000.0[Pa];
			}

			requirement powerReq : Definitions::PowerConsumptionRequirement {
				attribute :>> maxPowerConsumption = 4000.0[W];
			}

			requirement continuousOpReq : Definitions::ContinuousOperationRequirement {
				attribute :>> minOperatingTime = 8760.0[h];
				attribute :>> continuousOperation = true;
			}

			part mainPump : Definitions::HighEfficiencyGlandlessCirculatingPump {
				attribute :>> overallEfficiency = 0.87;
				attribute :>> currentFlowRate = 0.04;
				attribute :>> pressureRise = 120000.0[Pa];
				attribute :>> powerConsumption = 5517.24[W];
				attribute :>> operatingSpeed = 2900.0;
				attribute :>> maxFlowRate = 0.08;
				attribute :>> maxPressureRise = 150000.0[Pa];
			}

			part reservoir : Definitions::FluidReservoir {
				attribute :>> capacity = 0.5[m^3];
				attribute :>> currentLevel = 0.4[m^3];
				attribute :>> fluidType = "Water-Glycol Mixture";
			}

			part heatExchanger : Definitions::HeatExchanger {
				attribute :>> coolingCapacity = 2000.0[W];
				attribute :>> inletTemperature = 323.15[K];
				attribute :>> outletTemperature = 303.15[K];
			}

			item circulatingFluid : Definitions::Fluid {
				attribute :>> temperature = 303.15[K];
				attribute :>> pressure = 101325.0[Pa];
				attribute :>> density = 1020.0[kg];
				attribute :>> viscosity = 0.0012;
			}

			flow of circulatingFluid : Definitions::Fluid
				from reservoir.outletPort.fluidOut
				to mainPump.inletPort.fluidIn;

			flow of circulatingFluid : Definitions::Fluid
				from mainPump.outletPort.fluidOut
				to heatExchanger.primaryInlet.fluidIn;

			flow of circulatingFluid : Definitions::Fluid
				from heatExchanger.primaryOutlet.fluidOut
				to reservoir.outletPort.fluidIn;

			assert constraint efficiencyAssertion {
				mainPump.overallEfficiency >= highEfficiencyReq.requiredEfficiency
			}

			assert constraint glandlessAssertion {
				mainPump.isGlandless == !glandlessReq.hasGland
			}

			assert constraint flowRateAssertion {
				mainPump.currentFlowRate >= flowRateReq.minFlowRate and
				mainPump.currentFlowRate <= flowRateReq.maxFlowRate
			}

			assert constraint pressureAssertion {
				mainPump.pressureRise >= pressureReq.minPressureRise and
				mainPump.pressureRise <= pressureReq.maxPressureRise
			}

			assert constraint powerAssertion {
				mainPump.powerConsumption <= powerReq.maxPowerConsumption
			}

			satisfy highEfficiencyReq by mainPump;
			satisfy glandlessReq by mainPump;
			satisfy flowRateReq by mainPump;
			satisfy pressureReq by mainPump;
			satisfy powerReq by mainPump;
			satisfy continuousOpReq by mainPump;
		}
	}
}
