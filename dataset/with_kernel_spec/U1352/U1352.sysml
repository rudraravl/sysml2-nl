package NodeRedTempMonitoring {
	private import ScalarValues::*;

	item def MQTTMessage {
		attribute topic : String;
		attribute payload : String;
	}

	item def TempData {
		attribute tempC : Real;
	}

	item def TempReading {
		attribute tempF : Real;
	}

	item def HighTempAlert {
		attribute tempF : Real;
	}

	item def NormalTempReading {
		attribute tempF : Real;
	}

	port def MQTTOutPort {
		out item msg : MQTTMessage;
	}

	port def MQTTInPort {
		in item msg : MQTTMessage;
	}

	port def DebugOutPort {
		out item alert : HighTempAlert;
	}

	port def DebugInPort {
		in item alert : HighTempAlert;
	}

	port def GaugeOutPort {
		out item alert : HighTempAlert;
	}

	port def GaugeInPort {
		in item alert : HighTempAlert;
	}

	port def ChartOutPort {
		out item reading : NormalTempReading;
	}

	port def ChartInPort {
		in item reading : NormalTempReading;
	}

	action def ParseJSON {
		in item msg : MQTTMessage;
		out item data : TempData;
	}

	action def ConvertTemp {
		in item data : TempData;
		out item reading : TempReading;
	}

	part def TempSensor {
		port outPort : MQTTOutPort;
		perform action generateReading {
			out item msg : MQTTMessage;
		}
	}

	part def MQTTBroker {
		port inPort : MQTTInPort;
		port outPort : MQTTOutPort;
	}

	part def NodeRedFlow {
		port inPort : MQTTInPort;
		port debugOut : DebugOutPort;
		port gaugeOut : GaugeOutPort;
		port chartOut : ChartOutPort;

		perform action flowExecution {
			action parse : ParseJSON {
				in item msg = inPort.msg;
				out item data;
			}
			then action convert : ConvertTemp {
				in item data = parse.data;
				out item reading;
			}
			then decide;
			if convert.reading.tempF >= 75 then highTemp;
			else normalTemp;

			action highTemp;
			then fork;
			then send new HighTempAlert(convert.reading.tempF) via debugOut;
			then send new HighTempAlert(convert.reading.tempF) via gaugeOut;
			then done;

			action normalTemp;
			then send new NormalTempReading(convert.reading.tempF) via chartOut;
			then done;
		}
	}

	part def DebugConsole {
		port inPort : DebugInPort;
		perform action logMessage {
			in item alert : HighTempAlert;
		}
	}

	part def Dashboard {
		part gaugeWidget {
			port inPort : GaugeInPort;
			perform action displayGauge {
				in item alert : HighTempAlert;
			}
		}
		part lineChartWidget {
			port inPort : ChartInPort;
			perform action displayChart {
				in item reading : NormalTempReading;
			}
		}
	}

	requirement def TempThresholdDef {
		/* Temperature readings at or above 75 degrees Fahrenheit must trigger an alert routed to the debug console and dashboard gauge. */
		attribute threshold : Real = 75.0;
	}

	requirement def DataConversionDef {
		/* Temperature readings shall be converted from Celsius to Fahrenheit before evaluation. */
	}

	requirement def AlertRoutingDef {
		/* High-temperature alerts shall be sent simultaneously to a debug console and a dashboard gauge widget. */
	}

	requirement def NormalRoutingDef {
		/* Normal temperature readings below 75 degrees Fahrenheit shall be sent to a line chart widget for trend monitoring. */
	}

	part system {
		part sensor : TempSensor;
		part broker : MQTTBroker;
		part nodeRedFlow : NodeRedFlow;
		part debug : DebugConsole;
		part dashboard : Dashboard;

		interface sensorToBroker : sensor.outPort to broker.inPort;
		interface brokerToFlow : broker.outPort to nodeRedFlow.inPort;
		interface flowToDebug : nodeRedFlow.debugOut to debug.inPort;
		interface flowToGauge : nodeRedFlow.gaugeOut to dashboard.gaugeWidget.inPort;
		interface flowToChart : nodeRedFlow.chartOut to dashboard.lineChartWidget.inPort;

		requirement tempThreshold : TempThresholdDef;
		requirement dataConversion : DataConversionDef;
		requirement alertRouting : AlertRoutingDef;
		requirement normalRouting : NormalRoutingDef;

		satisfy tempThreshold by nodeRedFlow.flowExecution;
		satisfy dataConversion by nodeRedFlow.flowExecution.convert;
		satisfy alertRouting by nodeRedFlow.flowExecution.highTemp;
		satisfy normalRouting by nodeRedFlow.flowExecution.normalTemp;
	}
}
