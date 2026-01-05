package AlertMeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SensorReading {
        attribute value : Real;
        attribute timestamp : ISQ::TimeValue;
        attribute sensorId : String;
    }
    
    attribute def ThresholdConfig {
        attribute warningLevel : Real;
        attribute criticalLevel : Real;
    }
    
    attribute def AlertLevel {
        attribute severity : Integer;
        attribute description : String;
    }
    
    item def AlertNotification {
        attribute level : AlertLevel;
        attribute content : String;
        attribute timestamp : ISQ::TimeValue;
        attribute sourceId : String;
    }
    
    port def SensorDataPort {
        out reading : SensorReading;
    }
    
    port def AlertPort {
        out notification : AlertNotification;
    }
    
    port def UserInterfacePort {
        in acknowledgement : Boolean;
        out displayMessage : AlertNotification;
    }
    
    part def EnvironmentalSensor {
        attribute sensorId : String;
        attribute currentReading : Real;
        port dataOut : SensorDataPort;
        
        action def MeasureEnvironment {
            out measurement : SensorReading;
        }
        
        perform action continuousMeasurement[*] {
            action measure : MeasureEnvironment {
                out measurement : SensorReading;
            }
            flow measure.measurement to dataOut.reading;
        }
    }
    
    part def MonitoringController {
        attribute thresholds : ThresholdConfig;
        port sensorIn : ~SensorDataPort;
        port alertOut : AlertPort;
        
        action def EvaluateThreshold {
            in reading : SensorReading;
            in config : ThresholdConfig;
            out alert : AlertNotification;
        }
        
        action monitoringBehavior {
            first start;
            then merge checkLoop;
            then action receiveReading {
                out currentReading : SensorReading;
            }
            flow receiveReading.currentReading from sensorIn.reading;
            then action evaluate : EvaluateThreshold {
                in reading = receiveReading.currentReading;
                in config = thresholds;
                out alert : AlertNotification;
            }
            then decide;
                if evaluate.alert.level.severity >= 2 then sendCritical;
                if evaluate.alert.level.severity == 1 then sendWarning;
                if evaluate.alert.level.severity == 0 then checkLoop;
            action sendWarning {
                in warningAlert : AlertNotification = evaluate.alert;
            }
            flow sendWarning.warningAlert to alertOut.notification;
            then checkLoop;
            action sendCritical {
                in criticalAlert : AlertNotification = evaluate.alert;
            }
            flow sendCritical.criticalAlert to alertOut.notification;
            then checkLoop;
        }
    }
    
    part def NotificationDispatcher {
        port alertIn : ~AlertPort;
        port userOut : UserInterfacePort;
        
        attribute pendingAlerts : AlertNotification[*];
        attribute acknowledgedAlerts : AlertNotification[*];
        
        action def DispatchNotification {
            in alert : AlertNotification;
            out dispatched : Boolean;
        }
        
        action manageNotifications {
            first start;
            then merge waitForAlert;
            then action receiveAlert {
                out incomingAlert : AlertNotification;
            }
            flow receiveAlert.incomingAlert from alertIn.notification;
            then action dispatch : DispatchNotification {
                in alert = receiveAlert.incomingAlert;
                out dispatched : Boolean;
            }
            flow dispatch.alert to userOut.displayMessage;
            then action waitForAck {
                out ack : Boolean;
            }
            flow waitForAck.ack from userOut.acknowledgement;
            then decide;
                if waitForAck.ack then archiveAlert;
                if not waitForAck.ack then escalate;
            action archiveAlert {
                in alert : AlertNotification = receiveAlert.incomingAlert;
            }
            then waitForAlert;
            action escalate {
                in alert : AlertNotification = receiveAlert.incomingAlert;
            }
            then waitForAlert;
        }
    }
    
    part def UserDisplay {
        port displayPort : ~UserInterfacePort;
        
        attribute activeNotifications : AlertNotification[*];
        
        action def ShowAlert {
            in notification : AlertNotification;
        }
        
        action def AcknowledgeAlert {
            in alertId : String;
            out confirmed : Boolean;
        }
    }
    
    part def DataArchive {
        attribute historicalReadings : SensorReading[*];
        attribute alertHistory : AlertNotification[*];
        
        action def StoreReading {
            in reading : SensorReading;
        }
        
        action def StoreAlert {
            in alert : AlertNotification;
        }
        
        action def RetrieveHistory {
            in startTime : ISQ::TimeValue;
            in endTime : ISQ::TimeValue;
            out readings : SensorReading[*];
            out alerts : AlertNotification[*];
        }
    }
    
    requirement def SystemMonitoringRequirement {
        doc /* The AlertMe system shall continuously monitor environmental conditions 
                and detect threshold violations in real-time. */
        
        require constraint monitoringContinuity {
            doc /* Sensor readings shall be evaluated at least once per second. */
        }
        
        require constraint thresholdAccuracy {
            doc /* Threshold violations shall be detected with 100% accuracy. */
        }
    }
    
    requirement def AlertGenerationRequirement {
        doc /* The system shall generate appropriate alerts based on severity levels 
                when thresholds are exceeded. */
        
        require constraint warningAlerts {
            doc /* Warning alerts shall be generated when readings exceed warning threshold. */
        }
        
        require constraint criticalAlerts {
            doc /* Critical alerts shall be generated when readings exceed critical threshold. */
        }
        
        require constraint alertLatency {
            doc /* Alerts shall be generated within 500 milliseconds of threshold violation. */
        }
    }
    
    requirement def NotificationRequirement {
        doc /* The system shall deliver notifications to users and track acknowledgements. */
        
        require constraint deliveryTime {
            doc /* Notifications shall be delivered to user interface within 1 second. */
        }
        
        require constraint acknowledgementTracking {
            doc /* All user acknowledgements shall be recorded with timestamp. */
        }
        
        require constraint escalationProcedure {
            doc /* Unacknowledged critical alerts shall be escalated after 5 minutes. */
        }
    }
    
    part alertMe : AlertMeSystem {
        doc /* 
            AlertMe is an intelligent environmental monitoring and alerting system.
            Its primary function is to continuously monitor environmental sensor data,
            evaluate readings against configurable warning and critical thresholds,
            and automatically generate prioritized alert notifications when conditions
            exceed safe operating limits. The system manages the complete alert lifecycle
            from detection through user notification and acknowledgement, maintaining
            a comprehensive audit trail of all sensor readings and alerts for compliance
            and analysis purposes.
        */
        
        part temperatureSensor : EnvironmentalSensor {
            attribute :>> sensorId = "TEMP-SENSOR-01";
        }
        
        part humiditySensor : EnvironmentalSensor {
            attribute :>> sensorId = "HUMID-SENSOR-01";
        }
        
        part controller : MonitoringController {
            attribute :>> thresholds : ThresholdConfig {
                attribute :>> warningLevel = 75.0;
                attribute :>> criticalLevel = 90.0;
            }
            perform action monitoring : monitoringBehavior;
        }
        
        part dispatcher : NotificationDispatcher {
            perform action handleNotifications : manageNotifications;
        }
        
        part display : UserDisplay;
        
        part archive : DataArchive;
        
        connect temperatureSensor.dataOut to controller.sensorIn;
        connect controller.alertOut to dispatcher.alertIn;
        connect dispatcher.userOut to display.displayPort;
        
        satisfy monitoringReq : SystemMonitoringRequirement by controller;
        satisfy alertReq : AlertGenerationRequirement by controller;
        satisfy notificationReq : NotificationRequirement by dispatcher;
    }
    
    requirement monitoringReq : SystemMonitoringRequirement;
    requirement alertReq : AlertGenerationRequirement;
    requirement notificationReq : NotificationRequirement;
    
    requirement systemMission {
        doc /* 
            The AlertMe system shall provide reliable, automated monitoring and alerting
            to ensure timely detection and notification of hazardous environmental conditions.
        */
        
        assume constraint sensorAccuracy {
            doc /* Environmental sensors provide readings accurate to within 2%. */
        }
        
        assume constraint systemAvailability {
            doc /* The system maintains 99.9% uptime during operational periods. */
        }
        
        require monitoringReq;
        require alertReq;
        require notificationReq;
    }
}
