package BlindSpotMonitoringSystem {
    import ScalarValues::*;

    doc /* Top-level package for the Automotive Blind Spot Monitoring System */

    // --- Units and Value Types ---
    unit km_per_h;
    unit m;
    unit deg;
    unit ms;

    value type Speed :> Real {
        unit km_per_h;
    }
    value type Distance :> Real {
        unit m;
    }
    value type AngleMeasure :> Real {
        unit deg;
    }
    value type TimeValue :> Real {
        unit ms;
    }

    // --- Items and Attributes ---
    item def RadarReturn {
        attribute distance : Distance;
        attribute relativeSpeed : Speed;
        attribute angle : AngleMeasure;
    }

    attribute def TurnSignalStatus {
        attribute leftActive : Boolean;
        attribute rightActive : Boolean;
    }

    enum def WarningLevel {
        OFF;
        STANDARD;
        ESCALATED;
    }

    // --- Ports ---
    port def RadarOutPort {
        out item return : RadarReturn;
    }
    port def RadarInPort {
        in item return : RadarReturn;
    }
    port def VehicleDataOutPort {
        out attribute speed : Speed;
        out attribute turnSignals : TurnSignalStatus;
    }
    port def VehicleDataInPort {
        in attribute speed : Speed;
        in attribute turnSignals : TurnSignalStatus;
    }
    port def IndicatorCommandOutPort {
        out attribute warning : WarningLevel;
    }
    port def IndicatorCommandInPort {
        in attribute warning : WarningLevel;
    }

    // --- Components ---
    part def RadarSensor {
        port radarOut : RadarOutPort;
        attribute maxRange : Distance = 70 [m];
        attribute minRange : Distance = 0.5 [m];
        attribute fieldOfView : AngleMeasure = 30 [deg];
        
        state radarState {
            state Idle;
            state Scanning;
            transition from Idle to Scanning when true;
        }
    }

    part def ControlModule {
        port leftRadarIn : RadarInPort;
        port rightRadarIn : RadarInPort;
        port vehicleDataIn : VehicleDataInPort;
        port leftIndicatorOut : IndicatorCommandOutPort;
        port rightIndicatorOut : IndicatorCommandOutPort;

        attribute minOperationSpeed : Speed = 10 [km_per_h];
        attribute maxProcessingLatency : TimeValue = 100 [ms];

        state controlState {
            state Inactive {
                entry / {
                    leftIndicatorOut.warning = WarningLevel::OFF;
                    rightIndicatorOut.warning = WarningLevel::OFF;
                }
            }
            state Active {
                state LeftNoWarn;
                state LeftStandardWarn;
                state LeftEscalatedWarn;
                state RightNoWarn;
                state RightStandardWarn;
                state RightEscalatedWarn;
            }

            transition from Inactive to Active when vehicleDataIn.speed >= minOperationSpeed;
            transition from Active to Inactive when vehicleDataIn.speed < minOperationSpeed {
                / {
                    leftIndicatorOut.warning = WarningLevel::OFF;
                    rightIndicatorOut.warning = WarningLevel::OFF;
                }
            }

            transition from LeftNoWarn to LeftStandardWarn 
                when leftRadarIn.return != null && leftRadarIn.return.distance <= 70 [m] && leftRadarIn.return.angle >= 10 [deg] && leftRadarIn.return.angle <= 40 [deg]
                / leftIndicatorOut.warning = WarningLevel::STANDARD;

            transition from LeftStandardWarn to LeftNoWarn 
                when leftRadarIn.return == null || leftRadarIn.return.distance > 70 [m] || leftRadarIn.return.angle < 10 [deg] || leftRadarIn.return.angle > 40 [deg]
                / leftIndicatorOut.warning = WarningLevel::OFF;

            transition from LeftStandardWarn to LeftEscalatedWarn 
                when vehicleDataIn.turnSignals.leftActive == true
                / leftIndicatorOut.warning = WarningLevel::ESCALATED;

            transition from LeftEscalatedWarn to LeftStandardWarn 
                when vehicleDataIn.turnSignals.leftActive == false
                / leftIndicatorOut.warning = WarningLevel::STANDARD;

            transition from RightNoWarn to RightStandardWarn 
                when rightRadarIn.return != null && rightRadarIn.return.distance <= 70 [m] && rightRadarIn.return.angle <= -10 [deg] && rightRadarIn.return.angle >= -40 [deg]
                / rightIndicatorOut.warning = WarningLevel::STANDARD;

            transition from RightStandardWarn to RightNoWarn 
                when rightRadarIn.return == null || rightRadarIn.return.distance > 70 [m] || rightRadarIn.return.angle > -10 [deg] || rightRadarIn.return.angle < -40 [deg]
                / rightIndicatorOut.warning = WarningLevel::OFF;

            transition from RightStandardWarn to RightEscalatedWarn 
                when vehicleDataIn.turnSignals.rightActive == true
                / rightIndicatorOut.warning = WarningLevel::ESCALATED;

            transition from RightEscalatedWarn to RightStandardWarn 
                when vehicleDataIn.turnSignals.rightActive == false
                / rightIndicatorOut.warning = WarningLevel::STANDARD;
        }
    }

    part def VisualIndicator {
        port indicatorIn : IndicatorCommandInPort;
        attribute currentWarning : WarningLevel = WarningLevel::OFF;
        
        state indicatorState {
            state Off {
                entry / currentWarning = WarningLevel::OFF;
            }
            state Standard {
                entry / currentWarning = WarningLevel::STANDARD;
            }
            state Escalated {
                entry / currentWarning = WarningLevel::ESCALATED;
            }
            transition from Off to Standard when indicatorIn.warning == WarningLevel::STANDARD;
            transition from Standard to Escalated when indicatorIn.warning == WarningLevel::ESCALATED;
            transition from Escalated to Standard when indicatorIn.warning == WarningLevel::STANDARD;
            transition from Standard to Off when indicatorIn.warning == WarningLevel::OFF;
            transition from Escalated to Off when indicatorIn.warning == WarningLevel::OFF;
        }
    }

    part def VehicleEnvironment {
        port vehicleDataOut : VehicleDataOutPort;
        attribute currentSpeed : Speed = 50 [km_per_h];
        attribute leftTurnSignal : Boolean = false;
        attribute rightTurnSignal : Boolean = false;
    }

    // --- System Assembly ---
    part def BlindSpotMonitoringSystem {
        part leftRadar : RadarSensor;
        part rightRadar : RadarSensor;
        part controlModule : ControlModule;
        part leftIndicator : VisualIndicator;
        part rightIndicator : VisualIndicator;
        part vehicleEnv : VehicleEnvironment;

        connect leftRadar.radarOut to controlModule.leftRadarIn;
        connect rightRadar.radarOut to controlModule.rightRadarIn;
        connect vehicleEnv.vehicleDataOut to controlModule.vehicleDataIn;
        connect controlModule.leftIndicatorOut to leftIndicator.indicatorIn;
        connect controlModule.rightIndicatorOut to rightIndicator.indicatorIn;
    }

    // --- Requirements ---
    requirement def BSMRequirement {
        doc /* Base requirement for Blind Spot Monitoring */
    }

    requirement bsmOverall : BSMRequirement {
        doc /* The system shall enhance driver safety by alerting them to vehicles in adjacent lanes. */
    }

    requirement minSpeedOperation : BSMRequirement {
        doc /* The system shall remain inactive below 10 km/h. */
        attribute minSpeed : Speed = 10 [km_per_h];
    }

    requirement detectionRange : BSMRequirement {
        doc /* Each radar sensor shall detect vehicles in the blind spot zone. */
        attribute maxRange : Distance = 70 [m];
        attribute minAngle : AngleMeasure = 10 [deg];
        attribute maxAngle : AngleMeasure = 40 [deg];
    }

    requirement standardWarning : BSMRequirement {
        doc /* A standard visual warning shall be triggered when a vehicle is detected in the blind spot. */
    }

    requirement escalatedWarning : BSMRequirement {
        doc /* An escalated warning shall be triggered if the turn signal is active while a vehicle is in the corresponding blind spot. */
    }

    requirement fastUpdate : BSMRequirement {
        doc /* The system shall process data and update warnings within milliseconds. */
        attribute maxLatency : TimeValue = 100 [ms];
    }

    // --- Satisfactions ---
    satisfy bsmOverall by BlindSpotMonitoringSystem;
    satisfy minSpeedOperation by ControlModule;
    satisfy detectionRange by RadarSensor;
    satisfy standardWarning by ControlModule;
    satisfy escalatedWarning by ControlModule;
    satisfy fastUpdate by ControlModule;
}
