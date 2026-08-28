package 'Tire Pressure Monitoring System' {
	private import ScalarValues::*;
	private import ISQ::PressureValue;
	private import ISQ::TemperatureValue;
	private import Time::TimeInstantValue;
	private import SI::s;
	private import SI::Pa;
	private import SI::K;

	enum def TireLocation {
		FrontLeft;
		FrontRight;
		RearLeft;
		RearRight;
	}

	enum def AlertSeverity {
		Nominal;
		Low;
		CriticalLow;
		High;
	}

	attribute def TireData {
		attribute location : TireLocation;
		attribute pressure : PressureValue;
		attribute temperature : TemperatureValue;
		attribute batteryLevel : Real;
		attribute timestamp : TimeInstantValue;
	}

	attribute def AlertMessage {
		attribute location : TireLocation;
		attribute severity : AlertSeverity;
		attribute text : String;
	}

	action def ShowWarning;
	action def PlayAudibleAlert;

	part def TireSensor {
		attribute location : TireLocation;
		attribute measuredPressure : PressureValue = 200000 [Pa];
		attribute measuredTemperature : TemperatureValue = 298 [K];
		attribute batteryLevel : Real = 100;

		port rfOutPort {
			out tireData : TireData;
		}

		exhibit state sensorStates {
			entry; then measuring;
			state measuring;
			accept after 5 [s]
				do send new TireData(
					location = location,
					pressure = measuredPressure,
					temperature = measuredTemperature,
					batteryLevel = batteryLevel
				) to rfOutPort
				then measuring;
		}
	}

	part def RFReceiver {
		port rfInPort {
			in tireData : TireData;
		}
		port ecuOutPort {
			out tireData : TireData;
		}
		flow tireDataPassThrough of TireData
			from rfInPort.tireData to ecuOutPort.tireData;
	}

	part def ECU {
		port receiverInPort {
			in tireData : TireData;
		}
		port displayOutPort {
			out alert : AlertMessage;
		}

		attribute lowPressureThreshold : PressureValue = 193000 [Pa];
		attribute criticalPressureThreshold : PressureValue = 151000 [Pa];
		attribute highPressureThreshold : PressureValue = 275000 [Pa];

		exhibit state ecuStates {
			entry; then normal;
			state normal;
			accept data : TireData
				if data.pressure < criticalPressureThreshold
				do send new AlertMessage(
					location = data.location,
					severity = AlertSeverity::CriticalLow,
					text = "Critical Low Pressure"
				) to displayOutPort
				then critical;
			accept data : TireData
				if data.pressure < lowPressureThreshold and data.pressure >= criticalPressureThreshold
				do send new AlertMessage(
					location = data.location,
					severity = AlertSeverity::Low,
					text = "Low Pressure"
				) to displayOutPort
				then warning;
			accept data : TireData
				if data.pressure > highPressureThreshold
				do send new AlertMessage(
					location = data.location,
					severity = AlertSeverity::High,
					text = "High Pressure"
				) to displayOutPort
				then high;

			state warning;
			accept data : TireData
				if data.pressure < criticalPressureThreshold
				do send new AlertMessage(
					location = data.location,
					severity = AlertSeverity::CriticalLow,
					text = "Critical Low Pressure"
				) to displayOutPort
				then critical;
			accept data : TireData
				if data.pressure > highPressureThreshold
				do send new AlertMessage(
					location = data.location,
					severity = AlertSeverity::High,
					text = "High Pressure"
				) to displayOutPort
				then high;
			accept data : TireData
				if data.pressure >= lowPressureThreshold and data.pressure <= highPressureThreshold
				do send new AlertMessage(
					location = data.location,
					severity = AlertSeverity::Nominal,
					text = "Pressure Normal"
				) to displayOutPort
				then normal;

			state critical;
			accept data : TireData
				if data.pressure >= lowPressureThreshold and data.pressure <= highPressureThreshold
				do send new AlertMessage(
					location = data.location,
					severity = AlertSeverity::Nominal,
					text = "Pressure Normal"
				) to displayOutPort
				then normal;
			accept data : TireData
				if data.pressure >= lowPressureThreshold
				do send new AlertMessage(
					location = data.location,
					severity = AlertSeverity::Low,
					text = "Low Pressure"
				) to displayOutPort
				then warning;

			state high;
			accept data : TireData
				if data.pressure <= highPressureThreshold and data.pressure >= lowPressureThreshold
				do send new AlertMessage(
					location = data.location,
					severity = AlertSeverity::Nominal,
					text = "Pressure Normal"
				) to displayOutPort
				then normal;
			accept data : TireData
				if data.pressure < lowPressureThreshold and data.pressure >= criticalPressureThreshold
				then warning;
			accept data : TireData
				if data.pressure < criticalPressureThreshold
				then critical;
		}
	}

	part def DriverDisplay {
		port ecuInPort {
			in alert : AlertMessage;
		}

		perform action showWarning : ShowWarning;
		perform action playAudibleAlert : PlayAudibleAlert;

		exhibit state displayStates {
			entry; then idle;
			state idle;
			accept alertMsg : AlertMessage
				if alertMsg.severity != AlertSeverity::Nominal
				then active;
			state active {
				entry showWarning;
				do playAudibleAlert;
			}
			accept alertMsg : AlertMessage
				if alertMsg.severity == AlertSeverity::Nominal
				then idle;
		}
	}

	part def TPMS {
		part frontLeftSensor : TireSensor {
			attribute :>> location = TireLocation::FrontLeft;
		}
		part frontRightSensor : TireSensor {
			attribute :>> location = TireLocation::FrontRight;
		}
		part rearLeftSensor : TireSensor {
			attribute :>> location = TireLocation::RearLeft;
		}
		part rearRightSensor : TireSensor {
			attribute :>> location = TireLocation::RearRight;
		}

		part receiver : RFReceiver;
		part ecu : ECU;
		part display : DriverDisplay;

		flow frontLeftFlow of TireData
			from frontLeftSensor.rfOutPort.tireData to receiver.rfInPort.tireData;
		flow frontRightFlow of TireData
			from frontRightSensor.rfOutPort.tireData to receiver.rfInPort.tireData;
		flow rearLeftFlow of TireData
			from rearLeftSensor.rfOutPort.tireData to receiver.rfInPort.tireData;
		flow rearRightFlow of TireData
			from rearRightSensor.rfOutPort.tireData to receiver.rfInPort.tireData;

		flow receiverToEcuFlow of TireData
			from receiver.ecuOutPort.tireData to ecu.receiverInPort.tireData;
		flow ecuToDisplayFlow of AlertMessage
			from ecu.displayOutPort.alert to display.ecuInPort.alert;
	}

	requirement def 'Monitor Tire Pressure' {
		subject tpms : TPMS;
		doc
		/* The system shall continuously monitor tire pressure and
		 * alert the driver if pressure becomes dangerously low or high. */
	}

	requirement def 'Report Tire Location' {
		subject tpms : TPMS;
		doc
		/* The alert message shall identify the affected tire location
		 * and the severity of the pressure condition. */
	}

	requirement def 'Return to Normal' {
		subject tpms : TPMS;
		doc
		/* The system shall return to a normal monitoring state once
		 * the tire pressure is corrected back into the safe range. */
	}
}
