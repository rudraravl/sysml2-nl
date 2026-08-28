package FarmWiseWeeder {
    import SI::*;
    import ScalarValues::*;
    import ScalarFunctions::*;

    // ---- Value Types ----
    value def Voltage { unit 'V'; }
    value def Current { unit 'A'; }
    value def Energy { unit 'Wh'; }
    value def Power { unit 'W'; }
    value def Percentage { unit '%'; }
    value def Speed { unit 'm/s'; }
    value def Distance { unit 'm'; }
    value def Duration { unit 'h'; }

    // ---- Item Types ----
    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def GPSPosition {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : Real;
    }

    item def ImageData {
        attribute timestamp : Real;
        attribute width : Integer;
        attribute height : Integer;
    }

    item def WeedDetection {
        attribute position : GPSPosition;
        attribute confidence : Real;
        attribute weedType : String;
    }

    item def NavigationCommand {
        attribute targetPosition : GPSPosition;
        attribute speed : Speed;
    }

    enum def WeederAction { deploy; retract; }

    item def WeederCommand {
        attribute action : WeederAction;
    }

    // ---- Port Definitions ----
    port def PowerOutPort { out power : ElectricalPower; }
    port def PowerInPort { in power : ElectricalPower; }
    port def ImageOutPort { out image : ImageData; }
    port def ImageInPort { in image : ImageData; }
    port def DetectionOutPort { out detection : WeedDetection; }
    port def DetectionInPort { in detection : WeedDetection; }
    port def PositionOutPort { out position : GPSPosition; }
    port def PositionInPort { in position : GPSPosition; }
    port def NavCommandOutPort { out command : NavigationCommand; }
    port def NavCommandInPort { in command : NavigationCommand; }
    port def WeederCommandOutPort { out command : WeederCommand; }
    port def WeederCommandInPort { in command : WeederCommand; }

    // ---- Requirements ----
    requirement def OperationalAutonomyRequirement {
        doc /* The system shall operate for at least 8 hours on a single charge. */
        attribute minDuration : Duration = 8 [h];
        subject weeder : FarmWiseWeeder;
        objective { weeder.batteryDuration >= minDuration; }
    }

    requirement def CropSafetyRequirement {
        doc /* The weeding process shall achieve a crop safety rate over 98%. */
        attribute minSafetyRate : Percentage = 98 [%];
        subject weeder : FarmWiseWeeder;
        objective { weeder.safetyRate >= minSafetyRate; }
    }

    requirement def WeedDetectionAccuracyRequirement {
        doc /* The vision processor shall distinguish weeds from crops with high accuracy. */
        attribute minAccuracy : Percentage = 95 [%];
        subject vision : VisionProcessor;
        objective { vision.detectionAccuracy >= minAccuracy; }
    }

    requirement def GPSAccuracyRequirement {
        doc /* The GPS navigation system shall pinpoint weed locations with high accuracy. */
        attribute maxError : Distance = 0.05 [m];
        subject gps : GPSNavigationSystem;
        objective { gps.positionError <= maxError; }
    }

    requirement def HerbicideFreeOperationRequirement {
        doc /* The system shall remove weeds mechanically without chemical herbicides. */
        subject weeder : FarmWiseWeeder;
        objective { weeder.usesHerbicide == false; }
    }

    // ---- Part Definitions ----
    part def BatteryPack {
        attribute capacity : Energy = 2400 [Wh];
        attribute nominalVoltage : Voltage = 48 [V];
        attribute currentCharge : Energy = 2400 [Wh];
        attribute chargeLevel : Real = 1.0;
        port powerOut : PowerOutPort;

        state def BatteryState {
            entry;
            state FullyCharged;
            state Normal;
            state Low;
            state Critical;
            transition FullyCharged to Normal when chargeLevel < 0.99;
            transition Normal to Low when chargeLevel < 0.20;
            transition Low to Critical when chargeLevel < 0.05;
            transition Low to Normal when chargeLevel > 0.30;
            transition Critical to Low when chargeLevel > 0.10;
        }
    }

    part def DriveSystem {
        attribute maxSpeed : Speed = 1.5 [m/s];
        attribute wheelbase : Distance = 0.8 [m];
        port powerIn : PowerInPort;
        port navCommandIn : NavCommandInPort;

        action def MoveTo {
            in target : GPSPosition;
            in speed : Speed;
        }

        action def Stop;
    }

    part def CameraSystem {
        attribute resolutionWidth : Integer = 3840;
        attribute resolutionHeight : Integer = 2160;
        attribute frameRate : Real = 30.0;
        port powerIn : PowerInPort;
        port imageOut : ImageOutPort;

        action def CaptureImage {
            out image : ImageData;
        }
    }

    part def VisionProcessor {
        attribute detectionAccuracy : Percentage = 96 [%];
        attribute modelVersion : String = "WeedNet-v3";
        port imageIn : ImageInPort;
        port detectionOut : DetectionOutPort;

        action def AnalyzeImage {
            in image : ImageData;
            out detection : WeedDetection;
        }

        action def ClassifyPlant {
            in image : ImageData;
            out isWeed : Boolean;
            out confidence : Real;
        }

        action def LocateWeed {
            in image : ImageData;
            out position : GPSPosition;
        }
    }

    part def GPSNavigationSystem {
        attribute positionError : Distance = 0.03 [m];
        attribute updateRate : Real = 10.0;
        port positionOut : PositionOutPort;
        port navCommandIn : NavCommandInPort;

        action def GetCurrentPosition {
            out position : GPSPosition;
        }

        action def PlanPath {
            in start : GPSPosition;
            in target : GPSPosition;
            out command : NavigationCommand;
        }
    }

    part def MechanicalWeeder {
        attribute safetyRate : Percentage = 99 [%];
        attribute bladeDepth : Distance = 0.05 [m];
        attribute deployTime : Duration = 0.5 [h];
        port powerIn : PowerInPort;
        port weederCommandIn : WeederCommandInPort;

        state def WeederState {
            entry;
            state Retracted;
            state Deployed;
            state Engaging;
            state Uprooting;
            transition Retracted to Deployed when weederCommandIn.command.action == WeederAction::deploy;
            transition Deployed to Engaging when Deployed.isStable;
            transition Engaging to Uprooting when Engaging.isComplete;
            transition Uprooting to Retracted when weederCommandIn.command.action == WeederAction::retract;
        }

        action def EngageSoil;
        action def UprootWeed;
        action def RetractTool;
    }

    part def ControlComputer {
        attribute batteryDuration : Duration = 9 [h];
        attribute safetyRate : Percentage = 99 [%];
        attribute usesHerbicide : Boolean = false;
        attribute batteryLevel : Real = 1.0;
        attribute atChargingStation : Boolean = false;

        port powerIn : PowerInPort;
        port detectionIn : DetectionInPort;
        port positionIn : PositionInPort;
        port navCommandOut : NavCommandOutPort;
        port weederCommandOut : WeederCommandOutPort;

        action def OrchestrateCycle {
            action scan { out image : ImageData; }
            action detect { in image : ImageData; out detection : WeedDetection; }
            action navigate { in detection : WeedDetection; out command : NavigationCommand; }
            action weed { in command : WeederCommand; }
            flow scan.image to detect.image;
            flow detect.detection to navigate.detection;
        }

        state def ControlState {
            entry;
            state Idle;
            state Scanning;
            state Detecting;
            state Navigating;
            state Weeding;
            state ReturningToBase;
            state Charging;

            transition Idle to Scanning when batteryLevel > 0.10;
            transition Scanning to Detecting when detectionIn.detection != null;
            transition Detecting to Navigating when detectionIn.detection.confidence > 0.8;
            transition Navigating to Weeding when positionIn.position == detectionIn.detection.position;
            transition Weeding to Scanning when weederCommandOut.command.action == WeederAction::retract;
            transition Scanning to ReturningToBase when batteryLevel < 0.10;
            transition ReturningToBase to Charging when atChargingStation == true;
            transition Charging to Idle when batteryLevel >= 0.95;
        }
    }

    part def ChargingStation {
        attribute outputVoltage : Voltage = 48 [V];
        attribute outputCurrent : Current = 20 [A];
        port powerOut : PowerOutPort;
    }

    // ---- Top-level System ----
    part def FarmWiseWeeder {
        attribute batteryDuration : Duration = 9 [h];
        attribute safetyRate : Percentage = 99 [%];
        attribute usesHerbicide : Boolean = false;

        part battery : BatteryPack;
        part drive : DriveSystem;
        part camera : CameraSystem;
        part vision : VisionProcessor;
        part gps : GPSNavigationSystem;
        part weeder : MechanicalWeeder;
        part computer : ControlComputer;

        satisfy OperationalAutonomyRequirement by weeder;
        satisfy CropSafetyRequirement by weeder;
        satisfy HerbicideFreeOperationRequirement by weeder;
        satisfy WeedDetectionAccuracyRequirement by vision;
        satisfy GPSAccuracyRequirement by gps;

        connection powerToComputer connect battery.powerOut to computer.powerIn;
        connection powerToDrive connect battery.powerOut to drive.powerIn;
        connection powerToCamera connect battery.powerOut to camera.powerIn;
        connection powerToWeeder connect battery.powerOut to weeder.powerIn;

        connection imageToVision connect camera.imageOut to vision.imageIn;
        connection detectionToComputer connect vision.detectionOut to computer.detectionIn;
        connection positionToComputer connect gps.positionOut to computer.positionIn;
        connection navCommandToDrive connect computer.navCommandOut to drive.navCommandIn;
        connection navCommandToGps connect computer.navCommandOut to gps.navCommandIn;
        connection weederCommandToWeeder connect computer.weederCommandOut to weeder.weederCommandIn;
    }

    part def FieldOperation {
        part robot : FarmWiseWeeder;
        part station : ChargingStation;
        connection chargingConnect connect station.powerOut to robot.battery.powerOut;
    }
}
