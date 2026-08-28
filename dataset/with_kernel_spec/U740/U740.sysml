package LORROS {
    attribute def ThreatLevelKind;
    attribute def SystemStatus;
    attribute def ImageData;
    attribute def ThermalData;
    attribute def CommandOrder;
    attribute def LaserCode;

    attribute def GeographicCoordinate {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : DistanceValue;
    }

    attribute def TargetData {
        attribute coordinates : GeographicCoordinate;
        attribute classification : String;
        attribute threatLevel : ThreatLevelKind;
        attribute distance : DistanceValue;
    }

    attribute def TelemetryData {
        attribute status : SystemStatus;
        attribute targetData : TargetData;
    }

    attribute def SigStartSurveillance;
    attribute def SigStopSurveillance;
    attribute def SigTargetDetected;
    attribute def SigTargetIdentified;
    attribute def SigReportOrder;
    attribute def SigDesignateOrder;
    attribute def SigReportComplete;
    attribute def SigDesignateComplete;
    attribute def SigMissionComplete;
    attribute def SigBatteryLow;
    attribute def SigBatteryCritical;
    attribute def SigSolarCharging;

    requirement def LongRangeRequirement {
        doc /* The system must operate over long distances. */
    }

    requirement def EnduranceRequirement {
        doc /* The system must operate for extended periods. */
    }

    requirement def AutonomousTargetingRequirement {
        doc /* The system shall autonomously find, track, and identify targets of interest. */
    }

    requirement def LaserDesignationRequirement {
        doc /* The system shall designate a target with a coded laser for precision-guided munitions. */
    }

    part def StabilizedGimbal {
        port powerIn { in power : PowerValue; }
        part sensorSuite : SensorSuite;
        perform action stabilize {
            first start;
            then action compensate;
            then done;
        }
    }

    part def SensorSuite {
        part eoCamera : EOCamera;
        part irSensor : IRSensor;
        part laserUnit : LaserUnit;
    }

    part def EOCamera {
        port imageOut { out image : ImageData; }
        perform action captureImage {
            out image : ImageData;
            first start;
            then done;
        }
    }

    part def IRSensor {
        port thermalOut { out thermal : ThermalData; }
        perform action captureThermal {
            out thermal : ThermalData;
            first start;
            then done;
        }
    }

    part def LaserUnit {
        port rangeOut { out range : DistanceValue; }
        port designatorIn { in code : LaserCode; }
        port designatorOut { out laserBeam : LaserCode; }
        perform action measureRange {
            out range : DistanceValue;
            first start;
            then done;
        }
        perform action designateTarget {
            in code : LaserCode;
            out laserBeam : LaserCode;
            first start;
            then done;
        }
    }

    part def TargetProcessingUnit {
        port powerIn { in power : PowerValue; }
        port eoIn { in image : ImageData; }
        port irIn { in thermal : ThermalData; }
        port rangeIn { in range : DistanceValue; }
        port navIn { in coords : GeographicCoordinate; }
        port cmdIn { in order : CommandOrder; }
        port targetDataOut { out targetData : TargetData; }
        port designationOut { out code : LaserCode; }

        perform action processTargets {
            in image : ImageData;
            in thermal : ThermalData;
            in range : DistanceValue;
            in coords : GeographicCoordinate;
            out targetData : TargetData;
            out code : LaserCode;
            first start;
            then action fuseSensorData;
            then action classifyTarget;
            then action assessThreat;
            then action prioritizeTargets;
            then done;
        }
    }

    part def CommunicationsSubsystem {
        port powerIn { in power : PowerValue; }
        port targetDataIn { in targetData : TargetData; }
        port telemetryOut { out telemetry : TelemetryData; }
        port rxIn { in order : CommandOrder; }
        perform action transmitTelemetry {
            in targetData : TargetData;
            out telemetry : TelemetryData;
            first start;
            then done;
        }
        perform action receiveOrders {
            in order : CommandOrder;
            first start;
            then done;
        }
    }

    part def NavigationUnit {
        port powerIn { in power : PowerValue; }
        port coordsOut { out coords : GeographicCoordinate; }
        perform action determinePosition {
            out coords : GeographicCoordinate;
            first start;
            then done;
        }
    }

    part def PowerManagementUnit {
        port powerOut { out power : PowerValue; }
        part battery;
        part solarPanel;
        state powerState {
            entry; then normal;
            state normal;
            state lowPower;
            state critical;
            transition normal_to_low first normal accept SigBatteryLow then lowPower;
            transition low_to_critical first lowPower accept SigBatteryCritical then critical;
            transition critical_to_normal first critical accept SigSolarCharging then normal;
            transition low_to_normal first lowPower accept SigSolarCharging then normal;
        }
    }

    part def LORROS_System {
        satisfy LongRangeRequirement;
        satisfy EnduranceRequirement;
        satisfy AutonomousTargetingRequirement;
        satisfy LaserDesignationRequirement;

        part gimbal : StabilizedGimbal;
        part tpu : TargetProcessingUnit;
        part comms : CommunicationsSubsystem;
        part nav : NavigationUnit;
        part pmu : PowerManagementUnit;

        connect gimbal.sensorSuite.eoCamera.imageOut to tpu.eoIn;
        connect gimbal.sensorSuite.irSensor.thermalOut to tpu.irIn;
        connect gimbal.sensorSuite.laserUnit.rangeOut to tpu.rangeIn;
        connect nav.coordsOut to tpu.navIn;
        connect tpu.targetDataOut to comms.targetDataIn;
        connect comms.rxIn to tpu.cmdIn;
        connect tpu.designationOut to gimbal.sensorSuite.laserUnit.designatorIn;

        connect pmu.powerOut to gimbal.powerIn;
        connect pmu.powerOut to tpu.powerIn;
        connect pmu.powerOut to comms.powerIn;
        connect pmu.powerOut to nav.powerIn;

        state missionStateMachine {
            entry; then idle;
            state idle;
            state searching;
            state tracking;
            state deciding;
            state reporting;
            state designating;
            transition idle_to_searching first idle accept SigStartSurveillance then searching;
            transition searching_to_tracking first searching accept SigTargetDetected then tracking;
            transition tracking_to_deciding first tracking accept SigTargetIdentified then deciding;
            transition deciding_to_reporting first deciding accept SigReportOrder then reporting;
            transition deciding_to_designating first deciding accept SigDesignateOrder then designating;
            transition reporting_to_searching first reporting accept SigReportComplete then searching;
            transition designating_to_searching first designating accept SigDesignateComplete then searching;
        }
    }
}
