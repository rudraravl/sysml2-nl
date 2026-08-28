package AutonomousRobotSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types =====
    value type Distance :> Real { unit 'm'; }
    value type Angle :> Real { unit 'deg'; }
    value type BatteryLevel :> Real { unit '%'; }
    value type Duration :> Real { unit 'h'; }
    value type Power :> Real { unit 'W'; }
    value type Probability :> Real { unit '1'; }
    value type Coordinate :> Real { unit 'm'; }
    value type Velocity :> Real { unit 'm/s'; }
    
    item def Position3D {
        attribute x : Coordinate;
        attribute y : Coordinate;
        attribute z : Coordinate;
    }
    
    item def Task {
        attribute id : String;
        attribute type : String; // delivery, cleaning, surveillance, assistance
        attribute destination : Position3D;
        attribute priority : Integer;
    }
    
    item def TaskResult {
        attribute taskId : String;
        attribute success : Boolean;
        attribute message : String;
        attribute timestamp : String;
    }
    
    item def SensorData {
        attribute sensorId : Integer;
        attribute distanceReading : Distance;
        attribute bearing : Angle;
        attribute timestamp : String;
    }
    
    item def Path {
        attribute waypoints : Position3D[0..*];
        attribute estimatedDuration : Duration;
    }
    
    item def DiagnosticReport {
        attribute faultCode : String;
        attribute description : String;
        attribute recoverable : Boolean;
    }
    
    // ===== Port Definitions =====
    port def TaskPort {
        in item tasks : Task[0..*];
        out item results : TaskResult[0..*];
    }
    
    port def PowerPort {
        attribute voltage : Real;
        attribute current : Real;
        out attribute available : Boolean;
    }
    
    port def SensorDataPort {
        out item data : SensorData[0..*];
    }
    
    port def CommandPort {
        in attribute command : String;
        out attribute status : String;
    }
    
    port def NavigationDataPort {
        out item path : Path;
        in item currentPosition : Position3D;
    }
    
    // ===== Requirements =====
    requirement def CollisionAvoidanceRequirement {
        doc "The robot must avoid collisions in human-occupied indoor spaces."
        attribute minObstacleDetectionDistance : Distance = 10 [m];
        attribute fieldOfView : Angle = 360 [deg];
        constraint { minObstacleDetectionDistance >= 10 [m] }
        constraint { fieldOfView >= 360 [deg] }
    }
    
    requirement def EnduranceRequirement {
        doc "The robot must operate for at least six hours on a single charge."
        attribute minOperationTime : Duration = 6 [h];
        constraint { minOperationTime >= 6 [h] }
    }
    
    requirement def TaskReliabilityRequirement {
        doc "The robot must complete assigned tasks with high reliability and accuracy."
        attribute minSuccessRate : Probability = 0.95;
        attribute maxPositionError : Distance = 0.1 [m];
        constraint { minSuccessRate >= 0.95 }
        constraint { maxPositionError <= 0.1 [m] }
    }
    
    requirement def AutonomousRechargeRequirement {
        doc "The robot must autonomously navigate to and recharge at its charging station when battery is low."
        attribute lowBatteryThreshold : BatteryLevel = 20 [%];
        constraint { lowBatteryThreshold <= 20 [%] }
    }
    
    requirement def FaultRecoveryRequirement {
        doc "The robot must diagnose faults and attempt automatic recovery."
        attribute maxDiagnosisTime : Duration = 0.25 [h];
        constraint { maxDiagnosisTime <= 0.25 [h] }
    }
    
    // ===== Subsystem Part Definitions =====
    part def Sensor {
        attribute sensorId : Integer;
        attribute maxRange : Distance = 10 [m];
        attribute fieldOfView : Angle = 60 [deg];
        port sensorOut : SensorDataPort;
    }
    
    part def PerceptionSystem {
        attribute sensorCount : Integer = 6;
        attribute totalFieldOfView : Angle = 360 [deg];
        attribute maxDetectionRange : Distance = 10 [m];
        port sensorDataOut : SensorDataPort;
        port perceptionOut : ~SensorDataPort;
        
        part sensors : Sensor[6] {
            port sensorOut : SensorDataPort;
        }
        
        action def ProcessSensorData {
            in raw : SensorData[0..*];
            out fused : SensorData;
        }
        
        perform process : ProcessSensorData;
    }
    
    part def NavigationSystem {
        attribute maxSpeed : Velocity = 1.5 [m/s];
        port navIn : SensorDataPort;
        port navOut : NavigationDataPort;
        port navCommand : CommandPort;
        
        action def PlanPath {
            in start : Position3D;
            in goal : Position3D;
            out path : Path;
        }
        
        action def FollowPath {
            in path : Path;
            out position : Position3D;
        }
        
        perform plan : PlanPath;
        perform follow : FollowPath;
    }
    
    part def TaskExecutionSystem {
        port taskIn : TaskPort;
        port execCommand : CommandPort;
        
        action def ExecuteTask {
            in task : Task;
            out result : TaskResult;
        }
        
        perform execute : ExecuteTask;
    }
    
    part def PowerManagementSystem {
        attribute batteryCapacity : Duration = 8 [h];
        attribute currentCharge : BatteryLevel = 100 [%];
        attribute lowThreshold : BatteryLevel = 20 [%];
        port powerOut : PowerPort;
        port powerStatus : CommandPort;
        
        state def BatteryState {
            entry; 
            attribute charge : BatteryLevel;
        }
        
        action def MonitorBattery {
            out charge : BatteryLevel;
            out isLow : Boolean;
        }
        
        perform monitor : MonitorBattery;
    }
    
    part def CentralControlSystem {
        port controlIn : TaskPort;
        port controlOut : CommandPort;
        port navCommand : CommandPort;
        port execCommand : CommandPort;
        port powerStatus : CommandPort;
        port perceptionIn : SensorDataPort;
        
        action def CoordinateSubsystems {
            in task : Task;
            out commands : String[0..*];
        }
        
        perform coordinate : CoordinateSubsystems;
    }
    
    // ===== Personal Robot =====
    part def PersonalRobot {
        port taskInterface : TaskPort;
        port powerInterface : PowerPort;
        
        part control : CentralControlSystem;
        part perception : PerceptionSystem;
        part navigation : NavigationSystem;
        part execution : TaskExecutionSystem;
        part power : PowerManagementSystem;
        
        // Internal connections
        connection perceptionToControl connect perception.perceptionOut to control.perceptionIn;
        connection perceptionToNav connect perception.perceptionOut to navigation.navIn;
        connection controlToNav connect control.navCommand to navigation.navCommand;
        connection controlToExec connect control.execCommand to execution.execCommand;
        connection controlToPower connect control.powerStatus to power.powerStatus;
        connection navToControl connect navigation.navOut to control.controlOut;
        
        // Robot operational state machine
        state def RobotOperationalState;
        
        state machine RobotBehavior {
            state standby;
            state active;
            state charging;
            state fault;
            
            // Active composite state
            state active {
                entry; 
                state planning;
                state navigating;
                state executing;
                state reporting;
                
                transition planning_to_navigating first planning then navigating;
                transition navigating_to_executing first navigating then executing;
                transition executing_to_reporting first executing then reporting;
            }
            
            transition standby_to_active first standby then active 
                if control.controlIn.tasks->notEmpty();
            transition active_to_standby first active.reporting then standby;
            transition any_to_charging first standby, active then charging 
                if power.currentCharge <= power.lowThreshold;
            transition charging_to_standby first charging then standby 
                if power.currentCharge >= 100 [%];
            transition any_to_fault first standby, active, charging then fault 
                if faultDetected;
            transition fault_to_standby first fault then standby 
                if faultRecovered;
            
            attribute faultDetected : Boolean;
            attribute faultRecovered : Boolean;
        }
        
        exhibit behavior : RobotBehavior;
        
        satisfy CollisionAvoidanceRequirement {
            requirement.id = "collision-avoidance";
            subject perception.totalFieldOfView;
        }
        
        satisfy EnduranceRequirement {
            requirement.id = "endurance";
            subject power.batteryCapacity;
        }
        
        satisfy TaskReliabilityRequirement {
            requirement.id = "task-reliability";
            subject execution;
        }
        
        satisfy AutonomousRechargeRequirement {
            requirement.id = "autonomous-recharge";
            subject power;
        }
        
        satisfy FaultRecoveryRequirement {
            requirement.id = "fault-recovery";
            subject control;
        }
    }
    
    // ===== Charging Station =====
    part def ChargingStation {
        attribute stationId : String;
        attribute location : Position3D;
        attribute outputPower : Power = 60 [W];
        port stationPower : PowerPort;
        
        state def StationState;
        
        state machine StationBehavior {
            state idle;
            state charging;
            state complete;
            
            transition idle_to_charging first idle then charging 
                if stationPower.available;
            transition charging_to_complete first charging then complete 
                if chargeComplete;
            transition complete_to_idle first complete then idle;
            
            attribute chargeComplete : Boolean;
        }
        
        exhibit behavior : StationBehavior;
    }
    
    // ===== Task Dispatcher =====
    part def TaskDispatcher {
        attribute dispatcherId : String;
        port dispatchPort : TaskPort;
        
        action def DispatchTask {
            out task : Task;
        }
        
        action def ReceiveResult {
            in result : TaskResult;
        }
        
        perform dispatch : DispatchTask;
        perform receive : ReceiveResult;
    }
    
    // ===== Top-level System =====
    part def AutonomousRobotSystem {
        part robot : PersonalRobot;
        part chargingStation : ChargingStation;
        part dispatcher : TaskDispatcher;
        
        connection dispatchToRobot connect dispatcher.dispatchPort to robot.taskInterface;
        connection robotToStation connect robot.powerInterface to chargingStation.stationPower;
        
        satisfy CollisionAvoidanceRequirement {
            requirement.id = "sys-collision-avoidance";
            subject robot.perception;
        }
        
        satisfy EnduranceRequirement {
            requirement.id = "sys-endurance";
            subject robot.power;
        }
        
        satisfy TaskReliabilityRequirement {
            requirement.id = "sys-task-reliability";
            subject robot.execution;
        }
        
        satisfy AutonomousRechargeRequirement {
            requirement.id = "sys-autonomous-recharge";
            subject robot;
        }
        
        satisfy FaultRecoveryRequirement {
            requirement.id = "sys-fault-recovery";
            subject robot;
        }
    }
}
