package 'Pumping Subsystem Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		item def Fluid {
			attribute temperature : TemperatureValue;
			attribute pressure : PressureValue;
			attribute flowRate : VolumeFlowRateValue;
			attribute density : Real;
			attribute viscosity : Real;
		}
		
		port def FluidPort {
			out item fluidOut : Fluid;
			in item fluidIn : Fluid;
		}
		
		port def PowerPort {
			in attribute voltage : Real;
			in attribute current : Real;
			in attribute frequency : Real;
		}
		
		port def ControlPort {
			in attribute speedCommand : Real;
			out attribute actualSpeed : Real;
			out attribute status : String;
		}
		
		port def ShaftConnection {
			attribute torque : Real;
			attribute speed : Real;
		}
		
		port def SensorDataPort {
			out attribute value : Real;
			out attribute timestamp : Real;
		}
		
		part def Motor {
			attribute ratedPower : PowerValue;
			attribute currentSpeed : Real;
			attribute efficiency : Real;
			attribute operatingVoltage : Real;
			
			port powerIn : PowerPort;
			port shaftOut : ShaftConnection;
			
			perform action runMotor : RunMotor;
		}
		
		part def Impeller {
			attribute diameter : LengthValue;
			attribute bladeCount : Integer;
			attribute rotationalSpeed : Real;
			attribute headPressure : PressureValue;
			
			port shaftIn : ~ShaftConnection;
			
			perform action rotateImpeller : RotateImpeller;
		}
		
		part def HousingCasing {
			attribute material : String;
			attribute maxPressureRating : PressureValue;
			attribute inletDiameter : LengthValue;
			attribute outletDiameter : LengthValue;
			
			port inletPort : ~FluidPort;
			port outletPort : FluidPort;
		}
		
		part def CirculatorPump {
			attribute maxFlowRate : VolumeFlowRateValue;
			attribute maxPressure : PressureValue;
			attribute operatingTemperatureMin : TemperatureValue;
			attribute operatingTemperatureMax : TemperatureValue;
			attribute currentFlowRate : VolumeFlowRateValue;
			attribute motorSpeed : Real;
			attribute minimumSpeed : Real;
			attribute inletPressure : PressureValue;
			attribute minimumPressure : PressureValue;
			attribute flowRate : VolumeFlowRateValue;
			attribute nominalFlowRate : VolumeFlowRateValue;
			attribute motorTemperature : TemperatureValue;
			attribute maxTemperature : TemperatureValue;
			
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			port powerPort : PowerPort;
			port controlPort : ControlPort;
			
			part motor : Motor;
			part impeller : Impeller;
			part housing : HousingCasing;
			
			connect motor.shaftOut to impeller.shaftIn;
			bind housing.inletPort = fluidInPort;
			bind housing.outletPort = fluidOutPort;
			
			perform action pumpFluid : PumpFluid;
			exhibit state pumpState : PumpOperatingStates;
		}
		
		part def Reservoir {
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			attribute minLevel : VolumeValue;
			
			port outletPort : FluidPort;
			port inletPort : ~FluidPort;
			
			item storedFluid : Fluid;
		}
		
		part def PipingNetwork {
			attribute length : LengthValue;
			attribute diameter : LengthValue;
			attribute roughness : Real;
			attribute pressureDrop : PressureValue;
			
			port inPort : ~FluidPort;
			port outPort : FluidPort;
		}
		
		part def HeatExchanger {
			attribute heatTransferRate : PowerValue;
			attribute effectiveArea : AreaValue;
			attribute coolingCapacity : PowerValue;
			
			port primaryInPort : ~FluidPort;
			port primaryOutPort : FluidPort;
			
			perform action transferHeat : TransferHeat;
		}
		
		part def FlowSensor {
			attribute measuredFlowRate : VolumeFlowRateValue;
			attribute accuracy : Real;
			
			port sensePort : ~FluidPort;
			port dataOut : SensorDataPort;
		}
		
		part def PressureSensor {
			attribute measuredPressure : PressureValue;
			attribute accuracy : Real;
			
			port sensePort : ~FluidPort;
			port dataOut : SensorDataPort;
		}
		
		part def TemperatureSensor {
			attribute measuredTemperature : TemperatureValue;
			attribute accuracy : Real;
			
			port sensePort : ~FluidPort;
			port dataOut : SensorDataPort;
		}
		
		action def RunMotor {
			in powerInput : PowerValue;
			out shaftTorque : Real;
			out shaftSpeed : Real;
			
			assert constraint {
				powerInput > 0.0 implies shaftSpeed > 0.0
			}
		}
		
		action def RotateImpeller {
			in torque : Real;
			in speed : Real;
			out pressureIncrease : PressureValue;
			out flowGenerated : VolumeFlowRateValue;
			
			assert constraint {
				speed > 0.0 implies flowGenerated > 0.0
			}
		}
		
		action def PumpFluid {
			in fluidIn : Fluid;
			out fluidOut : Fluid;
			
			first start;
			then action drawFluid {
				in fluid = fluidIn;
				out drawnFluid : Fluid;
			}
			then action accelerateFluid {
				in inputFluid = drawFluid.drawnFluid;
				out acceleratedFluid : Fluid;
			}
			then action dischargeFluid {
				in acceleratedFluid = accelerateFluid.acceleratedFluid;
				out fluid = fluidOut;
			}
			then done;
		}
		
		action def TransferHeat {
			in fluidIn : Fluid;
			out fluidOut : Fluid;
			
			attribute heatRemoved : PowerValue;
			
			assert constraint {
				fluidOut.temperature < fluidIn.temperature
			}
		}
		
		action def MonitorPumpOperation {
			out currentFlowRate : VolumeFlowRateValue;
			out currentPressure : PressureValue;
			out motorTemperature : TemperatureValue;
			out motorSpeed : Real;
		}
		
		action def ControlPumpSpeed {
			in targetFlowRate : VolumeFlowRateValue;
			in actualFlowRate : VolumeFlowRateValue;
			out speedCommand : Real;
			
			first start;
			then merge controlLoop;
			then action measureFlow : MonitorPumpOperation {
				out flowRate : VolumeFlowRateValue;
			}
			then decide;
				if measureFlow.flowRate < targetFlowRate then increaseSpeed;
				if measureFlow.flowRate > targetFlowRate then decreaseSpeed;
				if measureFlow.flowRate == targetFlowRate then maintainSpeed;
			
			action increaseSpeed {
				out newSpeed : Real;
			}
			then controlLoop;
			
			action decreaseSpeed {
				out newSpeed : Real;
			}
			then controlLoop;
			
			action maintainSpeed {
				out newSpeed : Real;
			}
			then controlLoop;
		}
		
		state def PumpOperatingStates {
			entry; then idle;
			
			state idle {
				entry action initializeSystem;
			}
			
			state starting {
				entry action primePump;
				entry action startMotor;
			}
			
			state running {
				state normalOperation {
					entry action maintainFlow;
				}
				state reducedFlow {
					entry action adjustSpeed;
				}
				state highTemperature {
					entry action activateCooling;
				}
				
				transition normal_to_reduced
					first normalOperation
					if flowRate < nominalFlowRate * 0.5
					then reducedFlow;
				
				transition reduced_to_normal
					first reducedFlow
					if flowRate >= nominalFlowRate * 0.5
					then normalOperation;
				
				transition normal_to_highTemp
					first normalOperation
					if motorTemperature > maxTemperature * 0.9
					then highTemperature;
				
				transition highTemp_to_normal
					first highTemperature
					if motorTemperature < maxTemperature * 0.8
					then normalOperation;
			}
			
			state stopping {
				entry action shutdownMotor;
				entry action drainSystem;
			}
			
			state fault {
				entry action triggerAlarm;
				entry action emergencyShutdown;
			}
			
			transition idle_to_starting
				first idle
				if motorSpeed == 0.0
				then starting;
			
			transition starting_to_running
				first starting
				if motorSpeed >= minimumSpeed & inletPressure > minimumPressure
				then running;
			
			transition running_to_stopping
				first running
				if motorSpeed > 0.0
				then stopping;
			
			transition stopping_to_idle
				first stopping
				if motorSpeed == 0.0
				then idle;
		}
		
		requirement def PumpPerformanceRequirement {
			doc /*
			 * The circulator pump shall maintain specified flow rate
			 * and pressure within operating conditions.
			 */
			
			subject pump : CirculatorPump;
			
			require constraint flowRateRequirement {
				pump.maxFlowRate >= 100.0
			}
			
			require constraint pressureRequirement {
				pump.maxPressure >= 5.0
			}
			
			require constraint efficiencyRequirement {
				pump.motor.efficiency >= 0.85
			}
		}
		
		requirement def SystemReliabilityRequirement {
			doc /*
			 * The pumping subsystem shall operate continuously
			 * for minimum specified duration without failure.
			 */
			
			subject pumpingSubsystem : PumpingSubsystem;
			
			require constraint continuousOperationRequirement {
				doc /* Minimum 10000 hours continuous operation */
			}
			
			require constraint maintenanceIntervalRequirement {
				doc /* Maintenance interval shall be at least 2000 hours */
			}
		}
		
		requirement def TemperatureOperatingRequirement {
			doc /*
			 * The pump shall operate within specified temperature range.
			 */
			
			subject pump : CirculatorPump;
			
			require constraint temperatureRangeRequirement {
				pump.operatingTemperatureMin >= -10.0 &
				pump.operatingTemperatureMax <= 120.0
			}
		}
		
		requirement def SafetyRequirement {
			doc /*
			 * The pumping subsystem shall include safety features
			 * to prevent damage and ensure safe operation.
			 */
			
			subject pumpingSubsystem : PumpingSubsystem;
			
			require constraint dryRunProtection {
				doc /* Pump shall not operate when inlet pressure is below minimum */
			}
			
			require constraint overTemperatureProtection {
				doc /* Pump shall shut down when temperature exceeds maximum */
			}
			
			require constraint overpressureProtection {
				doc /* System shall include pressure relief when pressure exceeds maximum */
			}
		}
		
		part def PumpingSubsystem {
			part sourceReservoir : Reservoir;
			part supplyPiping : PipingNetwork;
			part inletPressureSensor : PressureSensor;
			part circulatorPump : CirculatorPump;
			part dischargePiping : PipingNetwork;
			part outletFlowSensor : FlowSensor;
			part heatExchanger : HeatExchanger;
			part outletTemperatureSensor : TemperatureSensor;
			part returnPiping : PipingNetwork;
		}
	}
	
	package Usages {
		import Definitions::*;
		
		part pumpingSubsystem : PumpingSubsystem {
			
			part :>> sourceReservoir {
				attribute :>> capacity = 500.0;
				attribute :>> currentLevel = 450.0;
				attribute :>> minLevel = 50.0;
				
				item :>> storedFluid {
					attribute :>> temperature = 20.0;
					attribute :>> pressure = 1.0;
					attribute :>> flowRate = 0.0;
					attribute :>> density = 1000.0;
					attribute :>> viscosity = 0.001;
				}
			}
			
			part :>> supplyPiping {
				attribute :>> length = 5.0;
				attribute :>> diameter = 0.05;
				attribute :>> roughness = 0.0015;
				attribute :>> pressureDrop = 0.2;
			}
			
			flow of fluid : Fluid
				from sourceReservoir.outletPort.fluidOut 
				to supplyPiping.inPort.fluidIn;
			
			part :>> inletPressureSensor {
				attribute :>> measuredPressure = 1.0;
				attribute :>> accuracy = 0.01;
			}
			
			flow of fluid : Fluid
				from supplyPiping.outPort.fluidOut
				to inletPressureSensor.sensePort.fluidIn;
			
			part :>> circulatorPump {
				attribute :>> maxFlowRate = 150.0;
				attribute :>> maxPressure = 8.0;
				attribute :>> operatingTemperatureMin = -10.0;
				attribute :>> operatingTemperatureMax = 120.0;
				attribute :>> currentFlowRate = 120.0;
				attribute :>> motorSpeed = 1450.0;
				attribute :>> minimumSpeed = 500.0;
				attribute :>> inletPressure = 1.0;
				attribute :>> minimumPressure = 0.5;
				attribute :>> flowRate = 120.0;
				attribute :>> nominalFlowRate = 120.0;
				attribute :>> motorTemperature = 60.0;
				attribute :>> maxTemperature = 100.0;
				
				part :>> motor {
					attribute :>> ratedPower = 2200.0;
					attribute :>> currentSpeed = 1450.0;
					attribute :>> efficiency = 0.88;
					attribute :>> operatingVoltage = 230.0;
				}
				
				part :>> impeller {
					attribute :>> diameter = 0.15;
					attribute :>> bladeCount = 6;
					attribute :>> rotationalSpeed = 1450.0;
					attribute :>> headPressure = 6.5;
				}
				
				part :>> housing {
					attribute :>> material = "Cast Iron";
					attribute :>> maxPressureRating = 10.0;
					attribute :>> inletDiameter = 0.05;
					attribute :>> outletDiameter = 0.05;
				}
				
				bind housing.inletPort = fluidInPort;
				bind housing.outletPort = fluidOutPort;
				
				perform action :>> pumpFluid {
					in fluidIn = fluidInPort.fluidIn;
					out fluidOut = fluidOutPort.fluidOut;
				}
				
				exhibit state :>> pumpState;
			}
			
			flow of fluid : Fluid
				from inletPressureSensor.sensePort.fluidOut
				to circulatorPump.fluidInPort.fluidIn;
			
			part :>> dischargePiping {
				attribute :>> length = 8.0;
				attribute :>> diameter = 0.05;
				attribute :>> roughness = 0.0015;
				attribute :>> pressureDrop = 0.3;
			}
			
			flow of fluid : Fluid
				from circulatorPump.fluidOutPort.fluidOut 
				to dischargePiping.inPort.fluidIn;
			
			part :>> outletFlowSensor {
				attribute :>> measuredFlowRate = 120.0;
				attribute :>> accuracy = 0.02;
			}
			
			flow of fluid : Fluid
				from dischargePiping.outPort.fluidOut
				to outletFlowSensor.sensePort.fluidIn;
			
			part :>> heatExchanger {
				attribute :>> heatTransferRate = 15000.0;
				attribute :>> effectiveArea = 2.5;
				attribute :>> coolingCapacity = 18000.0;
				
				perform action :>> transferHeat {
					in fluidIn = primaryInPort.fluidIn;
					out fluidOut = primaryOutPort.fluidOut;
				}
			}
			
			flow of fluid : Fluid
				from outletFlowSensor.sensePort.fluidOut
				to heatExchanger.primaryInPort.fluidIn;
			
			part :>> outletTemperatureSensor {
				attribute :>> measuredTemperature = 18.0;
				attribute :>> accuracy = 0.5;
			}
			
			flow of fluid : Fluid
				from heatExchanger.primaryOutPort.fluidOut
				to outletTemperatureSensor.sensePort.fluidIn;
			
			part :>> returnPiping {
				attribute :>> length = 6.0;
				attribute :>> diameter = 0.05;
				attribute :>> roughness = 0.0015;
				attribute :>> pressureDrop = 0.25;
			}
			
			flow of fluid : Fluid
				from outletTemperatureSensor.sensePort.fluidOut
				to returnPiping.inPort.fluidIn;
			
			flow of fluid : Fluid
				from returnPiping.outPort.fluidOut 
				to sourceReservoir.inletPort.fluidIn;
			
			perform action controlPump : ControlPumpSpeed {
				in targetFlowRate = 120.0;
				in actualFlowRate = outletFlowSensor.measuredFlowRate;
				out speedCommand;
			}
			
			assert constraint systemPressureBalance {
				circulatorPump.impeller.headPressure >= 
					supplyPiping.pressureDrop + 
					dischargePiping.pressureDrop + 
					returnPiping.pressureDrop
			}
			
			assert constraint flowContinuity {
				circulatorPump.currentFlowRate == outletFlowSensor.measuredFlowRate
			}
			
			assert constraint temperatureControl {
				outletTemperatureSensor.measuredTemperature < 
					circulatorPump.operatingTemperatureMax
			}
			
			satisfy pumpPerformanceReq : PumpPerformanceRequirement {
				subject pump = circulatorPump;
			}
			
			satisfy systemReliabilityReq : SystemReliabilityRequirement {
				subject pumpingSubsystem = pumpingSubsystem;
			}
			
			satisfy temperatureReq : TemperatureOperatingRequirement {
				subject pump = circulatorPump;
			}
			
			satisfy safetyReq : SafetyRequirement {
				subject pumpingSubsystem = pumpingSubsystem;
			}
		}
	}
}
