package 'Hydrocarbon Dew Point Control System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def HydrocarbonDewPointValue :> TemperatureValue;
	attribute def CompositionFraction :> Real;
	
	item def NaturalGasStream {
		attribute temperature : TemperatureValue;
		attribute pressure : PressureValue;
		attribute flowRate : VolumeFlowRateValue;
		attribute methane : CompositionFraction;
		attribute ethane : CompositionFraction;
		attribute propane : CompositionFraction;
		attribute butane : CompositionFraction;
		attribute pentanePlus : CompositionFraction;
		attribute hydrocarbonDewPoint : HydrocarbonDewPointValue;
	}
	
	item def ProcessedGasStream :> NaturalGasStream;
	item def CondensateLiquid {
		attribute temperature : TemperatureValue;
		attribute flowRate : VolumeFlowRateValue;
		attribute hydrocarbonContent : CompositionFraction;
	}
	
	port def GasInletPort {
		in item rawGas : NaturalGasStream;
	}
	
	port def GasOutletPort {
		out item processedGas : ProcessedGasStream;
	}
	
	port def CondensatePort {
		out item condensate : CondensateLiquid;
	}
	
	port def RefrigerantPort {
		in attribute refrigerantTemp : TemperatureValue;
		out attribute returnTemp : TemperatureValue;
	}
	
	part def DewPointAnalyzer {
		port gasInput : GasInletPort;
		attribute measuredDewPoint : HydrocarbonDewPointValue;
		attribute accuracy : TemperatureValue;
		perform action analyzeDewPoint : AnalyzeDewPoint;
	}
	
	part def ChillerUnit {
		port gasIn : GasInletPort;
		port gasOut : GasOutletPort;
		port refrigerant : RefrigerantPort;
		attribute coolingCapacity : PowerValue;
		attribute targetTemperature : TemperatureValue;
		perform action coolGas : CoolGasStream;
	}
	
	part def SeparationVessel {
		port gasIn : GasInletPort;
		port gasOut : GasOutletPort;
		port liquidOut : CondensatePort;
		attribute operatingPressure : PressureValue;
		attribute separationEfficiency : Real;
		perform action separatePhases : SeparateCondensate;
	}
	
	part def ProcessController {
		attribute dewPointSetpoint : HydrocarbonDewPointValue;
		attribute controllerGain : Real;
		port dewPointInput {
			in attribute currentDewPoint : HydrocarbonDewPointValue;
		}
		port temperatureInput {
			in attribute gasTemperature : TemperatureValue;
		}
		port coolingOutput {
			out attribute coolingDemand : PowerValue;
		}
		perform action regulateDewPoint : RegulateDewPoint;
	}
	
	part def RefrigerationSystem {
		port refrigerantSupply : RefrigerantPort;
		attribute refrigerantType : String;
		attribute maxCoolingPower : PowerValue;
		attribute operatingTemperature : TemperatureValue;
	}
	
	part def TemperatureSensor {
		attribute reading : TemperatureValue;
		attribute sensorRange : TemperatureValue;
		port output {
			out attribute temperature : TemperatureValue;
		}
	}
	
	part def PressureSensor {
		attribute reading : PressureValue;
		attribute sensorRange : PressureValue;
		port output {
			out attribute pressure : PressureValue;
		}
	}
	
	action def AnalyzeDewPoint {
		in gasStream : NaturalGasStream;
		out dewPoint : HydrocarbonDewPointValue;
	}
	
	action def CoolGasStream {
		in gasInput : NaturalGasStream;
		in coolingPower : PowerValue;
		out cooledGas : ProcessedGasStream;
	}
	
	action def SeparateCondensate {
		in cooledGas : ProcessedGasStream;
		out dryGas : ProcessedGasStream;
		out liquidCondensate : CondensateLiquid;
	}
	
	action def CalculateDewPoint {
		in temperature : TemperatureValue;
		in pressure : PressureValue;
		in methane : CompositionFraction;
		in ethane : CompositionFraction;
		in propane : CompositionFraction;
		out dewPoint : HydrocarbonDewPointValue;
	}
	
	action def RegulateDewPoint {
		in currentDewPoint : HydrocarbonDewPointValue;
		in setpoint : HydrocarbonDewPointValue;
		out coolingAdjustment : PowerValue;
	}
	
	action def ControlHydrocarbonDewPoint {
		in rawGasStream : NaturalGasStream;
		in targetDewPoint : HydrocarbonDewPointValue;
		out salesGas : ProcessedGasStream;
		out condensateProduct : CondensateLiquid;
		
		first start;
		then merge monitoringLoop;
		
		then action analyzeInlet : AnalyzeDewPoint {
			in gasStream = rawGasStream;
			out dewPoint : HydrocarbonDewPointValue;
		}
		
		then action calculateDewPoint : CalculateDewPoint {
			in temperature = rawGasStream.temperature;
			in pressure = rawGasStream.pressure;
			in methane = rawGasStream.methane;
			in ethane = rawGasStream.ethane;
			in propane = rawGasStream.propane;
			out dewPoint : HydrocarbonDewPointValue;
		}
		
		then decide;
			if calculateDewPoint.dewPoint > targetDewPoint then adjustCooling;
			if calculateDewPoint.dewPoint <= targetDewPoint then maintainCooling;
		
		action adjustCooling : RegulateDewPoint {
			in currentDewPoint = calculateDewPoint.dewPoint;
			in setpoint = targetDewPoint;
			out coolingAdjustment : PowerValue;
		}
		then performCooling;
		
		action maintainCooling;
		then performCooling;
		
		action performCooling : CoolGasStream {
			in gasInput = rawGasStream;
			in coolingPower = adjustCooling.coolingAdjustment;
			out cooledGas : ProcessedGasStream;
		}
		
		then action separateLiquids : SeparateCondensate {
			in cooledGas = performCooling.cooledGas;
			out dryGas : ProcessedGasStream;
			out liquidCondensate : CondensateLiquid;
		}
		
		then assign salesGas := separateLiquids.dryGas;
		then assign condensateProduct := separateLiquids.liquidCondensate;
		then monitoringLoop;
	}
	
	part def HydrocarbonDewPointControlSystem {
		doc /*
			The Hydrocarbon Dew Point Control System is designed to condition natural gas 
			streams by managing the temperature at which heavier hydrocarbon components 
			condense from the gas phase into liquid. Its primary function is to cool the 
			incoming natural gas to a controlled temperature below the hydrocarbon dew point, 
			causing heavier hydrocarbons such as propane, butane, and pentanes to condense 
			and separate from the gas stream.
			
			This process ensures that the outlet gas meets pipeline quality specifications 
			by preventing liquid hydrocarbon dropout in downstream pipelines and equipment, 
			which could cause operational issues, corrosion, and safety hazards. The system 
			operates through continuous monitoring of gas composition and temperature, 
			calculating the hydrocarbon dew point, and adjusting refrigeration capacity to 
			maintain the gas temperature at the required specification.
			
			The separated condensate, rich in valuable natural gas liquids, is recovered 
			as a separate product stream. The system provides automated control to respond 
			to variations in inlet gas composition, flow rate, and ambient conditions while 
			maintaining consistent outlet gas quality.
		*/
		
		attribute operatingDewPointSpecification : HydrocarbonDewPointValue;
		
		part inletTemperatureSensor : TemperatureSensor {
			attribute sensorRange = 350.0 [SI::K];
		}
		
		part inletPressureSensor : PressureSensor {
			attribute sensorRange = 10000000.0 [SI::Pa];
		}
		
		part outletTemperatureSensor : TemperatureSensor {
			attribute sensorRange = 300.0 [SI::K];
		}
		
		part dewPointAnalyzer : DewPointAnalyzer {
			attribute accuracy = 1.0 [SI::K];
		}
		
		part chiller : ChillerUnit {
			attribute coolingCapacity = 750000.0 [SI::W];
			attribute targetTemperature = 258.15 [SI::K];
		}
		
		part separator : SeparationVessel {
			attribute operatingPressure = 7500000.0 [SI::Pa];
			attribute separationEfficiency = 0.97;
		}
		
		part controller : ProcessController {
			attribute dewPointSetpoint = 268.15 [SI::K];
			attribute controllerGain = 1.5;
		}
		
		part refrigerationSystem : RefrigerationSystem {
			attribute refrigerantType = "R-404A";
			attribute maxCoolingPower = 800000.0 [SI::W];
			attribute operatingTemperature = 253.15 [SI::K];
		}
		
		port rawGasInlet : GasInletPort;
		port salesGasOutlet : GasOutletPort;
		port condensateOutlet : CondensatePort;
		
		connect rawGasInlet to dewPointAnalyzer.gasInput;
		connect dewPointAnalyzer.gasInput to chiller.gasIn;
		connect chiller.gasOut to separator.gasIn;
		connect separator.gasOut to salesGasOutlet;
		connect separator.liquidOut to condensateOutlet;
		connect refrigerationSystem.refrigerantSupply to chiller.refrigerant;
		
		connect inletTemperatureSensor.output.temperature 
			to controller.temperatureInput.gasTemperature;
		connect dewPointAnalyzer.measuredDewPoint 
			to controller.dewPointInput.currentDewPoint;
		connect controller.coolingOutput.coolingDemand 
			to chiller.coolingCapacity;
		
		perform action controlProcess : ControlHydrocarbonDewPoint {
			in rawGasStream : NaturalGasStream;
			in targetDewPoint = operatingDewPointSpecification;
			out salesGas : ProcessedGasStream;
			out condensateProduct : CondensateLiquid;
		}
	}
	
	part hydrocarbonDewPointSystem : HydrocarbonDewPointControlSystem {
		attribute operatingDewPointSpecification = 268.15 [SI::K];
	}
	
	requirement <'HDPC-001'> dewPointSpecificationRequirement {
		doc /*
			The system shall maintain the outlet gas hydrocarbon dew point at or below 
			-5 degrees Celsius at the maximum operating pressure to prevent liquid 
			condensation in downstream pipelines under all expected ambient conditions.
		*/
		
		subject hydrocarbonDewPointSystem;
		
		require constraint {
			hydrocarbonDewPointSystem.operatingDewPointSpecification <= 268.15 [SI::K]
		}
	}
	
	requirement <'HDPC-002'> separationPerformanceRequirement {
		doc /*
			The separation vessel shall achieve a minimum liquid removal efficiency of 
			95% to ensure outlet gas quality and maximize condensate recovery.
		*/
		
		subject hydrocarbonDewPointSystem.separator;
		
		require constraint {
			hydrocarbonDewPointSystem.separator.separationEfficiency >= 0.95
		}
	}
	
	requirement <'HDPC-003'> coolingSystemCapacityRequirement {
		doc /*
			The refrigeration system shall provide sufficient cooling capacity to process 
			the maximum design flow rate from inlet conditions to the target dew point 
			temperature with a minimum 10% margin.
		*/
		
		subject hydrocarbonDewPointSystem.refrigerationSystem;
		
		require constraint {
			hydrocarbonDewPointSystem.refrigerationSystem.maxCoolingPower >= 700000.0 [SI::W]
		}
	}
	
	requirement <'HDPC-004'> measurementAccuracyRequirement {
		doc /*
			The dew point analyzer shall measure hydrocarbon dew point with an accuracy 
			of ±1 Kelvin across the full operating range to enable precise control.
		*/
		
		subject hydrocarbonDewPointSystem.dewPointAnalyzer;
		
		require constraint {
			hydrocarbonDewPointSystem.dewPointAnalyzer.accuracy <= 1.0 [SI::K]
		}
	}
	
	requirement <'HDPC-005'> continuousOperationRequirement {
		doc /*
			The system shall maintain continuous automated control of the hydrocarbon 
			dew point with automatic adjustment to variations in inlet gas composition, 
			flow rate, temperature, and pressure without manual intervention.
		*/
		
		subject hydrocarbonDewPointSystem;
	}
}
