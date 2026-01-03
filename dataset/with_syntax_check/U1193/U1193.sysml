package RoboticVacuumCleanerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def BatteryChargeLevel :> Real;
    attribute def DustLevel :> Real;
    attribute def DistanceValue :> LengthValue;
    attribute def RotationSpeed :> Real;
    
    enum def OperatingMode {
        automatic;
        spot;
        edge;
        manual;
    }
    
    enum def SurfaceType {
        hardFloor;
        carpet;
        tile;
        mixed;
    }
    
    item def DustParticle;
    item def Debris;
    item def ObstacleObject;
    item def ElectricalPower;
    
    port def PowerPort {
        inout power : ElectricalPower;
    }
    
    port def SensorDataPort {
        out obstacleDistance : DistanceValue;
        out surfaceType : SurfaceType;
        out dirtLevel : DustLevel;
    }
    
    port def MotorControlPort {
        in speed : Real;
        in direction : Real;
    }
    
    port def DustIntakePort {
        in dust : DustParticle;
        in debris : Debris;
    }
    
    part def LithiumBattery {
        attribute capacity : Real = 5000.0;
        attribute voltage : Real = 14.4;
        attribute chargeLevel : BatteryChargeLevel = 100.0;
        attribute chargingRate : Real = 2.0;
        port powerOut : PowerPort;
    }
    
    part def SuctionFan {
        attribute maxPower : PowerValue = 40.0 [W];
        attribute currentPower : PowerValue;
        attribute airflowRate : Real = 15.0;
        port powerIn : PowerPort;
        port dustIntake : DustIntakePort;
    }
    
    part def RotatingBrush {
        attribute rotationSpeed : RotationSpeed = 250.0;
        attribute brushWidth : LengthValue = 200.0 [mm];
        attribute bristleLength : LengthValue = 15.0 [mm];
        port powerIn : PowerPort;
    }
    
    part def SideBrush {
        attribute rotationSpeed : RotationSpeed = 180.0;
        attribute diameter : LengthValue = 80.0 [mm];
        port powerIn : PowerPort;
    }
    
    part def DustContainer {
        attribute maxCapacity : VolumeValue = 0.6 [L];
        attribute currentLevel : DustLevel = 0.0;
        attribute filterEfficiency : Real = 99.5;
        port dustIn : DustIntakePort;
    }
    
    part def InfraredSensor {
        attribute detectionRange : DistanceValue = 30.0 [cm];
        attribute scanAngle : Real = 180.0;
        port dataOut : SensorDataPort;
        port powerIn : PowerPort;
    }
    
    part def BumperSensor {
        attribute sensitivity : Real = 0.5;
        attribute responseTime : Real = 0.05;
        port dataOut : SensorDataPort;
        port powerIn : PowerPort;
    }
    
    part def CliffSensor {
        attribute detectionDepth : DistanceValue = 8.0 [cm];
        port dataOut : SensorDataPort;
        port powerIn : PowerPort;
    }
    
    part def DirtDetectionSensor {
        attribute sensitivity : Real = 0.8;
        port dataOut : SensorDataPort;
        port powerIn : PowerPort;
    }
    
    part def DriveWheel {
        attribute diameter : LengthValue = 65.0 [mm];
        attribute maxSpeed : Real = 0.35;
        attribute currentSpeed : Real;
        port motorControl : MotorControlPort;
        port powerIn : PowerPort;
    }
    
    part def NavigationController {
        attribute processingPower : PowerValue = 5.0 [W];
        attribute mappingResolution : LengthValue = 5.0 [cm];
        port sensorInput : SensorDataPort;
        port motorOutput : MotorControlPort;
        port powerIn : PowerPort;
    }
    
    part def ChargingDock {
        attribute outputVoltage : Real = 16.8;
        attribute outputCurrent : Real = 1.8;
        attribute chargingEfficiency : Real = 92.0;
        port powerSupply : PowerPort;
    }
    
    action def MonitorBatteryLevel {
        out batteryLevel : BatteryChargeLevel;
    }
    
    action def ScanEnvironment {
        out obstacleDetected : Boolean;
        out obstacleDistance : DistanceValue;
        out cliffDetected : Boolean;
    }
    
    action def DetectDirt {
        out dirtPresent : Boolean;
        out dirtConcentration : DustLevel;
    }
    
    action def PlanPath {
        in obstacleInfo : DistanceValue;
        in currentPosition : Real[2];
        out targetDirection : Real;
        out targetSpeed : Real;
    }
    
    action def ActivateCleaning {
        in suctionPower : Real;
        in brushSpeed : Real;
    }
    
    action def NavigateToPosition {
        in targetDirection : Real;
        in speed : Real;
    }
    
    action def AvoidObstacle {
        in obstacleDistance : DistanceValue;
        out newDirection : Real;
    }
    
    action def ReturnToChargingDock {
        in currentBatteryLevel : BatteryChargeLevel;
    }
    
    action def ChargeBattery {
        in currentCharge : BatteryChargeLevel;
        out newCharge : BatteryChargeLevel;
    }
    
    state def VacuumOperationalStates {
        entry; then idleState;
        
        state idleState {
            doc /* Vacuum is docked and fully charged, awaiting start command. */
        }
        
        transition idleToActive
            first idleState
            accept startCommand : Boolean
            if startCommand
            then activeCleaningState;
        
        state activeCleaningState {
            entry; then navigationMode;
            
            state navigationMode {
                doc /* Vacuum navigates room using systematic pattern. */
            }
            
            transition navToSpot
                first navigationMode
                accept heavyDirtDetected : Boolean
                if heavyDirtDetected
                then spotCleaningMode;
            
            state spotCleaningMode {
                doc /* Intensive cleaning of concentrated dirt area. */
            }
            
            transition spotToNav
                first spotCleaningMode
                accept areaClean : Boolean
                if areaClean
                then navigationMode;
            
            transition navToAvoid
                first navigationMode
                accept obstacleDetected : Boolean
                if obstacleDetected
                then obstacleAvoidanceMode;
            
            state obstacleAvoidanceMode {
                doc /* Vacuum maneuvers around detected obstacle. */
            }
            
            transition avoidToNav
                first obstacleAvoidanceMode
                accept obstacleClear : Boolean
                if obstacleClear
                then navigationMode;
        }
        
        transition activeToReturning
            first activeCleaningState
            accept lowBattery : Boolean
            if lowBattery
            then returningToDockState;
        
        state returningToDockState {
            doc /* Vacuum navigates back to charging dock. */
        }
        
        transition returningToCharging
            first returningToDockState
            accept dockReached : Boolean
            if dockReached
            then chargingState;
        
        state chargingState {
            doc /* Vacuum is connected to dock and recharging battery. */
        }
        
        transition chargingToIdle
            first chargingState
            accept fullyCharged : Boolean
            if fullyCharged
            then idleState;
    }
    
    action def AutonomousCleaningOperation {
        first start;
        then merge operationLoop;
        
        action checkBattery : MonitorBatteryLevel {
            out currentBatteryLevel : BatteryChargeLevel;
        }
        
        then decide batteryDecision;
            if checkBattery.currentBatteryLevel < 15.0 then initiateReturn;
            if checkBattery.currentBatteryLevel >= 15.0 then continueCleaningSequence;
        
        action continueCleaningSequence {
            first scanArea;
            
            action scanArea : ScanEnvironment {
                out obstacleDetected : Boolean;
                out obstacleDistance : DistanceValue;
                out cliffDetected : Boolean;
            }
            
            then decide safetyCheck;
                if scanArea.cliffDetected then executeAvoidance;
                if scanArea.obstacleDetected and scanArea.obstacleDistance < 10.0 [cm] then executeAvoidance;
                if !scanArea.cliffDetected and (!scanArea.obstacleDetected or scanArea.obstacleDistance >= 10.0 [cm]) then checkForDirt;
            
            action executeAvoidance : AvoidObstacle {
                in obstacleDistance = scanArea.obstacleDistance;
                out newDirection : Real;
            }
            then planNewPath;
            
            action checkForDirt : DetectDirt {
                out dirtPresent : Boolean;
                out dirtConcentration : DustLevel;
            }
            
            then decide dirtDecision;
                if checkForDirt.dirtPresent and checkForDirt.dirtConcentration > 5.0 then intensiveClean;
                if !checkForDirt.dirtPresent or checkForDirt.dirtConcentration <= 5.0 then normalClean;
            
            action intensiveClean : ActivateCleaning {
                in suctionPower = 100.0;
                in brushSpeed = 300.0;
            }
            then planNewPath;
            
            action normalClean : ActivateCleaning {
                in suctionPower = 70.0;
                in brushSpeed = 250.0;
            }
            then planNewPath;
            
            action planNewPath : PlanPath {
                in obstacleInfo = scanArea.obstacleDistance;
                in currentPosition = (0.0, 0.0);
                out targetDirection : Real;
                out targetSpeed : Real;
            }
            
            then navigateAction;
            
            action navigateAction : NavigateToPosition {
                in targetDirection = planNewPath.targetDirection;
                in speed = planNewPath.targetSpeed;
            }
        }
        then operationLoop;
        
        action initiateReturn : ReturnToChargingDock {
            in currentBatteryLevel = checkBattery.currentBatteryLevel;
        }
        
        then chargeAction;
        
        action chargeAction : ChargeBattery {
            in currentCharge = checkBattery.currentBatteryLevel;
            out newCharge : BatteryChargeLevel;
        }
        
        then decide chargeComplete;
            if chargeAction.newCharge >= 100.0 then done;
            if chargeAction.newCharge < 100.0 then chargeAction;
    }
    
    part def RoboticVacuumCleaner {
        doc /* Autonomous floor cleaning robot with navigation and obstacle avoidance. */
        
        attribute totalMass : MassValue = 3.2 [kg];
        attribute diameter : LengthValue = 340.0 [mm];
        attribute height : LengthValue = 92.0 [mm];
        attribute operatingMode : OperatingMode = OperatingMode::automatic;
        attribute cleaningEfficiency : Real = 96.5;
        attribute noiseLevel : Real = 62.0;
        
        part battery : LithiumBattery {
            attribute :>> capacity = 5200.0;
            attribute :>> chargeLevel = 100.0;
        }
        
        part mainSuction : SuctionFan {
            attribute :>> currentPower = 35.0 [W];
        }
        
        part mainBrush : RotatingBrush {
            attribute :>> rotationSpeed = 250.0;
        }
        
        part leftSideBrush : SideBrush {
            attribute :>> rotationSpeed = 180.0;
        }
        
        part rightSideBrush : SideBrush {
            attribute :>> rotationSpeed = 180.0;
        }
        
        part dustBin : DustContainer {
            attribute :>> maxCapacity = 0.6 [L];
            attribute :>> currentLevel = 0.0;
        }
        
        part frontIRSensor : InfraredSensor {
            attribute :>> detectionRange = 30.0 [cm];
        }
        
        part leftIRSensor : InfraredSensor {
            attribute :>> detectionRange = 25.0 [cm];
        }
        
        part rightIRSensor : InfraredSensor {
            attribute :>> detectionRange = 25.0 [cm];
        }
        
        part bumper : BumperSensor {
            attribute :>> sensitivity = 0.5;
        }
        
        part cliffSensors : CliffSensor[4] {
            attribute :>> detectionDepth = 8.0 [cm];
        }
        
        part dirtSensor : DirtDetectionSensor {
            attribute :>> sensitivity = 0.8;
        }
        
        part leftWheel : DriveWheel {
            attribute :>> maxSpeed = 0.35;
        }
        
        part rightWheel : DriveWheel {
            attribute :>> maxSpeed = 0.35;
        }
        
        part navigationUnit : NavigationController {
            attribute :>> processingPower = 5.0 [W];
        }
        
        connection batteryToSuction connect battery.powerOut to mainSuction.powerIn;
        connection batteryToBrush connect battery.powerOut to mainBrush.powerIn;
        connection batteryToSideBrushes connect battery.powerOut to leftSideBrush.powerIn;
        connection batteryToNavigation connect battery.powerOut to navigationUnit.powerIn;
        connection batteryToWheels connect battery.powerOut to leftWheel.powerIn;
        connection batteryToSensors connect battery.powerOut to frontIRSensor.powerIn;
        
        connection sensorsToController connect frontIRSensor.dataOut to navigationUnit.sensorInput;
        connection controllerToWheels connect navigationUnit.motorOutput to leftWheel.motorControl;
        
        connection suctionToDustBin connect mainSuction.dustIntake to dustBin.dustIn;
        
        perform action cleaning[*] ordered references AutonomousCleaningOperation;
    }
    
    part dockingStation : ChargingDock {
        attribute :>> outputVoltage = 16.8;
        attribute :>> outputCurrent = 1.8;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The robotic vacuum cleaner shall autonomously navigate and clean 
             * floor surfaces by removing dust, dirt, and debris without human 
             * intervention during operation.
             */
        subject vacuum : RoboticVacuumCleaner;
    }
    
    requirement <'RVC-REQ-001'> autonomousOperation : PrimaryFunctionRequirement {
        subject vacuum :>> vacuumSystem;
    }
    
    requirement <'RVC-REQ-002'> batteryRuntime {
        doc /* The vacuum shall operate continuously for at least 90 minutes 
             * on a full charge under normal cleaning conditions.
             */
        subject battery :>> vacuumSystem.battery;
        assert constraint {
            battery.capacity >= 5000.0
        }
    }
    
    requirement <'RVC-REQ-003'> obstacleDetection {
        doc /* The vacuum shall detect obstacles within 30 cm and avoid 
             * collisions during navigation.
             */
        subject sensor :>> vacuumSystem.frontIRSensor;
        assert constraint {
            sensor.detectionRange >= 30.0 [cm]
        }
    }
    
    requirement <'RVC-REQ-004'> cliffPrevention {
        doc /* The vacuum shall detect drops greater than 8 cm and prevent 
             * falling from stairs or ledges.
             */
        subject sensors :>> vacuumSystem.cliffSensors;
        assert constraint {
            sensors.detectionDepth >= 8.0 [cm]
        }
    }
    
    requirement <'RVC-REQ-005'> suctionCapability {
        doc /* The suction system shall provide at least 35 W of cleaning power 
             * to effectively remove dirt from various floor surfaces.
             */
        subject suction :>> vacuumSystem.mainSuction;
        assert constraint {
            suction.currentPower >= 35.0 [W]
        }
    }
    
    requirement <'RVC-REQ-006'> dustCapacity {
        doc /* The dust container shall hold at least 0.5 liters of debris 
             * before requiring emptying.
             */
        subject dustbin :>> vacuumSystem.dustBin;
        assert constraint {
            dustbin.maxCapacity >= 0.5 [L]
        }
    }
    
    requirement <'RVC-REQ-007'> automaticRecharging {
        doc /* The vacuum shall automatically return to its charging dock when 
             * battery level drops below 15% and resume cleaning after recharging.
             */
        subject vacuum :>> vacuumSystem;
    }
    
    requirement <'RVC-REQ-008'> cleaningEfficiency {
        doc /* The vacuum shall achieve at least 95% cleaning efficiency on 
             * hard floors and low-pile carpets.
             */
        subject vacuum :>> vacuumSystem;
        assert constraint {
            vacuum.cleaningEfficiency >= 95.0
        }
    }
    
    part vacuumSystem : RoboticVacuumCleaner {
        attribute :>> operatingMode = OperatingMode::automatic;
        attribute :>> cleaningEfficiency = 96.5;
        
        part :>> battery {
            attribute :>> chargeLevel = 100.0;
        }
        
        part :>> mainSuction {
            attribute :>> currentPower = 38.0 [W];
        }
        
        part :>> dustBin {
            attribute :>> maxCapacity = 0.6 [L];
        }
        
        part :>> frontIRSensor {
            attribute :>> detectionRange = 32.0 [cm];
        }
    }
    
    satisfy autonomousOperation by vacuumSystem;
    satisfy batteryRuntime by vacuumSystem.battery;
    satisfy obstacleDetection by vacuumSystem.frontIRSensor;
    satisfy cliffPrevention by vacuumSystem.cliffSensors;
    satisfy suctionCapability by vacuumSystem.mainSuction;
    satisfy dustCapacity by vacuumSystem.dustBin;
    satisfy automaticRecharging by vacuumSystem;
    satisfy cleaningEfficiency by vacuumSystem;
}
