package 'Rotodynamic Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		item def Fluid {
			attribute density : Real;
			attribute viscosity : Real;
			attribute temperature : Real;
			attribute pressure : Real;
		}
		
		port def FluidPort {
			attribute pressure : Real;
			attribute flowRate : Real;
			out item fluidOut : Fluid;
			in item fluidIn : Fluid;
		}
		
		port def PowerPort {
			attribute voltage : Real;
			attribute current : Real;
			attribute power : Real;
		}
		
		part def Impeller {
			attribute diameter : Real;
			attribute bladeCount : Integer;
			attribute rotationalSpeed : Real;
			attribute efficiency : Real;
		}
		
		part def Volute {
			attribute inletDiameter : Real;
			attribute outletDiameter : Real;
		}
		
		part def Shaft {
			attribute diameter : Real;
			attribute length : Real;
			attribute material : String;
			attribute torque : Real;
		}
		
		part def Bearing {
			attribute type : String;
			attribute loadCapacity : Real;
		}
		
		part def MechanicalSeal {
			attribute type : String;
			attribute material : String;
			attribute leakageRate : Real;
		}
		
		part def ElectricMotor {
			port powerInput : PowerPort;
			attribute ratedPower : Real;
			attribute ratedSpeed : Real;
			attribute efficiency : Real;
			attribute currentSpeed : Real;
		}
		
		part def RotodynamicPump {
			port inletPort : FluidPort;
			port outletPort : FluidPort;
			
			part impeller : Impeller;
			part volute : Volute;
			part shaft : Shaft;
			part inletBearing : Bearing;
			part outletBearing : Bearing;
			part seal : MechanicalSeal;
			
			attribute headPressure : Real;
			attribute flowRate : Real;
			attribute hydraulicEfficiency : Real;
			attribute mechanicalEfficiency : Real;
			attribute overallEfficiency : Real;
			
			assert constraint efficiencyRelation {
				overallEfficiency == hydraulicEfficiency * mechanicalEfficiency
			}
			
			assert constraint flowContinuity {
				inletPort.flowRate == outletPort.flowRate
			}
			
			assert constraint pressureIncrease {
				outletPort.pressure == inletPort.pressure + headPressure
			}
		}
		
		part def SupplyReservoir {
			port outletPort : FluidPort;
			attribute capacity : Real;
			attribute currentLevel : Real;
			item storedFluid : Fluid;
		}
		
		part def DischargeReservoir {
			port inletPort : FluidPort;
			attribute capacity : Real;
			attribute currentLevel : Real;
			item receivedFluid : Fluid;
		}
		
		part def PressureSensor {
			attribute measuredPressure : Real;
			attribute accuracy : Real;
		}
		
		part def FlowSensor {
			attribute measuredFlowRate : Real;
			attribute accuracy : Real;
		}
		
		part def ControlValve {
			attribute position : Real;
			attribute maxFlowCoefficient : Real;
		}
		
		part def PumpController {
			attribute targetFlowRate : Real;
			attribute targetPressure : Real;
			attribute controlMode : String;
		}
		
		action def StartPump {
			in initialSpeed : Real;
			out finalSpeed : Real;
		}
		
		action def StopPump {
			in currentSpeed : Real;
			out finalSpeed : Real;
		}
		
		action def RegulateFlow {
			in targetFlow : Real;
			in currentFlow : Real;
			out valvePosition : Real;
		}
		
		action def MonitorPressure {
			in sensorReading : Real;
			out status : String;
		}
		
		action def PumpOperation {
			first start;
			then merge operating;
			action startSequence : StartPump;
			then operating;
			action regulate : RegulateFlow;
			action monitor : MonitorPressure;
			then decide;
				if monitor.status == "critical" then shutdown;
			action shutdown : StopPump;
			then done;
		}
		
		requirement def PumpPerformanceRequirement {
			subject pump : RotodynamicPump;
			
			require constraint minFlowRate {
				pump.flowRate >= 50.0
			}
			
			require constraint minHeadPressure {
				pump.headPressure >= 2.0
			}
			
			require constraint minEfficiency {
				pump.overallEfficiency >= 0.70
			}
		}
		
		requirement def SystemReliabilityRequirement {
			doc /* The pumping subsystem shall operate continuously for at least 8000 hours between maintenance intervals. */
		}
	}
	
	package Usages {
		part pumpingSubsystem {
			part supplyTank : Definitions::SupplyReservoir {
				attribute redefines capacity = 5000.0;
				attribute redefines currentLevel = 4200.0;
				
				item redefines storedFluid : Definitions::Fluid {
					attribute redefines density = 998.0;
					attribute redefines viscosity = 0.001;
					attribute redefines temperature = 20.0;
					attribute redefines pressure = 1.0;
				}
			}
			
			part pump : Definitions::RotodynamicPump {
				attribute redefines headPressure = 3.5;
				attribute redefines flowRate = 100.0;
				attribute redefines hydraulicEfficiency = 0.82;
				attribute redefines mechanicalEfficiency = 0.92;
				attribute redefines overallEfficiency = 0.75;
				
				part redefines impeller {
					attribute redefines diameter = 250.0;
					attribute redefines bladeCount = 6;
					attribute redefines rotationalSpeed = 1450.0;
					attribute redefines efficiency = 0.82;
				}
				
				part redefines volute {
					attribute redefines inletDiameter = 100.0;
					attribute redefines outletDiameter = 80.0;
				}
				
				part redefines shaft {
					attribute redefines diameter = 40.0;
					attribute redefines length = 300.0;
					attribute redefines material = "Stainless Steel 316";
					attribute redefines torque = 150.0;
				}
				
				part redefines inletBearing {
					attribute redefines type = "Ball Bearing";
					attribute redefines loadCapacity = 5000.0;
				}
				
				part redefines outletBearing {
					attribute redefines type = "Ball Bearing";
					attribute redefines loadCapacity = 5000.0;
				}
				
				part redefines seal {
					attribute redefines type = "Mechanical Face Seal";
					attribute redefines material = "Silicon Carbide";
					attribute redefines leakageRate = 0.01;
				}
				
				perform action pumpOp : Definitions::PumpOperation;
			}
			
			part motor : Definitions::ElectricMotor {
				attribute redefines ratedPower = 15.0;
				attribute redefines ratedSpeed = 1450.0;
				attribute redefines efficiency = 0.92;
				attribute redefines currentSpeed = 1450.0;
				
				port redefines powerInput {
					attribute redefines voltage = 400.0;
					attribute redefines current = 25.0;
					attribute redefines power = 15.0;
				}
			}
			
			part dischargeTank : Definitions::DischargeReservoir {
				attribute redefines capacity = 3000.0;
				attribute redefines currentLevel = 1500.0;
				
				item redefines receivedFluid : Definitions::Fluid {
					attribute redefines density = 998.0;
					attribute redefines viscosity = 0.001;
					attribute redefines temperature = 22.0;
					attribute redefines pressure = 4.5;
				}
			}
			
			part inletSensor : Definitions::PressureSensor {
				attribute redefines measuredPressure = 1.0;
				attribute redefines accuracy = 0.5;
			}
			
			part dischargeSensor : Definitions::PressureSensor {
				attribute redefines measuredPressure = 4.5;
				attribute redefines accuracy = 0.5;
			}
			
			part flowMeter : Definitions::FlowSensor {
				attribute redefines measuredFlowRate = 100.0;
				attribute redefines accuracy = 1.0;
			}
			
			part controlValve : Definitions::ControlValve {
				attribute redefines position = 0.75;
				attribute redefines maxFlowCoefficient = 150.0;
			}
			
			part controller : Definitions::PumpController {
				attribute redefines targetFlowRate = 100.0;
				attribute redefines targetPressure = 4.5;
				attribute redefines controlMode = "Constant Flow";
			}
			
			flow of fluid : Definitions::Fluid
				from supplyTank.outletPort.fluidOut 
				to pump.inletPort.fluidIn;
			
			flow of fluid : Definitions::Fluid
				from pump.outletPort.fluidOut 
				to dischargeTank.inletPort.fluidIn;
			
			connection motorDrive from motor to pump.shaft;
			
			satisfy performanceReq : Definitions::PumpPerformanceRequirement {
				subject pump = pump;
			}
			
			satisfy reliabilityReq : Definitions::SystemReliabilityRequirement;
		}
	}
}
