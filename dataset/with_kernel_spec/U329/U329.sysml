package NellcorPulseOximeter {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ScalarValues::String;

    value type SpO2 :> Real;
    value type PulseRate :> Real;
    value type BatteryLevel :> Real;
    value type BatteryCapacity :> Real;
    value type ResponseTime :> Real;
    value type Accuracy :> Real;
    value type Wavelength :> Real;

    item def LightSignal {
        attribute redIntensity : Real;
        attribute irIntensity : Real;
        attribute redAbsorption : Real;
        attribute irAbsorption : Real;
    }

    item def PlethWaveform {
        attribute amplitude : Real;
        attribute phase : Real;
    }

    item def AlarmEvent {
        attribute severity : String;
        attribute alarmType : String;
        attribute alarmText : String;
    }

    part def RedLED {
        out port lightEmission : LightSignal;
        attribute wavelength : Wavelength = 660.0;
    }

    part def InfraredLED {
        out port lightEmission : LightSignal;
        attribute wavelength : Wavelength = 940.0;
    }

    part def Photodetector {
        in port lightReception : LightSignal;
        out port rawSignal : LightSignal;
    }

    part def OpticalFingerSensor {
        out port rawSignalOut : LightSignal;
        part redLED : RedLED;
        part infraredLED : InfraredLED;
        part photodetector : Photodetector;
        connect photodetector.rawSignal to rawSignalOut;
    }

    part def SignalProcessingUnit {
        in port rawSignalIn : LightSignal;
        out port spo2Out : SpO2;
        out port pulseRateOut : PulseRate;
        out port waveformOut : PlethWaveform;

        action processSignal {
            in raw : LightSignal;
            out spo2 : SpO2;
            out pulseRate : PulseRate;
            out waveform : PlethWaveform;

            action filterNoise {
                in rawSignal : LightSignal;
                out filteredSignal : LightSignal;
            }
            action calculateSpO2 {
                in filtered : LightSignal;
                out saturation : SpO2;
            }
            action calculatePulseRate {
                in filtered : LightSignal;
                out rate : PulseRate;
            }
            action generateWaveform {
                in filtered : LightSignal;
                out pleth : PlethWaveform;
            }

            flow raw to filterNoise.rawSignal;
            flow filterNoise.filteredSignal to calculateSpO2.filtered;
            flow filterNoise.filteredSignal to calculatePulseRate.filtered;
            flow filterNoise.filteredSignal to generateWaveform.filtered;
            flow calculateSpO2.saturation to spo2;
            flow calculatePulseRate.rate to pulseRate;
            flow generateWaveform.pleth to waveform;
        }
    }

    part def DisplayModule {
        in port spo2In : SpO2;
        in port pulseRateIn : PulseRate;
        in port waveformIn : PlethWaveform;
        part lcdScreen {
            attribute displaySpO2 : SpO2;
            attribute displayPulseRate : PulseRate;
            attribute displayWaveform : PlethWaveform;
        }
    }

    part def AlarmSubsystem {
        in port spo2In : SpO2;
        in port pulseRateIn : PulseRate;
        out port alarmOut : AlarmEvent;

        attribute lowSpO2Critical : SpO2 = 90.0;
        attribute lowSpO2Warning : SpO2 = 94.0;
        attribute pulseRateLow : PulseRate = 50.0;
        attribute pulseRateHigh : PulseRate = 120.0;

        part audibleAlarm {
            attribute active : Boolean = false;
        }
        part visualAlarm {
            attribute active : Boolean = false;
            attribute severity : String;
        }

        state machine alarmStates {
            state Normal;
            state Warning;
            state Critical;

            transition Normal_to_Warning first Normal if (spo2In < lowSpO2Warning and spo2In >= lowSpO2Critical or pulseRateIn < pulseRateLow or pulseRateIn > pulseRateHigh) then Warning;
            transition Normal_to_Critical first Normal if (spo2In < lowSpO2Critical) then Critical;
            transition Warning_to_Normal first Warning if (spo2In >= lowSpO2Warning and pulseRateIn >= pulseRateLow and pulseRateIn <= pulseRateHigh) then Normal;
            transition Warning_to_Critical first Warning if (spo2In < lowSpO2Critical) then Critical;
            transition Critical_to_Warning first Critical if (spo2In >= lowSpO2Critical and spo2In < lowSpO2Warning) then Warning;
            transition Critical_to_Normal first Critical if (spo2In >= lowSpO2Warning and pulseRateIn >= pulseRateLow and pulseRateIn <= pulseRateHigh) then Normal;
        }
    }

    part def PowerUnit {
        part rechargeableBattery {
            attribute capacity : BatteryCapacity = 3000.0;
            attribute currentLevel : BatteryLevel = 100.0;
        }
    }

    part def NellcorOximeter {
        attribute spo2Accuracy : Accuracy = 2.0;
        attribute pulseRateAccuracy : Accuracy = 3.0;
        attribute alarmResponseTime : ResponseTime = 0.5;
        attribute batteryLife : Real = 10.0;
        attribute lowSpO2Threshold : SpO2 = 90.0;

        part fingerSensor : OpticalFingerSensor;
        part processor : SignalProcessingUnit;
        part display : DisplayModule;
        part alarm : AlarmSubsystem;
        part power : PowerUnit;

        connect fingerSensor.rawSignalOut to processor.rawSignalIn;
        connect processor.spo2Out to display.spo2In;
        connect processor.pulseRateOut to display.pulseRateIn;
        connect processor.waveformOut to display.waveformIn;
        connect processor.spo2Out to alarm.spo2In;
        connect processor.pulseRateOut to alarm.pulseRateIn;

        state machine stateBehavior {
            state Off;
            state Monitoring;
            state AlarmActive;

            transition Off_to_Monitoring first Off if (power.rechargeableBattery.currentLevel > 0.0) then Monitoring;
            transition Monitoring_to_AlarmActive first Monitoring if (alarm.visualAlarm.active == true) then AlarmActive;
            transition AlarmActive_to_Monitoring first AlarmActive if (alarm.visualAlarm.active == false) then Monitoring;
            transition Monitoring_to_Off first Monitoring if (power.rechargeableBattery.currentLevel == 0.0) then Off;
            transition AlarmActive_to_Off first AlarmActive if (power.rechargeableBattery.currentLevel == 0.0) then Off;
        }
    }

    requirement measurementAccuracyReq {
        doc "The device shall measure SpO2 with an accuracy of ±2% and pulse rate with an accuracy of ±3 bpm.";
    }
    requirement patientSafetyReq {
        doc "The system shall activate alarms within 10 seconds if SpO2 drops below 90%.";
    }
    requirement operationalReliabilityReq {
        doc "The device shall operate for at least 8 hours on a full battery charge.";
    }

    part nellcorOximeter : NellcorOximeter;
    satisfy measurementAccuracyReq by nellcorOximeter;
    satisfy patientSafetyReq by nellcorOximeter;
    satisfy operationalReliabilityReq by nellcorOximeter;
}
