package 'Biliblanket Phototherapy System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	package Definitions {
		item def Light;
		item def Bilirubin;

		attribute def SetParameters {
			attribute intensity : Real;
			attribute duration : DurationValue;
		}
		attribute def StartTreatment;
		attribute def StopTreatment;
		attribute def TreatmentComplete;
		attribute def OverTemp;
		attribute def AlarmSignal;
		attribute def LightOnCommand;
		attribute def LightOffCommand;
		attribute def SensedTemperature {
			attribute temp : TemperatureValue;
		}

		action def ConvertPower {
			in ac : ElectricPotentialValue;
			out dc : ElectricPotentialValue;
		}
		action def GenerateLight {
			in pwr : ElectricPotentialValue;
			out light : Light;
		}
		action def SenseTemperature {
			out temp : TemperatureValue;
		}
		action def TriggerAlarm;

		part def ControlModule {
			attribute maxSafeTemp : TemperatureValue = 311.15 [K];
			attribute setIntensity : Real;
			attribute setDuration : DurationValue;
			attribute elapsedTime : DurationValue;

			port powerInPort {
				in power : ElectricPotentialValue;
			}
			port tempSensorPort {
				in sensedTemp : SensedTemperature;
			}
			port lightCommandPort {
				out lightOn : LightOnCommand;
				out lightOff : LightOffCommand;
			}
			port alarmPort {
				out alarm : AlarmSignal;
			}
			port userInterfacePort {
				in setParams : SetParameters;
				in start : StartTreatment;
				in stop : StopTreatment;
			}
		}

		part def PowerSupply {
			port acInPort {
				in acIn : ElectricPotentialValue;
			}
			port dcOutPort {
				out dcOut : ElectricPotentialValue;
			}
			action convertPower : ConvertPower;
		}

		part def LEDLightEngine {
			attribute peakWavelength : LengthValue = 475 [nm];
			port powerInPort {
				in power : ElectricPotentialValue;
			}
			port lightCommandPort {
				in lightOn : LightOnCommand;
				in lightOff : LightOffCommand;
			}
			port lightOutPort {
				out light : Light;
			}
			action generateLight : GenerateLight;
		}

		part def FiberOpticPad {
			port lightInPort {
				in light : Light;
			}
			port surfacePort {
				out surfaceLight : Light;
			}
		}

		part def TemperatureSensor {
			port tempOutPort {
				out sensedTemp : SensedTemperature;
			}
			action senseTemperature : SenseTemperature;
		}

		part def BiliblanketSystem {
			part controlModule : ControlModule;
			part powerSupply : PowerSupply;
			part ledLightEngine : LEDLightEngine;
			part fiberOpticPad : FiberOpticPad;
			part tempSensor : TemperatureSensor;

			interface powerInterface1 connect powerSupply.dcOutPort to controlModule.powerInPort {
				flow powerFlow1 of ElectricPotentialValue
					from powerSupply.dcOutPort.dcOut to controlModule.powerInPort.power;
			}
			interface powerInterface2 connect powerSupply.dcOutPort to ledLightEngine.powerInPort {
				flow powerFlow2 of ElectricPotentialValue
					from powerSupply.dcOutPort.dcOut to ledLightEngine.powerInPort.power;
			}
			interface lightCmdInterface connect controlModule.lightCommandPort to ledLightEngine.lightCommandPort {
				flow lightOnFlow of LightOnCommand
					from controlModule.lightCommandPort.lightOn to ledLightEngine.lightCommandPort.lightOn;
				flow lightOffFlow of LightOffCommand
					from controlModule.lightCommandPort.lightOff to ledLightEngine.lightCommandPort.lightOff;
			}
			interface lightInterface connect ledLightEngine.lightOutPort to fiberOpticPad.lightInPort {
				flow lightFlow of Light
					from ledLightEngine.lightOutPort.light to fiberOpticPad.lightInPort.light;
			}
			interface tempInterface connect tempSensor.tempOutPort to controlModule.tempSensorPort {
				flow tempFlow of SensedTemperature
					from tempSensor.tempOutPort.sensedTemp to controlModule.tempSensorPort.sensedTemp;
			}
		}

		state def ControlStates;

		requirement def TreatmentRequirement {
			doc /* The system shall reduce bilirubin levels in newborn infants through phototherapy using blue-green light. */
		}
		requirement def SafetyRequirement {
			doc /* The system shall automatically shut down the light and trigger an alarm if the pad surface temperature exceeds 38 degrees Celsius. */
		}
		requirement def WavelengthRequirement {
			doc /* The LED Light Engine shall produce light peaking at approximately 475 nm for effective bilirubin breakdown. */
		}
		requirement def PowerRequirement {
			doc /* The Power Supply shall convert standard wall outlet AC voltage to low-voltage DC power for the system electronics. */
		}
	}

	package Usages {
		private import Definitions::*;

		action senseTemperature : SenseTemperature {
			out temp;
		}
		action triggerAlarm : TriggerAlarm;

		state controlStates : ControlStates {
			in controlModule : ControlModule;
			in ledLightEngine : LEDLightEngine;

			entry; then standby;
			do senseTemperature;

			state standby;
			accept StartTreatment
				do send new LightOnCommand() to ledLightEngine
				then active;

			state active;
			accept StopTreatment
				do send new LightOffCommand() to ledLightEngine
				then standby;
			accept TreatmentComplete
				do send new LightOffCommand() to ledLightEngine
				then standby;
			accept when senseTemperature.temp > controlModule.maxSafeTemp
				do send new LightOffCommand() to ledLightEngine
				then alarm;

			state alarm {
				entry triggerAlarm;
			}
			accept StopTreatment
				then standby;
		}

		part biliblanketSystem : BiliblanketSystem;

		requirement treatmentReq : TreatmentRequirement;
		requirement safetyReq : SafetyRequirement;
		requirement wavelengthReq : WavelengthRequirement;
		requirement powerReq : PowerRequirement;
	}
}
