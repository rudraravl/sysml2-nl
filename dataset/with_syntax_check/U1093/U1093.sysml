package IRobotCleaningSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def BatteryPercentage :> Real;
    attribute def DustCapacityPercentage :> Real;
    attribute def CleaningEfficiency :> Real;
    
    enum def OperatingMode {
        standby;
        cleaning;
        returning;
        docked;
        error;
    }
    
    enum def FloorType {
        hardwood;
        carpet;
        tile;
        mixed;
    }
    
    item def DustParticle {
        attribute size : LengthValue;
        attribute mass : MassValue;
    }
    
    item def CleaningZone {
        attribute area : AreaValue;
        attribute floorType : FloorType;
        attribute dustDensity : Real;
    }
    
    attribute def ElectricPowerValue :> PowerValue;
    attribute def RotationalSpeedValue :> Real;
    attribute def SuctionForceValue :> ForceValue;
    
    port def PowerPort {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }
    
    port def DataPort {
        attribute signalRate : FrequencyValue;
    }
    
    port def DockingPort {
        attribute aligned : Boolean;
        attribute contactMade : Boolean;
    }
    
    part def BatteryModule {
        attribute capacity : EnergyValue;
        attribute currentCharge : EnergyValue;
        attribute chargeLevel : BatteryPercentage;
        attribute voltage : ElectricPotentialValue;
        
        port output : PowerPort;
        port chargeInput : PowerPort;
        
        assert constraint validCharge {
            currentCharge >= 0.0 [W*h] and currentCharge <= capacity
        }
        
        assert constraint chargeLevelConsistency {
            chargeLevel == (currentCharge / capacity) * 100.0
        }
    }
    
    part def DustContainer {
        attribute maxCapacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute fillLevel : DustCapacityPercentage;
        attribute isFull : Boolean;
        
        assert constraint volumeLimit {
            currentVolume <= maxCapacity
        }
        
        assert constraint fullIndicator {
            isFull == (fillLevel >= 95.0)
        }
    }
    
    part def NavigationSystem {
        attribute currentPosition : LengthValue[2];
        attribute heading : Real;
        attribute obstacleDistance : LengthValue;
        
        port sensorData : DataPort;
        port motorControl : DataPort;
        
        part infraredSensors[8] {
            attribute range : LengthValue;
            attribute detectionAngle : Real;
        }
        
        part bumpSensors[4] {
            attribute activated : Boolean;
        }
        
        part cliffSensors[4] {
            attribute dropDetected : Boolean;
        }
    }
    
    part def CleaningMechanism {
        attribute brushSpeed : RotationalSpeedValue;
        attribute vacuumPower : ElectricPowerValue;
        attribute suctionForce : SuctionForceValue;
        
        port power : PowerPort;
        
        part mainBrush {
            attribute diameter : LengthValue;
            attribute length : LengthValue;
            attribute rpm : RotationalSpeedValue;
        }
        
        part sideBrushes[2] {
            attribute diameter : LengthValue;
            attribute rpm : RotationalSpeedValue;
        }
        
        part vacuumMotor {
            attribute powerRating : ElectricPowerValue;
            attribute airflow : VolumeValue;
        }
    }
    
    part def DriveSystem {
        attribute leftWheelSpeed : Real;
        attribute rightWheelSpeed : Real;
        attribute maxSpeed : Real;
        
        port power : PowerPort;
        port control : DataPort;
        
        part leftWheel {
            attribute diameter : LengthValue;
            attribute speed : Real;
        }
        
        part rightWheel {
            attribute diameter : LengthValue;
            attribute speed : Real;
        }
        
        part casterWheel {
            attribute diameter : LengthValue;
        }
    }
    
    part def ChargingStation {
        attribute outputVoltage : ElectricPotentialValue;
        attribute outputCurrent : ElectricCurrentValue;
        attribute position : LengthValue[2];
        attribute isActive : Boolean;
        
        port chargingPort : PowerPort;
        port dockingInterface : DockingPort;
        
        part beaconEmitter {
            attribute signalStrength : Real;
            attribute frequency : FrequencyValue;
        }
    }
    
    part def ControlProcessor {
        attribute mode : OperatingMode;
        attribute cleaningTime : TimeValue;
        attribute areaCleaned : AreaValue;
        
        port mainPower : PowerPort;
        port navigationInterface : DataPort;
        port cleaningInterface : DataPort;
        port driveInterface : DataPort;
    }
    
    action def ScanEnvironment {
        in currentPos : LengthValue[2];
        out obstacles : Boolean[*];
        out cliffDetected : Boolean;
        out wallDistance : LengthValue;
    }
    
    action def CalculateNavigationPath {
        in obstacles : Boolean[*];
        in targetPos : LengthValue[2];
        in currentPos : LengthValue[2];
        out leftSpeed : Real;
        out rightSpeed : Real;
    }
    
    action def ActivateCleaningSystem {
        in floorType : FloorType;
        in dustLevel : Real;
        out brushSpeed : RotationalSpeedValue;
        out vacuumPower : ElectricPowerValue;
    }
    
    action def MonitorBatteryStatus {
        in chargeLevel : BatteryPercentage;
        out needsCharging : Boolean;
        out canContinue : Boolean;
    }
    
    action def NavigateToDock {
        in dockPosition : LengthValue[2];
        in currentPosition : LengthValue[2];
        out driveCommands : Real[2];
        out dockingAlignment : Boolean;
    }
    
    action def PerformCharging {
        in currentCharge : EnergyValue;
        in chargingRate : ElectricPowerValue;
        out updatedCharge : EnergyValue;
        out chargingComplete : Boolean;
    }
    
    action def CheckDustBin {
        in fillLevel : DustCapacityPercentage;
        out binFull : Boolean;
        out canContinueCleaning : Boolean;
    }
    
    action def ExecuteCleaningCycle;
    action def NavigateToBase;
    action def ChargeBattery;
    
    state def RobotOperationalStates {
        entry; then standbyState;
        
        state standbyState;
        
        state cleaningState {
            do action executeCleaningCycle : ExecuteCleaningCycle;
            
            state normalCleaning;
            state intensiveCleaning;
            state edgeCleaning;
            
            transition normalToIntensive
                first normalCleaning
                accept highDustDetected
                then intensiveCleaning;
            
            transition intensiveToNormal
                first intensiveCleaning
                accept lowDustDetected
                then normalCleaning;
            
            transition normalToEdge
                first normalCleaning
                accept wallDetected
                then edgeCleaning;
        }
        
        state returningState {
            do action navigateToBase : NavigateToBase;
        }
        
        state dockedState {
            do action chargeBattery : ChargeBattery;
        }
        
        state errorState;
        
        transition standbyToCleaning
            first standbyState
            accept startCleaningCommand
            then cleaningState;
        
        transition cleaningToReturning
            first cleaningState
            accept lowBatteryAlert
            then returningState;
        
        transition cleaningToStandby
            first cleaningState
            accept missionComplete
            then returningState;
        
        transition returningToDocked
            first returningState
            accept dockingComplete
            then dockedState;
        
        transition dockedToStandby
            first dockedState
            accept chargingComplete
            then standbyState;
        
        transition anyToError
            first standbyState
            accept systemFault
            then errorState;
    }
    
    action def AutonomousCleaningMission {
        first start;
        then merge cycleStart;
        
        then action initialize {
            out systemReady : Boolean;
            out initialPosition : LengthValue[2];
        }
        
        then action scanArea : ScanEnvironment {
            in currentPos = initialize.initialPosition;
            out obstacles;
            out cliffDetected;
            out wallDistance;
        }
        
        then decide;
            if scanArea.cliffDetected then avoidCliff;
            else if scanArea.wallDistance < 0.1 [m] then followWall;
            else proceedCleaning;
        
        action avoidCliff : CalculateNavigationPath {
            in obstacles = scanArea.obstacles;
            in targetPos;
            in currentPos;
            out leftSpeed;
            out rightSpeed;
        }
        then proceedCleaning;
        
        action followWall : CalculateNavigationPath {
            in obstacles = scanArea.obstacles;
            in targetPos;
            in currentPos;
            out leftSpeed;
            out rightSpeed;
        }
        then proceedCleaning;
        
        action proceedCleaning : ActivateCleaningSystem {
            in floorType;
            in dustLevel;
            out brushSpeed;
            out vacuumPower;
        }
        
        then action checkBattery : MonitorBatteryStatus {
            in chargeLevel;
            out needsCharging;
            out canContinue;
        }
        
        then decide;
            if checkBattery.needsCharging then initiateReturn;
            else checkDustStatus;
        
        action checkDustStatus : CheckDustBin {
            in fillLevel;
            out binFull;
            out canContinueCleaning;
        }
        
        then decide;
            if checkDustStatus.binFull then initiateReturn;
            else evaluateCoverage;
        
        action evaluateCoverage {
            in areaCleaned : AreaValue;
            in totalArea : AreaValue;
            out missionComplete : Boolean;
        }
        
        then decide;
            if evaluateCoverage.missionComplete then initiateReturn;
            else cycleStart;
        
        action initiateReturn : NavigateToDock {
            in dockPosition;
            in currentPosition;
            out driveCommands;
            out dockingAlignment;
        }
        
        then action performDocking {
            in aligned : Boolean;
            out docked : Boolean;
        }
        
        then action chargeRobot : PerformCharging {
            in currentCharge;
            in chargingRate;
            out updatedCharge;
            out chargingComplete;
        }
        
        then done;
    }
    
    part def IRobotVacuum {
        attribute serialNumber : String;
        attribute firmwareVersion : String;
        attribute operatingMode : OperatingMode;
        attribute currentLocation : LengthValue[2];
        attribute totalAreaCleaned : AreaValue;
        attribute totalRuntime : TimeValue;
        
        part battery : BatteryModule {
            attribute :>> capacity = 3600.0 [W*h];
            attribute :>> currentCharge = 3600.0 [W*h];
            attribute :>> chargeLevel = 100.0;
            attribute :>> voltage = 14.4 [V];
        }
        
        part dustBin : DustContainer {
            attribute :>> maxCapacity = 0.7 [L];
            attribute :>> currentVolume = 0.0 [L];
            attribute :>> fillLevel = 0.0;
            attribute :>> isFull = false;
        }
        
        part navigation : NavigationSystem {
            attribute :>> currentPosition = (0.0 [m], 0.0 [m]);
            attribute :>> heading = 0.0;
            attribute :>> obstacleDistance = 1.0 [m];
            
            part :>> infraredSensors {
                attribute :>> range = 0.5 [m];
                attribute :>> detectionAngle = 45.0;
            }
        }
        
        part cleaning : CleaningMechanism {
            attribute :>> brushSpeed = 1500.0;
            attribute :>> vacuumPower = 55.0 [W];
            attribute :>> suctionForce = 20.0 [N];
            
            part :>> mainBrush {
                attribute :>> diameter = 0.05 [m];
                attribute :>> length = 0.2 [m];
                attribute :>> rpm = 1500.0;
            }
            
            part :>> sideBrushes {
                attribute :>> diameter = 0.08 [m];
                attribute :>> rpm = 2000.0;
            }
            
            part :>> vacuumMotor {
                attribute :>> powerRating = 55.0 [W];
                attribute :>> airflow = 0.015 [m^3];
            }
        }
        
        part drive : DriveSystem {
            attribute :>> leftWheelSpeed = 0.0;
            attribute :>> rightWheelSpeed = 0.0;
            attribute :>> maxSpeed = 0.3;
            
            part :>> leftWheel {
                attribute :>> diameter = 0.072 [m];
                attribute :>> speed = 0.0;
            }
            
            part :>> rightWheel {
                attribute :>> diameter = 0.072 [m];
                attribute :>> speed = 0.0;
            }
            
            part :>> casterWheel {
                attribute :>> diameter = 0.025 [m];
            }
        }
        
        part controller : ControlProcessor {
            attribute :>> mode = OperatingMode::standby;
            attribute :>> cleaningTime = 0.0 [s];
            attribute :>> areaCleaned = 0.0 [m^2];
        }
        
        port mainPowerBus : PowerPort;
        port chargingPort : PowerPort;
        port dockingInterface : DockingPort;
        
        perform action cleaningMission : AutonomousCleaningMission;
        
        exhibit state operationStates : RobotOperationalStates;
        
        assert constraint batteryIntegrity {
            battery.currentCharge >= 0.0 [W*h] and 
            battery.currentCharge <= battery.capacity
        }
        
        assert constraint dustBinIntegrity {
            dustBin.currentVolume <= dustBin.maxCapacity
        }
        
        assert constraint safeOperation {
            operatingMode != OperatingMode::error or 
            battery.chargeLevel > 5.0
        }
    }
    
    part homeBase : ChargingStation {
        attribute :>> outputVoltage = 20.0 [V];
        attribute :>> outputCurrent = 2.0 [A];
        attribute :>> position = (5.0 [m], 5.0 [m]);
        attribute :>> isActive = true;
        
        part :>> beaconEmitter {
            attribute :>> signalStrength = 0.8;
            attribute :>> frequency = 38.0 [kHz];
        }
    }
    
    part serviceArea : CleaningZone {
        attribute :>> area = 75.0 [m^2];
        attribute :>> floorType = FloorType::mixed;
        attribute :>> dustDensity = 0.5;
    }
    
    part robotSystem : IRobotVacuum {
        attribute :>> serialNumber = "IROBOT-RV-2024-7891";
        attribute :>> firmwareVersion = "v3.2.8";
        attribute :>> operatingMode = OperatingMode::standby;
        attribute :>> currentLocation = (0.0 [m], 0.0 [m]);
        attribute :>> totalAreaCleaned = 0.0 [m^2];
        attribute :>> totalRuntime = 0.0 [min];
    }
    
    connection batteryToMain connect robotSystem.battery.output to robotSystem.mainPowerBus;
    connection mainToCleaning connect robotSystem.mainPowerBus to robotSystem.cleaning.power;
    connection mainToDrive connect robotSystem.mainPowerBus to robotSystem.drive.power;
    connection mainToController connect robotSystem.mainPowerBus to robotSystem.controller.mainPower;
    connection navToController connect robotSystem.navigation.motorControl to robotSystem.controller.navigationInterface;
    connection cleanToController connect robotSystem.cleaning.power to robotSystem.controller.cleaningInterface;
    connection driveToController connect robotSystem.drive.control to robotSystem.controller.driveInterface;
    connection dockToRobot connect homeBase.chargingPort to robotSystem.chargingPort;
    connection dockInterface connect homeBase.dockingInterface to robotSystem.dockingInterface;
    
    requirement <'REQ-100'> primaryMission {
        doc /* The IRobot system shall autonomously navigate and clean floor surfaces 
             * within a designated area, achieving comprehensive coverage while avoiding 
             * obstacles and hazards, and automatically return to its charging station 
             * when battery is depleted or cleaning is complete.
             */
        subject robot :> robotSystem;
        
        require autonomousNavigation;
        require cleaningPerformance;
        require batteryManagement;
        require dockingCapability;
    }
    
    requirement <'REQ-101'> autonomousNavigation {
        doc /* The robot shall navigate autonomously using onboard sensors to detect 
             * and avoid obstacles, walls, and drop-offs without human intervention.
             */
        subject robot :> robotSystem;
        
        assert constraint {
            robot.navigation.infraredSensors->size() >= 6 and
            robot.navigation.bumpSensors->size() >= 4 and
            robot.navigation.cliffSensors->size() >= 4
        }
    }
    
    requirement <'REQ-102'> cleaningPerformance {
        doc /* The robot shall effectively remove dust and debris from floor surfaces 
             * using rotating brushes and vacuum suction with minimum 50W power.
             */
        subject robot :> robotSystem;
        
        assert constraint {
            robot.cleaning.vacuumPower >= 50.0 [W] and
            robot.cleaning.mainBrush.rpm >= 1000.0
        }
    }
    
    requirement <'REQ-103'> batteryManagement {
        doc /* The robot shall monitor battery charge level continuously and initiate 
             * return to charging station when charge falls below 15%.
             */
        subject robot :> robotSystem;
        
        assert constraint {
            robot.battery.chargeLevel > 15.0 or 
            robot.operatingMode == OperatingMode::returning or
            robot.operatingMode == OperatingMode::docked
        }
    }
    
    requirement <'REQ-104'> dockingCapability {
        doc /* The robot shall autonomously locate and dock with its charging station 
             * using beacon signals and alignment sensors.
             */
        subject robot :> robotSystem;
        
        require beaconDetection;
        require alignmentPrecision;
    }
    
    requirement <'REQ-105'> beaconDetection {
        doc /* The robot shall detect charging station beacon signals from at least 
             * 3 meters distance.
             */
        subject robot :> robotSystem;
    }
    
    requirement <'REQ-106'> alignmentPrecision {
        doc /* The robot shall achieve docking alignment within 5mm tolerance.
             */
        subject robot :> robotSystem;
    }
    
    requirement <'REQ-107'> dustCapacity {
        doc /* The dust bin shall have minimum capacity of 0.6 liters and provide 
             * indication when 95% full.
             */
        subject bin :> robotSystem.dustBin;
        
        assert constraint {
            bin.maxCapacity >= 0.6 [L]
        }
    }
    
    requirement <'REQ-108'> operationalDuration {
        doc /* The robot shall operate continuously for at least 90 minutes on a 
             * full battery charge under normal cleaning conditions.
             */
        subject robot :> robotSystem;
        
        assert constraint {
            robot.battery.capacity >= 3000.0 [W*h]
        }
    }
    
    requirement <'REQ-109'> coverageEfficiency {
        doc /* The robot shall achieve at least 90% coverage of accessible floor area 
             * during a complete cleaning mission.
             */
        subject robot :> robotSystem;
        
        assert constraint {
            robot.totalAreaCleaned >= serviceArea.area * 0.90
        }
    }
    
    requirement <'REQ-110'> safetyOperation {
        doc /* The robot shall cease operation and enter error state if battery charge 
             * falls below 5% before reaching charging station.
             */
        subject robot :> robotSystem;
        
        assert constraint {
            robot.battery.chargeLevel >= 5.0 or 
            robot.operatingMode == OperatingMode::error
        }
    }
    
    satisfy primaryMission by robotSystem;
    satisfy autonomousNavigation by robotSystem.navigation;
    satisfy cleaningPerformance by robotSystem.cleaning;
    satisfy batteryManagement by robotSystem.battery;
    satisfy dockingCapability by robotSystem.dockingInterface;
    satisfy dustCapacity by robotSystem.dustBin;
    satisfy operationalDuration by robotSystem.battery;
}
