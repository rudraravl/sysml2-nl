package 'Hydraulic Power Unit System' {
	private import ScalarValues::*;

	package Definitions {
		value type PressureValue :> Real;
		value type TemperatureValue :> Real;
		value type FlowRateValue :> Real;
		value type RotationalSpeedValue :> Real;
		value type VoltageValue :> Real;
		value type CurrentValue :> Real;
		value type VolumeValue :> Real;

		item def HydraulicFluid;

		attribute def PrimeCommand;
		attribute def StopCommand;
		attribute def ResetFaultCommand;
		attribute def PumpPrimedSignal;
		attribute def ShutdownCompleteSignal;
		attribute def HighPressureAlarm;
		attribute def LowFlowAlarm;
		attribute def OverTempAlarm;
		attribute def CavitationAlarm;
		attribute def MotorOverloadAlarm;
		attribute def MechanicalDamageAlarm;

		port def FluidPort {
			out item fluid : HydraulicFluid;
		}
		port def PressureSignalPort {
			out pressure : PressureValue;
		}
		port def TemperatureSignalPort {
			out temperature : TemperatureValue;
		}
		port def FlowSignalPort {
			out flowRate : FlowRateValue;
		}
		port def ElectricalPort {
			in voltage : VoltageValue;
			in current : CurrentValue;
			in phases : Integer;
		}
		port def DrivePort {
			in speed : RotationalSpeedValue;
		}

		part def Reservoir {
			attribute capacity : VolumeValue;
			attribute fluidLevel : Real;
			port fluidOut : FluidPort;
			port returnIn : ~FluidPort;
			item storedFluid : HydraulicFluid;
		}

		part def ElectricMotor {
			attribute powerRating : Real;
			attribute nominalSpeed : RotationalSpeedValue;
			attribute isOverloaded : Boolean;
			port electricalIn : ElectricalPort;
			port driveOut : ~DrivePort;
		}

		part def RotaryVanePump {
			attribute displacement : VolumeValue;
			attribute eccentricity : Real;
			attribute isCavitating : Boolean;
			port fluidIn : ~FluidPort;
			port fluidOut : FluidPort;
			port driveIn : DrivePort;
			part rotor {
				attribute radius : Real;
				attribute isDamaged : Boolean;
			}
			part vanes {
				attribute material : String = "Carbon Composite";
				attribute count : Integer;
			}
		}

		part def CheckValve {
			attribute crackingPressure : PressureValue;
			port fluidIn : ~FluidPort;
			port fluidOut : FluidPort;
		}

		part def InletFilter {
			attribute micronRating : Real;
			port fluidIn : ~FluidPort;
			port fluidOut : FluidPort;
		}

		part def OutletFilter {
			attribute micronRating : Real;
			port fluidIn : ~FluidPort;
			port fluidOut : FluidPort;
		}

		part def PressureReliefValve {
			attribute setPressure : PressureValue;
			attribute isOpen : Boolean;
			attribute springPreload : PressureValue;
			port inletPort : ~FluidPort;
			port outletPort : FluidPort;
		}

		part def PressureSensor {
			attribute rangeMax : PressureValue;
			port fluidTap : ~FluidPort;
			port signalOut : PressureSignalPort;
		}

		part def TemperatureSensor {
			attribute rangeMax : TemperatureValue;
			port fluidTap : ~FluidPort;
			port signalOut : TemperatureSignalPort;
		}

		part def FlowMeter {
			attribute rangeMax : FlowRateValue;
			port fluidIn : ~FluidPort;
			port fluidOut : FluidPort;
			port signalOut : FlowSignalPort;
		}

		part def HPUController {
			exhibit state controllerStates : ControllerStates;
		}

		action def StartMotor;
		action def StopMotor;
		action def ProvideHydraulicPower;
		action def MonitorPressure {
			in inletPressure : PressureValue;
			in outletPressure : PressureValue;
		}
		action def MonitorFlow {
			in flowRate : FlowRateValue;
		}
		action def MonitorTemperature {
			in temp : TemperatureValue;
		}
		action def DetectCavitation;
		action def DetectMotorOverload;
		action def DetectMechanicalDamage;

		state def HPUStates;
		state def ControllerStates;

		requirement def PressureReliefRequirement {
			doc
			/*
			 * The system shall include a pressure relief valve that diverts
			 * excess fluid back to the reservoir when system pressure exceeds
			 * the safe operating threshold.
			 */
		}
		requirement def FlowMonitoringRequirement {
			doc
			/*
			 * The system shall monitor output flow rate and raise a low
			 * flow alarm if the flow falls below the minimum threshold.
			 */
		}
		requirement def OverTempRequirement {
			doc
			/*
			 * The system shall monitor fluid temperature and raise an
			 * over-temperature alarm if temperature exceeds the maximum
			 * operating limit.
			 */
		}
		requirement def FaultDetectionRequirement {
			doc
			/*
			 * The system shall detect cavitation, motor overload, and
			 * mechanical damage faults and report them to the controller.
			 */
		}

		part def HydraulicPowerUnit {
			attribute maxOperatingPressure : PressureValue;
			attribute maxOperatingTemperature : TemperatureValue;
			attribute minOutputFlow : FlowRateValue;

			port dischargePort : FluidPort;

			part reservoir : Reservoir;
			part electricMotor : ElectricMotor;
			part rotaryVanePump : RotaryVanePump;
			part checkValve : CheckValve;
			part inletFilter : InletFilter;
			part outletFilter : OutletFilter;
			part pressureReliefValve : PressureReliefValve;
			part inletPressureSensor : PressureSensor;
			part dischargePressureSensor : PressureSensor;
			part temperatureSensor : TemperatureSensor;
			part flowMeter : FlowMeter;
			part controller : HPUController;

			action startMotor : StartMotor;
			action stopMotor : StopMotor;
			action provideHydraulicPower : ProvideHydraulicPower;
			action monitorPressure : MonitorPressure {
				in inletPressure = inletPressureSensor.signalOut.pressure;
				in outletPressure = dischargePressureSensor.signalOut.pressure;
			}
			action monitorFlow : MonitorFlow {
				in flowRate = flowMeter.signalOut.flowRate;
			}
			action monitorTemperature : MonitorTemperature {
				in temp = temperatureSensor.signalOut.temperature;
			}
			action detectCavitation : DetectCavitation;
			action detectMotorOverload : DetectMotorOverload;
			action detectMechanicalDamage : DetectMechanicalDamage;

			exhibit state hpuStates : HPUStates parallel {
				state operationalStates {
					entry; then idle;

					state idle;
					accept PrimeCommand
						then priming;

					state priming;
					accept PumpPrimedSignal
						then running;

					state running {
						entry startMotor;
						do provideHydraulicPower;
						do monitorPressure;
						do monitorFlow;
						do monitorTemperature;
						do detectCavitation;
						do detectMotorOverload;
						do detectMechanicalDamage;
						exit stopMotor;
					}
					accept StopCommand
						then shuttingDown;

					state shuttingDown;
					accept ShutdownCompleteSignal
						then idle;
				}

				state faultStates {
					entry; then noFault;

					state noFault;
					accept when dischargePressureSensor.signalOut.pressure > maxOperatingPressure
						do send new HighPressureAlarm() to controller
						then highPressureFault;
					accept when flowMeter.signalOut.flowRate < minOutputFlow
						do send new LowFlowAlarm() to controller
						then lowFlowFault;
					accept when temperatureSensor.signalOut.temperature > maxOperatingTemperature
						do send new OverTempAlarm() to controller
						then overTempFault;
					accept when rotaryVanePump.isCavitating
						do send new CavitationAlarm() to controller
						then cavitationFault;
					accept when electricMotor.isOverloaded
						do send new MotorOverloadAlarm() to controller
						then motorOverloadFault;
					accept when rotaryVanePump.rotor.isDamaged
						do send new MechanicalDamageAlarm() to controller
						then mechDamageFault;

					state highPressureFault;
					accept ResetFaultCommand
						then noFault;

					state lowFlowFault;
					accept ResetFaultCommand
						then noFault;

					state overTempFault;
					accept ResetFaultCommand
						then noFault;

					state cavitationFault;
					accept ResetFaultCommand
						then noFault;

					state motorOverloadFault;
					accept ResetFaultCommand
						then noFault;

					state mechDamageFault;
					accept ResetFaultCommand
						then noFault;
				}
			}

			flow of fluid : HydraulicFluid
				from reservoir.fluidOut.fluid to inletFilter.fluidIn.fluid;
			flow of fluid : HydraulicFluid
				from inletFilter.fluidOut.fluid to checkValve.fluidIn.fluid;
			flow of fluid : HydraulicFluid
				from checkValve.fluidOut.fluid to rotaryVanePump.fluidIn.fluid;
			flow of fluid : HydraulicFluid
				from rotaryVanePump.fluidOut.fluid to outletFilter.fluidIn.fluid;
			flow of fluid : HydraulicFluid
				from outletFilter.fluidOut.fluid to flowMeter.fluidIn.fluid;
			flow of fluid : HydraulicFluid
				from flowMeter.fluidOut.fluid to dischargePort.fluid;

			flow of reliefFluid : HydraulicFluid
				from rotaryVanePump.fluidOut.fluid to pressureReliefValve.inletPort.fluid;
			flow of reliefFluid : HydraulicFluid
				from pressureReliefValve.outletPort.fluid to reservoir.returnIn.fluid;

			flow of fluid : HydraulicFluid
				from inletFilter.fluidOut.fluid to inletPressureSensor.fluidTap.fluid;
			flow of fluid : HydraulicFluid
				from outletFilter.fluidOut.fluid to dischargePressureSensor.fluidTap.fluid;
			flow of fluid : HydraulicFluid
				from reservoir.fluidOut.fluid to temperatureSensor.fluidTap.fluid;

			connection electricMotor.driveOut to rotaryVanePump.driveIn;

			requirement pressureReliefReq : PressureReliefRequirement;
			requirement flowMonitoringReq : FlowMonitoringRequirement;
			requirement overTempReq : OverTempRequirement;
			requirement faultDetectionReq : FaultDetectionRequirement;

			satisfy pressureReliefReq by pressureReliefValve;
			satisfy flowMonitoringReq by flowMeter;
			satisfy overTempReq by temperatureSensor;
			satisfy faultDetectionReq by controller;
		}
	}

	package Usages {
		private import Definitions::*;
		part hpuInstance : HydraulicPowerUnit;
	}
}
