package TortoiseSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types ----
    value type LightIntensity :> Real { unit 'lux'; }
    value type MassValue :> Real { unit 'kg'; }
    value type SpeedValue :> Real { unit 'm/s'; }
    value type BatteryCapacityValue :> Real { unit 'Wh'; }
    value type BatteryChargeValue :> Real { unit 'percent'; }
    value type DistanceValue :> Real { unit 'm'; }
    value type AngleValue :> Real { unit 'deg'; }
    value type PowerValue :> Real { unit 'W'; }
    value type VoltageValue :> Real { unit 'V'; }
    value type CurrentValue :> Real { unit 'A'; }
    value type TimeValue :> Real { unit 's'; }

    // ---- Item Definitions ----
    item def Light {
        attribute intensity : LightIntensity;
        attribute sourceId : String;
    }

    item def Power {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    item def BeaconSignal {
        attribute intensity : LightIntensity;
        attribute dockId : String;
    }

    // ---- Port Definitions ----
    port def LightSensingPort {
        out lightReading : Light;
    }

    port def LightEmissionPort {
        out emittedLight : Light;
    }

    port def BeaconPort {
        out beaconSignal : BeaconSignal;
    }

    port def PowerPort {
        in powerIn : Power;
    }

    port def DriveCommandPort {
        out speed : SpeedValue;
        out heading : AngleValue;
    }

    port def DockingPort {
        out docked : Boolean;
        in powerIn : Power;
    }

    // ---- Requirements ----
    requirement def LightSeekingBehavior {
        subject robot : TortoiseRobot;
        doc /* The robot shall seek light sources in its environment. */
        require {
            constraint { robot.sensedLight.intensity > 50 [lux] implies robot.drive.speed > 0 [m/s] }
        }
    }

    requirement def HeadlampActivation {
        subject robot : TortoiseRobot;
        doc /* The robot shall activate its headlamp in dim conditions. */
        require {
            constraint { robot.sensedLight.intensity < 20 [lux] implies robot.headlamp.isOn == true }
        }
    }

    requirement def LowBatteryReturn {
        subject robot : TortoiseRobot;
        doc /* The robot shall return to charging station when battery is low. */
        require {
            constraint { robot.battery.charge < 15 [percent] implies robot.currentState == RobotState::returningToDock }
        }
    }

    requirement def RechargeAndResume {
        subject robot : TortoiseRobot;
        doc /* The robot shall resume exploration after sufficient recharge. */
        require {
            constraint { robot.battery.charge > 90 [percent] and robot.isDocked == true implies robot.currentState == RobotState::exploring }
        }
    }

    requirement def MutualAttraction {
        subject robots : TortoiseRobot[2];
        doc /* Two robots shall be mutually attracted to each other's headlamps. */
        require {
            constraint { 
                robots[1].sensedLight.sourceId == robots[2].name or 
                robots[2].sensedLight.sourceId == robots[1].name 
            }
        }
    }

    // ---- Enumerations ----
    enum def RobotState {
        exploring;
        seekingLight;
        returningToDock;
        docking;
        charging;
        undocking;
    }

    enum def DockState {
        empty;
        occupied;
        charging;
    }

    // ---- Part Definitions ----

    part def PhotocellSensor {
        port lightOut : LightSensingPort;
        attribute sensedIntensity : LightIntensity;
        
        action def SenseLight {
            in ambientLight : Light;
            out reading : Light;
        }
    }

    part def Headlamp {
        port lightOut : LightEmissionPort;
        attribute isOn : Boolean = false;
        attribute brightness : LightIntensity = 80 [lux];
        
        action def TurnOn;
        action def TurnOff;
    }

    part def DriveMotor {
        port commandIn : DriveCommandPort;
        attribute currentSpeed : SpeedValue = 0 [m/s];
        attribute maxSpeed : SpeedValue;
        
        action def SetSpeed {
            in targetSpeed : SpeedValue;
        }
    }

    part def SteeringMechanism {
        attribute currentHeading : AngleValue = 0 [deg];
        attribute maxTurnRate : AngleValue = 45 [deg/s];
        
        action def SetHeading {
            in targetHeading : AngleValue;
        }
    }

    part def RechargeableBattery {
        port powerOut : PowerPort;
        attribute capacity : BatteryCapacityValue;
        attribute charge : BatteryChargeValue = 100 [percent];
        attribute voltage : VoltageValue = 12 [V];
        attribute isLow : Boolean = false;
        
        action def Discharge {
            in rate : PowerValue;
            out remainingCharge : BatteryChargeValue;
        }
        
        action def Recharge {
            in supply : Power;
            out chargeLevel : BatteryChargeValue;
        }
    }

    part def ChargingDock {
        port beaconOut : BeaconPort;
        port dockingPort : DockingPort;
        attribute dockId : String;
        attribute dockState : DockState = DockState::empty;
        attribute outputVoltage : VoltageValue = 12 [V];
        attribute chargeCurrent : CurrentValue = 2 [A];
        
        action def EmitBeacon {
            out signal : BeaconSignal;
        }
        
        action def EngageCharging {
            in robot : TortoiseRobot;
            out power : Power;
        }
        
        action def DisengageCharging;
    }

    part def TortoiseRobot {
        port lightSensorPort : LightSensingPort;
        port headlampPort : LightEmissionPort;
        port drivePort : DriveCommandPort;
        port dockingPort : DockingPort;
        
        attribute name : String;
        attribute mass : MassValue;
        attribute maxSpeed : SpeedValue;
        attribute currentState : RobotState = RobotState::exploring;
        attribute isDocked : Boolean = false;
        attribute sensedLight : Light;
        
        part photocell : PhotocellSensor {
            redefines lightOut = lightSensorPort;
        }
        
        part headlamp : Headlamp {
            redefines lightOut = headlampPort;
        }
        
        part driveMotor : DriveMotor {
            redefines commandIn = drivePort;
        }
        
        part steering : SteeringMechanism;
        
        part battery : RechargeableBattery;
        
        satisfy LightSeekingBehavior {
            subject = self;
        }
        
        satisfy HeadlampActivation {
            subject = self;
        }
        
        satisfy LowBatteryReturn {
            subject = self;
        }
        
        satisfy RechargeAndResume {
            subject = self;
        }
        
        // ---- State Machine ----
        state def RobotBehavior {
            entry; then exploring;
            
            state exploring {
                entry action { 
                    /* Move randomly while monitoring light and battery */
                }
                
                do action MonitorEnvironment {
                    /* Continuously sense light and check battery */
                }
                
                transition explore_to_seeking 
                    first exploring 
                    then seekingLight 
                    if sensedLight.intensity > 50 [lux];
                
                transition explore_to_returning 
                    first exploring 
                    then returningToDock 
                    if battery.charge < 15 [percent];
            }
            
            state seekingLight {
                entry action {
                    /* Orient toward strongest light source and move toward it */
                }
                
                do action ApproachLight {
                    /* Adjust heading and speed toward detected light */
                }
                
                transition seeking_to_explore 
                    first seekingLight 
                    then exploring 
                    if sensedLight.intensity < 30 [lux] and battery.charge >= 15 [percent];
                
                transition seeking_to_returning 
                    first seekingLight 
                    then returningToDock 
                    if battery.charge < 15 [percent];
            }
            
            state returningToDock {
                entry action {
                    /* Disengage light-seeking; navigate to charging station beacon */
                }
                
                do action NavigateToBeacon {
                    /* Follow charging station beacon signal */
                }
                
                transition returning_to_docking 
                    first returningToDock 
                    then docking 
                    if isDocked == true;
            }
            
            state docking {
                entry action {
                    /* Align with dock and establish power connection */
                }
                
                do action EstablishConnection {
                    /* Confirm docking and initiate charging handshake */
                }
                
                transition docking_to_charging 
                    first docking 
                    then charging 
                    if dockingPort.docked == true;
            }
            
            state charging {
                entry action {
                    /* Charge battery until sufficiently full */
                }
                
                do action ChargeBattery {
                    /* Receive power from dock and monitor charge level */
                }
                
                transition charging_to_undocking 
                    first charging 
                    then undocking 
                    if battery.charge > 90 [percent];
            }
            
            state undocking {
                entry action {
                    /* Disconnect from dock and prepare to resume exploration */
                }
                
                do action Disengage {
                    /* Release dock connection and back away */
                }
                
                transition undocking_to_exploring 
                    first undocking 
                    then exploring 
                    if isDocked == false;
            }
        }
        
        behavior robotStateMachine : RobotBehavior;
    }

    part def ChargingStation {
        port beaconPort1 : BeaconPort;
        port beaconPort2 : BeaconPort;
        port dockPort1 : DockingPort;
        port dockPort2 : DockingPort;
        
        attribute stationId : String = "CentralStation";
        attribute location : String;
        
        part dock1 : ChargingDock {
            redefines dockId = "Dock-Alpha";
            redefines beaconOut = beaconPort1;
            redefines dockingPort = dockPort1;
        }
        
        part dock2 : ChargingDock {
            redefines dockId = "Dock-Beta";
            redefines beaconOut = beaconPort2;
            redefines dockingPort = dockPort2;
        }
        
        action def BroadcastBeacons {
            out signal1 : BeaconSignal;
            out signal2 : BeaconSignal;
        }
    }

    part def PhysicalSpace {
        attribute width : DistanceValue = 5 [m];
        attribute length : DistanceValue = 7 [m];
        attribute height : DistanceValue = 3 [m];
        attribute ambientLightLevel : LightIntensity = 15 [lux];
    }

    // ---- Specialized Robot Definitions ----
    part def ElmerRobot :> TortoiseRobot {
        redefines name = "Elmer";
        redefines mass = 1.2 [kg];
        redefines maxSpeed = 0.35 [m/s];
        
        part battery : RechargeableBattery {
            redefines capacity = 12 [Wh];
        }
        
        part driveMotor : DriveMotor {
            redefines maxSpeed = 0.35 [m/s];
        }
        
        part headlamp : Headlamp {
            redefines brightness = 85 [lux];
        }
    }

    part def ElsieRobot :> TortoiseRobot {
        redefines name = "Elsie";
        redefines mass = 0.95 [kg];
        redefines maxSpeed = 0.42 [m/s];
        
        part battery : RechargeableBattery {
            redefines capacity = 10 [Wh];
        }
        
        part driveMotor : DriveMotor {
            redefines maxSpeed = 0.42 [m/s];
        }
        
        part headlamp : Headlamp {
            redefines brightness = 75 [lux];
        }
    }

    // ---- System Assembly ----
    part def TortoiseSystem {
        part environment : PhysicalSpace;
        
        part elmer : ElmerRobot;
        part elsie : ElsieRobot;
        
        part chargingStation : ChargingStation {
            redefines location = "North Wall";
        }
        
        satisfy MutualAttraction {
            subject = (elmer, elsie);
        }
        
        // Connections between robots' headlamps and each other's sensors
        connection elmerLightToElsie connect elmer.headlampPort to elsie.lightSensorPort;
        connection elsieLightToElmer connect elsie.headlampPort to elmer.lightSensorPort;
        
        // Connections from charging station beacons to robot sensors
        connection beacon1ToElmer connect chargingStation.beaconPort1 to elmer.lightSensorPort;
        connection beacon2ToElsie connect chargingStation.beaconPort2 to elsie.lightSensorPort;
        
        // Docking connections
        connection elmerToDock1 connect elmer.dockingPort to chargingStation.dockPort1;
        connection elsieToDock2 connect elsie.dockingPort to chargingStation.dockPort2;
        
        // Drive command connections (internal to each robot, represented here for completeness)
        connection elmerDrive connect elmer.drivePort to elmer.driveMotor.commandIn;
        connection elsieDrive connect elsie.drivePort to elsie.driveMotor.commandIn;
    }
}
