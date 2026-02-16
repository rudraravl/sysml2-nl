package 'Pumping Subsystem Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import NumericalFunctions::*;
	
	package Definitions {
		item def Fluid {
			attribute density : DensityValue;
			attribute viscosity : DynamicViscosityValue;
			attribute temperature : ThermodynamicTemperatureValue;
			attribute vaporPressure : PressureValue;
		}
		
		port def FluidPort {
			attribute pressure : PressureValue;
			attribute flowRate : VolumeFlowRateValue;
			out item fluid : Fluid;
		}
		
		attribute def PumpCharacteristics {
			attribute ratedFlowRate : VolumeFlowRateValue;
			attribute ratedHead : LengthValue;
			attribute maxPressure : PressureValue;
			attribute efficiency : Real;
			attribute powerRating : PowerValue;
			attribute impellerDiameter : LengthValue;
			attribute operatingSpeed : AngularVelocityValue;
			attribute npshRequired : LengthValue;
		}
		
		part def CentrifugalPump {
			port inletPort : ~FluidPort;
			port outletPort : FluidPort;
			
			attribute characteristics : PumpCharacteristics;
			attribute operatingFlowRate : VolumeFlowRateValue;
			attribute operatingHead : LengthValue;
			attribute currentEfficiency : Real;
			attribute powerConsumed : PowerValue;
			
			part impeller {
				attribute diameter : LengthValue;
				attribute rotationalSpeed : AngularVelocityValue;
				attribute bladeCount : Integer;
			}
			
			part volute {
				attribute inletArea : AreaValue;
				attribute outletArea : AreaValue;
			}
			
			part shaft {
				attribute diameter : LengthValue;
				attribute material : String;
				attribute maxTorque : TorqueValue;
			}
			
			part motor {
				attribute ratedPower : PowerValue;
				attribute voltage : ElectricPotentialValue;
				attribute current : ElectricCurrentValue;
				attribute motorEfficiency : Real;
			}
			
			constraint pumpPerformance {
				operatingFlowRate <= characteristics.ratedFlowRate
			}
			
			constraint pressureLimit {
				outletPort.pressure - inletPort.pressure <= characteristics.maxPressure
			}
			
			constraint powerBalance {
				powerConsumed <= motor.ratedPower
			}
		}
		
		part def PipingNetwork {
			port inletPort : ~FluidPort;
			port outletPort : FluidPort;
			
			attribute length : LengthValue;
			attribute diameter : LengthValue;
			attribute roughness : LengthValue;
			attribute frictionLoss : PressureValue;
			attribute minorLosses : PressureValue;
		}
		
		part def FluidReservoir {
			port outletPort : FluidPort;
			
			attribute capacity : VolumeValue;
			attribute currentLevel : LengthValue;
			attribute fluidStored : Fluid;
			attribute surfacePressure : PressureValue;
		}
		
		part def DischargeVessel {
			port inletPort : ~FluidPort;
			
			attribute capacity : VolumeValue;
			attribute currentLevel : LengthValue;
			attribute operatingPressure : PressureValue;
		}
		
		part def PressureSensor {
			attribute measuredPressure : PressureValue;
			attribute accuracy : Real;
			attribute range : PressureValue;
		}
		
		part def FlowMeter {
			attribute measuredFlowRate : VolumeFlowRateValue;
			attribute accuracy : Real;
			attribute range : VolumeFlowRateValue;
		}
		
		part def ControlValve {
			attribute position : Real;
			attribute maxFlowCoefficient : Real;
			attribute currentFlowCoefficient : Real;
		}
		
		action def StartCommand;
		action def StopCommand;
		
		state def PumpOperatingStates {
			in pumpRef : CentrifugalPump;
			
			entry; then idle;
			
			state idle {
				doc /* Pump is stopped and ready to start */
			}
			
			transition idle_to_starting
				first idle
				accept StartCommand
				then starting;
			
			state starting {
				doc /* Pump motor is accelerating to operating speed */
				entry assign pumpRef.motor.current := pumpRef.motor.ratedPower / pumpRef.motor.voltage;
			}
			
			transition starting_to_running
				first starting
				if pumpRef.impeller.rotationalSpeed >= 0.95 * pumpRef.characteristics.operatingSpeed
				then running;
			
			state running {
				doc /* Pump is operating normally */
				
				state normalOperation {
					doc /* Pump operating within design parameters */
				}
				
				state cavitation {
					doc /* Insufficient NPSH causing cavitation */
				}
				
				state overload {
					doc /* Pump operating beyond rated capacity */
				}
				
				transition to_cavitation
					first normalOperation
					if pumpRef.inletPort.pressure < pumpRef.characteristics.npshRequired
					then cavitation;
				
				transition to_overload
					first normalOperation
					if pumpRef.powerConsumed > 1.1 * pumpRef.characteristics.powerRating
					then overload;
				
				transition cavitation_recovery
					first cavitation
					if pumpRef.inletPort.pressure >= pumpRef.characteristics.npshRequired
					then normalOperation;
				
				transition overload_recovery
					first overload
					if pumpRef.powerConsumed <= pumpRef.characteristics.powerRating
					then normalOperation;
			}
			
			transition running_to_stopping
				first running
				accept StopCommand
				then stopping;
			
			state stopping {
				doc /* Pump motor is decelerating */
				entry assign pumpRef.motor.current := 0.0[A];
			}
			
			transition stopping_to_idle
				first stopping
				if pumpRef.impeller.rotationalSpeed <= 0.05 * pumpRef.characteristics.operatingSpeed
				then idle;
		}
		
		action def StartPump {
			in pump : CentrifugalPump;
			out status : String;
		}
		
		action def StopPump {
			in pump : CentrifugalPump;
			out status : String;
		}
		
		action def MonitorPumpPerformance {
			in pump : CentrifugalPump;
			in flowMeter : FlowMeter;
			in pressureSensorInlet : PressureSensor;
			in pressureSensorOutlet : PressureSensor;
			out efficiency : Real;
			out head : LengthValue;
		}
		
		action def AdjustFlowRate {
			in targetFlowRate : VolumeFlowRateValue;
			in controlValve : ControlValve;
			out newValvePosition : Real;
		}
		
		calc def CalculatePumpHead {
			in inletPressure : PressureValue;
			in outletPressure : PressureValue;
			in fluidDensity : DensityValue;
			return head : LengthValue = (outletPressure - inletPressure) / (fluidDensity * 9.81[m/s^2]);
		}
		
		calc def CalculateEfficiency {
			in flowRate : VolumeFlowRateValue;
			in head : LengthValue;
			in powerConsumed : PowerValue;
			in fluidDensity : DensityValue;
			return efficiency : Real = (fluidDensity * 9.81[m/s^2] * flowRate * head) / powerConsumed;
		}
		
		calc def CalculateNPSHAvailable {
			in reservoirPressure : PressureValue;
			in staticHead : LengthValue;
			in frictionLoss : PressureValue;
			in vaporPressure : PressureValue;
			in fluidDensity : DensityValue;
			return npshAvailable : LengthValue = 
				(reservoirPressure - vaporPressure) / (fluidDensity * 9.81[m/s^2]) + staticHead - frictionLoss / (fluidDensity * 9.81[m/s^2]);
		}
		
		calc def CalculateReynoldsNumber {
			in flowRate : VolumeFlowRateValue;
			in diameter : LengthValue;
			in density : DensityValue;
			in viscosity : DynamicViscosityValue;
			return reynoldsNumber : Real = (4.0 * density * flowRate) / (3.14159 * diameter * viscosity);
		}
		
		requirement def PumpSelectionRequirement {
			doc /* The centrifugal pump shall be selected based on required flow rate and head */
			
			attribute requiredFlowRate : VolumeFlowRateValue;
			attribute requiredHead : LengthValue;
			attribute minEfficiency : Real = 0.70;
			attribute npshMargin : LengthValue = 1.0[m];
		}
		
		requirement def SystemOperationalRequirement {
			doc /* Pumping subsystem operational requirements */
			
			attribute operatingHours : Real = 8760.0;
			attribute targetReliability : Real = 0.99;
			attribute maintenanceInterval : TimeValue = 2000.0[h];
		}
	}
	
	package Usages {
		part pumpingSubsystem {
			doc /* Complete pumping subsystem with centrifugal pump, piping, and instrumentation */
			
			part sourceReservoir : Definitions::FluidReservoir {
				attribute :>> capacity = 50.0[m^3];
				attribute :>> currentLevel = 3.5[m];
				attribute :>> surfacePressure = 101325.0[Pa];
				attribute :>> fluidStored {
					attribute :>> density = 1000.0[kg/m^3];
					attribute :>> viscosity = 0.001[Pa*s];
					attribute :>> temperature = 293.15[K];
					attribute :>> vaporPressure = 2340.0[Pa];
				}
			}
			
			part suctionPiping : Definitions::PipingNetwork {
				attribute :>> length = 15.0[m];
				attribute :>> diameter = 0.15[m];
				attribute :>> roughness = 0.000045[m];
				attribute :>> frictionLoss = 5000.0[Pa];
				attribute :>> minorLosses = 2000.0[Pa];
			}
			
			flow of fluid : Definitions::Fluid
				from sourceReservoir.outletPort.fluid
				to suctionPiping.inletPort.fluid;
			
			part centrifugalPump : Definitions::CentrifugalPump {
				attribute :>> characteristics {
					attribute :>> ratedFlowRate = 100.0[m^3/h];
					attribute :>> ratedHead = 50.0[m];
					attribute :>> maxPressure = 600000.0[Pa];
					attribute :>> efficiency = 0.78;
					attribute :>> powerRating = 22000.0[W];
					attribute :>> impellerDiameter = 0.25[m];
					attribute :>> operatingSpeed = 303.7[rad/s];
					attribute :>> npshRequired = 3.5[m];
				}
				
				attribute :>> operatingFlowRate = 95.0[m^3/h];
				attribute :>> operatingHead = 48.0[m];
				attribute :>> currentEfficiency = 0.76;
				attribute :>> powerConsumed = 18500.0[W];
				
				part :>> impeller {
					attribute :>> diameter = 0.25[m];
					attribute :>> rotationalSpeed = 303.7[rad/s];
					attribute :>> bladeCount = 6;
				}
				
				part :>> volute {
					attribute :>> inletArea = 0.0177[m^2];
					attribute :>> outletArea = 0.0123[m^2];
				}
				
				part :>> shaft {
					attribute :>> diameter = 0.05[m];
					attribute :>> material = "Stainless Steel 316";
					attribute :>> maxTorque = 100.0[N*m];
				}
				
				part :>> motor {
					attribute :>> ratedPower = 22000.0[W];
					attribute :>> voltage = 400.0[V];
					attribute :>> current = 45.0[A];
					attribute :>> motorEfficiency = 0.92;
				}
				
				perform action pumpOperation : Definitions::PumpOperatingStates {
					in pumpRef = centrifugalPump;
				}
			}
			
			flow of fluid : Definitions::Fluid
				from suctionPiping.outletPort.fluid
				to centrifugalPump.inletPort.fluid;
			
			part dischargePiping : Definitions::PipingNetwork {
				attribute :>> length = 100.0[m];
				attribute :>> diameter = 0.125[m];
				attribute :>> roughness = 0.000045[m];
				attribute :>> frictionLoss = 35000.0[Pa];
				attribute :>> minorLosses = 8000.0[Pa];
			}
			
			flow of fluid : Definitions::Fluid
				from centrifugalPump.outletPort.fluid
				to dischargePiping.inletPort.fluid;
			
			part dischargeControlValve : Definitions::ControlValve {
				attribute :>> position = 0.75;
				attribute :>> maxFlowCoefficient = 150.0;
				attribute :>> currentFlowCoefficient = 112.5;
			}
			
			part dischargeVessel : Definitions::DischargeVessel {
				attribute :>> capacity = 30.0[m^3];
				attribute :>> currentLevel = 2.0[m];
				attribute :>> operatingPressure = 400000.0[Pa];
			}
			
			flow of fluid : Definitions::Fluid
				from dischargePiping.outletPort.fluid
				to dischargeVessel.inletPort.fluid;
			
			part inletPressureSensor : Definitions::PressureSensor {
				attribute :>> measuredPressure = 95000.0[Pa];
				attribute :>> accuracy = 0.005;
				attribute :>> range = 200000.0[Pa];
			}
			
			part outletPressureSensor : Definitions::PressureSensor {
				attribute :>> measuredPressure = 565000.0[Pa];
				attribute :>> accuracy = 0.005;
				attribute :>> range = 1000000.0[Pa];
			}
			
			part flowMeter : Definitions::FlowMeter {
				attribute :>> measuredFlowRate = 95.0[m^3/h];
				attribute :>> accuracy = 0.01;
				attribute :>> range = 150.0[m^3/h];
			}
			
			action performanceMonitoring : Definitions::MonitorPumpPerformance {
				in pump = centrifugalPump;
				in flowMeter = pumpingSubsystem::flowMeter;
				in pressureSensorInlet = inletPressureSensor;
				in pressureSensorOutlet = outletPressureSensor;
				
				calc headCalculation : Definitions::CalculatePumpHead {
					in inletPressure = inletPressureSensor.measuredPressure;
					in outletPressure = outletPressureSensor.measuredPressure;
					in fluidDensity = sourceReservoir.fluidStored.density;
					return head;
				}
				
				calc efficiencyCalculation : Definitions::CalculateEfficiency {
					in flowRate = flowMeter.measuredFlowRate;
					in head = headCalculation.head;
					in powerConsumed = centrifugalPump.powerConsumed;
					in fluidDensity = sourceReservoir.fluidStored.density;
					return efficiency;
				}
				
				out efficiency = efficiencyCalculation.efficiency;
				out head = headCalculation.head;
			}
			
			action flowControl : Definitions::AdjustFlowRate {
				in targetFlowRate = 100.0[m^3/h];
				in controlValve = dischargeControlValve;
				out newValvePosition;
			}
			
			calc npshCheck : Definitions::CalculateNPSHAvailable {
				in reservoirPressure = sourceReservoir.surfacePressure;
				in staticHead = sourceReservoir.currentLevel;
				in frictionLoss = suctionPiping.frictionLoss + suctionPiping.minorLosses;
				in vaporPressure = sourceReservoir.fluidStored.vaporPressure;
				in fluidDensity = sourceReservoir.fluidStored.density;
				return npshAvailable;
			}
			
			calc reynoldsCheck : Definitions::CalculateReynoldsNumber {
				in flowRate = centrifugalPump.operatingFlowRate;
				in diameter = dischargePiping.diameter;
				in density = sourceReservoir.fluidStored.density;
				in viscosity = sourceReservoir.fluidStored.viscosity;
				return reynoldsNumber;
			}
			
			requirement pumpSelection : Definitions::PumpSelectionRequirement {
				attribute :>> requiredFlowRate = 90.0[m^3/h];
				attribute :>> requiredHead = 45.0[m];
				attribute :>> minEfficiency = 0.70;
				attribute :>> npshMargin = 1.0[m];
			}
			
			requirement systemOperation : Definitions::SystemOperationalRequirement {
				attribute :>> operatingHours = 8760.0;
				attribute :>> targetReliability = 0.99;
				attribute :>> maintenanceInterval = 2000.0[h];
			}
			
			constraint pumpMeetsFlowRequirement {
				centrifugalPump.characteristics.ratedFlowRate >= pumpSelection.requiredFlowRate
			}
			
			constraint pumpMeetsHeadRequirement {
				centrifugalPump.characteristics.ratedHead >= pumpSelection.requiredHead
			}
			
			constraint pumpMeetsEfficiencyRequirement {
				centrifugalPump.currentEfficiency >= pumpSelection.minEfficiency
			}
			
			constraint npshAdequate {
				npshCheck.npshAvailable >= centrifugalPump.characteristics.npshRequired + pumpSelection.npshMargin
			}
			
			constraint massConservation {
				suctionPiping.outletPort.flowRate == centrifugalPump.inletPort.flowRate and
				centrifugalPump.outletPort.flowRate == dischargePiping.inletPort.flowRate
			}
			
			constraint energyBalance {
				centrifugalPump.powerConsumed == 
					sourceReservoir.fluidStored.density * 9.81[m/s^2] * 
					centrifugalPump.operatingFlowRate * centrifugalPump.operatingHead / 
					centrifugalPump.currentEfficiency
			}
		}
	}
}
