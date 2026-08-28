package IndustrialSafetySystem {

	import ScalarValues::*;
	import ISQ::*;

	value type PressureValue :> Real { unit 'Pa'; }
	value type TemperatureValue :> Real { unit 'K'; }
	value type GasConcentrationValue :> Real { unit 'ppm'; }
	value type VolumeValue :> Real { unit 'dB'; }
	value type FrequencyValue :> Real { unit 'Hz'; }
	value type BrightnessValue :> Real { unit 'cd'; }
	value type PowerValue :> Real { unit 'W'; }
	value type TimeValue :> Real { unit 's'; }

	enum def RiskLevel { normal; warning; critical; emergency; }
	enum def AlarmColor { green; yellow; red; }
	enum def EquipmentState { running; shutdown; }
	enum def VentilationState { inactive; active; }

	item def SensorReading {
		attribute value : Real;
		attribute timestamp : TimeValue;
		attribute overThreshold : Boolean;
	}

	item def ControlCommand {
		attribute activateAlarm : Boolean;
		attribute activateShutdown : Boolean;
		attribute activateVentilation : Boolean;
		attribute alarmColor : AlarmColor;
		attribute alarmVolume : VolumeValue;
		attribute alarmFrequency : FrequencyValue;
		attribute lightBrightness : BrightnessValue;
	}

	port def SensorPort {
		out reading : SensorReading;
	}

	port def CommandPort {
		in command : ControlCommand;
	}

	port def PowerPort {
		out powerState : EquipmentState;
	}

	port def VentilationPort {
		out ventilationState : VentilationState;
	}

	part def PressureSensor {
		port sensorOut : SensorPort;
		attribute threshold : PressureValue = 200000;
		attribute currentValue : PressureValue;
		attribute samplePeriod : TimeValue = 0.1;

		action def ReadPressure {
			out reading : SensorReading;
		}

		perform readPressure : ReadPressure {
			action readValue;
			then action evaluateThreshold {
				reading.overThreshold := currentValue > threshold;
			}
		}
	}

	part def TemperatureSensor {
		port sensorOut : SensorPort;
		attribute threshold : TemperatureValue = 350;
		attribute currentValue : TemperatureValue;
		attribute samplePeriod : TimeValue = 0.1;

		action def ReadTemperature {
			out reading : SensorReading;
		}

		perform readTemperature : ReadTemperature {
			action readValue;
			then action evaluateThreshold {
				reading.overThreshold := currentValue > threshold;
			}
		}
	}

	part def GasSensor {
		port sensorOut : SensorPort;
		attribute threshold : GasConcentrationValue = 50;
		attribute currentValue : GasConcentrationValue;
		attribute samplePeriod : TimeValue = 0.05;

		action def ReadGasConcentration {
			out reading : SensorReading;
		}

		perform readGas : ReadGasConcentration {
			action readValue;
			then action evaluateThreshold {
				reading.overThreshold := currentValue > threshold;
			}
		}
	}

	part def VisualAlarm {
		attribute color : AlarmColor = green;
		attribute brightness : BrightnessValue = 0;
		attribute active : Boolean = false;

		action def Flash {
			in color : AlarmColor;
			in brightness : BrightnessValue;
		}

		perform flash : Flash;
	}

	part def AudioAlarm {
		attribute volume : VolumeValue = 0;
		attribute frequency : FrequencyValue = 0;
		attribute active : Boolean = false;

		action def SoundSiren {
			in volume : VolumeValue;
			in frequency : FrequencyValue;
		}

		perform soundSiren : SoundSiren;
	}

	part def AlarmSystem {
		port cmdIn : CommandPort;
		attribute active : Boolean = false;
		attribute color : AlarmColor = green;
		attribute brightness : BrightnessValue = 0;
		attribute volume : VolumeValue = 0;
		attribute frequency : FrequencyValue = 0;

		part visualAlarm : VisualAlarm;
		part audioAlarm : AudioAlarm;

		action def ActivateAlarm {
			in command : ControlCommand;
		}

		perform activateAlarm : ActivateAlarm {
			action receiveCommand;
			then action setVisual {
				visualAlarm.color := command.alarmColor;
				visualAlarm.brightness := command.lightBrightness;
				visualAlarm.active := command.activateAlarm;
			}
			then action setAudio {
				audioAlarm.volume := command.alarmVolume;
				audioAlarm.frequency := command.alarmFrequency;
				audioAlarm.active := command.activateAlarm;
			}
		}
	}

	part def EmergencyShutdown {
		port cmdIn : CommandPort;
		port powerOut : PowerPort;
		port ventilationOut : VentilationPort;
		attribute equipmentState : EquipmentState = running;
		attribute ventilationState : VentilationState = inactive;
		attribute responseTime : TimeValue = 0.5;

		action def CutPower {
			out state : EquipmentState;
		}

		action def ActivateVentilation {
			out state : VentilationState;
		}

		action def ExecuteShutdown {
			in command : ControlCommand;
		}

		perform executeShutdown : ExecuteShutdown {
			action receiveCommand;
			then action cutPower : CutPower {
				state := if command.activateShutdown then EquipmentState::shutdown else EquipmentState::running endif;
				equipmentState := state;
			}
			then action activateVentilation : ActivateVentilation {
				state := if command.activateVentilation then VentilationState::active else VentilationState::inactive endif;
				ventilationState := state;
			}
		}
	}

	part def SafetyController {
		port pressureIn : SensorPort;
		port temperatureIn : SensorPort;
		port gasIn : SensorPort;
		port alarmCmdOut : CommandPort;
		port shutdownCmdOut : CommandPort;

		attribute riskLevel : RiskLevel = normal;
		attribute pressureThreshold : PressureValue = 200000;
		attribute temperatureThreshold : TemperatureValue = 350;
		attribute gasThreshold : GasConcentrationValue = 50;
		attribute evaluationPeriod : TimeValue = 0.05;

		action def EvaluateRisk {
			in pressure : SensorReading;
			in temperature : SensorReading;
			in gas : SensorReading;
			out risk : RiskLevel;
		}

		action def GenerateCommand {
			in risk : RiskLevel;
			out alarmCommand : ControlCommand;
			out shutdownCommand : ControlCommand;
		}

		state def SafetyControllerBehavior {
			entry action { riskLevel := RiskLevel::normal; }

			state normal {
				entry action { riskLevel := RiskLevel::normal; }
				transition normal to warning
					if pressureIn.reading.overThreshold
					or temperatureIn.reading.overThreshold
					or gasIn.reading.overThreshold;
			}

			state warning {
				entry action { riskLevel := RiskLevel::warning; }
				transition warning to critical
					if pressureIn.reading.value > pressureThreshold * 1.5
					or temperatureIn.reading.value > temperatureThreshold * 1.5
					or gasIn.reading.value > gasThreshold * 1.5;
				transition warning to normal
					if not pressureIn.reading.overThreshold
					and not temperatureIn.reading.overThreshold
					and not gasIn.reading.overThreshold;
			}

			state critical {
				entry action { riskLevel := RiskLevel::critical; }
				transition critical to emergency
					if pressureIn.reading.value > pressureThreshold * 2.0
					or temperatureIn.reading.value > temperatureThreshold * 2.0
					or gasIn.reading.value > gasThreshold * 2.0;
				transition critical to warning
					if pressureIn.reading.value <= pressureThreshold * 1.5
					and temperatureIn.reading.value <= temperatureThreshold * 1.5
					and gasIn.reading.value <= gasThreshold * 1.5;
			}

			state emergency {
				entry action { riskLevel := RiskLevel::emergency; }
				transition emergency to critical
					if pressureIn.reading.value <= pressureThreshold * 2.0
					and temperatureIn.reading.value <= temperatureThreshold * 2.0
					and gasIn.reading.value <= gasThreshold * 2.0;
			}
		}

		perform behavior : SafetyControllerBehavior;

		perform evaluateRisk : EvaluateRisk {
			action collectReadings;
			then action computeRisk {
				risk := 
					if pressureIn.reading.value > pressureThreshold * 2.0
					or temperatureIn.reading.value > temperatureThreshold * 2.0
					or gasIn.reading.value > gasThreshold * 2.0
					then RiskLevel::emergency
					elseif pressureIn.reading.value > pressureThreshold * 1.5
					or temperatureIn.reading.value > temperatureThreshold * 1.5
					or gasIn.reading.value > gasThreshold * 1.5
					then RiskLevel::critical
					elseif pressureIn.reading.overThreshold
					or temperatureIn.reading.overThreshold
					or gasIn.reading.overThreshold
					then RiskLevel::warning
					else RiskLevel::normal
					endif;
				riskLevel := risk;
			}
		}

		perform generateCommand : GenerateCommand {
			action determineRisk;
			then action buildAlarmCommand {
				alarmCommand.activateAlarm := risk <> RiskLevel::normal;
				alarmCommand.activateShutdown := risk == RiskLevel::emergency;
				alarmCommand.activateVentilation := risk == RiskLevel::critical or risk == RiskLevel::emergency;
				alarmCommand.alarmColor := 
					if risk == RiskLevel::emergency then AlarmColor::red
					elseif risk == RiskLevel::critical then AlarmColor::red
					elseif risk == RiskLevel::warning then AlarmColor::yellow
					else AlarmColor::green endif;
				alarmCommand.alarmVolume := 
					if risk == RiskLevel::emergency then 120.0
					elseif risk == RiskLevel::critical then 100.0
					elseif risk == RiskLevel::warning then 80.0
					else 0.0 endif;
				alarmCommand.alarmFrequency := 
					if risk == RiskLevel::emergency then 2000.0
					elseif risk == RiskLevel::critical then 1500.0
					elseif risk == RiskLevel::warning then 1000.0
					else 0.0 endif;
				alarmCommand.lightBrightness := 
					if risk == RiskLevel::emergency then 500.0
					elseif risk == RiskLevel::critical then 400.0
					elseif risk == RiskLevel::warning then 200.0
					else 0.0 endif;
			}
			then action buildShutdownCommand {
				shutdownCommand.activateAlarm := risk == RiskLevel::emergency;
				shutdownCommand.activateShutdown := risk == RiskLevel::emergency;
				shutdownCommand.activateVentilation := risk == RiskLevel::critical or risk == RiskLevel::emergency;
				shutdownCommand.alarmColor := AlarmColor::red;
				shutdownCommand.alarmVolume := 120.0;
				shutdownCommand.alarmFrequency := 2000.0;
				shutdownCommand.lightBrightness := 500.0;
			}
		}
	}

	part def IndustrialSafetySystem {
		part controller : SafetyController;
		part pressureSensor : PressureSensor;
		part temperatureSensor : TemperatureSensor;
		part gasSensor : GasSensor;
		part alarmSystem : AlarmSystem;
		part emergencyShutdown : EmergencyShutdown;

		connection pressureSensor.sensorOut to controller.pressureIn;
		connection temperatureSensor.sensorOut to controller.temperatureIn;
		connection gasSensor.sensorOut to controller.gasIn;
		connection controller.alarmCmdOut to alarmSystem.cmdIn;
		connection controller.shutdownCmdOut to emergencyShutdown.cmdIn;
		connection emergencyShutdown.powerOut to controller.pressureIn;
	}

	requirement def SafetyMonitoringRequirement {
		doc "The system shall continuously monitor pressure, temperature, and gas conditions at predefined sample rates.";
		subject system : IndustrialSafetySystem;
		attribute maxSamplePeriod : TimeValue = 0.1;
		objective monitorConditions;
	}

	requirement def RiskEvaluationRequirement {
		doc "The controller shall continuously evaluate the overall risk level as normal, warning, critical, or emergency.";
		subject controller : SafetyController;
		attribute evaluationPeriod : TimeValue = 0.05;
		objective evaluateRisk;
	}

	requirement def AlarmResponseRequirement {
		doc "Upon detection of low-level risk, the controller shall activate the alarm system with visual and audio alarms appropriate to the risk level.";
		subject alarmSystem : AlarmSystem;
		objective alertPersonnel;
	}

	requirement def EmergencyShutdownRequirement {
		doc "For severe threats, the system shall trigger emergency shutdown, cutting power to equipment and activating ventilation to mitigate the hazard.";
		subject emergencyShutdown : EmergencyShutdown;
		objective preventCatastrophe;
	}

	requirement def ResponseTimeRequirement {
		doc "The response time from condition detection to protective action shall be less than 1 second.";
		subject system : IndustrialSafetySystem;
		attribute maxResponseTime : TimeValue = 1.0;
		objective fastResponse;
	}

	requirement def ReliabilityRequirement {
		doc "The system shall operate continuously and reliably without false negatives in hazard detection.";
		subject system : IndustrialSafetySystem;
		attribute minUptime : Real = 0.9999;
		objective ensureReliability;
	}

	requirement group IndustrialSafetyRequirements {
		requirement monitoringReq : SafetyMonitoringRequirement;
		requirement riskEvalReq : RiskEvaluationRequirement;
		requirement alarmReq : AlarmResponseRequirement;
		requirement shutdownReq : EmergencyShutdownRequirement;
		requirement responseTimeReq : ResponseTimeRequirement;
		requirement reliabilityReq : ReliabilityRequirement;
	}

	satisfy IndustrialSafetyRequirements by IndustrialSafetySystem;

}
