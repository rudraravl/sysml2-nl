package RoboticVacuumCleanerSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    item def Distance :> Real { :>> unit = 'mm'; }
    item def BatteryPercentage :> Real { :>> unit = '%'; }
    item def RotationalSpeed :> Real { :>> unit = 'rpm'; }
    item def SuctionPower :> Real { :>> unit = 'W'; }
    item def DirtDensity :> Real { :>> unit = 'mg/m2'; }
    
    port def PowerFlowPort {
        out power : Power;
    }
    
    port def ObstacleDataPort {
        out distance : Distance;
    }
    
    port def DirtDataPort {
        out dirt : DirtDensity;
    }
    
    port def MotorControlPort {
        in speed : RotationalSpeed;
    }
    
    port def FanControlPort {
        in power : SuctionPower;
    }
    
    requirement def ObstacleDetectionRequirement {
        doc "The robot must detect obstacles within 15 cm."
        subject sensorSuite
        objective {
            doc "Detect obstacles within 150 mm."
            assert constraint { sensorSuite.detectionRange <= 150 }
        }
    }
    
    requirement def BatteryReturnRequirement {
        doc "The robot must return to dock when battery is below 20%."
        subject robot
        objective {
            assert constraint { robot.battery.level < 20 implies robot.currentState == "returning" }
        }
    }
    
    part def Battery {
        attribute level : BatteryPercentage = 100;
        port chargingPort : PowerFlowPort;
    }
    
    part def Brush {
        attribute speed : RotationalSpeed;
        port controlPort : MotorControlPort;
    }
    
    part def VacuumFan {
        attribute power : SuctionPower;
        port controlPort : FanControlPort;
    }
    
    part def Dustbin {
        attribute capacity : Volume = 0.5 [L];
        attribute currentFill : Volume = 0 [L];
    }
    
    part def WheelMotor {
        attribute speed : RotationalSpeed;
        port controlPort : MotorControlPort;
    }
    
    part def ObstacleSensor {
        attribute detectionRange : Distance = 150;
        port dataPort : ObstacleDataPort;
    }
    
    part def DirtSensor {
        port dataPort : DirtDataPort;
    }
    
    part def NavigationController {
        port sensorInput : ObstacleDataPort;
        port leftMotorOutput : MotorControlPort;
        port rightMotorOutput : MotorControlPort;
        
        action def ComputePath {
            in sensorData : ObstacleDataPort;
            out leftMotorCommand : MotorControlPort;
            out rightMotorCommand : MotorControlPort;
        }
    }
    
    part def CleaningController {
        port dirtInput : DirtDataPort;
        port mainBrushOutput : MotorControlPort;
        port sideBrush1Output : MotorControlPort;
        port sideBrush2Output : MotorControlPort;
        port fanOutput : FanControlPort;
        
        action def AdjustCleaning {
            in dirtData : DirtDataPort;
            out mainBrushCommand : MotorControlPort;
            out sideBrush1Command : MotorControlPort;
            out sideBrush2Command : MotorControlPort;
            out fanCommand : FanControlPort;
        }
    }
    
    part def ChargingDock {
        port powerOutput : PowerFlowPort;
    }
    
    part def Robot {
        attribute currentState : String;
        attribute cleanCommand : Boolean = false;
        attribute docked : Boolean = true;
        
        part battery : Battery;
        part mainBrush : Brush;
        part sideBrush1 : Brush;
        part sideBrush2 : Brush;
        part vacuumFan : VacuumFan;
        part dustbin : Dustbin;
        part leftWheel : WheelMotor;
        part rightWheel : WheelMotor;
        part obstacleSensors[6] : ObstacleSensor;
        part dirtSensor : DirtSensor;
        part navController : NavigationController;
        part cleanController : CleaningController;
        
        state machine RobotLifecycle {
            initial start;
            
            state Idle {
                entry action { currentState = "idle"; }
            }
            
            state Undocking {
                entry action { currentState = "undocking"; docked = false; }
            }
            
            state Cleaning {
                entry action { currentState = "cleaning"; }
            }
            
            state Returning {
                entry action { currentState = "returning"; }
            }
            
            state Charging {
                entry action { currentState = "charging"; docked = true; }
            }
            
            transition start -> Idle;
            transition Idle -> Undocking when cleanCommand;
            transition Undocking -> Cleaning when !docked;
            transition Cleaning -> Returning when battery.level < 20;
            transition Returning -> Charging when docked;
            transition Charging -> Idle when battery.level >= 100;
        }
        
        connect obstacleSensors.dataPort to navController.sensorInput;
        connect dirtSensor.dataPort to cleanController.dirtInput;
        connect navController.leftMotorOutput to leftWheel.controlPort;
        connect navController.rightMotorOutput to rightWheel.controlPort;
        connect cleanController.mainBrushOutput to mainBrush.controlPort;
        connect cleanController.sideBrush1Output to sideBrush1.controlPort;
        connect cleanController.sideBrush2Output to sideBrush2.controlPort;
        connect cleanController.fanOutput to vacuumFan.controlPort;
    }
    
    part def VacuumSystem {
        part dock : ChargingDock;
        part robot : Robot;
        
        connect dock.powerOutput to robot.battery.chargingPort;
        
        satisfy ObstacleDetectionRequirement by robot.obstacleSensors;
        satisfy BatteryReturnRequirement by robot;
    }
}
