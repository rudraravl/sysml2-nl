package CurbFeelerSystem {
    import ISQ::*;
    import SI::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====

    value type DistanceMM :> Length;
    value type ToneFreqHz :> Frequency;
    value type ForceN :> Force;
    value type SpeedKmh :> Speed;
    value type TimeSec :> Time;

    // ===== Item Definitions =====

    item def ContactSignal {
        attribute detected : Boolean;
        attribute impactForce : ForceN;
        attribute timestamp : TimeSec;
    }

    item def ProximityReport {
        attribute estimatedDistance : DistanceMM;
        attribute withinThreshold : Boolean;
        attribute alertActive : Boolean;
        attribute side : String;
    }

    item def AlertCommand {
        attribute activate : Boolean;
        attribute frequency : ToneFreqHz;
        attribute sourceSide : String;
    }

    // ===== Port Definitions =====

    port def ContactPort {
        item contactSignal : ContactSignal;
    }

    port def ProximityPort {
        item proximityReport : ProximityReport;
    }

    port def AlertPort {
        item alertCommand : AlertCommand;
    }

    port def VehicleStatePort {
        attribute speed : SpeedKmh;
        attribute ignitionOn : Boolean;
        attribute maneuvering : Boolean;
    }

    // ===== Requirements =====

    requirement def CurbFeelerSystemRequirement {
        doc
            /* The curb feeler system shall help drivers avoid hitting curbs and
               other low obstacles during parking and slow-speed maneuvers. */;
    }

    requirement curbFeelerSystemReq : CurbFeelerSystemRequirement {
        doc /* Overall curb feeler system requirement. */;
    }

    requirement def DualAssemblyRequirement {
        doc
            /* The system shall be composed of two independent assemblies,
               mounted on the left and right sides of the vehicle. */;
    }

    requirement dualAssemblyReq : DualAssemblyRequirement {
        doc /* Two independent left and right side assemblies. */;
    }

    requirement def RodSpecificationRequirement {
        doc
            /* Each assembly shall feature a flexible 200 mm spring-steel rod
               that extends outwards as the primary sensor. */;
    }

    requirement rodSpecReq : RodSpecificationRequirement {
        doc /* 200 mm spring-steel rod specification. */;
    }

    requirement def ContactDetectionRequirement {
        doc
            /* When the rod makes physical contact with an object, a force-sensitive
               contact sensor at its base shall register the impact. */;
    }

    requirement contactDetectionReq : ContactDetectionRequirement {
        doc /* Force-sensitive contact detection at rod base. */;
    }

    requirement def AlertControllerRequirement {
        doc
            /* A dedicated alert controller for each side shall process the contact
               signal, calculate proximity, and determine if it is within a
               predefined safety threshold. */;
    }

    requirement alertControllerReq : AlertControllerRequirement {
        doc /* Per-side alert controller with proximity calculation and threshold. */;
    }

    requirement def AudibleAlertRequirement {
        doc
            /* When the vehicle is too close, the controller shall send a command to
               the driver alert interface, which shall activate an audible alarm
               producing a 2000 Hz tone. */;
    }

    requirement audibleAlertReq : AudibleAlertRequirement {
        doc /* 2000 Hz audible alarm activation upon threshold breach. */;
    }

    requirement def OperatingStateRequirement {
        doc
            /* The system shall move from inactive to a continuous monitoring state
               when the vehicle is maneuvering. */;
    }

    requirement operatingStateReq : OperatingStateRequirement {
        doc /* State transition from inactive to monitoring. */;
    }

    requirement def DamagePreventionRequirement {
        doc
            /* The system shall provide a tactile physical warning that prevents wheel
               scuffs, tire damage, and scratches to body panels by alerting the
               driver before the wheels or body make contact with the curb. */;
    }

    requirement damagePreventionReq : DamagePreventionRequirement {
        doc /* Prevents wheel scuffs, tire damage, and body panel scratches. */;
    }

    // ===== Part Definitions =====

    part def CurbFeelerSystem {
        satisfies curbFeelerSystemReq;
        satisfies dualAssemblyReq;
        satisfies operatingStateReq;
        satisfies damagePreventionReq;

        attribute systemState : String = "inactive";
        attribute monitoringSpeedLimit : SpeedKmh = 10 [km/h];
        attribute shutdownSpeedLimit : SpeedKmh = 15 [km/h];

        port in vehicleState : VehicleStatePort;
        port out alertStatus : AlertPort;

        part leftAssembly : CurbFeelerAssembly {
            attribute side : String = "left";
        }

        part rightAssembly : CurbFeelerAssembly {
            attribute side : String = "right";
        }

        part driverInterface : DriverAlertInterface;

        connection leftStateConn : vehicleState to leftAssembly.vehicleState;
        connection rightStateConn : vehicleState to rightAssembly.vehicleState;
        connection leftProximityConn : leftAssembly.proximityOut to driverInterface.leftProximityIn;
        connection rightProximityConn : rightAssembly.proximityOut to driverInterface.rightProximityIn;
        connection alertConn : driverInterface.alertOut to alertStatus;

        exhibit state CurbFeelerSystemSM {
            entry action { systemState = "inactive"; }

            state inactive {
                entry action { systemState = "inactive"; }
                transition to monitoring
                    when vehicleState.ignitionOn
                        && vehicleState.maneuvering
                        && vehicleState.speed <= monitoringSpeedLimit;
            }

            state monitoring {
                entry action { systemState = "monitoring"; }
                transition to inactive
                    when !vehicleState.ignitionOn
                        || vehicleState.speed > shutdownSpeedLimit;
            }
        }
    }

    part def CurbFeelerAssembly {
        satisfies rodSpecReq;
        satisfies contactDetectionReq;
        satisfies alertControllerReq;

        attribute side : String;
        attribute rodLength : DistanceMM = 200 [mm];
        attribute safetyThreshold : DistanceMM = 50 [mm];

        part flexibleRod : FlexibleRod {
            attribute length : DistanceMM = 200 [mm];
            attribute material : String = "spring-steel";
            attribute maxDeflection : DistanceMM = 30 [mm];
        }

        part contactSensor : ContactSensor {
            attribute sensitivityThreshold : ForceN = 0.5 [N];
        }

        part alertCtrl : AlertController {
            attribute safetyThreshold : DistanceMM = 50 [mm];
            attribute side : String = side;
        }

        port in vehicleState : VehicleStatePort;
        port out proximityOut : ProximityPort;

        connection rodToSensor : flexibleRod.baseContact to contactSensor.rodContact;
        connection sensorToController : contactSensor.signalOut to alertCtrl.signalIn;
        connection stateToController : vehicleState to alertCtrl.vehicleState;
        connection controllerToOutput : alertCtrl.proximityOut to proximityOut;
    }

    part def FlexibleRod {
        attribute length : DistanceMM;
        attribute material : String;
        attribute maxDeflection : DistanceMM;
        attribute springConstant : Real = 2.0;

        port out baseContact : ContactPort;
    }

    part def ContactSensor {
        attribute sensitivityThreshold : ForceN;
        attribute lastDetected : Boolean = false;
        attribute lastForce : ForceN;
        attribute lastTimestamp : TimeSec;

        port in rodContact : ContactPort;
        port out signalOut : ContactPort;

        exhibit state ContactSensorSM {
            state idle {
                entry action {
                    lastDetected = false;
                    signalOut.contactSignal.detected = false;
                }
                transition to detecting
                    when rodContact.contactSignal.detected
                        && rodContact.contactSignal.impactForce >= sensitivityThreshold;
            }

            state detecting {
                entry action {
                    lastDetected = true;
                    lastForce = rodContact.contactSignal.impactForce;
                    lastTimestamp = rodContact.contactSignal.timestamp;
                    signalOut.contactSignal.detected = true;
                    signalOut.contactSignal.impactForce = lastForce;
                    signalOut.contactSignal.timestamp = lastTimestamp;
                }
                transition to idle
                    when !rodContact.contactSignal.detected
                        || rodContact.contactSignal.impactForce < sensitivityThreshold;
            }
        }
    }

    part def AlertController {
        attribute safetyThreshold : DistanceMM;
        attribute side : String;
        attribute currentDistance : DistanceMM = 200 [mm];
        attribute alertActive : Boolean = false;
        attribute forceToDistanceScale : Real = 3.0;

        port in signalIn : ContactPort;
        port in vehicleState : VehicleStatePort;
        port out proximityOut : ProximityPort;

        exhibit state AlertControllerSM {
            state waiting {
                entry action {
                    alertActive = false;
                    proximityOut.proximityReport.alertActive = false;
                    proximityOut.proximityReport.withinThreshold = false;
                }
                transition to evaluating
                    when signalIn.contactSignal.detected;
            }

            state evaluating {
                entry action {
                    currentDistance = rodLength
                        - (signalIn.contactSignal.impactForce * forceToDistanceScale);
                }
                transition to alerting
                    when currentDistance <= safetyThreshold;
                transition to waiting
                    when !signalIn.contactSignal.detected;
                transition to waiting
                    when currentDistance > safetyThreshold;
            }

            state alerting {
                entry action {
                    alertActive = true;
                    proximityOut.proximityReport.estimatedDistance = currentDistance;
                    proximityOut.proximityReport.withinThreshold = true;
                    proximityOut.proximityReport.alertActive = true;
                    proximityOut.proximityReport.side = side;
                }
                transition to waiting
                    when !signalIn.contactSignal.detected;
            }
        }
    }

    part def DriverAlertInterface {
        satisfies audibleAlertReq;

        attribute toneFrequency : ToneFreqHz = 2000 [Hz];
        attribute activeSide : String = "none";
        attribute alarmActive : Boolean = false;

        part alarm : AudibleAlarm {
            attribute baseFrequency : ToneFreqHz = 2000 [Hz];
            attribute volume : Real = 75.0;
        }

        port in leftProximityIn : ProximityPort;
        port in rightProximityIn : ProximityPort;
        port out alertOut : AlertPort;

        connection leftToAlarm : leftProximityIn to alarm.leftActivation;
        connection rightToAlarm : rightProximityIn to alarm.rightActivation;

        exhibit state DriverAlertSM {
            state quiet {
                entry action {
                    activeSide = "none";
                    alarmActive = false;
                    alertOut.alertCommand.activate = false;
                    alertOut.alertCommand.sourceSide = "none";
                }
                transition to alertingLeft
                    when leftProximityIn.proximityReport.alertActive;
                transition to alertingRight
                    when rightProximityIn.proximityReport.alertActive;
            }

            state alertingLeft {
                entry action {
                    activeSide = "left";
                    alarmActive = true;
                    alertOut.alertCommand.activate = true;
                    alertOut.alertCommand.frequency = toneFrequency;
                    alertOut.alertCommand.sourceSide = "left";
                }
                transition to quiet
                    when !leftProximityIn.proximityReport.alertActive;
                transition to alertingBoth
                    when rightProximityIn.proximityReport.alertActive;
            }

            state alertingRight {
                entry action {
                    activeSide = "right";
                    alarmActive = true;
                    alertOut.alertCommand.activate = true;
                    alertOut.alertCommand.frequency = toneFrequency;
                    alertOut.alertCommand.sourceSide = "right";
                }
                transition to quiet
                    when !rightProximityIn.proximityReport.alertActive;
                transition to alertingBoth
                    when leftProximityIn.proximityReport.alertActive;
            }

            state alertingBoth {
                entry action {
                    activeSide = "both";
                    alarmActive = true;
                    alertOut.alertCommand.activate = true;
                    alertOut.alertCommand.frequency = toneFrequency;
                    alertOut.alertCommand.sourceSide = "both";
                }
                transition to alertingLeft
                    when !rightProximityIn.proximityReport.alertActive;
                transition to alertingRight
                    when !leftProximityIn.proximityReport.alertActive;
            }
        }
    }

    part def AudibleAlarm {
        attribute baseFrequency : ToneFreqHz = 2000 [Hz];
        attribute volume : Real;
        attribute sounding : Boolean = false;

        port in leftActivation : ProximityPort;
        port in rightActivation : ProximityPort;

        exhibit state AlarmSM {
            state silent {
                entry action { sounding = false; }
                transition to sounding
                    when leftActivation.proximityReport.alertActive
                        || rightActivation.proximityReport.alertActive;
            }

            state sounding {
                entry action {
                    sounding = true;
                }
                transition to silent
                    when !leftActivation.proximityReport.alertActive
                        && !rightActivation.proximityReport.alertActive;
            }
        }
    }

    // ===== Verification Relationships =====

    verify rodVerification : rodSpecReq {
        subject part leftAssembly.flexibleRod;
        subject part rightAssembly.flexibleRod;
        assert leftAssembly.flexibleRod.length == 200 [mm];
        assert rightAssembly.flexibleRod.length == 200 [mm];
        assert leftAssembly.flexibleRod.material == "spring-steel";
        assert rightAssembly.flexibleRod.material == "spring-steel";
    }

    verify alertToneVerification : audibleAlertReq {
        subject part driverInterface;
        assert driverInterface.toneFrequency == 2000 [Hz];
        assert driverInterface.alarm.baseFrequency == 2000 [Hz];
    }

    verify thresholdVerification : alertControllerReq {
        subject part leftAssembly.alertCtrl;
        subject part rightAssembly.alertCtrl;
        assert leftAssembly.alertCtrl.safetyThreshold == 50 [mm];
        assert rightAssembly.alertCtrl.safetyThreshold == 50 [mm];
    }

    verify dualAssemblyVerification : dualAssemblyReq {
        subject part leftAssembly;
        subject part rightAssembly;
        assert leftAssembly.side == "left";
        assert rightAssembly.side == "right";
    }

    verify operatingStateVerification : operatingStateReq {
        subject part CurbFeelerSystem;
        assert CurbFeelerSystem.monitoringSpeedLimit == 10 [km/h];
        assert CurbFeelerSystem.shutdownSpeedLimit == 15 [km/h];
    }
}
