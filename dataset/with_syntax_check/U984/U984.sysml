package 'Automated Pool Cleaner System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def CleaningCommand;
    attribute def DockCommand;
    attribute def EmergencyStop;
    attribute def ObstacleDetected;
    attribute def WallDetected;
    
    attribute def CleaningCoverage :> Real;
    attribute def FilterLoad :> Real;
    attribute def BatteryCharge :> Real;
    
    item def Debris;
    item def PoolWater;
    item def DirtyWater {
        attribute debrisContent : Debris[*];
        attribute waterContent : PoolWater;
    }
    item def FilteredWater {
        attribute waterContent : PoolWater;
    }
    
    port def WaterInletPort {
        in waterFlow : DirtyWater;
    }
    
    port def WaterOutletPort {
        out waterFlow : FilteredWater;
    }
    
    port def PowerSupplyPort {
        out powerDelivery : PowerValue;
    }
    
    port def ChargingPort {
        in chargingPower : PowerValue;
    }
    
    port def SensorPort {
        out obstacleSignal : ObstacleDetected;
        out wallSignal : WallDetected;
        out depthReading : LengthValue;
    }
    
    part def HydraulicPump {
        attribute flowRate : VolumetricFlowRateValue;
        attribute operatingPressure : PressureValue;
        port powerInput : PowerSupplyPort;
        port waterIn : WaterInletPort;
        port waterOut : WaterOutletPort;
        perform action generateSuction;
    }
    
    part def DebrisFilter {
        attribute filterMeshSize : LengthValue;
        attribute currentLoad : FilterLoad;
        attribute maxCapacity : MassValue;
        port waterInlet : WaterInletPort;
        port waterOutlet : WaterOutletPort;
        perform action captureDebris;
    }
    
    part def NavigationController {
        attribute currentPosition : LengthValue[2];
        attribute cleanedArea : CleaningCoverage;
        attribute totalPoolArea : AreaValue;
        port sensorInput : SensorPort;
        perform action calculatePath;
        perform action updateCoverage;
    }
    
    part def MotorDrive {
        attribute leftWheelSpeed : SpeedValue;
        attribute rightWheelSpeed : SpeedValue;
        attribute brushMotorSpeed : AngularVelocityValue;
        port powerInput : PowerSupplyPort;
        perform action propelCleaner;
        perform action rotateBrush;
    }
    
    part def ProximitySensor {
        attribute detectionRange : LengthValue;
        attribute scanAngle : Real;
        port sensorOutput : SensorPort;
        perform action detectObstacles;
    }
    
    part def BatterySystem {
        attribute capacity : EnergyValue;
        attribute currentCharge : BatteryCharge;
        attribute voltage : VoltageValue;
        port powerOutput : PowerSupplyPort;
        port chargingInput : ChargingPort;
        perform action dischargePower;
        perform action acceptCharge;
    }
    
    part def BrushAssembly {
        attribute brushDiameter : LengthValue;
        attribute rotationSpeed : AngularVelocityValue;
        attribute bristleStiffness : PressureValue;
        perform action scrubSurface;
    }
    
    action def ScanEnvironment {
        in currentLocation : LengthValue[2];
        out obstacleMap : ObstacleDetected[*];
        out wallProximity : LengthValue;
        out depthMeasurement : LengthValue;
    }
    
    action def ComputeNavigationPath {
        in obstacleData : ObstacleDetected[*];
        in wallDistance : LengthValue;
        in coverageMap : CleaningCoverage;
        out targetDirection : Real;
        out targetSpeed : SpeedValue;
    }
    
    action def ActivateHydraulics {
        in suctionLevel : PressureValue;
        in flowTarget : VolumetricFlowRateValue;
        out actualFlow : VolumetricFlowRateValue;
        out debrisCaptured : MassValue;
    }
    
    action def DriveWheels {
        in leftSpeed : SpeedValue;
        in rightSpeed : SpeedValue;
        out distanceTraveled : LengthValue;
        out newPosition : LengthValue[2];
    }
    
    action def MonitorBattery {
        in currentCharge : BatteryCharge;
        in powerConsumption : PowerValue;
        out remainingTime : TimeValue;
        out needsCharging : Boolean;
    }
    
    action def CheckFilterStatus {
        in filterLoad : FilterLoad;
        in maxCapacity : MassValue;
        out filterFull : Boolean;
    }
    
    action def ReturnToDock {
        in currentPosition : LengthValue[2];
        in dockPosition : LengthValue[2];
        out navigationCommands : Real[*];
    }
    
    action def PerformCleaningCycle {
        in poolArea : AreaValue;
        in targetCoverage : CleaningCoverage;
        in maxDuration : TimeValue;
        out actualCoverage : CleaningCoverage;
        out debrisCollected : MassValue;
        
        private attribute coverage : CleaningCoverage := 0.0;
        private attribute elapsedTime : TimeValue := 0.0[SI::s];
        private attribute position : LengthValue[2];
        
        first start;
        then accept startCmd : CleaningCommand;
        then merge cleaningLoop;
        
        then action monitorBattery : MonitorBattery {
            in currentCharge;
            in powerConsumption;
            out remainingTime;
            out needsCharging;
        }
        
        then decide;
            if monitorBattery.needsCharging then returnForCharging;
            if !monitorBattery.needsCharging then continueCleaningCheck;
        
        action continueCleaningCheck {
            then action checkFilter : CheckFilterStatus {
                in filterLoad;
                in maxCapacity;
                out filterFull;
            }
            then decide;
                if checkFilter.filterFull then returnForMaintenance;
                if !checkFilter.filterFull then scanAndNavigate;
        }
        
        action scanAndNavigate {
            then action scan : ScanEnvironment {
                in currentLocation = position;
                out obstacleMap;
                out wallProximity;
                out depthMeasurement;
            }
            then action computePath : ComputeNavigationPath {
                in obstacleData = scan.obstacleMap;
                in wallDistance = scan.wallProximity;
                in coverageMap = coverage;
                out targetDirection;
                out targetSpeed;
            }
            then action drive : DriveWheels {
                in leftSpeed = computePath.targetSpeed;
                in rightSpeed = computePath.targetSpeed;
                out distanceTraveled;
                out newPosition;
            }
            then action activateHydraulics : ActivateHydraulics {
                in suctionLevel = 50000.0[SI::Pa];
                in flowTarget = 0.08[SI::m^3/SI::s];
                out actualFlow;
                out debrisCaptured;
            }
            then assign position := drive.newPosition;
            then assign coverage := coverage + 2.5;
            then assign elapsedTime := elapsedTime + 15.0[SI::s];
            then decide;
                if coverage >= targetCoverage then completeCleaning;
                if elapsedTime >= maxDuration then completeCleaning;
                if coverage < targetCoverage and elapsedTime < maxDuration then cleaningLoop;
        }
        
        action returnForCharging {
            then action navigateToDock : ReturnToDock {
                in currentPosition = position;
                in dockPosition;
                out navigationCommands;
            }
            then accept dockCmd : DockCommand;
            then completeCleaning;
        }
        
        action returnForMaintenance {
            then action navigateToDock : ReturnToDock {
                in currentPosition = position;
                in dockPosition;
                out navigationCommands;
            }
            then completeCleaning;
        }
        
        action completeCleaning {
            then assign actualCoverage := coverage;
            then done;
        }
    }
    
    part def AutomatedPoolCleaner {
        doc /* 
            An autonomous robotic pool cleaner that systematically navigates a swimming pool,
            removing debris through hydraulic suction and mechanical brushing while maintaining
            optimal water circulation and filtration.
        */
        
        port waterIntake : WaterInletPort;
        port waterDischarge : WaterOutletPort;
        port dockingInterface : ChargingPort;
        
        part pump : HydraulicPump;
        part filterUnit : DebrisFilter;
        part navigation : NavigationController;
        part drive : MotorDrive;
        part sensors : ProximitySensor;
        part battery : BatterySystem;
        part brush : BrushAssembly;
        
        perform action cleaningMission[*] ordered;
        
        connect waterIntake to pump.waterIn;
        connect pump.waterOut to filterUnit.waterInlet;
        connect filterUnit.waterOutlet to waterDischarge;
        connect battery.powerOutput to pump.powerInput;
        connect battery.powerOutput to drive.powerInput;
        connect sensors.sensorOutput to navigation.sensorInput;
        connect dockingInterface to battery.chargingInput;
    }
    
    part poolCleaner : AutomatedPoolCleaner {
        perform action mission : PerformCleaningCycle {
            in poolArea = 75.0[SI::m^2];
            in targetCoverage = 98.0;
            in maxDuration = 7200.0[SI::s];
            out actualCoverage;
            out debrisCollected;
        }
    }
    
    requirement def AutonomousOperation {
        doc /* The pool cleaner shall operate autonomously without human intervention during cleaning cycles. */
        subject cleaner : AutomatedPoolCleaner;
    }
    
    requirement def DebrisRemovalEfficiency {
        doc /* The pool cleaner shall remove at least 95% of debris particles larger than 2mm from pool surfaces. */
        subject cleaner : AutomatedPoolCleaner;
    }
    
    requirement def BatteryEndurance {
        doc /* The pool cleaner shall operate continuously for at least 2 hours on a full charge. */
        subject cleaner : AutomatedPoolCleaner;
    }
    
    requirement def ObstacleAvoidance {
        doc /* The pool cleaner shall detect and avoid obstacles within 15cm to prevent collisions. */
        subject cleaner : AutomatedPoolCleaner;
    }
    
    requirement def WaterCirculation {
        doc /* The pool cleaner shall maintain water flow rate of at least 75 liters per minute. */
        subject cleaner : AutomatedPoolCleaner;
    }
    
    requirement <'APC-SYS-001'> poolCleanerSystemRequirement {
        doc /* 
            The automated pool cleaner system shall autonomously clean pool surfaces by
            navigating the entire pool area, removing debris through suction and brushing,
            filtering water, and managing its own power and maintenance needs.
        */
        subject poolCleaner;
        
        require autonomousOp : AutonomousOperation;
        require debrisRemoval : DebrisRemovalEfficiency;
        require batteryLife : BatteryEndurance;
        require obstacleAvoid : ObstacleAvoidance;
        require waterCirc : WaterCirculation;
    }
}
