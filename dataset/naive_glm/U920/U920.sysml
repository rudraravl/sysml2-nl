package TPMS {
    import ISQ::*;
    import SI::*;

    // ===== Value Types =====
    value def PressureValue :> Real {
        unit psi;
    }
    value def TemperatureValue :> Real {
        unit '°C';
    }
    value def BatteryLevel :> Real {
        unit '%';
    }
    value def Timestamp :> Real {
        unit 's';
    }

    // ===== Enumerations =====
    enum def TireLocation {
        frontLeft;
        frontRight;
        rearLeft;
        rearRight;
    }

    enum def PressureStatus {
        nominal;
        low;
        criticallyLow;
        high;
    }

    enum def AlertSeverity {
        none;
        warning;
        critical;
        overPressure;
    }

    // ===== Item Types =====
    item def TireMeasurement {
        attribute location : TireLocation;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute batteryLevel : BatteryLevel;
        attribute timestamp : Timestamp;
    }

    item def AlertMessage {
        attribute location : TireLocation;
        attribute severity : AlertSeverity;
        attribute measuredPressure : PressureValue;
        attribute timestamp : Timestamp;
    }

    // ===== Thresholds =====
    value def NominalThresholdMin = 28 [psi];
    value def CriticalThresholdMin = 22 [psi];
    value def OverPressureThresholdMax = 45 [psi];
    value def NominalThresholdMax = 45 [psi];

    // ===== Interfaces =====
    interface def RFTransmission {
        end transmitted : TireMeasurement;
        end received : TireMeasurement;
    }

    interface def MeasurementDelivery {
        end sent : TireMeasurement;
        end received : TireMeasurement;
    }

    interface def AlertDelivery {
        end sent : AlertMessage;
        end received : AlertMessage;
    }

    // ===== Ports =====
    port def RFTransmitterPort {
        out transmitted : TireMeasurement;
    }

    port def RFReceiverPort {
        in received : TireMeasurement;
    }

    port def MeasurementOutPort {
        out sent : TireMeasurement;
    }

    port def MeasurementInPort {
        in received : TireMeasurement;
    }

    port def AlertOutPort {
        out sent : AlertMessage;
    }

    port def AlertInPort {
        in received : AlertMessage;
    }

    // ===== Tire Sensor =====
    part def TireSensor {
        attribute location : TireLocation;
        attribute batteryLevel : BatteryLevel = 100 [%];
        attribute measurementInterval : Real = 60 [s];

        port rfOut : RFTransmitterPort;

        attribute currentPressure : PressureValue;
        attribute currentTemperature : TemperatureValue;

        action def takeMeasurement {
            in loc : TireLocation;
            out measurement : TireMeasurement;
        }

        action def transmitMeasurement {
            in measurement : TireMeasurement;
            out transmitted : TireMeasurement;
        }

        perform action measureCycle {
            // Periodically measure and transmit
            item m : TireMeasurement;
            then takeMeasurement(location, m);
            then transmitMeasurement(m, rfOut.transmitted);
        }
    }

    // ===== RF Receiver =====
    part def RFReceiver {
        port rfIn : RFReceiverPort[4];
        port dataOut : MeasurementOutPort;

        action def relayMeasurement {
            in received : TireMeasurement;
            out forwarded : TireMeasurement;
        }

        perform action relayLoop {
            // Relay received measurements to ECU
            item incoming : TireMeasurement;
            then relayMeasurement(incoming, dataOut.sent);
        }
    }

    // ===== ECU =====
    part def ECU {
        port dataIn : MeasurementInPort[4];
        port alertOut : AlertOutPort;

        attribute nominalMin : PressureValue = 28 [psi];
        attribute criticalMin : PressureValue = 22 [psi];
        attribute overPressureMax : PressureValue = 45 [psi];

        attribute tireStatuses : PressureStatus[4];

        action def evaluatePressure {
            in measurement : TireMeasurement;
            out status : PressureStatus;
            out alert : AlertMessage;

            // Determine status based on thresholds
            if measurement.pressure < criticalMin then {
                status := PressureStatus::criticallyLow;
                alert.severity := AlertSeverity::critical;
            } else if measurement.pressure < nominalMin then {
                status := PressureStatus::low;
                alert.severity := AlertSeverity::warning;
            } else if measurement.pressure > overPressureMax then {
                status := PressureStatus::high;
                alert.severity := AlertSeverity::overPressure;
            } else {
                status := PressureStatus::nominal;
                alert.severity := AlertSeverity::none;
            }
            alert.location := measurement.location;
            alert.measuredPressure := measurement.pressure;
            alert.timestamp := measurement.timestamp;
        }

        state def ECUStateMachine {
            entry;
            then Monitoring;

            state Monitoring {
                // Continuously evaluate incoming measurements
                entry;
                do evaluatePressure;
            }

            transition normalToAlert
                source Monitoring
                target AlertActive
                when (dataIn.received.pressure < nominalMin || dataIn.received.pressure > overPressureMax);

            state AlertActive {
                // Emit alert message
                entry then sendAlert;
                action sendAlert {
                    out alertOut.sent;
                }
            }

            transition alertToNormal
                source AlertActive
                target Monitoring
                when (dataIn.received.pressure >= nominalMin && dataIn.received.pressure <= overPressureMax);
        }

        exhibit ECUStateMachine;
    }

    // ===== Driver Display =====
    part def DriverDisplay {
        port alertIn : AlertInPort;

        attribute displayActive : Boolean = false;
        attribute audibleEnabled : Boolean = true;

        action def showVisualWarning {
            in alert : AlertMessage;
        }

        action def playAudibleAlert {
            in alert : AlertMessage;
        }

        action def clearDisplay {
        }

        state def DisplayStateMachine {
            entry;
            then Idle;

            state Idle {
                entry then clearDisplay;
            }

            transition idleToActive
                source Idle
                target Active
                when (alertIn.received.severity != AlertSeverity::none);

            state Active {
                entry;
                do showVisualWarning(alertIn.received);
                then playAudibleAlert(alertIn.received) if audibleEnabled;
            }

            transition activeToIdle
                source Active
                target Idle
                when (alertIn.received.severity == AlertSeverity::none);
        }

        exhibit DisplayStateMachine;
    }

    // ===== TPMS System Assembly =====
    part def TPMS {
        part frontLeftSensor : TireSensor {
            attribute location = TireLocation::frontLeft;
        }
        part frontRightSensor : TireSensor {
            attribute location = TireLocation::frontRight;
        }
        part rearLeftSensor : TireSensor {
            attribute location = TireLocation::rearLeft;
        }
        part rearRightSensor : TireSensor {
            attribute location = TireLocation::rearRight;
        }

        part rfReceiver : RFReceiver;
        part ecu : ECU;
        part driverDisplay : DriverDisplay;

        // RF connections: sensors to receiver
        connection rfFL : RFTransmission connect frontLeftSensor.rfOut to rfReceiver.rfIn[1];
        connection rfFR : RFTransmission connect frontRightSensor.rfOut to rfReceiver.rfIn[2];
        connection rfRL : RFTransmission connect rearLeftSensor.rfOut to rfReceiver.rfIn[3];
        connection rfRR : RFTransmission connect rearRightSensor.rfOut to rfReceiver.rfIn[4];

        // Receiver to ECU
        connection dataToECU : MeasurementDelivery connect rfReceiver.dataOut to ecu.dataIn[1];

        // ECU to Display
        connection alertToDisplay : AlertDelivery connect ecu.alertOut to driverDisplay.alertIn;
    }

    // ===== Requirements =====
    requirement def PressureMonitoringRequirement {
        subject tpms : TPMS;
        objective {
            doc "The TPMS shall continuously monitor tire pressure and temperature for all four tires."
        }
        assume {
            doc "All four tire sensors are operational and battery-powered."
        }
    }

    requirement def LowPressureAlertRequirement {
        subject tpms : TPMS;
        objective {
            doc "If any tire pressure drops below 28 psi, the ECU shall generate a warning alert identifying the affected tire."
        }
    }

    requirement def CriticalPressureAlertRequirement {
        subject tpms : TPMS;
        objective {
            doc "If any tire pressure drops below 22 psi, the ECU shall generate a critical alert identifying the affected tire."
        }
    }

    requirement def OverPressureAlertRequirement {
        subject tpms : TPMS;
        objective {
            doc "If any tire pressure exceeds 45 psi, the ECU shall generate an over-pressure alert identifying the affected tire."
        }
    }

    requirement def DriverNotificationRequirement {
        subject tpms : TPMS;
        objective {
            doc "The Driver Display shall show a visual warning and may play an audible alert when an alert message is received."
        }
    }

    requirement def NormalStateRecoveryRequirement {
        subject tpms : TPMS;
        objective {
            doc "The system shall return to a normal monitoring state once all tire pressures are within safe operating thresholds."
        }
    }

    requirement def WirelessTransmissionRequirement {
        subject tpms : TPMS;
        objective {
            doc "Each tire sensor shall wirelessly transmit measurement data including location, pressure, temperature, battery level, and timestamp."
        }
    }

    requirement def RFReceptionRequirement {
        subject tpms : TPMS;
        objective {
            doc "The RF Receiver shall receive transmissions from all four tire sensors and forward the data to the ECU."
        }
    }

    // ===== Requirement Satisfaction =====
    satisfaction satisfy PressureMonitoringRequirement by TPMS;
    satisfaction satisfy LowPressureAlertRequirement by ECU;
    satisfaction satisfy CriticalPressureAlertRequirement by ECU;
    satisfaction satisfy OverPressureAlertRequirement by ECU;
    satisfaction satisfy DriverNotificationRequirement by DriverDisplay;
    satisfaction satisfy NormalStateRecoveryRequirement by ECU;
    satisfaction satisfy WirelessTransmissionRequirement by TireSensor;
    satisfaction satisfy RFReceptionRequirement by RFReceiver;
}
