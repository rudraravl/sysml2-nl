package 'ScrewPumpSubsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		item def Fluid {
			attribute density : Real;
			attribute viscosity : Real;
			attribute temperature : Real;
			attribute volume : Real;
		}
		
		attribute def FlowRate {
			attribute num : Real;
			attribute unit : String;
		}
		
		attribute def Pressure {
			attribute num : Real;
			attribute unit : String;
		}
		
		attribute def RotationalSpeed {
			attribute num : Real;
			attribute unit : String;
		}
		
		attribute def Torque {
			attribute num : Real;
			attribute unit : String;
		}
		
		port def FluidInletPort {
			attribute inletPressure : Pressure;
			in item fluidIn : Fluid;
		}
		
		port def FluidOutletPort {
			attribute outletPressure : Pressure;
			out item fluidOut : Fluid;
		}
		
		port def DriveShaftPort {
			attribute shaftSpeed : RotationalSpeed;
			attribute shaftTorque : Torque;
		}
		
		part def ScrewRotor {
			attribute numberOfThreads : Integer;
			attribute threadPitch : Real;
			attribute rotorDiameter : Real;
			attribute rotorLength : Real;
			attribute currentSpeed : RotationalSpeed;
		}
		
		part def PumpCasing {
			attribute innerDiameter : Real;
			attribute casingLength : Real;
			port inletPort : FluidInletPort;
			port outletPort : FluidOutletPort;
		}
		
		action def TransportFluid {
			in fluidIn : Fluid;
			in rotorSpeed : RotationalSpeed;
			out fluidOut : Fluid;
			out achievedFlowRate : FlowRate;
			
			action captureFluid {
				in fluid : Fluid;
				out capturedFluid : Fluid;
			}
			
			action conveyFluid {
				in fluid : Fluid;
				in speed : RotationalSpeed;
				out conveyedFluid : Fluid;
			}
			
			action dischargeFluid {
				in fluid : Fluid;
				out discharged : Fluid;
			}
			
			first start;
			then captureFluid;
			then conveyFluid;
			then dischargeFluid;
			then done;
		}
		
		part def ScrewPump {
			attribute nominalFlowRate : FlowRate;
			attribute maxDischargePressure : Pressure;
			attribute efficiency : Real;
			attribute currentFlowRate : FlowRate;
			
			port inletPort : FluidInletPort;
			port outletPort : FluidOutletPort;
			port driveShaftPort : ~DriveShaftPort;
			
			part rotor : ScrewRotor;
			part casing : PumpCasing;
			
			binding inletBinding of inletPort = casing.inletPort;
			binding outletBinding of outletPort = casing.outletPort;
			
			perform action transportFluid : TransportFluid {
				in fluidIn = inletPort.fluidIn;
				in rotorSpeed = driveShaftPort.shaftSpeed;
				out fluidOut = outletPort.fluidOut;
				out achievedFlowRate = currentFlowRate;
			}
			
			assert constraint flowRateConstraint {
				currentFlowRate.num <= nominalFlowRate.num * 1.10
			}
			
			assert constraint pressureConstraint {
				outletPort.outletPressure.num - inletPort.inletPressure.num <= maxDischargePressure.num
			}
		}
		
		part def ElectricMotor {
			attribute ratedPower : Real;
			attribute nominalSpeed : RotationalSpeed;
			attribute currentSpeed : RotationalSpeed;
			attribute outputTorque : Torque;
			
			port shaftPort : DriveShaftPort;
			
			perform action driveShaft {
				out speed : RotationalSpeed = currentSpeed;
				out torque : Torque = outputTorque;
			}
		}
		
		part def SupplyTank {
			attribute capacity : Real;
			attribute currentLevel : Real;
			
			port outletPort : FluidOutletPort;
			
			item storedFluid : Fluid {
				attribute volume : Real;
			}
			
			assert constraint levelConstraint {
				currentLevel <= capacity
			}
		}
		
		part def ReceivingTank {
			attribute capacity : Real;
			attribute currentLevel : Real;
			
			port inletPort : FluidInletPort;
			
			item receivedFluid : Fluid {
				attribute volume : Real;
			}
		}
		
		part def FlowMeter {
			attribute measuredFlowRate : FlowRate;
			port sensingPort : FluidInletPort;
		}
		
		part def PressureGauge {
			attribute measuredPressure : Pressure;
			port sensingPort : FluidInletPort;
		}
		
		requirement def FlowCapabilityRequirement {
			doc /* The screw pump shall deliver fluid at the specified nominal flow rate. */
			
			subject pump : ScrewPump;
			
			require constraint {
				pump.currentFlowRate.num >= pump.nominalFlowRate.num * 0.95 and
				pump.currentFlowRate.num <= pump.nominalFlowRate.num * 1.05
			}
		}
		
		requirement def PressureCapabilityRequirement {
			doc /* The screw pump shall maintain discharge pressure within rated limits. */
			
			subject pump : ScrewPump;
			
			require constraint {
				(pump.outletPort.outletPressure.num - pump.inletPort.inletPressure.num) <= 
				pump.maxDischargePressure.num
			}
		}
		
		requirement def EfficiencyRequirement {
			doc /* The screw pump shall operate at minimum volumetric efficiency. */
			
			subject pump : ScrewPump;
			
			require constraint {
				pump.efficiency >= 0.75
			}
		}
	}
	
	package Usages {
		part pumpingSystem {
			part supplyTank : SupplyTank {
				attribute :>> capacity = 10000.0;
				attribute :>> currentLevel = 8500.0;
				
				item :>> storedFluid {
					attribute :>> density = 998.0;
					attribute :>> viscosity = 0.001002;
					attribute :>> temperature = 293.15;
					attribute :>> volume = 8500.0;
				}
			}
			
			part driveMotor : ElectricMotor {
				attribute :>> ratedPower = 11000.0;
				attribute :>> nominalSpeed {
					attribute :>> num = 1450.0;
					attribute :>> unit = "rpm";
				}
				attribute :>> currentSpeed {
					attribute :>> num = 1450.0;
					attribute :>> unit = "rpm";
				}
				attribute :>> outputTorque {
					attribute :>> num = 72.4;
					attribute :>> unit = "N*m";
				}
			}
			
			part screwPump : ScrewPump {
				attribute :>> nominalFlowRate {
					attribute :>> num = 150.0;
					attribute :>> unit = "L/min";
				}
				attribute :>> maxDischargePressure {
					attribute :>> num = 600000.0;
					attribute :>> unit = "Pa";
				}
				attribute :>> efficiency = 0.82;
				attribute :>> currentFlowRate {
					attribute :>> num = 150.0;
					attribute :>> unit = "L/min";
				}
				
				part :>> rotor {
					attribute :>> numberOfThreads = 2;
					attribute :>> threadPitch = 0.12;
					attribute :>> rotorDiameter = 0.10;
					attribute :>> rotorLength = 0.80;
					attribute :>> currentSpeed {
						attribute :>> num = 1450.0;
						attribute :>> unit = "rpm";
					}
				}
				
				part :>> casing {
					attribute :>> innerDiameter = 0.102;
					attribute :>> casingLength = 0.85;
				}
			}
			
			part receivingTank : ReceivingTank {
				attribute :>> capacity = 5000.0;
				attribute :>> currentLevel = 1200.0;
			}
			
			part inletFlowMeter : FlowMeter {
				attribute :>> measuredFlowRate {
					attribute :>> num = 150.0;
					attribute :>> unit = "L/min";
				}
			}
			
			part dischargePressureGauge : PressureGauge {
				attribute :>> measuredPressure {
					attribute :>> num = 550000.0;
					attribute :>> unit = "Pa";
				}
			}
			
			part suctionPressureGauge : PressureGauge {
				attribute :>> measuredPressure {
					attribute :>> num = 101325.0;
					attribute :>> unit = "Pa";
				}
			}
			
			connect supplyTank.outletPort to screwPump.inletPort;
			
			binding motorShaftBinding of driveMotor.shaftPort = screwPump.driveShaftPort;
			
			connect screwPump.outletPort to receivingTank.inletPort;
			
			flow of fluid : Fluid
				from supplyTank.outletPort.fluidOut 
				to screwPump.inletPort.fluidIn;
			
			flow of fluid : Fluid
				from screwPump.outletPort.fluidOut 
				to receivingTank.inletPort.fluidIn;
			
			succession motorStart then pumpStart
				first driveMotor.driveShaft
				then screwPump.transportFluid;
		}
		
		requirement flowCapability : FlowCapabilityRequirement {
			subject pump = pumpingSystem.screwPump;
		}
		
		requirement pressureCapability : PressureCapabilityRequirement {
			subject pump = pumpingSystem.screwPump;
		}
		
		requirement pumpEfficiency : EfficiencyRequirement {
			subject pump = pumpingSystem.screwPump;
		}
		
		satisfy flowCapability by pumpingSystem.screwPump;
		satisfy pressureCapability by pumpingSystem.screwPump;
		satisfy pumpEfficiency by pumpingSystem.screwPump;
	}
}
