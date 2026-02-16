package HeatedHumidifiedHighFlowTherapySystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import NumericalFunctions::*;

	attribute def FlowRateValue :> VolumeFlowRateValue;
	attribute def TemperatureValue :> ThermodynamicTemperatureValue;
	attribute def HumidityValue :> Real;
	attribute def OxygenConcentrationValue :> Real;
	attribute def PressureValue :> ISQ::PressureValue;

	item def MedicalGas {
		attribute flowRate : FlowRateValue;
		attribute oxygenConcentration : OxygenConcentrationValue;
		attribute pressure : PressureValue;
	}

	item def HeatedHumidifiedGas :> MedicalGas {
		attribute temperature : TemperatureValue;
		attribute humidity : HumidityValue;
	}

	item def FlowCommand {
		attribute targetFlowRate : FlowRateValue;
	}

	item def TemperatureCommand {
		attribute targetTemperature : TemperatureValue;
	}

	item def OxygenCommand {
		attribute targetConcentration : OxygenConcentrationValue;
	}

	item def SensorReading {
		attribute measuredFlowRate : FlowRateValue;
		attribute measuredTemperature : TemperatureValue;
		attribute measuredHumidity : HumidityValue;
	}

	port def GasSupplyPort {
		in item gasIn : MedicalGas;
	}

	port def GasDeliveryPort {
		out item gasOut : HeatedHumidifiedGas;
	}

	port def ControlPort {
		in item command : FlowCommand;
	}

	port def SensorPort {
		out item reading : SensorReading;
	}

	part def OxygenSource {
		port gasOutput : GasDeliveryPort;
		attribute sourceConcentration : OxygenConcentrationValue = 1.0;
	}

	part def AirSource {
		port gasOutput : GasDeliveryPort;
		attribute sourceConcentration : OxygenConcentrationValue = 0.21;
	}

	part def GasBlender {
		port oxygenInput : GasSupplyPort;
		port airInput : GasSupplyPort;
		port blendedOutput : GasDeliveryPort;
		port oxygenControl : ControlPort;
		attribute targetConcentration : OxygenConcentrationValue;
		attribute actualConcentration : OxygenConcentrationValue;
	}

	part def FlowGenerator {
		port gasInput : GasSupplyPort;
		port gasOutput : GasDeliveryPort;
		port flowControl : ControlPort;
		attribute maxFlowRate : FlowRateValue = 70.0 [L/min];
		attribute currentFlowRate : FlowRateValue;
	}

	part def Humidifier {
		port gasInput : GasSupplyPort;
		port humidifiedOutput : GasDeliveryPort;
		attribute waterLevel : Real;
		attribute targetHumidity : HumidityValue = 1.0;
		attribute actualHumidity : HumidityValue;
	}

	part def Heater {
		port gasInput : GasSupplyPort;
		port heatedOutput : GasDeliveryPort;
		port temperatureControl : ControlPort;
		attribute targetTemperature : TemperatureValue;
		attribute actualTemperature : TemperatureValue;
		attribute heatingPower : PowerValue;
	}

	part def HeatedTubing {
		port gasInput : GasSupplyPort;
		port gasOutput : GasDeliveryPort;
		attribute tubingTemperature : TemperatureValue;
		attribute ambientTemperature : TemperatureValue = 295.15 [K];
	}

	part def NasalCannula {
		port gasInput : GasSupplyPort;
		attribute cannulaSize : String;
	}

	part def FlowSensor {
		port sensePoint : GasSupplyPort;
		port sensorOutput : SensorPort;
		attribute measuredFlowRate : FlowRateValue;
		attribute accuracy : FlowRateValue = 2.0 [L/min];
	}

	part def TemperatureSensor {
		port sensePoint : GasSupplyPort;
		port sensorOutput : SensorPort;
		attribute measuredTemperature : TemperatureValue;
		attribute accuracy : TemperatureValue = 0.2 [K];
	}

	part def HumiditySensor {
		port sensePoint : GasSupplyPort;
		port sensorOutput : SensorPort;
		attribute measuredHumidity : HumidityValue;
		attribute accuracy : HumidityValue = 0.02;
	}

	part def ControlSystem {
		port flowSensorInput : SensorPort;
		port tempSensorInput : SensorPort;
		port humiditySensorInput : SensorPort;
		port flowControlOutput : ControlPort;
		port tempControlOutput : ControlPort;
		port oxygenControlOutput : ControlPort;
		attribute operatingMode : String;
		attribute targetFlowRate : FlowRateValue = 40.0 [L/min];
		attribute targetTemperature : TemperatureValue = 310.15 [K];
		attribute targetOxygenConcentration : OxygenConcentrationValue = 0.6;
	}

	part def HighFlowTherapyDevice {
		attribute deviceId : String;

		part oxygenSource : OxygenSource;
		part airSource : AirSource;
		part gasBlender : GasBlender;
		part flowGenerator : FlowGenerator;
		part humidifier : Humidifier;
		part heater : Heater;
		part heatedTubing : HeatedTubing;
		part cannula : NasalCannula;
		part controller : ControlSystem;
		part flowSensor : FlowSensor;
		part tempSensor : TemperatureSensor;
		part humiditySensor : HumiditySensor;

		connect oxygenSource.gasOutput to gasBlender.oxygenInput;
		connect airSource.gasOutput to gasBlender.airInput;
		connect gasBlender.blendedOutput to flowGenerator.gasInput;
		connect flowGenerator.gasOutput to humidifier.gasInput;
		connect humidifier.humidifiedOutput to heater.gasInput;
		connect heater.heatedOutput to heatedTubing.gasInput;
		connect heatedTubing.gasOutput to cannula.gasInput;
		connect heatedTubing.gasOutput to flowSensor.sensePoint;
		connect heatedTubing.gasOutput to tempSensor.sensePoint;
		connect heatedTubing.gasOutput to humiditySensor.sensePoint;
		connect flowSensor.sensorOutput to controller.flowSensorInput;
		connect tempSensor.sensorOutput to controller.tempSensorInput;
		connect humiditySensor.sensorOutput to controller.humiditySensorInput;
		connect controller.flowControlOutput to flowGenerator.flowControl;
		connect controller.tempControlOutput to heater.temperatureControl;
		connect controller.oxygenControlOutput to gasBlender.oxygenControl;
	}

	action def BlendGases {
		in oxygenFlow : FlowRateValue;
		in airFlow : FlowRateValue;
		in targetConcentration : OxygenConcentrationValue;
		out blendedGas : MedicalGas;
	}

	action def GenerateFlow {
		in gasIn : MedicalGas;
		in targetFlowRate : FlowRateValue;
		out gasOut : MedicalGas;
	}

	action def HumidifyGas {
		in gasIn : MedicalGas;
		in targetHumidity : HumidityValue;
		out gasOut : HeatedHumidifiedGas;
	}

	action def HeatGas {
		in gasIn : HeatedHumidifiedGas;
		in targetTemperature : TemperatureValue;
		out gasOut : HeatedHumidifiedGas;
	}

	action def MeasureParameters {
		in gas : HeatedHumidifiedGas;
		out reading : SensorReading;
	}

	action def ControlTherapy {
		in sensorReading : SensorReading;
		in targetFlowRate : FlowRateValue;
		in targetTemperature : TemperatureValue;
		in targetConcentration : OxygenConcentrationValue;
		out flowCmd : FlowCommand;
		out tempCmd : TemperatureCommand;
		out oxygenCmd : OxygenCommand;
	}

	action def DeliverTherapy {
		in targetFlowRate : FlowRateValue;
		in targetTemperature : TemperatureValue;
		in targetConcentration : OxygenConcentrationValue;
		out deliveredGas : HeatedHumidifiedGas;

		first start;
		then merge continuousDelivery;

		then action blendGases : BlendGases {
			in targetConcentration = DeliverTherapy::targetConcentration;
			out blendedGas : MedicalGas;
		}

		flow blendGases.blendedGas to generateFlow.gasIn;

		then action generateFlow : GenerateFlow {
			in gasIn : MedicalGas;
			in targetFlowRate = DeliverTherapy::targetFlowRate;
			out gasOut : MedicalGas;
		}

		flow generateFlow.gasOut to humidifyGas.gasIn;

		then action humidifyGas : HumidifyGas {
			in gasIn : MedicalGas;
			in targetHumidity = 1.0;
			out gasOut : HeatedHumidifiedGas;
		}

		flow humidifyGas.gasOut to heatGas.gasIn;

		then action heatGas : HeatGas {
			in gasIn : HeatedHumidifiedGas;
			in targetTemperature = DeliverTherapy::targetTemperature;
			out gasOut : HeatedHumidifiedGas;
		}

		then action measureParameters : MeasureParameters {
			in gas = heatGas.gasOut;
			out reading : SensorReading;
		}

		then action controlTherapy : ControlTherapy {
			in sensorReading = measureParameters.reading;
			in targetFlowRate = DeliverTherapy::targetFlowRate;
			in targetTemperature = DeliverTherapy::targetTemperature;
			in targetConcentration = DeliverTherapy::targetConcentration;
			out flowCmd : FlowCommand;
			out tempCmd : TemperatureCommand;
			out oxygenCmd : OxygenCommand;
		}

		then decide;
			if measureParameters.reading.measuredTemperature < DeliverTherapy::targetTemperature then adjustHeating;
			if measureParameters.reading.measuredFlowRate < DeliverTherapy::targetFlowRate then adjustFlow;
			if measureParameters.reading.measuredTemperature >= DeliverTherapy::targetTemperature and 
			   measureParameters.reading.measuredFlowRate >= DeliverTherapy::targetFlowRate then maintainTherapy;

		action adjustHeating;
		then continuousDelivery;

		action adjustFlow;
		then continuousDelivery;

		action maintainTherapy;
		then continuousDelivery;
	}

	item def StartTherapyCommand;
	item def PauseTherapyCommand;
	item def ResumeTherapyCommand;
	item def StopTherapyCommand;

	state def TherapyOperatingStates {
		attribute deviceStatus : String;

		entry; then idle;

		state idle;
		accept StartTherapyCommand;
		then priming;

		state priming;
		then active;

		state active;
		accept PauseTherapyCommand;
		then paused;
		accept StopTherapyCommand;
		then shutdown;

		state paused;
		accept ResumeTherapyCommand;
		then active;
		accept StopTherapyCommand;
		then shutdown;

		state shutdown;
		then idle;
	}

	requirement def SafetyRequirement;
	requirement def PerformanceRequirement;
	requirement def ClinicalRequirement;

	requirement <'HFNC-001'> temperatureControl : SafetyRequirement {
		doc /* The delivered gas temperature shall be maintained at 37°C ±2°C to prevent thermal injury. */
		subject device : HighFlowTherapyDevice;
		require constraint {
			device.heater.actualTemperature >= 308.15 [K] and 
			device.heater.actualTemperature <= 312.15 [K]
		}
	}

	requirement <'HFNC-002'> flowRateRange : PerformanceRequirement {
		doc /* The system shall deliver gas flow rates from 10 to 70 liters per minute. */
		subject device : HighFlowTherapyDevice;
		require constraint {
			device.flowGenerator.currentFlowRate >= 10.0 [L/min] and 
			device.flowGenerator.currentFlowRate <= 70.0 [L/min]
		}
	}

	requirement <'HFNC-003'> humidificationLevel : ClinicalRequirement {
		doc /* The system shall deliver gas with relative humidity of at least 95% at body temperature. */
		subject device : HighFlowTherapyDevice;
		require constraint {
			device.humidifier.actualHumidity >= 0.95
		}
	}

	requirement <'HFNC-004'> oxygenConcentrationAccuracy : PerformanceRequirement {
		doc /* The delivered oxygen concentration shall be within ±3% of the set value. */
		subject device : HighFlowTherapyDevice;
		require constraint {
			abs(device.gasBlender.actualConcentration - device.gasBlender.targetConcentration) <= 0.03
		}
	}

	requirement <'HFNC-005'> continuousOperation : PerformanceRequirement {
		doc /* The system shall operate continuously for at least 24 hours without requiring water refill. */
		subject device : HighFlowTherapyDevice;
		require constraint {
			device.humidifier.waterLevel >= 0.1
		}
	}

	requirement systemMission : ClinicalRequirement {
		doc /* The heated humidified high-flow therapy system shall deliver precisely controlled, 
		       heated, and humidified oxygen-enriched gas to patients requiring respiratory support. */

		assume constraint patientNeedsSupport {
			doc /* Patient requires supplemental oxygen and respiratory support. */
		}

		require temperatureControl;
		require flowRateRange;
		require humidificationLevel;
		require oxygenConcentrationAccuracy;
		require continuousOperation;
	}
}
