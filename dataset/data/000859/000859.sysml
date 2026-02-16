package ChopperPumpingSubsystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		item def Fluid {
			attribute viscosity : Real;
			attribute density : Real;
			attribute temperature : Real;
			attribute volume : Real;
		}
		
		attribute def VolumeValue :> Real;
		attribute def VolumeFlowRateValue :> Real;
		attribute def PressureValue :> Real;
		attribute def PowerValue :> Real;
		attribute def RotationalSpeedValue :> Real;
		
		port def FluidInletPort {
			in item fluidIn : Fluid;
			attribute inletPressure : PressureValue;
		}
		
		port def FluidOutletPort {
			out item fluidOut : Fluid;
			attribute outletPressure : PressureValue;
		}
		
		port def PowerPort {
			in attribute powerSupply : PowerValue;
			in attribute voltage : Real;
			in attribute current : Real;
		}
		
		port def ControlPort {
			in attribute startCommand : Boolean;
			in attribute stopCommand : Boolean;
			in attribute speedSetpoint : RotationalSpeedValue;
			out attribute operatingStatus : Boolean;
			out attribute actualSpeed : RotationalSpeedValue;
		}
		
		action def ChopAndPropel {
			in fluidInput : Fluid;
			in targetSpeed : RotationalSpeedValue;
			out choppedFluid : Fluid;
			out actualSpeed : RotationalSpeedValue;
		}
		
		action def DriveShaft {
			in electricalPower : PowerValue;
			in targetSpeed : RotationalSpeedValue;
			out mechanicalSpeed : RotationalSpeedValue;
			out mechanicalTorque : Real;
		}
		
		part def ChopperImpeller {
			attribute numberOfBlades : Integer;
			attribute bladeThickness : Real;
			attribute impellerDiameter : Real;
			attribute rotationalSpeed : RotationalSpeedValue;
			attribute maxSpeed : RotationalSpeedValue;
		}
		
		part def ElectricMotor {
			port powerInput : PowerPort;
			attribute ratedPower : PowerValue;
			attribute efficiency : Real;
			attribute outputSpeed : RotationalSpeedValue;
			attribute outputTorque : Real;
		}
		
		part def PumpCasing {
			port inletPort : FluidInletPort;
			port outletPort : FluidOutletPort;
			attribute casingMaterial : String;
			attribute maxPressureRating : PressureValue;
			attribute internalVolume : VolumeValue;
		}
		
		action def PumpingOperation {
			in fluidInput : Fluid;
			in powerInput : PowerValue;
			in speedSetpoint : RotationalSpeedValue;
			out fluidOutput : Fluid;
			out flowRate : VolumeFlowRateValue;
			
			first start;
			then action initializePump;
			then merge operatingLoop;
			
			action chopFluid {
				in rawFluid : Fluid;
				out choppedFluid : Fluid;
			}
			
			then action pressurizeFluid {
				in choppedFluid : Fluid;
				in speed : RotationalSpeedValue;
				out pressurizedFluid : Fluid;
				out achievedFlowRate : VolumeFlowRateValue;
			}
			
			then operatingLoop;
			then done;
		}
		
		part def ChopperPump {
			port fluidInlet : FluidInletPort;
			port fluidOutlet : FluidOutletPort;
			port powerPort : PowerPort;
			port controlPort : ControlPort;
			
			attribute designFlowRate : VolumeFlowRateValue;
			attribute maxHeadPressure : PressureValue;
			attribute isOperating : Boolean;
			
			part casing : PumpCasing {
				attribute :>> casingMaterial = "Stainless Steel 316";
				attribute :>> maxPressureRating = 1000000.0;
				attribute :>> internalVolume = 0.05;
			}
			
			part impeller : ChopperImpeller {
				attribute :>> numberOfBlades = 4;
				attribute :>> bladeThickness = 0.008;
				attribute :>> impellerDiameter = 0.25;
				attribute :>> maxSpeed = 1800.0;
			}
			
			part motor : ElectricMotor {
				attribute :>> ratedPower = 7500.0;
				attribute :>> efficiency = 0.92;
			}
			
			connection motorToImpeller connect motor to impeller;
			
			bind fluidInlet = casing.inletPort;
			bind fluidOutlet = casing.outletPort;
			bind powerPort = motor.powerInput;
			
			flow of processedFluid : Fluid 
				from casing.inletPort.fluidIn 
				to casing.outletPort.fluidOut;
			
			perform action pumpOperation : PumpingOperation;
		}
		
		part def FluidReservoir {
			port outletPort : FluidOutletPort;
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			
			item storedFluid : Fluid {
				attribute :>> volume = currentLevel;
			}
		}
		
		part def DischargeVessel {
			port inletPort : FluidInletPort;
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			
			item receivedFluid : Fluid;
		}
		
		part def PipingSection {
			port inlet : FluidInletPort;
			port outlet : FluidOutletPort;
			attribute length : Real;
			attribute diameter : Real;
			attribute material : String;
		}
		
		requirement def PumpPerformanceRequirement {
			doc /* The chopper pump shall meet specified performance criteria */
			
			subject pump : ChopperPump;
			
			require minFlowRate : MinimumFlowRateRequirement;
			require maxPressure : MaximumPressureRequirement;
			require efficiency : EfficiencyRequirement;
		}
		
		requirement def MinimumFlowRateRequirement {
			doc /* The pump shall deliver a minimum flow rate of 100 liters per minute */
			
			attribute requiredFlowRate : VolumeFlowRateValue = 0.00167;
		}
		
		requirement def MaximumPressureRequirement {
			doc /* The pump shall generate a maximum discharge pressure of 10 bar */
			
			attribute maxAllowablePressure : PressureValue = 1000000.0;
		}
		
		requirement def EfficiencyRequirement {
			doc /* The pump system shall operate at a minimum efficiency of 85 percent */
			
			attribute minEfficiency : Real = 0.85;
		}
	}
	
	package Usages {
		part pumpingSubsystem {
			part sourceReservoir : Definitions::FluidReservoir {
				attribute :>> capacity = 5.0;
				attribute :>> currentLevel = 3.5;
				
				item :>> storedFluid : Definitions::Fluid {
					attribute :>> viscosity = 0.001;
					attribute :>> density = 1000.0;
					attribute :>> temperature = 20.0;
					attribute :>> volume = 3.5;
				}
			}
			
			part suctionPipe : Definitions::PipingSection {
				attribute :>> length = 5.0;
				attribute :>> diameter = 0.1;
				attribute :>> material = "Stainless Steel 316";
			}
			
			part chopperPump : Definitions::ChopperPump {
				attribute :>> designFlowRate = 0.00167;
				attribute :>> maxHeadPressure = 1000000.0;
				attribute :>> isOperating = false;
				
				part :>> impeller {
					attribute :>> rotationalSpeed = 1450.0;
				}
				
				part :>> motor {
					attribute :>> outputSpeed = 1450.0;
					attribute :>> outputTorque = 49.3;
				}
			}
			
			part dischargePipe : Definitions::PipingSection {
				attribute :>> length = 10.0;
				attribute :>> diameter = 0.08;
				attribute :>> material = "Stainless Steel 316";
			}
			
			part destinationVessel : Definitions::DischargeVessel {
				attribute :>> capacity = 3.0;
				attribute :>> currentLevel = 0.5;
			}
			
			flow of transferFluid : Definitions::Fluid 
				from sourceReservoir.outletPort.fluidOut 
				to suctionPipe.inlet.fluidIn;
			
			flow of suctionFluid : Definitions::Fluid 
				from suctionPipe.outlet.fluidOut 
				to chopperPump.fluidInlet.fluidIn;
			
			flow of dischargeFluid : Definitions::Fluid 
				from chopperPump.fluidOutlet.fluidOut 
				to dischargePipe.inlet.fluidIn;
			
			flow of deliveredFluid : Definitions::Fluid 
				from dischargePipe.outlet.fluidOut 
				to destinationVessel.inletPort.fluidIn;
			
			requirement pumpPerformance : Definitions::PumpPerformanceRequirement {
				subject pump = chopperPump;
				
				require :>> minFlowRate {
					attribute :>> requiredFlowRate = 0.00167;
				}
				
				require :>> maxPressure {
					attribute :>> maxAllowablePressure = 1000000.0;
				}
				
				require :>> efficiency {
					attribute :>> minEfficiency = 0.85;
				}
			}
			
			assert constraint flowRateConstraint {
				chopperPump.designFlowRate >= pumpPerformance.minFlowRate.requiredFlowRate
			}
			
			assert constraint pressureConstraint {
				chopperPump.maxHeadPressure <= pumpPerformance.maxPressure.maxAllowablePressure
			}
			
			assert constraint efficiencyConstraint {
				chopperPump.motor.efficiency >= pumpPerformance.efficiency.minEfficiency
			}
		}
	}
}
