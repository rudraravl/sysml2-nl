package PumpingSubsystem {
	private import ScalarValues::*;
	
	attribute def Pressure {
		attribute num : Real;
		attribute mRef : PressureUnit;
	}
	
	attribute def FlowRate {
		attribute num : Real;
		attribute mRef : FlowRateUnit;
	}
	
	attribute def RotationalSpeed {
		attribute num : Real;
		attribute mRef : RotationalSpeedUnit;
	}
	
	attribute def Temperature {
		attribute num : Real;
		attribute mRef : TemperatureUnit;
	}
	
	attribute def Power {
		attribute num : Real;
		attribute mRef : PowerUnit;
	}
	
	attribute def Torque {
		attribute num : Real;
		attribute mRef : TorqueUnit;
	}
	
	attribute def PressureUnit;
	attribute def FlowRateUnit;
	attribute def RotationalSpeedUnit;
	attribute def TemperatureUnit;
	attribute def PowerUnit;
	attribute def TorqueUnit;
	
	attribute Pa : PressureUnit;
	attribute m3_per_s : FlowRateUnit;
	attribute rpm : RotationalSpeedUnit;
	attribute K : TemperatureUnit;
	attribute W : PowerUnit;
	attribute Nm : TorqueUnit;
	
	item def Fluid {
		attribute pressure : Pressure;
		attribute temperature : Temperature;
		attribute flowRate : FlowRate;
		attribute density : Real;
	}
	
	port def FluidInletPort {
		attribute inletPressure : Pressure;
		attribute inletTemperature : Temperature;
		in item fluidIn : Fluid;
	}
	
	port def FluidOutletPort {
		attribute outletPressure : Pressure;
		attribute outletTemperature : Temperature;
		out item fluidOut : Fluid;
	}
	
	port def PowerInputPort {
		attribute inputPower : Power;
		attribute voltage : Real;
		attribute current : Real;
	}
	
	port def ControlPort {
		in item commandSignal : ControlSignal;
	}
	
	port def TelemetryPort {
		out item telemetryData : TelemetryData;
	}
	
	item def ControlSignal {
		attribute command : String;
		attribute targetSpeed : RotationalSpeed;
	}
	
	item def TelemetryData {
		attribute currentSpeed : RotationalSpeed;
		attribute dischargePressure : Pressure;
		attribute currentFlowRate : FlowRate;
		attribute motorTemperature : Temperature;
	}
	
	part def Impeller {
		attribute bladeCount : Integer;
		attribute diameter : Real;
		attribute rotationSpeed : RotationalSpeed;
		attribute efficiency : Real;
		
		action def GeneratePressure {
			in speed : RotationalSpeed;
			in inletFluid : Fluid;
			out pressureRise : Pressure;
			out outletFluid : Fluid;
		}
	}
	
	part def Motor {
		port powerPort : PowerInputPort;
		attribute motorSpeed : RotationalSpeed;
		attribute efficiency : Real;
		attribute temperature : Temperature;
		
		action def DriveShaft {
			in powerInput : Power;
			out shaftSpeed : RotationalSpeed;
			out outputTorque : Torque;
		}
	}
	
	part def Shaft {
		attribute length : Real;
		attribute diameter : Real;
		attribute rotationSpeed : RotationalSpeed;
		attribute material : String;
		
		action def TransmitTorque {
			in inputTorque : Torque;
			in inputSpeed : RotationalSpeed;
			out outputTorque : Torque;
			out outputSpeed : RotationalSpeed;
		}
	}
	
	part def HousingCasing {
		attribute material : String;
		attribute maxPressureRating : Pressure;
		attribute internalVolume : Real;
		attribute wallThickness : Real;
	}
	
	part def BearingAssembly {
		attribute bearingType : String;
		attribute loadCapacity : Real;
		attribute lubricationType : String;
		attribute operatingTemperature : Temperature;
	}
	
	part def SealAssembly {
		attribute sealType : String;
		attribute maxPressure : Pressure;
		attribute maxTemperature : Temperature;
		
		action def PreventLeakage {
			in operatingPressure : Pressure;
			in operatingTemperature : Temperature;
			out leakageRate : FlowRate;
		}
	}
	
	part def Turbopump {
		port fluidInlet : FluidInletPort;
		port fluidOutlet : FluidOutletPort;
		port motorPower : PowerInputPort;
		port controlInput : ControlPort;
		port telemetryOutput : TelemetryPort;
		
		part motor : Motor {
			port :>> powerPort = motorPower;
		}
		
		part driveshaft : Shaft {
			attribute :>> rotationSpeed = motor.motorSpeed;
			attribute :>> material = "Titanium Alloy";
		}
		
		part impeller : Impeller {
			attribute :>> rotationSpeed = driveshaft.rotationSpeed;
			attribute :>> bladeCount = 6;
			attribute :>> efficiency = 0.85;
		}
		
		part housing : HousingCasing {
			attribute :>> material = "Stainless Steel 316";
			attribute maxPressure : Pressure {
				attribute :>> num = 5000000.0;
				attribute :>> mRef = Pa;
			}
			attribute :>> wallThickness = 0.015;
		}
		
		part bearings : BearingAssembly[2] {
			attribute :>> bearingType = "Ceramic Ball Bearing";
			attribute :>> lubricationType = "Oil Mist";
			attribute :>> loadCapacity = 50000.0;
		}
		
		part seals : SealAssembly {
			attribute :>> sealType = "Mechanical Face Seal";
			attribute maxSealPressure : Pressure {
				attribute :>> num = 3000000.0;
				attribute :>> mRef = Pa;
			}
		}
		
		attribute nominalFlowRate : FlowRate {
			attribute :>> num = 0.5;
			attribute :>> mRef = m3_per_s;
		}
		
		attribute nominalDischargePressure : Pressure {
			attribute :>> num = 2000000.0;
			attribute :>> mRef = Pa;
		}
		
		attribute operatingSpeed : RotationalSpeed {
			attribute :>> num = 3600.0;
			attribute :>> mRef = rpm;
		}
		
		flow fluidFlow from fluidInlet.fluidIn to fluidOutlet.fluidOut;
		
		bind telemetryOutput.telemetryData.currentSpeed = motor.motorSpeed;
		bind telemetryOutput.telemetryData.dischargePressure = fluidOutlet.outletPressure;
		bind telemetryOutput.telemetryData.motorTemperature = motor.temperature;
		
		assert constraint pressureIncrease {
			doc /* Outlet pressure must exceed inlet pressure during operation */
			fluidOutlet.outletPressure.num > fluidInlet.inletPressure.num
		}
		
		assert constraint flowContinuity {
			doc /* Flow rate must be conserved through the pump */
			fluidInlet.fluidIn.flowRate.num == fluidOutlet.fluidOut.flowRate.num
		}
		
		assert constraint sealPressureLimit {
			doc /* Operating pressure must not exceed seal rating */
			fluidOutlet.outletPressure.num <= seals.maxSealPressure.num
		}
	}
	
	action def PumpFluid {
		in inletFluid : Fluid;
		in targetFlowRate : FlowRate;
		out outletFluid : Fluid;
		
		first start;
		then action initializeMotor {
			out motorReady : Boolean;
		}
		then action accelerateImpeller {
			in targetSpeed : RotationalSpeed;
			out currentSpeed : RotationalSpeed;
		}
		then action establishFlow {
			in fluid : Fluid = inletFluid;
			in desiredFlow : FlowRate = targetFlowRate;
			out pumpedFluid : Fluid;
		}
		then merge continueOperation;
		then action monitorOperation {
			in operatingFluid : Fluid;
			out pressureRise : Pressure;
			out flowAchieved : FlowRate;
		}
		then decide;
			if monitorOperation.flowAchieved.num >= targetFlowRate.num then maintainSteadyState;
			if monitorOperation.flowAchieved.num < targetFlowRate.num then adjustSpeed;
		action adjustSpeed {
			in currentFlow : FlowRate = monitorOperation.flowAchieved;
			out newSpeed : RotationalSpeed;
		}
		then continueOperation;
		action maintainSteadyState {
			in steadyFluid : Fluid = monitorOperation.operatingFluid;
			out :>> outletFluid : Fluid;
		}
		then done;
	}
	
	part pumpingSystem {
		attribute turbopumpSpeed : Real;
		attribute dischargePressure : Pressure;
		attribute operatingMode : String;
		
		part turbopump : Turbopump {
			attribute :>> operatingSpeed.num = 3600.0;
			attribute :>> nominalFlowRate.num = 0.5;
			attribute :>> nominalDischargePressure.num = 2000000.0;
		}
		
		part fluidSupplyTank {
			port supplyPort : FluidOutletPort {
				attribute :>> outletPressure.num = 101325.0;
				attribute :>> outletPressure.mRef = Pa;
				attribute :>> outletTemperature.num = 298.0;
				attribute :>> outletTemperature.mRef = K;
			}
		}
		
		part receiverTank {
			port receiverPort : FluidInletPort;
		}
		
		part powerSupply {
			port powerOut : PowerInputPort {
				attribute :>> inputPower.num = 15000.0;
				attribute :>> inputPower.mRef = W;
				attribute :>> voltage = 480.0;
				attribute :>> current = 31.25;
			}
		}
		
		part controlSystem {
			port commandOut : ControlPort;
			port telemetryIn : TelemetryPort;
			
			action controlPump : PumpFluid;
		}
		
		flow supplyFlow from fluidSupplyTank.supplyPort.fluidOut to turbopump.fluidInlet.fluidIn;
		flow dischargeFlow from turbopump.fluidOutlet.fluidOut to receiverTank.receiverPort.fluidIn;
		
		connect powerSupply.powerOut to turbopump.motorPower;
		connect controlSystem.commandOut to turbopump.controlInput;
		connect turbopump.telemetryOutput to controlSystem.telemetryIn;
		
		perform action controlSystem.controlPump;
	}
	
	requirement def PumpPerformanceRequirement {
		subject pump : Turbopump;
		
		doc /* The turbopump shall meet minimum performance specifications */
		
		require constraint minimumFlowRate {
			doc /* Minimum flow rate requirement */
			pump.nominalFlowRate.num >= 0.45
		}
		
		require constraint minimumPressureRise {
			doc /* Minimum discharge pressure requirement */
			pump.nominalDischargePressure.num >= 1800000.0
		}
		
		require constraint maximumOperatingSpeed {
			doc /* Maximum safe operating speed */
			pump.operatingSpeed.num <= 4000.0
		}
		
		require constraint efficiencyRequirement {
			doc /* Minimum pump efficiency */
			pump.impeller.efficiency >= 0.80
		}
	}
	
	requirement def ReliabilityRequirement {
		subject pump : Turbopump;
		
		doc /* The turbopump shall meet reliability and safety requirements */
		
		require constraint sealIntegrity {
			doc /* Seal must withstand operating pressure */
			pump.seals.maxSealPressure.num >= pump.nominalDischargePressure.num
		}
		
		require constraint housingStrength {
			doc /* Housing must have safety factor of 1.5 */
			pump.housing.maxPressure.num >= 1.5 * pump.nominalDischargePressure.num
		}
		
		require constraint bearingLoadCapacity {
			doc /* Bearings must support operational loads */
			pump.bearings.loadCapacity >= 40000.0
		}
	}
	
	requirement pumpSystemRequirements {
		subject system : pumpingSystem;
		
		doc /* Top-level requirements for the pumping subsystem */
		
		requirement performanceReq : PumpPerformanceRequirement {
			subject :>> pump = system.turbopump;
		}
		
		requirement reliabilityReq : ReliabilityRequirement {
			subject :>> pump = system.turbopump;
		}
		
		require constraint continuousOperation {
			doc /* The pumping system shall operate continuously for minimum 10000 hours */
		}
		
		require constraint powerConsumption {
			doc /* Power consumption shall not exceed 20 kW */
			system.powerSupply.powerOut.inputPower.num <= 20000.0
		}
	}
	
	allocation pumpAllocation 
		allocate pumpingSystem.controlSystem.controlPump 
		to pumpingSystem.turbopump {
		allocate pumpingSystem.controlSystem.controlPump.establishFlow 
			to pumpingSystem.turbopump.impeller;
		allocate pumpingSystem.controlSystem.controlPump.initializeMotor 
			to pumpingSystem.turbopump.motor;
	}
}
