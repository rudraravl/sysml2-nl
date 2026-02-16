package 'Axial Piston Pump Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		attribute def PressureValue :> Real;
		attribute def VolumeFlowRateValue :> Real;
		attribute def AngularVelocityValue :> Real;
		attribute def TorqueValue :> Real;
		attribute def AngleValue :> Real;
		attribute def VolumeValue :> Real;
		attribute def LengthValue :> Real;
		attribute def PowerValue :> Real;
		attribute def TemperatureValue :> Real;
		attribute def DensityValue :> Real;
		attribute def SpeedValue :> Real;
		
		item def HydraulicFluid {
			attribute viscosity : Real;
			attribute density : DensityValue;
			attribute temperature : TemperatureValue;
			attribute pressure : PressureValue;
			attribute flowRate : VolumeFlowRateValue;
		}
		
		port def FluidInPort {
			attribute pressure : PressureValue;
			attribute temperature : TemperatureValue;
			in item fluid : HydraulicFluid;
		}
		
		port def FluidOutPort {
			attribute pressure : PressureValue;
			attribute temperature : TemperatureValue;
			out item fluid : HydraulicFluid;
		}
		
		port def DriveShaftPort {
			attribute torque : TorqueValue;
			attribute angularVelocity : AngularVelocityValue;
		}
		
		part def Piston {
			attribute diameter : LengthValue;
			attribute stroke : LengthValue;
			attribute position : LengthValue;
			attribute velocity : SpeedValue;
		}
		
		part def CylinderBlock {
			attribute numberOfPistons : Integer;
			attribute boreCircleDiameter : LengthValue;
			part pistons : Piston[9];
		}
		
		part def SwashPlate {
			attribute swashAngle : AngleValue;
			attribute maxSwashAngle : AngleValue;
			attribute minSwashAngle : AngleValue;
		}
		
		part def DriveShaft {
			attribute diameter : LengthValue;
			attribute angularVelocity : AngularVelocityValue;
			port shaftConnection : DriveShaftPort;
		}
		
		part def ValvePlate {
			attribute inletArcAngle : AngleValue;
			attribute outletArcAngle : AngleValue;
		}
		
		part def AxialPistonPump {
			attribute ratedPressure : PressureValue;
			attribute maxPressure : PressureValue;
			attribute ratedFlowRate : VolumeFlowRateValue;
			attribute displacement : VolumeValue;
			attribute efficiency : Real;
			attribute ratedSpeed : AngularVelocityValue;
			
			port inletPort : FluidInPort;
			port outletPort : FluidOutPort;
			port drivePort : DriveShaftPort;
			
			part cylinderBlock : CylinderBlock {
				attribute :>> numberOfPistons = 9;
			}
			
			part swashPlate : SwashPlate {
				attribute :>> maxSwashAngle = 18.0;
				attribute :>> minSwashAngle = 0.0;
			}
			
			part driveShaft : DriveShaft;
			
			part valvePlate : ValvePlate;
			
			part housingCase {
				attribute material : String;
			}
			
			binding of driveShaft.shaftConnection = drivePort;
			
			perform action pumpOperation : PumpingAction;
		}
		
		part def Reservoir {
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			attribute minLevel : VolumeValue;
			attribute ambientPressure : PressureValue;
			
			port outletPort : FluidOutPort;
			
			item storedFluid : HydraulicFluid {
				attribute :>> pressure = ambientPressure;
			}
			
			flow of outletPort.fluid from storedFluid;
		}
		
		part def Motor {
			attribute ratedPower : PowerValue;
			attribute ratedSpeed : AngularVelocityValue;
			attribute currentSpeed : AngularVelocityValue;
			
			port outputShaft : DriveShaftPort;
			
			perform action motorOperation : MotorDriveAction;
		}
		
		part def PressureReliefValve {
			attribute crackingPressure : PressureValue;
			attribute maxFlowCapacity : VolumeFlowRateValue;
			
			port inletPort : FluidInPort;
			port outletPort : FluidOutPort;
			
			perform action reliefOperation : ReliefValveAction;
		}
		
		part def FluidCooler {
			attribute coolingCapacity : PowerValue;
			attribute targetTemperature : TemperatureValue;
			
			port inletPort : FluidInPort;
			port outletPort : FluidOutPort;
			
			perform action coolingOperation : CoolingAction;
		}
		
		part def Filter {
			attribute filtrationRating : LengthValue;
			attribute pressureDrop : PressureValue;
			
			port inletPort : FluidInPort;
			port outletPort : FluidOutPort;
		}
		
		part def Actuator {
			attribute requiredPressure : PressureValue;
			attribute requiredFlowRate : VolumeFlowRateValue;
			
			port supplyPort : FluidInPort;
			
			perform action actuate : ActuationAction;
		}
		
		action def PumpingAction {
			in inletFluid : HydraulicFluid;
			in driveSpeed : AngularVelocityValue;
			in swashAngle : AngleValue;
			out outletFluid : HydraulicFluid;
			out flowRate : VolumeFlowRateValue;
			out outputPressure : PressureValue;
		}
		
		action def MotorDriveAction {
			out shaftSpeed : AngularVelocityValue;
			out shaftTorque : TorqueValue;
		}
		
		action def ReliefValveAction {
			in systemPressure : PressureValue;
			in setCrackingPressure : PressureValue;
			out relievedFlow : VolumeFlowRateValue;
		}
		
		action def CoolingAction {
			in hotFluid : HydraulicFluid;
			out cooledFluid : HydraulicFluid;
		}
		
		action def ActuationAction {
			in supplyFluid : HydraulicFluid;
			out mechanicalWork : Real;
		}
		
		action def MonitorPumpPerformance {
			in currentPressure : PressureValue;
			in currentFlowRate : VolumeFlowRateValue;
			in currentTemperature : TemperatureValue;
			out performanceStatus : PerformanceStatus;
		}
		
		enum def PerformanceStatus {
			enum normal;
			enum degraded;
			enum critical;
			enum failed;
		}
		
		action def PumpControlBehavior {
			in startCmd : Boolean;
			in stopCmd : Boolean;
			in emergencyStop : Boolean;
			inout pumpSpeed : AngularVelocityValue;
			in ratedSpeed : AngularVelocityValue;
			in rampUpSpeed : AngularVelocityValue;
			in rampDownSpeed : AngularVelocityValue;
			in outputPressure : PressureValue;
			in maxPressure : PressureValue;
			in fluidTemperature : TemperatureValue;
			in maxTemperature : TemperatureValue;
			out operatingMode : String;
			out emergencyShutdown : Boolean;
			
			first start;
			then merge checkState;
			then decide;
				if startCmd then rampUp;
				if stopCmd then rampDown;
				if emergencyStop then emergencyAction;
			
			action rampUp {
				then assign pumpSpeed = pumpSpeed + rampUpSpeed;
			}
			then checkState;
			
			action rampDown {
				then assign pumpSpeed = pumpSpeed - rampDownSpeed;
			}
			then checkState;
			
			action emergencyAction {
				then assign emergencyShutdown = true;
				then assign pumpSpeed = 0.0;
			}
			then done;
		}
		
		requirement def PumpPerformanceRequirement {
			doc /* The axial piston pump shall deliver rated flow at rated pressure. */
			
			subject pump : AxialPistonPump;
			
			require constraint {
				pump.outletPort.fluid.flowRate >= pump.ratedFlowRate
			}
			
			require constraint {
				pump.outletPort.pressure >= pump.ratedPressure
			}
		}
		
		requirement def PumpEfficiencyRequirement {
			doc /* The pump shall maintain minimum volumetric efficiency. */
			
			subject pump : AxialPistonPump;
			
			attribute minEfficiency : Real = 0.90;
			
			require constraint {
				pump.efficiency >= minEfficiency
			}
		}
		
		requirement def PressureSafetyRequirement {
			doc /* System pressure shall not exceed maximum rated pressure. */
			
			subject reliefValve : PressureReliefValve;
			subject pump : AxialPistonPump;
			
			require constraint {
				reliefValve.crackingPressure <= pump.maxPressure
			}
		}
		
		requirement def FluidTemperatureRequirement {
			doc /* Hydraulic fluid temperature shall be maintained within operating range. */
			
			subject cooler : FluidCooler;
			
			attribute maxOperatingTemp : TemperatureValue;
			
			require constraint {
				cooler.outletPort.fluid.temperature <= maxOperatingTemp
			}
		}
	}
	
	package Usages {
		part pumpingSystem {
			part reservoir : Reservoir {
				attribute :>> capacity = 100.0;
				attribute :>> minLevel = 20.0;
				attribute :>> ambientPressure = 101325.0;
			}
			
			part suctionFilter : Filter {
				attribute :>> filtrationRating = 25.0;
				attribute :>> pressureDrop = 5000.0;
			}
			
			flow of fluid : HydraulicFluid from reservoir.outletPort.fluid to suctionFilter.inletPort.fluid;
			
			part driveMotor : Motor {
				attribute :>> ratedPower = 15000.0;
				attribute :>> ratedSpeed = 1800.0;
				
				perform action :>> motorOperation {
					out :>> shaftSpeed = outputShaft.angularVelocity;
					out :>> shaftTorque = outputShaft.torque;
				}
			}
			
			part axialPump : AxialPistonPump {
				attribute :>> ratedPressure = 21000000.0;
				attribute :>> maxPressure = 25000000.0;
				attribute :>> ratedFlowRate = 0.00167;
				attribute :>> displacement = 0.0001;
				attribute :>> ratedSpeed = 1800.0;
				attribute :>> efficiency = 0.92;
				
				perform action :>> pumpOperation {
					in :>> inletFluid = inletPort.fluid;
					in :>> driveSpeed = drivePort.angularVelocity;
					in :>> swashAngle = swashPlate.swashAngle;
					out :>> outletFluid = outletPort.fluid;
					out :>> flowRate = outletPort.fluid.flowRate;
					out :>> outputPressure = outletPort.pressure;
				}
			}
			
			flow of fluid : HydraulicFluid from suctionFilter.outletPort.fluid to axialPump.inletPort.fluid;
			
			binding of driveMotor.outputShaft = axialPump.drivePort;
			
			part pressureFilter : Filter {
				attribute :>> filtrationRating = 10.0;
				attribute :>> pressureDrop = 10000.0;
			}
			
			flow of fluid : HydraulicFluid from axialPump.outletPort.fluid to pressureFilter.inletPort.fluid;
			
			part reliefValve : PressureReliefValve {
				attribute :>> crackingPressure = 24500000.0;
				attribute :>> maxFlowCapacity = 0.002;
				
				perform action :>> reliefOperation {
					in :>> systemPressure = inletPort.pressure;
					in :>> setCrackingPressure = crackingPressure;
					out :>> relievedFlow = outletPort.fluid.flowRate;
				}
			}
			
			flow of fluid : HydraulicFluid from pressureFilter.outletPort.fluid to reliefValve.inletPort.fluid;
			
			part cooler : FluidCooler {
				attribute :>> coolingCapacity = 5000.0;
				attribute :>> targetTemperature = 60.0;
				
				perform action :>> coolingOperation {
					in :>> hotFluid = inletPort.fluid;
					out :>> cooledFluid = outletPort.fluid;
				}
			}
			
			flow of fluid : HydraulicFluid from reliefValve.outletPort.fluid to cooler.inletPort.fluid;
			
			flow of fluid : HydraulicFluid from cooler.outletPort.fluid to reservoir.outletPort.fluid;
			
			part hydraulicActuator : Actuator {
				attribute :>> requiredPressure = 20000000.0;
				attribute :>> requiredFlowRate = 0.00133;
				
				perform action :>> actuate {
					in :>> supplyFluid = supplyPort.fluid;
					out :>> mechanicalWork = 15000.0;
				}
			}
			
			flow of fluid : HydraulicFluid from pressureFilter.outletPort.fluid to hydraulicActuator.supplyPort.fluid;
			
			perform action monitorPerformance : MonitorPumpPerformance {
				in :>> currentPressure = axialPump.outletPort.pressure;
				in :>> currentFlowRate = axialPump.outletPort.fluid.flowRate;
				in :>> currentTemperature = axialPump.outletPort.fluid.temperature;
				out :>> performanceStatus;
			}
			
			perform action pumpControl : PumpControlBehavior {
				in startCmd = false;
				in stopCmd = false;
				in emergencyStop = false;
				inout pumpSpeed = axialPump.drivePort.angularVelocity;
				in ratedSpeed = axialPump.ratedSpeed;
				in rampUpSpeed = 300.0;
				in rampDownSpeed = 200.0;
				in outputPressure = axialPump.outletPort.pressure;
				in maxPressure = axialPump.maxPressure;
				in fluidTemperature = axialPump.outletPort.fluid.temperature;
				in maxTemperature = 90.0;
				out operatingMode;
				out emergencyShutdown;
			}
			
			satisfy pumpPerformanceReq : PumpPerformanceRequirement {
				subject pump = axialPump;
			}
			
			satisfy pumpEfficiencyReq : PumpEfficiencyRequirement {
				subject pump = axialPump;
			}
			
			satisfy pressureSafetyReq : PressureSafetyRequirement {
				subject reliefValve = reliefValve;
				subject pump = axialPump;
			}
			
			satisfy fluidTempReq : FluidTemperatureRequirement {
				subject cooler = cooler;
				attribute :>> maxOperatingTemp = 80.0;
			}
		}
	}
}
