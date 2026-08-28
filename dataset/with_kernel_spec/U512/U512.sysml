package ClosedLoopFluidCirculationSystem {
	item def Fluid;
	item def WaterGlycolMixture :> Fluid;
	item def FlowRateData {
		attribute value :> ISQ::volumeFlowRate;
	}
	item def PressureData {
		attribute value :> ISQ::pressure;
	}
	item def TemperatureData {
		attribute value :> ISQ::temperature;
	}
	item def SpeedCommand {
		attribute targetSpeed : ScalarValues::Real;
	}

	port def FluidInPort {
		in fluid : Fluid;
	}
	port def FluidOutPort {
		out fluid : Fluid;
	}
	port def ControlOutPort {
		out command : SpeedCommand;
	}
	port def ControlInPort {
		in command : SpeedCommand;
	}
	port def SensorDataOutPort {
		out measuredValue : ScalarValues::Real;
	}
	port def SensorDataInPort {
		in measuredValue : ScalarValues::Real;
	}

	action def CirculateFluid {
		action pumpFluid : PumpFluid;
		then action transferHeat : TransferHeat;
		then action returnFluid : ReturnFluid;
		flow from pumpFluid.discharge to transferHeat.intake;
		flow from transferHeat.outflow to returnFluid.inlet;
	}
	action def PumpFluid {
		in inlet : WaterGlycolMixture;
		out discharge : WaterGlycolMixture;
	}
	action def TransferHeat {
		in intake : WaterGlycolMixture;
		out outflow : WaterGlycolMixture;
	}
	action def ReturnFluid {
		in inlet : WaterGlycolMixture;
	}
	action def ControlPump {
		in flowRateData : FlowRateData;
		in pressureData : PressureData;
		in temperatureData : TemperatureData;
		out speedCommand : SpeedCommand;
	}
	action def SenseFlowRate {
		out flowRateData : FlowRateData;
	}
	action def SensePressure {
		out pressureData : PressureData;
	}
	action def SenseTemperature {
		out temperatureData : TemperatureData;
	}
	action def DetectCavitation {
		out cavitationDetected : ScalarValues::Boolean;
	}

	state def OperationalStates {
		attribute startSignal : ScalarValues::Boolean;
		attribute primingComplete : ScalarValues::Boolean;
		attribute stopSignal : ScalarValues::Boolean;
		attribute cavitationDetected : ScalarValues::Boolean;
		attribute faultCleared : ScalarValues::Boolean;
		attribute highDemand : ScalarValues::Boolean;
		attribute lowDemand : ScalarValues::Boolean;
		attribute normalDemand : ScalarValues::Boolean;

		state idle;
		state priming;
		state normalCirculation;
		state highDemandOperation;
		state lowDemandOperation;
		state safeShutdown;
		state faultHandling;

		transition from idle to priming when startSignal;
		transition from priming to normalCirculation when primingComplete;
		transition from normalCirculation to highDemandOperation when highDemand;
		transition from normalCirculation to lowDemandOperation when lowDemand;
		transition from highDemandOperation to normalCirculation when normalDemand;
		transition from lowDemandOperation to normalCirculation when normalDemand;
		transition from normalCirculation to faultHandling when cavitationDetected;
		transition from highDemandOperation to faultHandling when cavitationDetected;
		transition from lowDemandOperation to faultHandling when cavitationDetected;
		transition from faultHandling to safeShutdown when faultCleared;
		transition from normalCirculation to safeShutdown when stopSignal;
		transition from safeShutdown to idle when faultCleared;
	}

	part def ElectricMotor {
		port controlIn : ControlInPort;
		attribute ratedPower :> ISQ::power;
		attribute ratedSpeed : ScalarValues::Real;
	}
	part def Impeller {
		attribute bladeCount : ScalarValues::Integer = 5;
		attribute material : ScalarValues::String = "Stainless Steel";
	}
	part def MagneticBearingAssembly {
		attribute sealless : ScalarValues::Boolean = true;
		attribute levitationForce :> ISQ::force;
	}
	part def PumpCasing {
		attribute material : ScalarValues::String = "Stainless Steel";
		port fluidIn : FluidInPort;
		port fluidOut : FluidOutPort;
	}
	part def CirculatingPump {
		port fluidIn : FluidInPort;
		port fluidOut : FluidOutPort;
		port controlIn : ControlInPort;
		part motor : ElectricMotor;
		part impeller : Impeller;
		part magneticBearing : MagneticBearingAssembly;
		part casing : PumpCasing;
		perform action pumpFluid : PumpFluid;
	}
	part def FluidReservoir {
		port fluidOut : FluidOutPort;
		port fluidReturn : FluidInPort;
		attribute capacity :> ISQ::volume;
		item coolant : WaterGlycolMixture;
	}
	part def HeatExchanger {
		port fluidIn : FluidInPort;
		port fluidOut : FluidOutPort;
		attribute heatTransferRate :> ISQ::power;
		perform action transferHeat : TransferHeat;
	}
	part def FlowSensor {
		port fluidSample : FluidInPort;
		port dataOut : SensorDataOutPort;
		attribute measuredFlowRate :> ISQ::volumeFlowRate;
		perform action senseFlowRate : SenseFlowRate;
	}
	part def PressureSensor {
		port fluidSample : FluidInPort;
		port dataOut : SensorDataOutPort;
		attribute measuredPressure :> ISQ::pressure;
		perform action sensePressure : SensePressure;
	}
	part def TemperatureSensor {
		port fluidSample : FluidInPort;
		port dataOut : SensorDataOutPort;
		attribute measuredTemperature :> ISQ::temperature;
		perform action senseTemperature : SenseTemperature;
	}
	part def PumpController {
		port flowDataIn : SensorDataInPort;
		port pressureDataIn : SensorDataInPort;
		port temperatureDataIn : SensorDataInPort;
		port controlOut : ControlOutPort;
		perform action controlPump : ControlPump;
		perform action detectCavitation : DetectCavitation;
		exhibit state controllerStates : OperationalStates;
	}
	part def FluidCirculationSystem {
		part reservoir : FluidReservoir;
		part pump : CirculatingPump;
		part heatExchanger : HeatExchanger;
		part controller : PumpController;
		part flowSensor : FlowSensor;
		part pressureSensor : PressureSensor;
		part temperatureSensor : TemperatureSensor;
		perform action circulateFluid : CirculateFluid;
		exhibit state systemStates : OperationalStates;
		connect reservoir.fluidOut to pump.fluidIn;
		connect pump.fluidOut to heatExchanger.fluidIn;
		connect heatExchanger.fluidOut to reservoir.fluidReturn;
		connect pump.fluidOut to flowSensor.fluidSample;
		connect pump.fluidOut to pressureSensor.fluidSample;
		connect heatExchanger.fluidOut to temperatureSensor.fluidSample;
		connect flowSensor.dataOut to controller.flowDataIn;
		connect pressureSensor.dataOut to controller.pressureDataIn;
		connect temperatureSensor.dataOut to controller.temperatureDataIn;
		connect controller.controlOut to pump.controlIn;
	}

	requirement def HighEfficiency {
		doc /* System efficiency shall exceed 85 percent under normal operating conditions */
		subject system : FluidCirculationSystem;
		attribute minEfficiency : ScalarValues::Real = 0.85;
	}
	requirement def LeakPrevention {
		doc /* Glandless magnetic bearing design eliminates fluid leakage */
		subject pump : CirculatingPump;
		assert constraint {
			pump.magneticBearing.sealless == true
		}
	}
	requirement def LowMaintenance {
		doc /* Maintenance interval of at least 365 days */
		subject system : FluidCirculationSystem;
		attribute maintenanceIntervalDays : ScalarValues::Integer = 365;
	}
	requirement def ContinuousOperation {
		doc /* Capable of continuous 24/7 duty */
		subject system : FluidCirculationSystem;
	}
	requirement def FlowRateControl {
		doc /* Controller adjusts motor speed to meet flow rate demand */
		subject controller : PumpController;
	}
	requirement def CavitationProtection {
		doc /* Detect cavitation and perform safe shutdown */
		subject controller : PumpController;
	}
	requirement def SystemSpecification {
		doc /* Overall system requirements group */
		subject system : FluidCirculationSystem;
	}

	part fluidCirculationSystem : FluidCirculationSystem;

	requirement systemSpecification : SystemSpecification {
		doc /* Closed-loop fluid circulation system specification */
		subject = fluidCirculationSystem;
		requirement highEfficiency : HighEfficiency {
			subject = fluidCirculationSystem;
		}
		requirement leakPrevention : LeakPrevention {
			subject = fluidCirculationSystem.pump;
		}
		requirement lowMaintenance : LowMaintenance {
			subject = fluidCirculationSystem;
		}
		requirement continuousOperation : ContinuousOperation {
			subject = fluidCirculationSystem;
		}
		requirement flowRateControl : FlowRateControl {
			subject = fluidCirculationSystem.controller;
		}
		requirement cavitationProtection : CavitationProtection {
			subject = fluidCirculationSystem.controller;
		}
	}
}
