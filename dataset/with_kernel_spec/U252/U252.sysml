package 'Hydrocollator System' {
	private import ISQ::TemperatureValue;
	private import ISQ::VolumeValue;
	private import ISQ::PowerValue;
	private import SI::C;
	private import SI::L;
	private import SI::W;
	private import ScalarValues::Boolean;
	private import ScalarValues::Integer;
	private import ScalarValues::String;

	attribute def PowerOnSignal;
	attribute def PowerOffSignal;

	attribute def ControlCmd;
	attribute def HeaterOnCmd :> ControlCmd;
	attribute def HeaterOffCmd :> ControlCmd;
	attribute def LightRedCmd :> ControlCmd;
	attribute def LightGreenCmd :> ControlCmd;
	attribute def LightOffCmd :> ControlCmd;

	part def Tank {
		attribute capacity : VolumeValue = 30 [L];
		attribute waterTemperature : TemperatureValue;
	}

	part def HeatingElement {
		attribute powerRating : PowerValue = 1500 [W];
		attribute isActive : Boolean = false;
		port cmdIn { in cmd : ControlCmd; }
	}

	part def PackHolder {
		attribute slotCount : Integer = 6;
	}

	part def MoistHeatPack {
		attribute isSaturated : Boolean = true;
		attribute isReady : Boolean = false;
	}

	part def TempSensor {
		port tempOut { out temp : TemperatureValue; }
	}

	part def Controller {
		attribute minTemp : TemperatureValue = 71 [C];
		attribute maxTemp : TemperatureValue = 79 [C];
		port tempIn { in temp : TemperatureValue; }
		port heaterCmdOut { out cmd : ControlCmd; }
		port lightCmdOut { out cmd : ControlCmd; }
	}

	part def IndicatorLight {
		attribute currentColor : String = "off";
		port cmdIn { in cmd : ControlCmd; }
	}

	part def Hydrocollator {
		attribute minTemp : TemperatureValue = 71 [C];
		attribute maxTemp : TemperatureValue = 79 [C];

		part tank : Tank;
		part heater : HeatingElement;
		part rack : PackHolder;
		part sensor : TempSensor;
		part controller : Controller;
		part indicator : IndicatorLight;
		part packs : MoistHeatPack[6];

		flow tempReadingFlow of TemperatureValue
			from sensor.tempOut.temp to controller.tempIn.temp;

		flow heaterCmdFlow of ControlCmd
			from controller.heaterCmdOut.cmd to heater.cmdIn.cmd;

		flow lightCmdFlow of ControlCmd
			from controller.lightCmdOut.cmd to indicator.cmdIn.cmd;
	}

	state hydrocollatorStates {
		in hydrocollator : Hydrocollator;
		in currentTemp : TemperatureValue;
		entry; then powerOff;

		state powerOff {
			entry send new LightOffCmd() to hydrocollator.indicator;
		}
		accept PowerOnSignal
			do send new HeaterOnCmd() to hydrocollator.heater
			then initialHeating;

		state initialHeating {
			entry send new LightRedCmd() to hydrocollator.indicator;
		}
		accept when currentTemp >= hydrocollator.maxTemp
			do send new LightGreenCmd() to hydrocollator.indicator
			then maintaining;

		state maintaining;
		accept when currentTemp < hydrocollator.minTemp
			do send new HeaterOnCmd() to hydrocollator.heater
			then maintaining;
		accept when currentTemp >= hydrocollator.maxTemp
			do send new HeaterOffCmd() to hydrocollator.heater
			then maintaining;
		accept PowerOffSignal
			do send new HeaterOffCmd() to hydrocollator.heater
			then powerOff;
	}

	requirement def TemperatureRegulationRequirement {
		doc /* The system shall maintain water temperature within the therapeutic range of 71°C to 79°C. */
		subject hydrocollator : Hydrocollator;
		constraint {
			hydrocollator.tank.waterTemperature >= 71 [C] and
			hydrocollator.tank.waterTemperature <= 79 [C]
		}
	}

	requirement def ReadyIndicationRequirement {
		doc /* The indicator light shall be red during initial heating, green when packs are ready, and off when the system is powered off. */
		subject hydrocollator : Hydrocollator;
	}

	requirement def PackCapacityRequirement {
		doc /* The system shall hold at least 6 moist heat packs simultaneously. */
		subject rack : PackHolder;
		constraint { rack.slotCount >= 6 }
	}

	requirement tempReq : TemperatureRegulationRequirement;
	requirement indicatorReq : ReadyIndicationRequirement;
	requirement capacityReq : PackCapacityRequirement;
}
