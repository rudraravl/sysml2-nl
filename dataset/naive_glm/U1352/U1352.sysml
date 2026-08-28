package TemperatureMonitoringSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    attribute def TemperatureCelsius :> Real {
        unit '°C';
    }
    attribute def TemperatureFahrenheit :> Real {
        unit '°F';
    }
    attribute def TemperatureThreshold :> Real {
        unit '°F';
    }

    // ---- Item definitions ----
    item def RawSensorMessage {
        attribute payload : String; // JSON string
        attribute topic : String;
    }
    item def ParsedMessage {
        attribute sensorId : String;
        attribute tempC : TemperatureCelsius;
        attribute timestamp : String;
    }
    item def ConvertedMessage {
        attribute sensorId : String;
        attribute tempC : TemperatureCelsius;
        attribute tempF : TemperatureFahrenheit;
        attribute timestamp : String;
    }
    item def AlertMessage {
        attribute sensorId : String;
        attribute tempF : TemperatureFahrenheit;
        attribute severity : String;
        attribute timestamp : String;
    }
    item def NormalMessage {
        attribute sensorId : String;
        attribute tempF : TemperatureFahrenheit;
        attribute timestamp : String;
    }

    // ---- Port definitions ----
    port def MQTTSubscriberPort {
        out item rawMsg : RawSensorMessage;
    }
    port def MQTTPublisherPort {
        in item rawMsg : RawSensorMessage;
    }
    port def ParsedMsgPort {
        in item parsed : ParsedMessage;
        out item parsed : ParsedMessage;
    }
    port def ConvertedMsgPort {
        in item converted : ConvertedMessage;
        out item converted : ConvertedMessage;
    }
    port def AlertMsgPort {
        in item alert : AlertMessage;
        out item alert : AlertMessage;
    }
    port def NormalMsgPort {
        in item normal : NormalMessage;
        out item normal : NormalMessage;
    }
    port def DebugPort {
        in item msg : Anything;
    }

    // ---- Node abstractions ----
    part def NodeREDNode {
        attribute nodeId : String;
        attribute name : String;
    }

    // ---- MQTT Broker ----
    part def MQTTBroker :> NodeREDNode {
        port pubSub : MQTTPublisherPort;
        attribute brokerUrl : String;
        attribute port : Integer;
    }

    // ---- MQTT Input Node ----
    part def MQTTInputNode :> NodeREDNode {
        port subscriberOut : MQTTSubscriberPort;
        attribute topic : String;
        attribute brokerRef : String;

        state def ReceiveStates {
            entry; then Listening;
            state Listening;
            transition Listening -> Listening
                when subscriberOut.rawMsg'@' 
                do send subscriberOut.rawMsg();
        }
        exhibit ReceiveStates;
    }

    // ---- JSON Parse Function Node ----
    part def JSONParseNode :> NodeREDNode {
        port parseIn : ParsedMsgPort;
        port parseOut : ParsedMsgPort;
        attribute jsonSchema : String;

        action def ParseAction {
            in raw : RawSensorMessage;
            out parsed : ParsedMessage;
        }
        perform ParseAction;
    }

    // ---- Celsius to Fahrenheit Conversion Node ----
    part def ConvertFunctionNode :> NodeREDNode {
        port convertIn : ConvertedMsgPort;
        port convertOut : ConvertedMsgPort;
        attribute conversionFormula : String = "F = C * 9/5 + 32";

        action def ConvertAction {
            in parsed : ParsedMessage;
            out converted : ConvertedMessage;
            // F = C * 9/5 + 32
        }
        perform ConvertAction;
    }

    // ---- Switch Node for conditional routing ----
    part def SwitchNode :> NodeREDNode {
        port switchIn : ConvertedMsgPort;
        port alertOut : AlertMsgPort;
        port normalOut : NormalMsgPort;
        attribute threshold : TemperatureThreshold = 75.0;

        action def SwitchAction {
            in converted : ConvertedMessage;
            out alert : AlertMessage;
            out normal : NormalMessage;
            decision if converted.tempF >= 75.0 then
                send alert;
            else
                send normal;
        }
        perform SwitchAction;
    }

    // ---- Debug Output Node ----
    part def DebugNode :> NodeREDNode {
        port debugIn : DebugPort;
        attribute outputTarget : String = "debug console";

        action def LogAction {
            in msg : Anything;
        }
        perform LogAction;
    }

    // ---- Dashboard Gauge Node (high temp alert display) ----
    part def DashboardGaugeNode :> NodeREDNode {
        port gaugeIn : AlertMsgPort;
        attribute widgetType : String = "gauge";
        attribute label : String = "High Temperature Alert";
        attribute minRange : TemperatureFahrenheit = 32.0;
        attribute maxRange : TemperatureFahrenheit = 150.0;

        action def DisplayGaugeAction {
            in alert : AlertMessage;
        }
        perform DisplayGaugeAction;
    }

    // ---- Dashboard Chart Node (normal trend display) ----
    part def DashboardChartNode :> NodeREDNode {
        port chartIn : NormalMsgPort;
        attribute widgetType : String = "line chart";
        attribute label : String = "Temperature Trend";

        action def DisplayChartAction {
            in normal : NormalMessage;
        }
        perform DisplayChartAction;
    }

    // ---- Dashboard subsystem ----
    part def Dashboard {
        part gauge : DashboardGaugeNode;
        part chart : DashboardChartNode;
    }

    // ---- The complete Node-RED Flow ----
    part def TemperatureMonitoringFlow {
        part broker : MQTTBroker {
            port pubSub : MQTTPublisherPort;
        }
        part mqttInput : MQTTInputNode;
        part jsonParse : JSONParseNode;
        part convert : ConvertFunctionNode;
        part switch : SwitchNode;
        part debug : DebugNode;
        part dashboard : Dashboard;

        connection broker.pubSub.rawMsg to mqttInput.subscriberOut.rawMsg;
        connection mqttInput.subscriberOut.rawMsg to jsonParse.parseIn.parsed;
        connection jsonParse.parseOut.parsed to convert.convertIn.converted;
        connection convert.convertOut.converted to switch.switchIn.converted;
        connection switch.alertOut.alert to debug.debugIn.msg;
        connection switch.alertOut.alert to dashboard.gauge.gaugeIn.alert;
        connection switch.normalOut.normal to dashboard.chart.chartIn.normal;
    }

    // ---- System-level state machine ----
    part def MonitoringSystem {
        part flow : TemperatureMonitoringFlow;

        state def SystemStates {
            entry; then Idle;
            state Idle;
            state Receiving;
            state Parsing;
            state Converting;
            state Routing;
            state Alerting;
            state LoggingNormal;

            transition Idle -> Receiving
                when flow.mqttInput.subscriberOut.rawMsg'@';
            transition Receiving -> Parsing;
            transition Parsing -> Converting;
            transition Converting -> Routing;
            transition Routing -> Alerting
                when flow.switch.alertOut.alert'@';
            transition Routing -> LoggingNormal
                when flow.switch.normalOut.normal'@';
            transition Alerting -> Idle;
            transition LoggingNormal -> Idle;
        }
        exhibit SystemStates;
    }

    // ---- Requirements ----
    requirement def ReceiveSensorData {
        subject system : MonitoringSystem;
        objective {
            The system shall receive temperature sensor data from an MQTT broker as JSON-formatted messages.
        }
    }
    requirement def ParseJSONData {
        subject system : MonitoringSystem;
        objective {
            The system shall parse incoming raw JSON messages to extract the temperature value in Celsius.
        }
    }
    requirement def ConvertTemperature {
        subject system : MonitoringSystem;
        objective {
            The system shall convert the temperature from Celsius to Fahrenheit using the formula F = C * 9/5 + 32.
        }
    }
    requirement def RouteByThreshold {
        subject system : MonitoringSystem;
        objective {
            The system shall route the converted temperature to the alert path if the Fahrenheit value is 75 or higher, and to the normal path otherwise.
        }
    }
    requirement def DisplayAlert {
        subject system : MonitoringSystem;
        objective {
            The system shall display high-temperature alerts on a dashboard gauge widget and log them to the debug console simultaneously.
        }
    }
    requirement def DisplayNormalTrend {
        subject system : MonitoringSystem;
        objective {
            The system shall display normal temperature readings on a dashboard line chart widget for trend monitoring.
        }
    }

    // ---- Requirement satisfaction ----
    part monitoringSystem : MonitoringSystem {
        satisfy ReceiveSensorData by flow.mqttInput;
        satisfy ParseJSONData by flow.jsonParse;
        satisfy ConvertTemperature by flow.convert;
        satisfy RouteByThreshold by flow.switch;
        satisfy DisplayAlert by flow.dashboard.gauge;
        satisfy DisplayAlert by flow.debug;
        satisfy DisplayNormalTrend by flow.dashboard.chart;
    }
}
