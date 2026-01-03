package 'Solar Powered Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package ValueTypes {
		attribute def Watt :> Real;
		attribute def Volt :> Real;
		attribute def Ampere :> Real;
		attribute def WattHour :> Real;
		attribute def LiterPerSecond :> Real;
		attribute def Liter :> Real;
		attribute def WattPerSquareMeter :> Real;
		attribute def Pascal :> Real;
		
		attribute def Power :> Real;
		attribute def Voltage :> Real;
		attribute def Current :> Real;
		attribute def Energy :> Real;
		attribute def FlowRate :> Real;
		attribute def Volume :> Real;
		attribute def Irradiance :> Real;
		attribute def Pressure :> Real;
	}
	
	package ItemDefinitions {
		private import ValueTypes::*;
		
		item def Fluid {
			attribute volume : Volume;
			attribute pressure : Pressure;
			attribute temperature : Real;
		}
		
		item def ElectricalEnergy {
			attribute voltage : Voltage;
			attribute current : Current;
			attribute power : Power;
		}
		
		item def SolarRadiation {
			attribute irradiance : Irradiance;
			attribute incidentAngle : Real;
		}
	}
	
	package PortDefinitions {
		private import ItemDefinitions::*;
		
		port def FluidInletPort {
			in item fluidIn : Fluid;
		}
		
		port def FluidOutletPort {
			out item fluidOut : Fluid;
		}
		
		port def ElectricalPowerPort {
			out item electricalPower : ElectricalEnergy;
		}
		
		port def SolarInputPort {
			in item solarRadiation : SolarRadiation;
		}
	}
	
	package PartDefinitions {
		private import ValueTypes::*;
		private import ItemDefinitions::*;
		private import PortDefinitions::*;
		
		attribute def PowerAvailableSignal;
		attribute def PowerLostSignal;
		attribute def FlowStabilizedSignal;
		attribute def ShutdownSignal;
		attribute def StartPumpCommand;
		attribute def StopPumpCommand;
		attribute def LowPowerWarning;
		attribute def PowerRestored;
		
		part def SolarPanel {
			attribute panelArea : Real;
			attribute conversionEfficiency : Real;
			attribute maxPowerOutput : Power;
			attribute currentPowerOutput : Power;
			
			port solarInput : SolarInputPort;
			port powerOutput : ElectricalPowerPort;
			
			action def ConvertSolarEnergy {
				in radiation : SolarRadiation;
				out generatedPower : ElectricalEnergy;
			}
			
			perform action convertEnergy : ConvertSolarEnergy {
				in radiation = solarInput.solarRadiation;
				out generatedPower = powerOutput.electricalPower;
			}
		}
		
		part def BatteryBank {
			attribute totalCapacity : Energy;
			attribute currentCharge : Energy;
			attribute stateOfCharge : Real;
			attribute minChargeLevel : Real;
			attribute maxChargeLevel : Real;
			attribute nominalVoltage : Voltage;
			
			port chargePort : ~ElectricalPowerPort;
			port dischargePort : ElectricalPowerPort;
			
			item storedEnergy : ElectricalEnergy {
				attribute voltage : Voltage;
				attribute current : Current;
				attribute power : Power;
			}
		}
		
		part def ChargeController {
			attribute maxChargeCurrent : Current;
			attribute maxDischargeCurrent : Current;
			attribute regulationVoltage : Voltage;
			attribute batteryVoltage : Voltage;
			
			port solarInput : ~ElectricalPowerPort;
			port batteryConnection : ElectricalPowerPort;
			port loadOutput : ElectricalPowerPort;
			
			state def ControllerStates;
			
			state controllerStates : ControllerStates {
				entry; then monitoring;
				
				state monitoring;
				then decide;
					if batteryVoltage < regulationVoltage then charging;
					if batteryVoltage >= regulationVoltage then passthrough;
				
				state charging {
					entry; then regulateCharge;
					state regulateCharge;
					then monitoring;
				}
				
				state passthrough {
					entry; then directSupply;
					state directSupply;
					then monitoring;
				}
			}
		}
		
		part def CentrifugalPump {
			attribute ratedPower : Power;
			attribute maxFlowRate : FlowRate;
			attribute maxPressure : Pressure;
			attribute operatingFlowRate : FlowRate;
			attribute efficiency : Real;
			attribute isOperating : Boolean;
			
			port powerInput : ~ElectricalPowerPort;
			port fluidInlet : FluidInletPort;
			port fluidOutlet : FluidOutletPort;
			
			action def PumpFluid {
				in electricalPower : ElectricalEnergy;
				in inletFluid : Fluid;
				out outletFluid : Fluid;
			}
			
			perform action pumpOperation : PumpFluid {
				in electricalPower = powerInput.electricalPower;
				in inletFluid = fluidInlet.fluidIn;
				out outletFluid = fluidOutlet.fluidOut;
			}
			
			state def PumpStates;
			
			state pumpStates : PumpStates {
				entry; then off;
				
				state off;
				accept PowerAvailableSignal
					then starting;
				
				state starting;
				accept FlowStabilizedSignal
					then running;
				
				state running;
				accept PowerLostSignal
					then stopping;
				accept ShutdownSignal
					then stopping;
				
				state stopping;
				then off;
			}
		}
		
		part def FluidReservoir {
			attribute capacity : Volume;
			attribute currentLevel : Volume;
			attribute fillPercentage : Real;
			attribute minOperatingLevel : Real;
			
			port outlet : FluidOutletPort;
			
			item containedFluid : Fluid {
				attribute volume : Volume;
				attribute pressure : Pressure;
			}
		}
		
		part def StorageTank {
			attribute capacity : Volume;
			attribute currentLevel : Volume;
			attribute fillPercentage : Real;
			attribute maxFillLevel : Real;
			
			port inlet : FluidInletPort;
			
			item receivedFluid : Fluid {
				attribute volume : Volume;
			}
		}
		
		part def PumpController {
			attribute lowBatteryThreshold : Real;
			attribute highBatteryThreshold : Real;
			attribute minSourceLevel : Real;
			attribute maxDestinationLevel : Real;
			attribute batteryLevel : Real;
			
			port batteryMonitor : ~ElectricalPowerPort;
			port pumpControl : ElectricalPowerPort;
			
			state def SystemControlStates;
			
			state systemControl : SystemControlStates parallel {
				state powerManagement {
					entry; then checkingPower;
					
					state checkingPower;
					then decide;
						if batteryLevel >= highBatteryThreshold then sufficientPower;
						if batteryLevel < lowBatteryThreshold then insufficientPower;
					
					state sufficientPower;
					then checkingPower;
					
					state insufficientPower;
					then checkingPower;
				}
				
				state operationControl {
					entry; then idle;
					
					state idle;
					accept StartPumpCommand
						then activating;
					
					state activating;
					then operating;
					
					state operating;
					accept StopPumpCommand
						then deactivating;
					accept LowPowerWarning
						then reducedOperation;
					
					state reducedOperation;
					accept PowerRestored
						then operating;
					accept StopPumpCommand
						then deactivating;
					
					state deactivating;
					then idle;
				}
			}
		}
	}
	
	package InterfaceDefinitions {
		private import PortDefinitions::*;
		
		interface def FluidInterface {
			end port source : FluidOutletPort;
			end port destination : FluidInletPort;
			connect source.fluidOut to destination.fluidIn;
		}
		
		interface def PowerInterface {
			end port supplier : ElectricalPowerPort;
			end port consumer : ~ElectricalPowerPort;
			connect supplier.electricalPower to consumer.electricalPower;
		}
	}
	
	package SystemAssembly {
		private import ValueTypes::*;
		private import ItemDefinitions::*;
		private import PortDefinitions::*;
		private import PartDefinitions::*;
		private import InterfaceDefinitions::*;
		
		part def SolarPumpingSubsystem {
			attribute systemEfficiency : Real;
			attribute dailyFluidTransfer : Volume;
			attribute operatingHoursPerDay : Real;
			
			part solarPanelArray : SolarPanel {
				attribute :>> panelArea = 3.0;
				attribute :>> conversionEfficiency = 0.20;
				attribute :>> maxPowerOutput = 600.0;
			}
			
			part batteryStorage : BatteryBank {
				attribute :>> totalCapacity = 300.0;
				attribute :>> currentCharge = 240.0;
				attribute :>> minChargeLevel = 0.20;
				attribute :>> maxChargeLevel = 0.95;
				attribute :>> nominalVoltage = 24.0;
			}
			
			part chargeControl : ChargeController {
				attribute :>> maxChargeCurrent = 25.0;
				attribute :>> maxDischargeCurrent = 30.0;
				attribute :>> regulationVoltage = 28.8;
			}
			
			part systemController : PumpController {
				attribute :>> lowBatteryThreshold = 22.0;
				attribute :>> highBatteryThreshold = 26.0;
				attribute :>> minSourceLevel = 0.15;
				attribute :>> maxDestinationLevel = 0.90;
			}
			
			part fluidPump : CentrifugalPump {
				attribute :>> ratedPower = 400.0;
				attribute :>> maxFlowRate = 2.5;
				attribute :>> maxPressure = 350000.0;
				attribute :>> efficiency = 0.75;
				attribute :>> isOperating = false;
			}
			
			part sourceReservoir : FluidReservoir {
				attribute :>> capacity = 8000.0;
				attribute :>> currentLevel = 6500.0;
				attribute :>> minOperatingLevel = 0.10;
			}
			
			part destinationTank : StorageTank {
				attribute :>> capacity = 5000.0;
				attribute :>> currentLevel = 1200.0;
				attribute :>> maxFillLevel = 0.95;
			}
			
			interface solarToBattery : PowerInterface connect
				supplier ::> solarPanelArray.powerOutput to
				consumer ::> chargeControl.solarInput;
			
			interface batteryToController : PowerInterface connect
				supplier ::> batteryStorage.dischargePort to
				consumer ::> chargeControl.batteryConnection;
			
			interface controllerToSystem : PowerInterface connect
				supplier ::> chargeControl.loadOutput to
				consumer ::> systemController.batteryMonitor;
			
			interface systemToPump : PowerInterface connect
				supplier ::> systemController.pumpControl to
				consumer ::> fluidPump.powerInput;
			
			interface sourceToFluidPump : FluidInterface connect
				source ::> sourceReservoir.outlet to
				destination ::> fluidPump.fluidInlet;
			
			interface pumpToDestination : FluidInterface connect
				source ::> fluidPump.fluidOutlet to
				destination ::> destinationTank.inlet;
			
			flow of fluid : Fluid
				from sourceReservoir.outlet.fluidOut to fluidPump.fluidInlet.fluidIn;
			
			flow of fluid : Fluid
				from fluidPump.fluidOutlet.fluidOut to destinationTank.inlet.fluidIn;
			
			flow of power : ElectricalEnergy
				from solarPanelArray.powerOutput.electricalPower to chargeControl.solarInput.electricalPower;
			
			flow of power : ElectricalEnergy
				from batteryStorage.dischargePort.electricalPower to chargeControl.batteryConnection.electricalPower;
			
			flow of power : ElectricalEnergy
				from chargeControl.loadOutput.electricalPower to systemController.batteryMonitor.electricalPower;
			
			flow of power : ElectricalEnergy
				from systemController.pumpControl.electricalPower to fluidPump.powerInput.electricalPower;
			
			action systemOperation {
				first start;
				then merge controlLoop;
				
				then action monitorConditions {
					in solarPower : Power;
					in batteryCharge : Real;
					in sourceLevel : Real;
					in destinationLevel : Real;
					out canOperate : Boolean;
				}
				
				then decide;
					if monitorConditions.canOperate then activatePumping;
					if not monitorConditions.canOperate then deactivatePumping;
				
				action activatePumping {
					then action transferFluid {
						in sourceFluid : Fluid;
						in pumpPower : ElectricalEnergy;
						out transferredFluid : Fluid;
					}
					then controlLoop;
				}
				
				action deactivatePumping;
				then controlLoop;
			}
		}
	}
	
	package SystemRequirements {
		private import SystemAssembly::*;
		
		requirement def SolarPumpingSystemRequirement {
			subject subsystem : SolarPumpingSubsystem;
			
			require solarPowered {
				doc /* The subsystem shall operate exclusively using solar energy 
				       with battery storage for continuous operation. */
			}
			
			require fluidTransfer {
				doc /* The subsystem shall transfer fluid from source reservoir 
				       to destination tank at a minimum rate of 2.0 liters per second. */
			}
			
			require autonomousOperation {
				doc /* The subsystem shall operate autonomously based on available 
				       solar power and battery charge level. */
			}
			
			require batteryProtection {
				doc /* The subsystem shall protect battery from over-discharge 
				       by stopping pump operation when charge falls below 20%. */
			}
			
			require sourceProtection {
				doc /* The subsystem shall stop pumping when source reservoir 
				       level falls below 15% to prevent pump damage. */
			}
			
			require destinationProtection {
				doc /* The subsystem shall stop pumping when destination tank 
				       reaches 90% capacity to prevent overflow. */
			}
			
			require efficiency {
				doc /* The subsystem shall achieve minimum overall efficiency 
				       of 60% from solar input to fluid transfer. */
			}
		}
		
		requirement solarPumpingReq : SolarPumpingSystemRequirement {
			subject subsystem = solarPumpingSystem;
		}
		
		part solarPumpingSystem : SolarPumpingSubsystem;
	}
}
