package 'Chain Pump Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		item def Fluid {
			attribute density : DensityValue;
			attribute viscosity : DynamicViscosityValue;
			attribute volume : VolumeValue;
		}
		
		port def FluidPort {
			out item fluidOut : Fluid;
		}
		
		port def FluidInletPort {
			in item fluidIn : Fluid;
		}
		
		port def PowerPort {
			in attribute voltage : ElectricPotentialValue;
			in attribute current : ElectricCurrentValue;
		}
		
		part def ChainPumpAssembly {
			port fluidInlet : FluidInletPort;
			port fluidOutlet : FluidPort;
			port powerInput : PowerPort;
			
			part endlessChain : EndlessChain;
			part diskSet : DiskSet;
			part driveUnit : DriveUnit;
			part housingTube : HousingTube;
			part lowerReservoir : LowerReservoir;
			part upperDischarge : UpperDischarge;
			
			connect endlessChain.diskMountPoints to diskSet.attachmentPoints;
			connect driveUnit.outputShaft to endlessChain.driveConnection;
			connect housingTube.innerChannel to diskSet.operatingSpace;
			connect lowerReservoir.outlet to housingTube.inlet;
			connect housingTube.outlet to upperDischarge.inlet;
			connect powerInput to driveUnit.powerIn;
			
			perform action pumpingOperation : ChainPumpingAction;
		}
		
		part def EndlessChain {
			attribute chainLength : LengthValue;
			attribute linkCount : Integer;
			attribute linkPitch : LengthValue;
			attribute tensileStrength : ForceValue;
			attribute operatingSpeed : SpeedValue;
			
			port diskMountPoints[0..*];
			port driveConnection;
		}
		
		part def DiskSet {
			attribute diskDiameter : LengthValue;
			attribute diskThickness : LengthValue;
			attribute diskSpacing : LengthValue;
			attribute diskCount : Integer;
			attribute clearanceGap : LengthValue;
			
			port attachmentPoints[0..*];
			port operatingSpace;
			
			part disks[1..*] : PumpingDisk;
		}
		
		part def PumpingDisk {
			attribute diameter : LengthValue;
			attribute thickness : LengthValue;
			attribute material : String;
			attribute sealingEfficiency : Real;
		}
		
		part def DriveUnit {
			port powerIn : PowerPort;
			port outputShaft;
			
			part motor : ElectricMotor;
			part gearReducer : GearReducer;
			part driveSprocket : DriveSprocket;
			
			connect motor.shaft to gearReducer.inputShaft;
			connect gearReducer.outputShaft to driveSprocket.shaft;
			
			perform action driveControl : DriveControlAction;
		}
		
		part def ElectricMotor {
			attribute ratedPower : PowerValue;
			attribute ratedSpeed : AngularVelocityValue;
			attribute ratedTorque : TorqueValue;
			attribute efficiency : Real;
			attribute currentPower : PowerValue;
			attribute currentSpeed : AngularVelocityValue;
			
			port shaft;
			port powerConnection : PowerPort;
			
			perform action motorOperation : MotorOperationAction;
		}
		
		part def GearReducer {
			attribute reductionRatio : Real;
			attribute efficiency : Real;
			attribute inputSpeed : AngularVelocityValue;
			attribute outputSpeed : AngularVelocityValue;
			attribute outputTorque : TorqueValue;
			
			port inputShaft;
			port outputShaft;
		}
		
		part def DriveSprocket {
			attribute diameter : LengthValue;
			attribute toothCount : Integer;
			
			port shaft;
		}
		
		part def HousingTube {
			attribute innerDiameter : LengthValue;
			attribute outerDiameter : LengthValue;
			attribute length : LengthValue;
			attribute material : String;
			attribute inclinationAngle : PlaneAngleValue;
			
			port innerChannel;
			port inlet : FluidInletPort;
			port outlet : FluidPort;
		}
		
		part def LowerReservoir {
			attribute capacity : VolumeValue;
			attribute currentLevel : LengthValue;
			attribute minimumLevel : LengthValue;
			
			port outlet : FluidPort;
			port supplyConnection : FluidInletPort;
			
			item storedFluid : Fluid {
				attribute :>> volume;
			}
		}
		
		part def UpperDischarge {
			attribute dischargeHeight : LengthValue;
			attribute dischargeRate : VolumeFlowRateValue;
			attribute dischargeAngle : PlaneAngleValue;
			
			port inlet : FluidInletPort;
			port outlet : FluidPort;
		}
		
		action def ChainPumpingAction {
			in fluidSource : Fluid;
			out fluidDelivered : Fluid;
			
			action captureFluid : FluidCaptureAction;
			action liftFluid : FluidLiftAction;
			action dischargeFluid : FluidDischargeAction;
			
			succession captureFluid then liftFluid;
			succession liftFluid then dischargeFluid;
		}
		
		action def FluidCaptureAction {
			in diskPosition : LengthValue;
			in reservoirLevel : LengthValue;
			in diskClearance : LengthValue;
			out capturedVolume : VolumeValue;
		}
		
		action def FluidLiftAction {
			in capturedVolume : VolumeValue;
			in liftHeight : LengthValue;
			in chainSpeed : SpeedValue;
			in diskSpacing : LengthValue;
			out liftedVolume : VolumeValue;
		}
		
		action def FluidDischargeAction {
			in liftedVolume : VolumeValue;
			in dischargeHeight : LengthValue;
			out dischargedVolume : VolumeValue;
		}
		
		action def DriveControlAction {
			in targetSpeed : AngularVelocityValue;
			in loadTorque : TorqueValue;
			out commandedPower : PowerValue;
		}
		
		action def MotorOperationAction {
			in powerInput : PowerValue;
			in loadTorque : TorqueValue;
			out shaftSpeed : AngularVelocityValue;
			out outputTorque : TorqueValue;
		}
		
		action def RampUpAction {
			in currentSpeed : SpeedValue;
			in targetSpeed : SpeedValue;
			in accelerationRate : AccelerationValue;
			out newSpeed : SpeedValue;
		}
		
		action def MaintainPumpingAction {
			in targetSpeed : SpeedValue;
			in currentLoad : TorqueValue;
			in fluidDensity : DensityValue;
			out adjustedSpeed : SpeedValue;
		}
		
		action def RampDownAction {
			in currentSpeed : SpeedValue;
			in decelerationRate : AccelerationValue;
			out newSpeed : SpeedValue;
		}
	}
	
	package Requirements {
		requirement def ChainPumpSystemRequirements {
			subject chainPumpSystem : ChainPumpAssembly;
			
			require flowRateRequirement : FlowRateRequirement;
			require liftHeightRequirement : LiftHeightRequirement;
			require efficiencyRequirement : EfficiencyRequirement;
			require reliabilityRequirement : ReliabilityRequirement;
			require operationalRequirement : OperationalRequirement;
		}
		
		requirement def FlowRateRequirement {
			doc /* The chain pump shall deliver a minimum flow rate of 5.0 liters per second under nominal operating conditions. */
			
			attribute minimumFlowRate : VolumeFlowRateValue = 5.0 [L/s];
			
			require constraint {
				chainPumpSystem.upperDischarge.dischargeRate >= minimumFlowRate
			}
		}
		
		requirement def LiftHeightRequirement {
			doc /* The chain pump shall lift fluid to a minimum vertical height of 10.0 meters from the lower reservoir to the upper discharge point. */
			
			attribute minimumLiftHeight : LengthValue = 10.0 [m];
			
			require constraint {
				chainPumpSystem.upperDischarge.dischargeHeight >= minimumLiftHeight
			}
		}
		
		requirement def EfficiencyRequirement {
			doc /* The chain pump drive system shall operate at a minimum overall efficiency of 65 percent. */
			
			attribute minimumEfficiency : Real = 0.65;
			
			require constraint {
				chainPumpSystem.driveUnit.motor.efficiency >= minimumEfficiency
			}
		}
		
		requirement def ReliabilityRequirement {
			doc /* The chain pump shall operate continuously for at least 2000 hours without mechanical failure. */
			
			attribute minimumOperatingHours : Real = 2000.0;
		}
		
		requirement def OperationalRequirement {
			doc /* The chain pump shall maintain stable operation with fluid viscosity ranging from 0.001 to 0.01 Pascal-seconds. */
			
			attribute minimumViscosity : DynamicViscosityValue = 0.001 [Pa*s];
			attribute maximumViscosity : DynamicViscosityValue = 0.01 [Pa*s];
		}
	}
	
	package Usages {
		part chainPumpingSystem : ChainPumpAssembly {
			part :>> endlessChain {
				attribute :>> chainLength = 18.0 [m];
				attribute :>> linkCount = 180;
				attribute :>> linkPitch = 0.1 [m];
				attribute :>> tensileStrength = 8000.0 [N];
				attribute :>> operatingSpeed = 0.6 [m/s];
			}
			
			part :>> diskSet {
				attribute :>> diskDiameter = 0.095 [m];
				attribute :>> diskThickness = 0.006 [m];
				attribute :>> diskSpacing = 0.1 [m];
				attribute :>> diskCount = 180;
				attribute :>> clearanceGap = 0.0025 [m];
				
				part :>> disks[180] {
					attribute :>> diameter = 0.095 [m];
					attribute :>> thickness = 0.006 [m];
					attribute :>> material = "Rubber";
					attribute :>> sealingEfficiency = 0.92;
				}
			}
			
			part :>> driveUnit {
				part :>> motor {
					attribute :>> ratedPower = 2500.0 [W];
					attribute :>> ratedSpeed = 1450.0 [rad/s];
					attribute :>> ratedTorque = 16.5 [N*m];
					attribute :>> efficiency = 0.88;
					attribute :>> currentPower = 2200.0 [W];
					attribute :>> currentSpeed = 1400.0 [rad/s];
				}
				
				part :>> gearReducer {
					attribute :>> reductionRatio = 12.0;
					attribute :>> efficiency = 0.92;
					attribute :>> inputSpeed = 1400.0 [rad/s];
					attribute :>> outputSpeed = 116.7 [rad/s];
					attribute :>> outputTorque = 182.0 [N*m];
				}
				
				part :>> driveSprocket {
					attribute :>> diameter = 0.18 [m];
					attribute :>> toothCount = 36;
				}
			}
			
			part :>> housingTube {
				attribute :>> innerDiameter = 0.1 [m];
				attribute :>> outerDiameter = 0.12 [m];
				attribute :>> length = 12.0 [m];
				attribute :>> material = "PVC";
				attribute :>> inclinationAngle = 80.0 [deg];
			}
			
			part :>> lowerReservoir {
				attribute :>> capacity = 800.0 [L];
				attribute :>> currentLevel = 1.2 [m];
				attribute :>> minimumLevel = 0.3 [m];
				
				item :>> storedFluid {
					attribute :>> volume = 600.0 [L];
					attribute :>> density = 1000.0 [kg/m^3];
					attribute :>> viscosity = 0.001 [Pa*s];
				}
			}
			
			part :>> upperDischarge {
				attribute :>> dischargeHeight = 11.5 [m];
				attribute :>> dischargeRate = 5.8 [L/s];
				attribute :>> dischargeAngle = 45.0 [deg];
			}
			
			flow of transferredFluid : Fluid
				from lowerReservoir.outlet.fluidOut
				to housingTube.inlet.fluidIn;
			
			flow of liftedFluid : Fluid
				from housingTube.outlet.fluidOut
				to upperDischarge.inlet.fluidIn;
			
			perform action :>> pumpingOperation {
				in fluidSource = lowerReservoir.storedFluid;
				out fluidDelivered : Fluid;
			}
		}
		
		part waterSupplySource {
			port waterOutlet : FluidPort;
			
			item supplyWater : Fluid {
				attribute :>> density = 1000.0 [kg/m^3];
				attribute :>> viscosity = 0.001 [Pa*s];
				attribute :>> volume = 10000.0 [L];
			}
		}
		
		part irrigationDestination {
			port waterInlet : FluidInletPort;
			
			attribute requiredFlowRate : VolumeFlowRateValue = 5.0 [L/s];
		}
		
		part powerSupply {
			port powerOutlet : ~PowerPort;
			
			attribute supplyVoltage : ElectricPotentialValue = 230.0 [V];
			attribute supplyFrequency : FrequencyValue = 50.0 [Hz];
		}
		
		part pumpingSystemContext {
			part waterSource : waterSupplySource;
			part chainPump : chainPumpingSystem;
			part irrigation : irrigationDestination;
			part power : powerSupply;
			
			flow of sourceWater : Fluid
				from waterSource.waterOutlet.fluidOut
				to chainPump.lowerReservoir.supplyConnection.fluidIn;
			
			flow of deliveredWater : Fluid
				from chainPump.upperDischarge.outlet.fluidOut
				to irrigation.waterInlet.fluidIn;
			
			connect power.powerOutlet to chainPump.powerInput;
		}
	}
	
	package Verification {
		requirement systemRequirements : ChainPumpSystemRequirements {
			subject pumpSystem = chainPumpingSystem;
		}
		
		satisfy systemRequirements.flowRateRequirement by chainPumpingSystem.upperDischarge;
		satisfy systemRequirements.liftHeightRequirement by chainPumpingSystem.housingTube;
		satisfy systemRequirements.efficiencyRequirement by chainPumpingSystem.driveUnit.motor;
	}
}
