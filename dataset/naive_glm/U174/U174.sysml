package BronchialBlockerSystem {

    import ScalarValues::*;

    // ---- Value Types ----
    value type PressureValue :> Real {
        attribute unit: String = "kPa";
    }
    value type VolumeValue :> Real {
        attribute unit: String = "mL";
    }
    value type OxygenSaturationValue :> Real {
        attribute unit: String = "%";
    }
    value type LengthValue :> Real {
        attribute unit: String = "cm";
    }
    value type FlowRateValue :> Real {
        attribute unit: String = "L/min";
    }
    value type FrequencyValue :> Real {
        attribute unit: String = "Hz";
    }

    // ---- Item Types ----
    item def Air;
    item def Oxygen;
    item def CarbonDioxide;
    item def AnestheticMixture;

    // ---- Enumerations ----
    enum def LungSide {
        left;
        right;
    }

    enum def DeviceStatus {
        standby;
        inserting;
        positioning;
        adjusting;
        verifying;
        inflating;
        monitoring;
        deflating;
        removing;
        emergency;
    }

    enum def AlarmLevel {
        none;
        warning;
        critical;
    }

    // ---- Port Definitions ----
    port def AirFlowPort {
        out item gasFlow: Air;
        in item returnFlow: Air;
    }

    port def PressureOutputPort {
        out attribute pressure: PressureValue;
        out attribute alarm: Boolean;
    }

    port def OxygenOutputPort {
        out attribute saturation: OxygenSaturationValue;
        out attribute alarm: Boolean;
    }

    port def VideoOutputPort {
        out attribute videoFeed: String;
        out attribute imageCaptured: Boolean;
    }

    port def ControlPort {
        in attribute command: String;
        out attribute status: DeviceStatus;
    }

    port def InflationControlPort {
        in attribute targetPressure: PressureValue;
        in attribute inflate: Boolean;
        in attribute deflate: Boolean;
        out attribute currentPressure: PressureValue;
        out attribute isInflated: Boolean;
    }

    // ---- Requirements ----
    requirement def CuffPressureSafetyReq {
        doc /* The cuff pressure must remain within a safe range to prevent airway tissue damage from over-inflation. */
        attribute maxSafePressure: PressureValue = 30.0;
        attribute minSealPressure: PressureValue = 15.0;
        subject cuffPressure: PressureValue;
        constraint { cuffPressure >= minSealPressure and cuffPressure <= maxSafePressure }
    }

    requirement def OxygenSaturationReq {
        doc /* Patient oxygen saturation must remain above a safe threshold during single-lung ventilation. */
        attribute minSaturation: OxygenSaturationValue = 88.0;
        subject oxygenSaturation: OxygenSaturationValue;
        constraint { oxygenSaturation >= minSaturation }
    }

    requirement def VisualVerificationReq {
        doc /* The blocker tip placement must be visually verified via the fiberoptic channel before cuff inflation. */
        subject placementVerified: Boolean;
        constraint { placementVerified == true }
    }

    requirement def SingleLungVentilationReq {
        doc /* The system must enable single-lung ventilation by isolating one lung while ventilating the other. */
        subject isolatedLung: LungSide;
        constraint { isolatedLung == LungSide::left or isolatedLung == LungSide::right }
    }

    requirement def ContinuousMonitoringReq {
        doc /* The system must continuously monitor cuff pressure and oxygen saturation during the surgical procedure. */
        attribute monitoringRate: FrequencyValue = 10.0;
        subject pressureMonitoringActive: Boolean;
        subject oxygenMonitoringActive: Boolean;
        constraint { pressureMonitoringActive == true and oxygenMonitoringActive == true }
    }

    requirement def EmergencyDeflationReq {
        doc /* If cuff pressure exceeds the safe threshold or oxygen saturation drops below the safe threshold, the system must deflate the cuff. */
        subject cuffPressure: PressureValue;
        subject oxygenSaturation: OxygenSaturationValue;
        attribute pressureTrigger: PressureValue = 30.0;
        attribute oxygenTrigger: OxygenSaturationValue = 85.0;
        constraint { cuffPressure > pressureTrigger or oxygenSaturation < oxygenTrigger implies cuffDeflated == true }
        attribute cuffDeflated: Boolean;
    }

    // ---- Inflatable Cuff ----
    part def InflatableCuff {
        attribute maxVolume: VolumeValue = 10.0;
        attribute nominalSealPressure: PressureValue = 20.0;
        attribute maxSafePressure: PressureValue = 30.0;
        attribute currentVolume: VolumeValue = 0.0;
        attribute currentPressure: PressureValue = 0.0;
        attribute isInflated: Boolean = false;

        port inflationControl: InflationControlPort;
        port pressureOutput: PressureOutputPort;

        action inflateCuff {
            in attribute targetPressure: PressureValue = 20.0;
            assign currentVolume = maxVolume;
            assign currentPressure = targetPressure;
            assign isInflated = true;
        }

        action deflateCuff {
            assign currentVolume = 0.0;
            assign currentPressure = 0.0;
            assign isInflated = false;
        }

        action updatePressureOutput {
            assign pressureOutput.pressure = currentPressure;
            assign pressureOutput.alarm = (currentPressure > maxSafePressure);
        }
    }

    // ---- Fiberoptic Channel ----
    part def FiberopticChannel {
        attribute channelDiameter: LengthValue = 0.3;
        attribute maxDepth: LengthValue = 30.0;
        attribute isCameraInserted: Boolean = false;
        attribute videoActive: Boolean = false;
        attribute currentDepth: LengthValue = 0.0;

        port videoOutput: VideoOutputPort;

        action insertCamera {
            in attribute depth: LengthValue;
            assign currentDepth = depth;
            assign isCameraInserted = true;
            assign videoActive = true;
        }

        action removeCamera {
            assign isCameraInserted = false;
            assign videoActive = false;
            assign currentDepth = 0.0;
        }

        action captureImage {
            assign videoOutput.imageCaptured = true;
            assign videoOutput.videoFeed = "live_feed_active";
        }

        action provideVisualFeed {
            assign videoOutput.videoFeed = "live_feed_active";
        }
    }

    // ---- Pressure Sensor ----
    part def PressureSensor {
        attribute samplingRate: FrequencyValue = 10.0;
        attribute measurementRange: PressureValue = 50.0;
        attribute currentReading: PressureValue = 0.0;
        attribute alarmThreshold: PressureValue = 30.0;
        attribute criticalThreshold: PressureValue = 35.0;
        attribute alarmActive: Boolean = false;
        attribute alarmLevel: AlarmLevel = AlarmLevel::none;

        port pressureOutput: PressureOutputPort;

        action measurePressure {
            in attribute inputPressure: PressureValue;
            assign currentReading = inputPressure;
            assign alarmActive = (inputPressure > alarmThreshold);
            then decide if (inputPressure > criticalThreshold)
                then assign alarmLevel = AlarmLevel::critical;
                else assign alarmLevel = AlarmLevel::warning;
            }
            assign pressureOutput.pressure = currentReading;
            assign pressureOutput.alarm = alarmActive;
        }

        action triggerAlarm {
            assign alarmActive = true;
            assign alarmLevel = AlarmLevel::critical;
        }

        action clearAlarm {
            assign alarmActive = false;
            assign alarmLevel = AlarmLevel::none;
        }
    }

    // ---- Oxygen Sensor ----
    part def OxygenSensor {
        attribute samplingRate: FrequencyValue = 1.0;
        attribute currentSaturation: OxygenSaturationValue = 98.0;
        attribute lowThreshold: OxygenSaturationValue = 88.0;
        attribute criticalThreshold: OxygenSaturationValue = 85.0;
        attribute alarmActive: Boolean = false;
        attribute alarmLevel: AlarmLevel = AlarmLevel::none;

        port oxygenOutput: OxygenOutputPort;

        action measureSaturation {
            in attribute inputSaturation: OxygenSaturationValue;
            assign currentSaturation = inputSaturation;
            assign alarmActive = (inputSaturation < lowThreshold);
            then decide if (inputSaturation < criticalThreshold)
                then assign alarmLevel = AlarmLevel::critical;
                else assign alarmLevel = AlarmLevel::warning;
            }
            assign oxygenOutput.saturation = currentSaturation;
            assign oxygenOutput.alarm = alarmActive;
        }

        action triggerLowOxygenAlarm {
            assign alarmActive = true;
            assign alarmLevel = AlarmLevel::critical;
        }

        action clearAlarm {
            assign alarmActive = false;
            assign alarmLevel = AlarmLevel::none;
        }
    }

    // ---- Ventilation Adapter ----
    part def VentilationAdapter {
        attribute ventilationMode: String = "two_lung";
        attribute flowRate: FlowRateValue = 6.0;

        port airFlowPort: AirFlowPort;

        action switchToSingleLung {
            assign ventilationMode = "single_lung";
            assign flowRate = 4.0;
        }

        action switchToTwoLung {
            assign ventilationMode = "two_lung";
            assign flowRate = 6.0;
        }
    }

    // ---- Blocker Catheter ----
    part def BlockerCatheter {
        attribute catheterLength: LengthValue = 50.0;
        attribute catheterDiameter: LengthValue = 0.8;
        attribute targetLung: LungSide = LungSide::left;
        attribute insertionDepth: LengthValue = 0.0;
        attribute placementVerified: Boolean = false;
        attribute targetDepth: LengthValue = 25.0;

        port airFlowPort: AirFlowPort;
        port controlPort: ControlPort;

        part cuff: InflatableCuff;
        part fiberopticChannel: FiberopticChannel;
        part pressureSensor: PressureSensor;
        part oxygenSensor: OxygenSensor;
        part ventilationAdapter: VentilationAdapter;

        connection cuffPressureSense {
            source cuff.pressureOutput;
            target pressureSensor.pressureOutput;
        }

        connection cuffControlLink {
            source cuff.inflationControl;
            target cuff.inflationControl;
        }

        action insertCatheter {
            in attribute depth: LengthValue;
            assign insertionDepth = depth;
        }

        action verifyPlacement {
            invoke fiberopticChannel.captureImage;
            assign placementVerified = true;
        }

        action adjustPosition {
            in attribute newDepth: LengthValue;
            assign insertionDepth = newDepth;
            assign placementVerified = false;
        }

        action inflateCuff {
            invoke cuff.inflateCuff;
            invoke ventilationAdapter.switchToSingleLung;
        }

        action deflateCuff {
            invoke cuff.deflateCuff;
            invoke ventilationAdapter.switchToTwoLung;
        }

        action monitorPatient {
            invoke pressureSensor.measurePressure(in inputPressure = cuff.currentPressure);
            invoke oxygenSensor.measureSaturation;
        }

        // ---- Operational Lifecycle State Machine ----
        state def OperationalLifecycle {
            entry; then standby;

            state standby {
                entry assign controlPort.status = DeviceStatus::standby;
                transition standby_to_inserting
                    accept when (controlPort.command == "insert")
                    then inserting;
            }

            state inserting {
                entry assign controlPort.status = DeviceStatus::inserting;
                do insertCatheter(in depth = targetDepth);
                transition inserting_to_positioning
                    accept when (controlPort.command == "position")
                    then positioning;
                transition inserting_to_standby
                    accept when (controlPort.command == "abort")
                    then standby;
            }

            state positioning {
                entry assign controlPort.status = DeviceStatus::positioning;
                do fiberopticChannel.insertCamera(in depth = insertionDepth);
                transition positioning_to_verifying
                    accept when (controlPort.command == "verify")
                    then verifying;
                transition positioning_to_adjusting
                    accept when (controlPort.command == "adjust")
                    then adjusting;
            }

            state adjusting {
                entry assign controlPort.status = DeviceStatus::adjusting;
                do adjustPosition(in newDepth = insertionDepth);
                transition adjusting_to_positioning
                    accept when (controlPort.command == "reposition")
                    then positioning;
            }

            state verifying {
                entry assign controlPort.status = DeviceStatus::verifying;
                do verifyPlacement;
                transition verifying_to_inflating
                    accept when (placementVerified == true and controlPort.command == "inflate")
                    then inflating;
                transition verifying_to_positioning
                    accept when (placementVerified == false)
                    then positioning;
            }

            state inflating {
                entry assign controlPort.status = DeviceStatus::inflating;
                do inflateCuff;
                transition inflating_to_monitoring
                    accept when (cuff.isInflated == true)
                    then monitoring;
            }

            state monitoring {
                entry assign controlPort.status = DeviceStatus::monitoring;
                do monitorPatient;
                transition monitoring_to_deflating
                    accept when (pressureSensor.alarmActive == true or controlPort.command == "deflate")
                    then deflating;
                transition monitoring_to_emergency
                    accept when (oxygenSensor.alarmActive == true and oxygenSensor.alarmLevel == AlarmLevel::critical)
                    then emergency;
            }

            state emergency {
                entry assign controlPort.status = DeviceStatus::emergency;
                do deflateCuff;
                transition emergency_to_deflating
                    accept when (cuff.isInflated == false)
                    then deflating;
            }

            state deflating {
                entry assign controlPort.status = DeviceStatus::deflating;
                do deflateCuff;
                transition deflating_to_standby
                    accept when (cuff.isInflated == false)
                    then standby;
            }
        }

        behavior operationalLifecycle: OperationalLifecycle;
    }

    // ---- Control Unit ----
    part def ControlUnit {
        attribute systemActive: Boolean = false;
        attribute currentPhase: DeviceStatus = DeviceStatus::standby;
        attribute operatorCommand: String = "";

        port controlPort: ControlPort;

        action issueCommand {
            in attribute cmd: String;
            assign operatorCommand = cmd;
            assign controlPort.command = cmd;
        }

        action receiveStatus {
            in attribute status: DeviceStatus;
            assign currentPhase = status;
        }

        action emergencyStop {
            assign operatorCommand = "deflate";
            assign controlPort.command = "deflate";
        }
    }

    // ---- Patient Context ----
    part def Patient {
        attribute leftLungIsolated: Boolean = false;
        attribute rightLungIsolated: Boolean = false;
        attribute oxygenSaturation: OxygenSaturationValue = 98.0;
        attribute respiratoryRate: FrequencyValue = 0.25;

        port airwayPort: AirFlowPort;
    }

    // ---- Top-level Bronchial Blocker System ----
    part BronchialBlockerSystem {
        part catheter: BlockerCatheter;
        part controlUnit: ControlUnit;
        part patient: Patient;

        connection controlLink {
            source controlUnit.controlPort;
            target catheter.controlPort;
        }

        connection airwayLink {
            source catheter.airFlowPort;
            target patient.airwayPort;
        }

        satisfy CuffPressureSafetyReq by catheter.cuff;
        satisfy OxygenSaturationReq by catheter.oxygenSensor;
        satisfy VisualVerificationReq by catheter.fiberopticChannel;
        satisfy SingleLungVentilationReq by catheter;
        satisfy ContinuousMonitoringReq by catheter.pressureSensor;
        satisfy EmergencyDeflationReq by catheter;
    }
}
