package AutonomousCleaningSystem {
    import ISQ::*;
    import ScalarValues::*;
    import Time::*;

    // ===== Value Types =====
    value type Percent :> Real {
        unit '%';
    }
    value type BatteryLevel :> Percent;
    value type PowerValue :> Real {
        unit 'W';
    }
    value type EnergyValue :> Real {
        unit 'Wh';
    }
    value type CleaningArea :> Real {
        unit 'm^2';
    }
    value type SpeedValue :> Real {
        unit 'm/s';
    }
    value type ProgressValue :> Percent;

    // ===== Item Definitions =====
    item def CleaningCommand {
        attribute commandId : String;
        attribute targetArea : CleaningArea;
        attribute priority : Integer;
    }
    item def EmergencyStopCommand {
        attribute reason : String;
    }
    item def ResumeCommand {
        attribute resumeId : String;
    }
    item def StatusReport {
        attribute positionX : LengthValue;
        attribute positionY : LengthValue;
        attribute battery : BatteryLevel;
        attribute taskProgress : ProgressValue;
        attribute currentMode : String;
    }
    item def CompletionReport {
        attribute areaCleaned : CleaningArea;
        attribute duration : TimeValue;
        attribute batteryConsumed : BatteryLevel;
        attribute success : Boolean;
    }
    item def ObstacleData {
        attribute distance : LengthValue;
        attribute bearing : PlaneAngleValue;
        attribute classifiedType : String;
    }
    item def MapData {
        attribute resolution : LengthValue;
        attribute originX : LengthValue;
        attribute originY : LengthValue;
    }
    item def PathPlan {
        attribute waypointsX : List(LengthValue);
        attribute waypointsY : List(LengthValue);
        attribute estimatedDuration : TimeValue;
    }
    item def BatteryStatus {
        attribute level : BatteryLevel;
        attribute voltage : Real;
        attribute charging : Boolean;
    }
    item def DockingSignal {
        attribute stationId : String;
        attribute signalStrength : Real;
    }
    item def CleaningAction {
        attribute mode : String;
        attribute suctionPower : PowerValue;
    }

    // ===== Port Definitions =====
    port def CommandPort {
        in item commands : CleaningCommand;
        in item emergencyStop : EmergencyStopCommand;
        in item resume : ResumeCommand;
        out item status : StatusReport;
        out item completion : CompletionReport;
    }
    port def SensorPort {
        out item obstacles : ObstacleData;
        out item map : MapData;
    }
    port def NavigationPort {
        out item path : PathPlan;
        in item updatedMap : MapData;
    }
    port def BatteryPort {
        out item batteryStatus : BatteryStatus;
        in item chargeCommand : Boolean;
    }
    port def CleaningPort {
        in item action : CleaningAction;
        out item progress : ProgressValue;
    }
    port def DockingPort {
        out item dockingSignal : DockingSignal;
        in item contact : Boolean;
    }
    port def PowerDeliveryPort {
        out item power : PowerValue;
        out item energy : EnergyValue;
    }

    // ===== Subsystem Parts =====
    part def SensorArray {
        port sensorOut : SensorPort;
        attribute scanRate : Real;
        perform action scanEnvironment {
            in area : MapData;
            out obstacles : ObstacleData;
            out map : MapData;
        }
    }

    part def NavigationSystem {
        port navOut : NavigationPort;
        port navIn : NavigationPort;
        attribute maxSpeed : SpeedValue;
        perform action planPath {
            in map : MapData;
            in target : List(LengthValue);
            out path : PathPlan;
        }
        perform action updateMap {
            in obstacles : ObstacleData;
            out map : MapData;
        }
    }

    part def CleaningSystem {
        port cleaningIn : CleaningPort;
        attribute coverageRate : CleaningArea;
        perform action cleanArea {
            in path : PathPlan;
            in action : CleaningAction;
            out progress : ProgressValue;
        }
    }

    part def BatterySystem {
        port batteryOut : BatteryPort;
        port powerIn : PowerDeliveryPort;
        attribute capacity : EnergyValue;
        attribute currentLevel : BatteryLevel;
        attribute lowThreshold : BatteryLevel = 20;
        perform action monitorCharge {
            out status : BatteryStatus;
        }
        perform action charge {
            in power : PowerValue;
            out updatedLevel : BatteryLevel;
        }
    }

    part def ControlSystem {
        port commandPort : CommandPort;
        port navControl : NavigationPort;
        port sensorControl : SensorPort;
        port batteryControl : BatteryPort;
        port cleaningControl : CleaningPort;
        attribute taskQueue : List(CleaningCommand);
        perform action coordinateTask {
            in command : CleaningCommand;
            in battery : BatteryStatus;
            in obstacles : ObstacleData;
            out path : PathPlan;
            out cleaningAction : CleaningAction;
            out status : StatusReport;
        }
        perform action generateReport {
            in progress : ProgressValue;
            out report : CompletionReport;
        }
    }

    // ===== Home Robot =====
    part def HomeRobot {
        port externalCommand : CommandPort;
        port dockingPort : DockingPort;

        part control : ControlSystem;
        part navigation : NavigationSystem;
        part sensors : SensorArray;
        part cleaning : CleaningSystem;
        part battery : BatterySystem;

        connection control.sensorControl connect control.sensorControl to sensors.sensorOut;
        connection navData connect sensors.sensorOut.map to navigation.navIn.updatedMap;
        connection obstacleToNav connect sensors.sensorOut.obstacles to navigation.navIn.updatedMap;
        connection navToControl connect navigation.navOut.path to control.navControl.path;
        connection controlToNav connect control.navControl.path to navigation.navIn.updatedMap;
        connection controlToCleaning connect control.cleaningControl.action to cleaning.cleaningIn.action;
        connection cleaningToControl connect cleaning.cleaningIn.progress to control.cleaningControl.progress;
        connection batteryToControl connect battery.batteryOut.batteryStatus to control.batteryControl.batteryStatus;
        connection controlToBattery connect control.batteryControl.chargeCommand to battery.batteryOut.chargeCommand;
        connection commandFlow connect externalCommand.commands to control.commandPort.commands;
        connection emergencyFlow connect externalCommand.emergencyStop to control.commandPort.emergencyStop;
        connection resumeFlow connect externalCommand.resume to control.commandPort.resume;
        connection statusFlow connect control.commandPort.status to externalCommand.status;
        connection completionFlow connect control.commandPort.completion to externalCommand.completion;

        state def RobotStateMachine {
            entry; then Standby;

            state Standby {
                entry action { /* initialize at charging station */ }
            }
            state Active;
            state Navigating;
            state Charging;
            state Error;

            transition from Standby to Active
                when externalCommand.commands ?@;
            transition from Active to Navigating
                when sensors.sensorOut.obstacles ?@;
            transition from Navigating to Active
                when navigation.navOut.path ?@;
            transition from Active to Charging
                when battery.batteryOut.batteryStatus.level < battery.lowThreshold;
            transition from Charging to Standby
                when battery.batteryOut.batteryStatus.level >= 100;
            transition from Active to Error
                when externalCommand.emergencyStop ?@;
            transition from Navigating to Error
                when externalCommand.emergencyStop ?@;
            transition from Charging to Error
                when externalCommand.emergencyStop ?@;
            transition from Error to Standby
                when externalCommand.resume ?@;
            transition from Active to Standby
                when control.commandPort.completion !@;
        }

        state robotBehavior : RobotStateMachine;
    }

    // ===== Charging Station =====
    part def ChargingStation {
        port dockingBeacon : DockingPort;
        port powerOutput : PowerDeliveryPort;
        attribute stationId : String;
        attribute outputPower : PowerValue;
        perform action emitDockingSignal {
            out signal : DockingSignal;
        }
        perform action deliverPower {
            out power : PowerValue;
            out energy : EnergyValue;
        }
    }

    // ===== Control Center =====
    part def ControlCenter {
        port userCommand : CommandPort;
        attribute connectedRobots : List(String);
        perform action sendCommand {
            out command : CleaningCommand;
        }
        perform action receiveStatus {
            in status : StatusReport;
        }
        perform action receiveCompletion {
            in report : CompletionReport;
        }
        perform action emergencyStop {
            out stop : EmergencyStopCommand;
        }
        perform action resumeOperation {
            out resume : ResumeCommand;
        }
    }

    // ===== Top-Level System =====
    part CleaningSystemAssembly {
        part robot : HomeRobot;
        part station : ChargingStation;
        part controlCenter : ControlCenter;

        connection commandLink connect controlCenter.userCommand.commands to robot.externalCommand.commands;
        connection emergencyLink connect controlCenter.userCommand.emergencyStop to robot.externalCommand.emergencyStop;
        connection resumeLink connect controlCenter.userCommand.resume to robot.externalCommand.resume;
        connection statusLink connect robot.externalCommand.status to controlCenter.userCommand.status;
        connection completionLink connect robot.externalCommand.completion to controlCenter.userCommand.completion;
        connection dockingLink connect station.dockingBeacon.dockingSignal to robot.dockingPort.dockingSignal;
        connection contactLink connect robot.dockingPort.contact to station.dockingBeacon.contact;
        connection powerLink connect station.powerOutput.power to robot.battery.powerIn.power;
        connection energyLink connect station.powerOutput.energy to robot.battery.powerIn.energy;
    }

    // ===== Requirements =====
    requirement def CleaningTaskRequirement {
        attribute requiredArea : CleaningArea;
        subject : CleaningSystemAssembly;
        require {
            subject.robot.cleaning.coverageRate >= requiredArea / (60 [s]);
        }
    }

    requirement def BatteryEnduranceRequirement {
        attribute minRunTime : TimeValue = 60 [min];
        subject : HomeRobot;
        require {
            subject.battery.capacity / subject.battery.currentLevel >= minRunTime;
        }
    }

    requirement def ObstacleAvoidanceRequirement {
        attribute minDetectionDistance : LengthValue = 0.2 [m];
        subject : HomeRobot;
        require {
            subject.sensors.scanRate > 0
            and subject.sensors.sensorOut.obstacles.distance >= minDetectionDistance;
        }
    }

    requirement def ChargingReturnRequirement {
        attribute lowThreshold : BatteryLevel = 20;
        subject : HomeRobot;
        require {
            subject.battery.lowThreshold == lowThreshold
            and subject.robotBehavior.Charging.isReached when subject.battery.currentLevel < lowThreshold;
        }
    }

    requirement def StatusReportingRequirement {
        attribute maxReportInterval : TimeValue = 5 [s];
        subject : CleaningSystemAssembly;
        require {
            subject.controlCenter.receiveStatus.status.battery.defined
            and subject.controlCenter.receiveStatus.status.positionX.defined;
        }
    }

    requirement def EmergencyStopRequirement {
        subject : CleaningSystemAssembly;
        require {
            subject.robot.robotBehavior.Error.isReached when subject.controlCenter.emergencyStop.stop ?@;
        }
    }

    requirement def CompletionReportRequirement {
        subject : CleaningSystemAssembly;
        require {
            subject.controlCenter.receiveCompletion.report.areaCleaned.defined
            and subject.controlCenter.receiveCompletion.report.success.defined;
        }
    }
}
