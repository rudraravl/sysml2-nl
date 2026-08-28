package ROTIGS {

    import ScalarValues::*;

    // ---- Units ----
    unit deg;
    unit m;
    unit K;
    unit Hz;
    unit W;
    unit percent;

    // ---- Value Types ----
    value type AngleValue = Real { unit deg; }
    value type DistanceValue = Real { unit m; }
    value type CoordinateValue = Real { unit m; }
    value type TemperatureValue = Real { unit K; }
    value type FrameRateValue = Real { unit Hz; }
    value type PowerValue = Real { unit W; }
    value type BatteryLevel = Real { unit percent; }

    // ---- Enumerations ----
    enum def CommandType { standby; scan; track; fire; }
    enum def SystemState { standby; searching; tracking; locked; engaging; }

    // ---- Item Definitions ----
    item def ThermalVideo {
        attribute frameId : Integer;
        attribute width : Integer;
        attribute height : Integer;
        attribute frameRate : FrameRateValue;
    }

    item def TargetData {
        value x : CoordinateValue;
        value y : CoordinateValue;
        value z : CoordinateValue;
        value locked : Boolean;
        value confidence : Real;
    }

    item def SystemStatus {
        value state : SystemState;
        value batteryLevel : BatteryLevel;
        value temperature : TemperatureValue;
        value targetLocked : Boolean;
    }

    item def Command {
        value commandType : CommandType;
        value panAngle : AngleValue;
        value tiltAngle : AngleValue;
        value fireAuthorized : Boolean;
    }

    // ---- Port Definitions ----
    port def VideoOutPort {
        out video : ThermalVideo;
        out targetData : TargetData;
    }

    port def VideoInPort {
        in video : ThermalVideo;
        in targetData : TargetData;
    }

    port def CommandOutPort {
        out command : Command;
    }

    port def CommandInPort {
        in command : Command;
    }

    port def StatusOutPort {
        out status : SystemStatus;
    }

    port def StatusInPort {
        in status : SystemStatus;
    }

    port def FireSignalPort {
        in fire : Boolean;
    }

    // ---- Operator Station ----
    part def OperatorStation {
        port videoPort : VideoInPort;
        port statusPort : StatusInPort;
        port commandPort : CommandOutPort;

        attribute operatorId : String;
        attribute stationRange : DistanceValue;

        part display {
            in video : ThermalVideo;
            in targetData : TargetData;
            in status : SystemStatus;
            attribute brightness : Real;
        }

        part controlInterface {
            out command : Command;
            attribute joystickSensitivity : Real;
        }

        part commLink {
            in video : ThermalVideo;
            in targetData : TargetData;
            in status : SystemStatus;
            out command : Command;
            attribute bandwidth : Real;
            attribute latency : Real;
        }

        connection videoFeed connect commLink.video to display.video;
        connection targetFeed connect commLink.targetData to display.targetData;
        connection statusFeed connect commLink.status to display.status;
        connection commandPath connect controlInterface.command to commLink.command;

        connection linkVideoIn connect videoPort.video to commLink.video;
        connection linkTargetIn connect videoPort.targetData to commLink.targetData;
        connection linkStatusIn connect statusPort.status to commLink.status;
        connection linkCommandOut connect commLink.command to commandPort.command;

        state machine operatorBehavior {
            entry; then idle;
            state idle;
            transition idle_to_commanding
                from idle to commanding
                when controlInterface.command.commandType != CommandType::standby;
            state commanding;
            transition commanding_to_idle
                from commanding to idle
                when controlInterface.command.commandType == CommandType::standby;
        }
    }

    // ---- Thermal Sight ----
    part def ThermalSight {
        port videoPort : VideoOutPort;
        port statusPort : StatusOutPort;
        port commandPort : CommandInPort;
        port firePort : FireSignalPort;

        attribute sightId : String;
        attribute fieldOfView : AngleValue;

        part thermalImager {
            out video : ThermalVideo;
            attribute resolution : String;
            attribute frameRate : FrameRateValue;
            attribute minDetectableTemp : TemperatureValue;
        }

        part gimbal {
            attribute pan : AngleValue;
            attribute tilt : AngleValue;
            in panCmd : AngleValue;
            in tiltCmd : AngleValue;
            attribute maxPanRate : Real;
            attribute maxTiltRate : Real;
        }

        part imageProcessor {
            in video : ThermalVideo;
            out processedVideo : ThermalVideo;
            out detectedTarget : TargetData;
            out targetDetected : Boolean;
            attribute processingLatency : Real;
        }

        part trackingComputer {
            in detectedTarget : TargetData;
            in command : Command;
            out targetData : TargetData;
            out panCmd : AngleValue;
            out tiltCmd : AngleValue;
            out fireAuthorized : Boolean;
            attribute lockConfirmed : Boolean;
            attribute trackAccuracy : Real;
        }

        connection rawVideo connect thermalImager.video to imageProcessor.video;
        connection processedVideoOut connect imageProcessor.processedVideo to videoPort.video;
        connection detectionFlow connect imageProcessor.detectedTarget to trackingComputer.detectedTarget;
        connection targetDataOut connect trackingComputer.targetData to videoPort.targetData;
        connection panDrive connect trackingComputer.panCmd to gimbal.panCmd;
        connection tiltDrive connect trackingComputer.tiltCmd to gimbal.tiltCmd;
        connection fireAuthOut connect trackingComputer.fireAuthorized to firePort.fire;
        connection commandDispatch connect commandPort.command to trackingComputer.command;

        connection statusOut connect statusPort.status to statusPort.status;

        state machine sightBehavior {
            entry; then standby;
            state standby;
            transition standby_to_searching
                from standby to searching
                when commandPort.command.commandType == CommandType::scan;
            state searching {
                // gimbal sweeps area
            }
            transition searching_to_tracking
                from searching to tracking
                when imageProcessor.targetDetected == true
                and commandPort.command.commandType == CommandType::track;
            state tracking;
            transition tracking_to_locked
                from tracking to locked
                when trackingComputer.lockConfirmed == true;
            state locked;
            transition locked_to_engaging
                from locked to engaging
                when commandPort.command.commandType == CommandType::fire
                and trackingComputer.lockConfirmed == true
                and commandPort.command.fireAuthorized == true;
            state engaging {
                // fire authorization emitted
            }
            transition engaging_to_searching
                from engaging to searching
                when commandPort.command.commandType == CommandType::scan;
            transition any_to_standby
                from searching to standby
                when commandPort.command.commandType == CommandType::standby;
        }
    }

    // ---- Weapon System ----
    part def WeaponSystem {
        port firePort : FireSignalPort;

        attribute weaponId : String;
        attribute maxRange : DistanceValue;

        part gun {
            attribute caliber : String;
            attribute barrelLength : DistanceValue;
        }

        part ammunition {
            attribute count : Integer;
            attribute caliber : String;
            attribute muzzleVelocity : Real;
        }

        part firingMechanism {
            in fire : Boolean;
            out fired : Boolean;
            attribute firingDelay : Real;
        }

        part safetyInterlock {
            in fire : Boolean;
            out safeFire : Boolean;
            attribute armed : Boolean;
            attribute faultDetected : Boolean;
        }

        connection safetyInput connect firePort.fire to safetyInterlock.fire;
        connection mechanismInput connect safetyInterlock.safeFire to firingMechanism.fire;

        state machine weaponBehavior {
            entry; then safe;
            state safe;
            transition safe_to_armed
                from safe to armed
                when firePort.fire == true
                and safetyInterlock.faultDetected == false;
            state armed;
            transition armed_to_firing
                from armed to firing
                when safetyInterlock.armed == true;
            state firing;
            transition firing_to_safe
                from firing to safe
                when firingMechanism.fired == true;
            transition armed_to_safe
                from armed to safe
                when firePort.fire == false;
        }
    }

    // ---- Top-level ROTIGS System ----
    part def ROTIGS {
        attribute systemId : String;
        attribute operationalRange : DistanceValue;

        part operatorStation : OperatorStation;
        part thermalSight : ThermalSight;
        part weaponSystem : WeaponSystem;

        connection videoLink connect thermalSight.videoPort to operatorStation.videoPort;
        connection statusLink connect thermalSight.statusPort to operatorStation.statusPort;
        connection commandLink connect operatorStation.commandPort to thermalSight.commandPort;
        connection fireLink connect thermalSight.firePort to weaponSystem.firePort;

        state machine missionBehavior {
            entry; then standby;
            state standby;
            transition standby_to_searching
                from standby to searching
                when operatorStation.controlInterface.command.commandType == CommandType::scan;
            state searching;
            transition searching_to_tracking
                from searching to tracking
                when thermalSight.imageProcessor.targetDetected == true
                and operatorStation.controlInterface.command.commandType == CommandType::track;
            state tracking;
            transition tracking_to_locked
                from tracking to locked
                when thermalSight.trackingComputer.lockConfirmed == true;
            state locked;
            transition locked_to_engaging
                from locked to engaging
                when operatorStation.controlInterface.command.commandType == CommandType::fire
                and thermalSight.trackingComputer.lockConfirmed == true
                and operatorStation.controlInterface.command.fireAuthorized == true;
            state engaging;
            transition engaging_to_searching
                from engaging to searching
                when operatorStation.controlInterface.command.commandType == CommandType::scan;
            transition any_to_standby
                from engaging to standby
                when operatorStation.controlInterface.command.commandType == CommandType::standby;
        }
    }

    // ---- Requirements ----
    requirement def RemoteControlRequirement {
        subject system : ROTIGS;
        doc /* The system shall allow an operator to control the weaponized camera from a safe, distant location. */
        require system.operatorStation != system.thermalSight;
        require system.operationalRange > 100 [m];
    }

    requirement def TargetLockRequirement {
        subject sight : ThermalSight;
        doc /* The thermal sight shall achieve and maintain a confirmed target lock before authorizing fire. */
        require sight.trackingComputer.lockConfirmed == true;
        require sight.imageProcessor.targetDetected == true;
    }

    requirement def SafetyInterlockRequirement {
        subject weapon : WeaponSystem;
        doc /* The weapon system shall not fire unless the safety interlock is armed and no fault is detected. */
        require weapon.safetyInterlock.armed == true;
        require weapon.safetyInterlock.faultDetected == false;
    }

    requirement def EngagementSequenceRequirement {
        subject system : ROTIGS;
        doc /* The system shall follow the sequence: standby, searching, tracking, locked, engaging, then return to searching. */
        require system.missionBehavior.standby.isReached == true;
        require system.missionBehavior.searching.isReached == true;
        require system.missionBehavior.tracking.isReached == true;
        require system.missionBehavior.locked.isReached == true;
        require system.missionBehavior.engaging.isReached == true;
    }

    requirement def FireAuthorizationRequirement {
        subject system : ROTIGS;
        doc /* A fire command shall only be sent to the weapon system when both target lock is confirmed and the operator explicitly authorizes fire. */
        require system.thermalSight.trackingComputer.lockConfirmed == true;
        require system.operatorStation.controlInterface.command.fireAuthorized == true;
        require system.operatorStation.controlInterface.command.commandType == CommandType::fire;
    }

    requirement def VideoFeedRequirement {
        subject sight : ThermalSight;
        doc /* The thermal sight shall provide a live thermal video feed and targeting data to the operator station. */
        require sight.videoPort.video.isProvided == true;
        require sight.videoPort.targetData.isProvided == true;
    }

    // ---- Requirement Satisfaction ----
    satisfaction remoteControlSatisfies : RemoteControlRequirement {
        subject system : ROTIGS;
    }

    satisfaction targetLockSatisfies : TargetLockRequirement {
        subject sight : ThermalSight;
    }

    satisfaction safetyInterlockSatisfies : SafetyInterlockRequirement {
        subject weapon : WeaponSystem;
    }

    satisfaction engagementSequenceSatisfies : EngagementSequenceRequirement {
        subject system : ROTIGS;
    }

    satisfaction fireAuthorizationSatisfies : FireAuthorizationRequirement {
        subject system : ROTIGS;
    }

    satisfaction videoFeedSatisfies : VideoFeedRequirement {
        subject sight : ThermalSight;
    }

}
