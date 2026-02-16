package 'Pressure Gauge System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PressureReading;
	attribute def CalibrationStatus;
	attribute def AlarmState;
	
	item def PressurizedFluid {
		attribute pressure : PressureValue;
		attribute temperature : ThermodynamicTemperatureValue;
	}
	
	port def FluidPort {
		attribute measuredPressure : PressureValue;
		in item fluid : PressurizedFluid;
	}
	
	port def DisplayPort {
		out attribute reading : PressureValue;
		out attribute status : CalibrationStatus;
		out attribute alarm : AlarmState;
	}
	
	port def PowerPort {
		in attribute voltage : ElectricPotentialValue;
		in attribute current : ElectricCurrentValue;
	}
	
	part def PressureSensor {
		port sensorPort : FluidPort;
		port powerIn : PowerPort;
		attribute sensitivity : Real;
		attribute accuracy : Real;
		
		action def MeasurePressure {
			in fluidPressure : PressureValue;
			out sensorOutput : PressureValue;
		}
		
		perform action sensing : MeasurePressure[*] ordered;
	}
	
	part def SignalProcessor {
		attribute calibrationFactor : Real;
		attribute zeroOffset : PressureValue;
		
		action def ProcessSignal {
			in rawSignal : PressureValue;
			in calibration : Real;
			in offset : PressureValue;
			out processedReading : PressureValue;
		}
		
		action def CheckCalibration {
			in lastCalibrationTime : TimeValue;
			in currentTime : TimeValue;
			out isValid : Boolean;
		}
		
		perform action processing : ProcessSignal[*] ordered;
	}
	
	part def DisplayUnit {
		port displayOut : DisplayPort;
		attribute displayResolution : PressureValue;
		attribute updateRate : FrequencyValue;
		
		action def UpdateDisplay {
			in pressureValue : PressureValue;
			in statusValue : CalibrationStatus;
			out displayReading : PressureValue;
		}
		
		perform action displaying : UpdateDisplay[*] ordered;
	}
	
	part def AlarmController {
		attribute highThreshold : PressureValue;
		attribute lowThreshold : PressureValue;
		attribute hysteresis : PressureValue;
		attribute currentAlarm : AlarmState;
		
		state def AlarmStateMachine {
			entry; then normal;
			
			state normal;
			
			state highPressureAlarm;
			
			state lowPressureAlarm;
			
			transition normal_to_high
				first normal
				accept pressureReading : PressureReading
				if pressureReading.value > highThreshold
				then highPressureAlarm;
			
			transition normal_to_low
				first normal
				accept pressureReading : PressureReading
				if pressureReading.value < lowThreshold
				then lowPressureAlarm;
			
			transition high_to_normal
				first highPressureAlarm
				accept pressureReading : PressureReading
				if pressureReading.value < (highThreshold - hysteresis)
				then normal;
			
			transition low_to_normal
				first lowPressureAlarm
				accept pressureReading : PressureReading
				if pressureReading.value > (lowThreshold + hysteresis)
				then normal;
		}
		
		perform state alarmBehavior : AlarmStateMachine;
	}
	
	part def PressureGauge {
		port fluidInput : FluidPort;
		port displayOutput : DisplayPort;
		port powerSupply : PowerPort;
		
		part sensor : PressureSensor {
			connect fluidInput to sensor.sensorPort;
			connect powerSupply to sensor.powerIn;
		}
		
		part processor : SignalProcessor;
		
		part display : DisplayUnit {
			connect displayOutput to display.displayOut;
		}
		
		part alarmControl : AlarmController;
		
		action def MonitorPressure {
			first start;
			then merge continuousMonitoring;
			
			then action measure {
				in fluidPressure : PressureValue;
				out rawReading : PressureValue;
			}
			
			then action process {
				in rawSignal : PressureValue = measure.rawReading;
				out calibratedReading : PressureValue;
			}
			
			then action checkAlarms {
				in currentPressure : PressureValue = process.calibratedReading;
				out alarmStatus : AlarmState;
			}
			
			then action updateDisplay {
				in pressureToDisplay : PressureValue = process.calibratedReading;
				in alarmToDisplay : AlarmState = checkAlarms.alarmStatus;
			}
			
			then continuousMonitoring;
		}
		
		perform action monitoring : MonitorPressure;
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The pressure gauge shall measure pressure with an accuracy of +/- 0.5% of full scale. */
		
		subject gauge : PressureGauge;
		
		require constraint {
			gauge.sensor.accuracy <= 0.005
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The pressure gauge shall update the display within 100 milliseconds of a pressure change. */
		
		subject gauge : PressureGauge;
	}
	
	requirement def AlarmFunctionRequirement {
		doc /* The pressure gauge shall activate alarms when pressure exceeds configured thresholds. */
		
		subject gauge : PressureGauge;
		
		require constraint {
			gauge.alarmControl.highThreshold > gauge.alarmControl.lowThreshold
		}
	}
	
	requirement def OperatingRangeRequirement {
		doc /* The pressure gauge shall operate accurately across the specified pressure and temperature ranges. */
		
		subject gauge : PressureGauge;
	}
	
	requirement <'PG-001'> pressureGaugeSystemRequirement {
		doc /* The pressure gauge system shall continuously monitor fluid pressure and provide accurate real-time readings with alarm capability. */
		
		require MeasurementAccuracyRequirement;
		require ResponseTimeRequirement;
		require AlarmFunctionRequirement;
		require OperatingRangeRequirement;
	}
	
	part pressureGaugeSystem : PressureGauge {
		attribute operatingRange : PressureValue[2];
		attribute temperatureRange : ThermodynamicTemperatureValue[2];
		
		perform action continuousMonitoring references monitoring {
			in attribute fluidPressure : PressureValue;
			out attribute displayedPressure : PressureValue;
			out attribute systemAlarm : AlarmState;
		}
	}
}
