package 'Permanent Downhole Gauge System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def WellborePressure :> PressureValue;
	attribute def DownholeTemperature :> TemperatureValue;
	attribute def FlowRateValue :> VolumeFlowRateValue;
	attribute def VibrationLevel :> AccelerationValue;
	attribute def BatteryCharge :> Real;

	item def Power;
	item def RawData;
	item def CalibratedData;
	item def TelemetryPacket;
	item def SurfaceCommand;

	attribute def FaultAlert;
	attribute def StartSignal;
	attribute def ResetCommand;
	attribute def FaultSignal;

	port def 'PowerOutPort' {
		out pwr : Power;
	}
	port def 'PowerInPort' {
		in pwr : Power;
	}
	port def 'PressurePort' {
		inout pressure : WellborePressure;
	}
	port def 'TempPort' {
		inout temp : DownholeTemperature;
	}
	port def 'FlowPort' {
		inout flowRate : FlowRateValue;
	}
	port def 'VibrationPort' {
		inout vibration : VibrationLevel;
	}
	port def 'RawDataPort' {
		inout data : RawData;
	}
	port def 'CalDataPort' {
		inout data : CalibratedData;
	}
	port def 'TelemetryPort' {
		inout packet : TelemetryPacket;
	}
	port def 'CommandPort' {
		in cmd : SurfaceCommand;
		in startCmd : StartSignal;
		in resetCmd : ResetCommand;
		in faultCmd : FaultSignal;
	}
	port def 'AlertInPort' {
		in alert : FaultAlert;
	}

	action def 'Acquire Data' {
		in pressure : WellborePressure;
		in temp : DownholeTemperature;
		in flowRate : FlowRateValue;
		in vibration : VibrationLevel;
		out data : RawData;
	}
	action def 'Calibrate Data' {
		in raw : RawData;
		out calibrated : CalibratedData;
	}
	action def 'Transmit Data' {
		in data : CalibratedData;
		out packet : TelemetryPacket;
	}
	action def 'Perform Self Test';
	action def 'Diagnose Fault';

	state def 'PDG Operational States';

	part def 'Protective Housing' {
		attribute material : String = "Inconel";
		attribute maxPressure : WellborePressure;
		attribute maxTemperature : DownholeTemperature;
	}

	part def 'Pressure Transducer' {
		port powerIn : 'PowerInPort';
		port dataOut : 'PressurePort';
	}

	part def 'Temperature Transducer' {
		port powerIn : 'PowerInPort';
		port dataOut : 'TempPort';
	}

	part def 'Flow Sensor' {
		port powerIn : 'PowerInPort';
		port dataOut : 'FlowPort';
	}

	part def 'Accelerometer' {
		port powerIn : 'PowerInPort';
		port dataOut : 'VibrationPort';
	}

	part def 'Data Acquisition Module' {
		port powerIn : 'PowerInPort';
		port pressureIn : 'PressurePort';
		port tempIn : 'TempPort';
		port flowIn : 'FlowPort';
		port vibIn : 'VibrationPort';
		port dataOut : 'RawDataPort';

		perform action 'acquire data' : 'Acquire Data' {
			in pressure = pressureIn.pressure;
			in temp = tempIn.temp;
			in flowRate = flowIn.flowRate;
			in vibration = vibIn.vibration;
			out data = dataOut.data;
		}
	}

	part def 'Calibration Module' {
		port powerIn : 'PowerInPort';
		port dataIn : 'RawDataPort';
		port dataOut : 'CalDataPort';

		perform action 'calibrate data' : 'Calibrate Data' {
			in raw = dataIn.data;
			out calibrated = dataOut.data;
		}
	}

	part def 'Telemetry Unit' {
		port powerIn : 'PowerInPort';
		port dataIn : 'CalDataPort';
		port cmdIn : 'CommandPort';
		port alertIn : 'AlertInPort';
		port telemetryOut : 'TelemetryPort';

		perform action 'transmit data' : 'Transmit Data' {
			in data = dataIn.data;
			out packet = telemetryOut.packet;
		}
	}

	part def 'Battery Pack' {
		port powerOut : 'PowerOutPort';
		attribute capacity : Real;
		attribute currentCharge : BatteryCharge;
	}

	requirement def 'Monitor Well Conditions' {
		subject pdg : 'PDG System';
		text "The PDG shall continuously monitor pressure, temperature, flow rate, and vibration.";
	}

	requirement def 'Survive Extreme Environment' {
		subject housing : 'Protective Housing';
		text "The system shall withstand high pressure, high temperature, and corrosive fluids.";
	}

	requirement def 'Long Battery Life' {
		subject battery : 'Battery Pack';
		text "The battery shall last for multiple years without intervention.";
	}

	part def 'PDG System' {
		requirement req1 : 'Monitor Well Conditions';
		requirement req2 : 'Survive Extreme Environment';
		requirement req3 : 'Long Battery Life';

		port surfaceCmdIn : 'CommandPort';

		part housing : 'Protective Housing';
		part pressureSensor : 'Pressure Transducer';
		part tempSensor : 'Temperature Transducer';
		part flowSensor : 'Flow Sensor';
		part accelSensor : 'Accelerometer';
		part daq : 'Data Acquisition Module';
		part calib : 'Calibration Module';
		part telemetry : 'Telemetry Unit';
		part battery : 'Battery Pack';

		connect battery.powerOut to pressureSensor.powerIn;
		connect battery.powerOut to tempSensor.powerIn;
		connect battery.powerOut to flowSensor.powerIn;
		connect battery.powerOut to accelSensor.powerIn;
		connect battery.powerOut to daq.powerIn;
		connect battery.powerOut to calib.powerIn;
		connect battery.powerOut to telemetry.powerIn;

		connect pressureSensor.dataOut to daq.pressureIn;
		connect tempSensor.dataOut to daq.tempIn;
		connect flowSensor.dataOut to daq.flowIn;
		connect accelSensor.dataOut to daq.vibIn;

		connect daq.dataOut to calib.dataIn;
		connect calib.dataOut to telemetry.dataIn;
		connect surfaceCmdIn to telemetry.cmdIn;

		exhibit state 'operational states' : 'PDG Operational States';
	}

	action 'perform self test' : 'Perform Self Test';
	action 'diagnose fault' : 'Diagnose Fault';
	action 'transmit telemetry' : 'Transmit Data';

	state 'operational states' : 'PDG Operational States' {
		in pdg : 'PDG System';
		entry; then initialization;
		state initialization {
			entry 'perform self test';
			accept StartSignal then normal;
		}
		state normal {
			do 'transmit telemetry';
			accept FaultSignal then fault;
			accept when pdg.battery.currentCharge < 0.1 then fault;
		}
		state fault {
			entry 'diagnose fault';
			do send new FaultAlert() to pdg.telemetry;
			accept ResetCommand then initialization;
		}
	}
}
