package 'Therapeutic Hypothermia Cap System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def StartTreatment;
	attribute def StopTreatment;
	attribute def ResetAlarm;
	attribute def AlarmSignal;
	attribute def FaultSignal;

	attribute def ScalpTemperature :> TemperatureValue;
	attribute def CoolantPressure :> PressureValue;
	attribute def CoolantFlowRate :> Real;
	attribute def CoolingPower :> Real;

	port def CoolantPort {
		attribute temperature : TemperatureValue;
		attribute pressure : CoolantPressure;
	}

	port def TempSignalPort {
		out temp : ScalpTemperature;
	}

	port def PressureSignalPort {
		out pressure : CoolantPressure;
	}

	port def CommandPort {
		in startCmd : StartTreatment;
		in stopCmd : StopTreatment;
		in resetCmd : ResetAlarm;
		out alarmOut : AlarmSignal;
		out faultOut : FaultSignal;
	}

	action def SenseScalpTemperature {
		out temp : ScalpTemperature;
	}

	action def SenseCoolantPressure {
		out pressure : CoolantPressure;
	}

	action def SenseConditions {
		out temp : ScalpTemperature;
		out pressure : CoolantPressure;
	}

	action def CirculateCoolant {
		in flowRate : CoolantFlowRate;
	}

	action def ChillCoolant {
		in power : CoolingPower;
	}

	action def AdjustCoolingPower {
		in currentTemp : ScalpTemperature;
		in targetTemp : TemperatureValue;
		out power : CoolingPower;
	}

	action def AdjustFlowRate {
		in currentTemp : ScalpTemperature;
		out flowRate : CoolantFlowRate;
	}

	action def PerformCooling {
		out temp : ScalpTemperature;
		out pressure : CoolantPressure;
	}

	action def PerformMaintenance {
		in currentTemp : ScalpTemperature;
		in targetTemp : TemperatureValue;
		out temp : ScalpTemperature;
		out pressure : CoolantPressure;
	}

	action def TriggerAlarm;
	action def NotifyStaff;

	part def CoolantChannel {
		port inlet : CoolantPort;
		port outlet : CoolantPort;
	}

	part def TherapeuticCap {
		attribute minTherapeuticTemp : TemperatureValue = 18 [Celsius];
		attribute maxTherapeuticTemp : TemperatureValue = 22 [Celsius];
		port coolantIn : CoolantPort;
		port coolantOut : CoolantPort;
		part channels : CoolantChannel[1..*];
	}

	part def CirculationPump {
		port coolantIn : CoolantPort;
		port coolantOut : CoolantPort;
		attribute flowRate : CoolantFlowRate;
	}

	part def CoolingUnit {
		port coolantIn : CoolantPort;
		port coolantOut : CoolantPort;
		attribute coolingPower : CoolingPower;
	}

	part def TemperatureSensor {
		port tempOut : TempSignalPort;
	}

	part def PressureSensor {
		port pressureOut : PressureSignalPort;
	}

	part def ControlModule {
		attribute minSafeTemp : TemperatureValue = 15 [Celsius];
		attribute targetTemp : TemperatureValue = 20 [Celsius];
		attribute maxTherapeuticTemp : TemperatureValue = 22 [Celsius];
		attribute minTherapeuticTemp : TemperatureValue = 18 [Celsius];
		attribute maxPressure : CoolantPressure = 50000 [Pa];
		attribute treatmentDuration : DurationValue = 3600 [s];
		port tempInput : TempSignalPort;
		port pressureInput : PressureSignalPort;
		port cmdPort : CommandPort;
		exhibit state controllerStates : ControllerStates;
	}

	part def ControlConsole {
		part controller : ControlModule;
		part pump : CirculationPump;
		part coolingUnit : CoolingUnit;
		port coolantSupply : CoolantPort;
		port coolantReturn : CoolantPort;
		connect pump.coolantOut to coolingUnit.coolantIn;
		connect coolingUnit.coolantOut to coolantSupply;
		connect coolantReturn to pump.coolantIn;
	}

	state def ControllerStates {
		in controller : ControlModule;
	}

	part hypothermiaSystem {
		part console : ControlConsole;
		part cap : TherapeuticCap;
		part scalpSensor : TemperatureSensor;
		part pressureSensor : PressureSensor;
		connect console.controller.tempInput to scalpSensor.tempOut;
		connect console.controller.pressureInput to pressureSensor.pressureOut;
		connect console.coolantSupply to cap.coolantIn;
		connect cap.coolantOut to console.coolantReturn;
	}

	action senseConditions : SenseConditions {
		out temp;
		out pressure;
	}

	action performCooling : PerformCooling;
	action performMaintenance : PerformMaintenance;
	action triggerAlarm : TriggerAlarm;
	action notifyStaff : NotifyStaff;

	state controllerStates : ControllerStates {
		in controller : ControlModule;

		entry; then idle;
		do senseConditions;

		state idle;
		accept StartTreatment
			then cooling;

		state cooling {
			do performCooling;
		}
		accept when senseConditions.temp >= controller.minTherapeuticTemp
			and senseConditions.temp <= controller.maxTherapeuticTemp
			then maintaining;
		accept when senseConditions.temp < controller.minSafeTemp
			do send new AlarmSignal() to controller.cmdPort
			then alarm;
		accept when senseConditions.pressure > controller.maxPressure
			do send new FaultSignal() to controller.cmdPort
			then alarm;
		accept StopTreatment
			then idle;

		state maintaining {
			do performMaintenance {
				in currentTemp = senseConditions.temp;
				in targetTemp = controller.targetTemp;
			}
		}
		accept when senseConditions.temp < controller.minSafeTemp
			do send new AlarmSignal() to controller.cmdPort
			then alarm;
		accept when senseConditions.pressure > controller.maxPressure
			do send new FaultSignal() to controller.cmdPort
			then alarm;
		accept after controller.treatmentDuration
			then idle;
		accept StopTreatment
			then idle;

		state alarm {
			entry triggerAlarm;
			do notifyStaff;
		}
		accept ResetAlarm
			then idle;
	}

	requirement def TherapeuticTempRange {
		attribute minTemp : TemperatureValue = 18 [Celsius];
		attribute maxTemp : TemperatureValue = 22 [Celsius];
		subject cap : TherapeuticCap;
		doc /*
		 * The scalp temperature shall be maintained between 18 and 22
		 * degrees Celsius during the maintaining phase of treatment.
		 */
	}

	requirement def SafetyTempLimit {
		attribute minSafeTemp : TemperatureValue = 15 [Celsius];
		subject cap : TherapeuticCap;
		doc /*
		 * The scalp temperature shall never drop below 15 degrees
		 * Celsius to prevent tissue damage.
		 */
	}

	requirement def CoolantPressureLimit {
		attribute maxPressure : CoolantPressure = 50000 [Pa];
		subject cap : TherapeuticCap;
		doc /*
		 * The coolant pressure shall not exceed 50000 Pa to ensure
		 * patient comfort during long treatment sessions.
		 */
	}

	requirement def AlarmResponse {
		subject controller : ControlModule;
		doc /*
		 * The controller shall enter an alarm state and notify
		 * medical staff when the scalp temperature drops below the
		 * safe minimum or when a fault condition is detected.
		 */
	}

	requirement 'Maintain Therapeutic Range' : TherapeuticTempRange;
	requirement 'Prevent Tissue Damage' : SafetyTempLimit;
	requirement 'Ensure Comfortable Pressure' : CoolantPressureLimit;
	requirement 'Alarm on Safety Violation' : AlarmResponse;
}
