package RoombaVacuumCleanerModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent : Real {
        unit = "%";
    }

    attribute def DirtLevel : Real {
        unit = "%";
    }

    attribute def BatteryCharge : Real {
        unit = "%";
    }

    attribute def ElectricPotential : Real {
        unit = "V";
    }

    attribute def PowerDraw : Real {
        unit = "W";
    }

    attribute def Distance : Real {
        unit = "m";
    }

    attribute def Area : Real {
        unit = "m^2";
    }

    attribute def Duration : Real {
        unit = "s";
    }

    attribute def RotationalSpeed : Real {
        unit = "rpm";
    }

    attribute def Velocity : Real {
        unit = "m/s";
    }

    attribute def DustMass : Real {
        unit = "g";
    }

    item def Debris {
        attribute mass : DustMass;
        attribute particleSize : Real;
        attribute dirtLevelContribution : DirtLevel;
    }

    item def FloorSurface {
        attribute area : Area;
        attribute estimatedDirtLevel : DirtLevel;
        attribute coveredArea : Area;
    }

    item def CleaningCommand {
        attribute requestedArea : Area;
        attribute maxDuration : Duration;
        attribute returnToDockWhenComplete : Boolean;
    }

    item def DockingSignal {
        attribute signalStrength : Percent;
        attribute dockDistanceEstimate : Distance;
    }

    item def PowerFlow {
        attribute voltage : ElectricPotential;
        attribute power : PowerDraw;
    }

    item def MotionCommand {
        attribute targetLinearSpeed : Velocity;
        attribute targetAngularSpeed : Real;
    }

    item def SensorReading {
        attribute obstacleDistance : Distance;
        attribute cliffDetected : Boolean;
        attribute dirtDetected : DirtLevel;
        attribute dockSignal : DockingSignal;
    }

    port def PowerPort {
        out item power : PowerFlow;
    }

    port def ChargingPort {
        in item power : PowerFlow;
    }

    port def DebrisIntakePort {
        in item debris : Debris;
    }

    port def DebrisStoragePort {
        in item debris : Debris;
    }

    port def CommandPort {
        in item command : CleaningCommand;
    }

    port def StatusPort {
        out attribute batteryCharge : BatteryCharge;
        out attribute cleanedArea : Area;
        out attribute binFillLevel : Percent;
        out attribute currentState : String;
    }

    port def SensorPort {
        out item reading : SensorReading;
    }

    port def ActuatorPort {
        in item command : MotionCommand;
    }

    part def Battery {
        attribute nominalVoltage : ElectricPotential = 14.4 [V];
        attribute capacity : Real = 5200;
        attribute chargeLevel : BatteryCharge;
        attribute lowChargeThreshold : BatteryCharge = 18 [%];
        attribute criticalChargeThreshold : BatteryCharge = 8 [%];

        port powerOut : PowerPort;
        port chargeIn : ChargingPort;

        action charge {
            in item incomingPower : PowerFlow;
            out attribute updatedCharge : BatteryCharge;
        }

        action discharge {
            in attribute load : PowerDraw;
            in attribute elapsedTime : Duration;
            out attribute updatedCharge : BatteryCharge;
        }
    }

    part def DockingStation {
        attribute availablePower : PowerDraw = 45 [W];
        attribute docked : Boolean;

        port charger : PowerPort;
        port beacon : SensorPort;

        action provideChargingPower {
            out item suppliedPower : PowerFlow;
        }

        action transmitDockingSignal {
            out item signal : DockingSignal;
        }
    }

    part def DriveSystem {
        attribute leftWheelSpeed : RotationalSpeed;
        attribute rightWheelSpeed : RotationalSpeed;
        attribute maximumLinearSpeed : Velocity = 0.45 [m/s];

        port commandIn : ActuatorPort;

        action driveForward {
            in attribute speed : Velocity;
        }

        action rotateInPlace {
            in attribute angularSpeed : Real;
        }

        action stopMotion;
    }

    part def VacuumMotor {
        attribute suctionPower : PowerDraw = 28 [W];
        attribute motorSpeed : RotationalSpeed = 11000 [rpm];

        action generateSuction {
            out item collectedDebris : Debris;
        }

        action stopSuction;
    }

    part def BrushAssembly {
        attribute mainBrushSpeed : RotationalSpeed = 850 [rpm];
        attribute sideBrushSpeed : RotationalSpeed = 160 [rpm];

        action agitateFloor {
            in item surface : FloorSurface;
            out item loosenedDebris : Debris;
        }

        action stopBrushes;
    }

    part def DustBin {
        attribute capacity : DustMass = 450 [g];
        attribute storedMass : DustMass;
        attribute fillLevel : Percent;

        port debrisIn : DebrisStoragePort;

        action storeDebris {
            in item debris : Debris;
            out attribute updatedFillLevel : Percent;
        }

        action emptyBin {
            out attribute updatedFillLevel : Percent;
        }
    }

    part def SensorSuite {
        attribute obstacleDetectionRange : Distance = 0.75 [m];
        attribute cliffDetectionRange : Distance = 0.08 [m];
        attribute dirtSensitivity : DirtLevel = 12 [%];

        port readings : SensorPort;

        action senseEnvironment {
            out item reading : SensorReading;
        }

        action detectObstacle {
            out attribute obstacleDistance : Distance;
        }

        action detectCliff {
            out attribute cliffDetected : Boolean;
        }

        action detectDirt {
            out attribute dirtLevel : DirtLevel;
        }
    }

    part def NavigationController {
        attribute mappedArea : Area;
        attribute cleanedArea : Area;
        attribute currentCoverage : Percent;
        attribute targetCoverage : Percent = 95 [%];

        port sensorIn : SensorPort;
        port motionOut : ActuatorPort;

        action planCleaningPath {
            in item surface : FloorSurface;
            out item motion : MotionCommand;
        }

        action avoidObstacle {
            in item reading : SensorReading;
            out item evasiveMotion : MotionCommand;
        }

        action seekDock {
            in item dockSignal : DockingSignal;
            out item dockingMotion : MotionCommand;
        }

        action updateCoverage {
            in attribute newAreaCleaned : Area;
            out attribute totalCleanedArea : Area;
        }
    }

    part def CleaningController {
        attribute activeCommand : CleaningCommand;
        attribute missionElapsedTime : Duration;
        attribute missionComplete : Boolean;

        port commandIn : CommandPort;
        port statusOut : StatusPort;

        action startCleaning {
            in item command : CleaningCommand;
        }

        action pauseCleaning;

        action resumeCleaning;

        action completeMission;

        action reportStatus {
            out attribute batteryCharge : BatteryCharge;
            out attribute cleanedArea : Area;
            out attribute binFillLevel : Percent;
            out attribute state : String;
        }
    }

    part def Roomba {
        attribute primaryFunction : String = "Autonomously clean floor surfaces by navigating through a room, detecting dirt and obstacles, collecting debris with brushes and suction, storing debris in an internal bin, and returning to a docking station for charging.";
        attribute maximumCleaningArea : Area = 120 [m^2];
        attribute nominalRuntime : Duration = 5400 [s];

        port userCommand : CommandPort;
        port status : StatusPort;
        port debrisIntake : DebrisIntakePort;
        port dockCharge : ChargingPort;

        part battery : Battery;
        part dock : DockingStation;
        part drive : DriveSystem;
        part vacuum : VacuumMotor;
        part brushes : BrushAssembly;
        part bin : DustBin;
        part sensors : SensorSuite;
        part navigation : NavigationController;
        part controller : CleaningController;

        connect battery.powerOut to drive.commandIn;
        connect battery.powerOut to vacuum;
        connect battery.powerOut to brushes;
        connect dock.charger to battery.chargeIn;
        connect dock.charger to dockCharge;
        connect sensors.readings to navigation.sensorIn;
        connect navigation.motionOut to drive.commandIn;
        connect userCommand to controller.commandIn;
        connect controller.statusOut to status;
        connect debrisIntake to bin.debrisIn;

        action cleanFloor {
            in item command : CleaningCommand;
            in item targetSurface : FloorSurface;
            out attribute cleanedArea : Area;
            out attribute finalDirtLevel : DirtLevel;

            first start;
            then controller.startCleaning(command);
            then sensors.senseEnvironment;
            then navigation.planCleaningPath(targetSurface);
            then brushes.agitateFloor(targetSurface);
            then vacuum.generateSuction;
            then bin.storeDebris;
            then navigation.updateCoverage;
            then controller.reportStatus;
            then done;
        }

        state def OperatingState {
            state Off;
            state Docked;
            state Charging;
            state Ready;
            state Cleaning;
            state SpotCleaning;
            state AvoidingObstacle;
            state ReturningToDock;
            state BinFull;
            state Error;

            initial then Off;

            transition Off_to_Docked
                first Off
                accept powerButtonPressed
                then Docked;

            transition Docked_to_Charging
                first Docked
                if battery.chargeLevel < 100 [%]
                then Charging;

            transition Charging_to_Ready
                first Charging
                if battery.chargeLevel >= 95 [%]
                then Ready;

            transition Ready_to_Cleaning
                first Ready
                accept CleaningCommand
                if battery.chargeLevel > battery.lowChargeThreshold
                then Cleaning;

            transition Cleaning_to_AvoidingObstacle
                first Cleaning
                if sensors.detectObstacle.obstacleDistance < 0.20 [m] or sensors.detectCliff.cliffDetected == true
                then AvoidingObstacle;

            transition AvoidingObstacle_to_Cleaning
                first AvoidingObstacle
                after 3 [s]
                then Cleaning;

            transition Cleaning_to_SpotCleaning
                first Cleaning
                if sensors.detectDirt.dirtLevel > 65 [%]
                then SpotCleaning;

            transition SpotCleaning_to_Cleaning
                first SpotCleaning
                after 30 [s]
                then Cleaning;

            transition Cleaning_to_BinFull
                first Cleaning
                if bin.fillLevel >= 95 [%]
                then BinFull;

            transition Cleaning_to_ReturningToDock_LowBattery
                first Cleaning
                if battery.chargeLevel <= battery.lowChargeThreshold
                then ReturningToDock;

            transition Cleaning_to_ReturningToDock_Complete
                first Cleaning
                if navigation.currentCoverage >= navigation.targetCoverage
                then ReturningToDock;

            transition BinFull_to_ReturningToDock
                first BinFull
                then ReturningToDock;

            transition ReturningToDock_to_Docked
                first ReturningToDock
                if dock.docked == true
                then Docked;

            transition Any_to_Error
                first Cleaning
                if battery.chargeLevel <= battery.criticalChargeThreshold
                then Error;
        }

        requirement def PrimaryCleaningFunction {
            doc
            /*
             The Roomba shall autonomously clean a bounded indoor floor area by navigating through the space, loosening debris with brushes, collecting debris using suction, storing collected debris in an internal dust bin, avoiding obstacles and cliffs, monitoring battery charge, and returning to its docking station when cleaning is complete or when charge is low.
            */

            require constraint {
                navigation.currentCoverage >= navigation.targetCoverage or battery.chargeLevel <= battery.lowChargeThreshold
            }
        }

        requirement def ObstacleAvoidanceRequirement {
            doc
            /*
             The Roomba shall detect obstacles within 0.75 m and command evasive motion before contact when an obstacle is detected within 0.20 m.
            */

            require constraint {
                sensors.obstacleDetectionRange >= 0.75 [m]
            }
        }

        requirement def BatteryReturnRequirement {
            doc
            /*
             The Roomba shall stop normal cleaning and return to the docking station when battery charge is at or below 18 percent.
            */

            require constraint {
                battery.lowChargeThreshold == 18 [%]
            }
        }

        requirement def DustStorageRequirement {
            doc
            /*
             The Roomba shall store collected debris in an onboard dust bin with at least 450 g capacity and shall report a bin-full condition when fill level reaches 95 percent.
            */

            require constraint {
                bin.capacity >= 450 [g] and bin.fillLevel <= 100 [%]
            }
        }

        requirement def CoverageRequirement {
            doc
            /*
             During a normal cleaning mission, the Roomba shall attempt to clean at least 95 percent of the mapped reachable floor area before returning to dock, unless interrupted by low battery, full bin, or fault condition.
            */

            require constraint {
                navigation.targetCoverage == 95 [%]
            }
        }

        satisfy PrimaryCleaningFunction by Roomba;
        satisfy ObstacleAvoidanceRequirement by sensors;
        satisfy BatteryReturnRequirement by battery;
        satisfy DustStorageRequirement by bin;
        satisfy CoverageRequirement by navigation;
    }
}