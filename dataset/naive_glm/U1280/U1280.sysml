package DustbotSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Units =====
    unit m;
    unit kg;
    unit W;
    unit J;
    unit Coulomb;
    unit percent;
    unit rad_per_s;
    unit m_per_s;
    unit mg_per_cm2;

    // ===== Value Types =====
    value def Distance :> Real { unit m; }
    value def MassValue :> Real { unit kg; }
    value def PowerValue :> Real { unit W; }
    value def EnergyValue :> Real { unit J; }
    value def ChargeValue :> Real { unit Coulomb; }
    value def PercentValue :> Real { unit percent; }
    value def AngularSpeed :> Real { unit rad_per_s; }
    value def LinearSpeed :> Real { unit m_per_s; }
    value def DirtDensity :> Real { unit mg_per_cm2; }

    // ===== Item Definitions =====
    item def Dirt {
        attr amount : MassValue;
    }
    item def Dust :> Dirt;
    item def Debris :> Dirt;

    item def ObstacleSignal {
        attr detected : Boolean;
        attr distance : Distance;
        attr direction : Real;
    }

    item def DirtReading {
        attr level : DirtDensity;
        attr location : Real[2];
    }

    item def PathPlan {
        attr waypoints : Real[0..*][2];
        attr estimatedDistance : Distance;
    }

    item def MotorCommand {
        attr leftWheelSpeed : LinearSpeed;
        attr rightWheelSpeed : LinearSpeed;
    }

    item def PowerFlow {
        attr voltage : Real;
        attr current : Real;
    }

    // ===== Port Definitions =====
    port def SensorOutPort {
        out obstacleData : ObstacleSignal;
    }

    port def FloorSensorOutPort {
        out dirtData : DirtReading;
    }

    port def MotorCmdOutPort {
        out command : MotorCommand;
    }

    port def MotorCmdInPort {
        in command : MotorCommand;
    }

    port def NavDataOutPort {
        out pathPlan : PathPlan;
    }

    port def NavDataInPort {
        in obstacleData : ObstacleSignal;
        in dirtData : DirtReading;
    }

    port def MotorNavInPort {
        in pathPlan : PathPlan;
    }

    port def PowerOutPort {
        out power : PowerFlow;
    }

    port def PowerInPort {
        in power : PowerFlow;
    }

    port def DockInterfacePort {
        in chargingPower : PowerFlow;
        out binFullSignal : Boolean;
        out requestDock : Boolean;
        in dockConfirmed : Boolean;
    }

    // ===== Connection Definitions =====
    connection def SensorToNavConn {
        end source : SensorOutPort;
        end target : NavDataInPort;
        flow obstacleData : ObstacleSignal;
    }

    connection def FloorSensorToNavConn {
        end source : FloorSensorOutPort;
        end target : NavDataInPort;
        flow dirtData : DirtReading;
    }

    connection def NavToMotorConn {
        end source : NavDataOutPort;
        end target : MotorNavInPort;
        flow pathPlan : PathPlan;
    }

    connection def MotorToWheelConn {
        end source : MotorCmdOutPort;
        end target : MotorCmdInPort;
        flow command : MotorCommand;
    }

    connection def PowerConn {
        end source : PowerOutPort;
        end target : PowerInPort;
        flow power : PowerFlow;
    }

    connection def DockConn {
        end robotSide : DockInterfacePort;
        end dockSide : ~DockInterfacePort;
        flow chargingPower : PowerFlow;
        flow binFullSignal : Boolean;
        flow requestDock : Boolean;
        flow dockConfirmed : Boolean;
    }

    // ===== Part Definitions =====
    part def ProximitySensor {
        attr maxRange : Distance = 0.8;
        attr isTriggered : Boolean = false;
        port sensorOut : SensorOutPort;
        action detectObstacle {
            out signal : ObstacleSignal;
        }
    }

    part def FloorSensor {
        attr detectionThreshold : DirtDensity;
        port dirtOut : FloorSensorOutPort;
        action measureDirt {
            out reading : DirtReading;
        }
    }

    part def VacuumUnit {
        attr powerConsumption : PowerValue = 30;
        attr isActive : Boolean = false;
        port powerIn : PowerInPort;
        action activate;
        action deactivate;
    }

    part def RotatingBrush {
        attr rotationSpeed : AngularSpeed = 15;
        attr isActive : Boolean = false;
        port powerIn : PowerInPort;
        action spin;
        action stop;
    }

    part def DustBin {
        attr capacity : MassValue = 0.6;
        attr currentLoad : MassValue = 0;
        attr isFull : Boolean = false;
        action collectDirt {
            in dirt : Dirt;
        }
        action emptyBin;
    }

    part def Battery {
        attr maxCharge : ChargeValue = 18000;
        attr currentCharge : ChargeValue = 18000;
        attr chargeLevel : PercentValue = 100;
        attr lowThreshold : PercentValue = 20;
        port powerOut : PowerOutPort;
        port chargeIn : PowerInPort;
        action discharge {
            out power : PowerFlow;
        }
        action charge {
            in power : PowerFlow;
        }
        action monitorLevel {
            out level : PercentValue;
        }
    }

    part def Wheel {
        attr radius : Distance = 0.05;
        port cmdIn : MotorCmdInPort;
        action rotate {
            in speed : LinearSpeed;
        }
    }

    part def MotorController {
        port navIn : MotorNavInPort;
        port cmdOut : MotorCmdOutPort;
        action driveMotors {
            in plan : PathPlan;
            out command : MotorCommand;
        }
    }

    part def NavigationModule {
        port sensorIn : NavDataInPort;
        port cmdOut : NavDataOutPort;
        attr mapData : Real[0..*][2];
        action planPath {
            in obstacles : ObstacleSignal[0..*];
            in dirtReadings : DirtReading[0..*];
            out plan : PathPlan;
        }
        action scanEnvironment {
            in obstacles : ObstacleSignal[0..*];
            out mapUpdate : Real[0..*][2];
        }
    }

    part def DockingStation {
        attr isStationary : Boolean = true;
        attr chargingPowerOutput : PowerValue = 60;
        port dockPort : ~DockInterfacePort;
        port powerOut : PowerOutPort;
        action provideCharge {
            out power : PowerFlow;
        }
        action emptyRobotBin;
    }

    // ===== Requirements =====
    requirement def ObstacleAvoidanceRequirement {
        doc /* The Dustbot shall detect obstacles up to 0.8 meters away using six proximity sensors and avoid collisions with furniture and walls. */
        subject s : Dustbot;
        objective {
            doc /* All six proximity sensors shall be operational with a maximum detection range of 0.8 m. */
        }
    }

    requirement def DirtDetectionRequirement {
        doc /* The Dustbot shall assess floor dirt levels using three dedicated floor sensors and focus cleaning efforts where dirt is most needed. */
        subject s : Dustbot;
        objective {
            doc /* Three floor sensors shall provide real-time dirt level readings to guide cleaning. */
        }
    }

    requirement def CleaningMechanismRequirement {
        doc /* The Dustbot shall clean using a main vacuum unit and a rotating brush assembly working together to lift and collect dust and debris. */
        subject s : Dustbot;
        objective {
            doc /* Vacuum and brush shall activate simultaneously when dirt is detected above threshold. */
        }
    }

    requirement def DustBinCapacityRequirement {
        doc /* The Dustbot shall have an internal dust bin with a capacity of 0.6 kg. */
        subject s : Dustbot;
        objective {
            doc /* Dust bin capacity shall be no less than 0.6 kg. */
        }
    }

    requirement def AutonomousReturnRequirement {
        doc /* The Dustbot shall automatically cease cleaning and return to the docking station when battery charge is low or dust bin is full. */
        subject s : Dustbot;
        objective {
            doc /* Return-to-dock shall be triggered when charge level drops below 20% or bin load reaches 0.6 kg capacity. */
        }
    }

    requirement def StateManagementRequirement {
        doc /* The Dustbot shall operate through standby, active, and charging states to manage its mission autonomously without human intervention. */
        subject s : Dustbot;
        objective {
            doc /* State transitions shall occur based on environmental and internal conditions. */
        }
    }

    requirement def DockingChargingRequirement {
        doc /* The docking station shall provide charging power to the Dustbot when connected. */
        subject s : DockingStation;
        objective {
            doc /* Docking station shall supply at least 60 W of charging power. */
        }
    }

    requirement def BinEmptyingRequirement {
        doc /* The docking station shall empty the Dustbot dust bin when the robot is docked and the bin is full. */
        subject s : DockingStation;
        objective {
            doc /* Bin emptying shall occur during charging state when bin is full. */
        }
    }

    // ===== Dustbot Robot =====
    part def Dustbot {
        part proximitySensors : ProximitySensor[6];
        part floorSensors : FloorSensor[3];
        part vacuum : VacuumUnit;
        part brush : RotatingBrush;
        part dustBin : DustBin;
        part navigation : NavigationModule;
        part motorController : MotorController;
        part wheels : Wheel[2];
        part battery : Battery;
        port dockPort : DockInterfacePort;

        connection : SensorToNavConn
            connect proximitySensors.sensorOut to navigation.sensorIn;
        connection : FloorSensorToNavConn
            connect floorSensors.dirtOut to navigation.sensorIn;
        connection : NavToMotorConn
            connect navigation.cmdOut to motorController.navIn;
        connection : MotorToWheelConn
            connect motorController.cmdOut to wheels.cmdIn;
        connection : PowerConn
            connect battery.powerOut to vacuum.powerIn;
        connection : PowerConn
            connect battery.powerOut to brush.powerIn;

        attr missionStart : Boolean = false;
        attr missionComplete : Boolean = false;
        attr docked : Boolean = false;
        attr obstacleDetected : Boolean = false;
        attr dirtDetected : Boolean = false;
        attr dirtThreshold : DirtDensity = 5;

        state DustbotStateMachine {
            state standby {
                entry action vacuum.deactivate;
                entry action brush.stop;
            }

            state active {
                state scanning {
                    entry action navigation.scanEnvironment;
                }
                state navigating {
                    entry action navigation.planPath;
                }
                state cleaning {
                    entry action vacuum.activate;
                    entry action brush.spin;
                }

                transition scanning -> navigating
                    if obstacleDetected or dirtDetected;
                transition navigating -> cleaning
                    if dirtDetected;
                transition cleaning -> scanning
                    if not dirtDetected;
            }

            state returningToDock {
                entry action vacuum.deactivate;
                entry action brush.stop;
                entry action navigation.planPath;
            }

            state charging {
                entry action battery.charge;
                entry action dustBin.emptyBin;
            }

            transition standby -> active if missionStart;
            transition active -> returningToDock
                if battery.chargeLevel <= battery.lowThreshold or dustBin.isFull;
            transition returningToDock -> charging if docked;
            transition charging -> standby
                if battery.chargeLevel >= 95 and not dustBin.isFull;
            transition active -> standby if missionComplete;
        }
    }

    // ===== Top-Level System =====
    part DustbotCleaningSystem {
        part robot : Dustbot;
        part dock : DockingStation;

        connection : DockConn
            connect robot.dockPort to dock.dockPort;
        connection : PowerConn
            connect dock.powerOut to robot.battery.chargeIn;

        satisfy ObstacleAvoidanceRequirement by robot.proximitySensors;
        satisfy DirtDetectionRequirement by robot.floorSensors;
        satisfy CleaningMechanismRequirement by robot.vacuum;
        satisfy CleaningMechanismRequirement by robot.brush;
        satisfy DustBinCapacityRequirement by robot.dustBin;
        satisfy AutonomousReturnRequirement by robot;
        satisfy StateManagementRequirement by robot;
        satisfy DockingChargingRequirement by dock;
        satisfy BinEmptyingRequirement by dock;
    }
}
