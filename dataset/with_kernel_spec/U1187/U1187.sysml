package AutonomousRoboticLawnMower {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def ChargeLevel :> ScalarValues::Real;
    attribute def DistanceValue :> ScalarValues::Real;
    attribute def GrassHeightValue :> ScalarValues::Real;
    attribute def BladeHeightValue :> ScalarValues::Real;
    attribute def DriveSpeed :> ScalarValues::Real;
    attribute def PowerOutput :> ScalarValues::Real;

    attribute def StartMowingSignal;
    attribute def StopMowingSignal;
    attribute def ObstacleDetectedSignal;
    attribute def BoundaryDetectedSignal;
    attribute def LowBatterySignal;
    attribute def BatteryFullSignal;
    attribute def DockingCompleteSignal;
    attribute def UndockingCompleteSignal;
    attribute def AvoidanceCompleteSignal;
    attribute def TurnCompleteSignal;

    action def StopMower;
    action def TurnMower;
    action def FindClearPath;
    action def TurnAround;
    action def NavigateToDock;
    action def WaitForFullCharge;
    action def Undock;
    action def MowLawn;
    action def CutGrass;
    action def MonitorCharge { out charge : ChargeLevel; }
    action def ScanForObstacles { out obstaclePresent : Boolean; out distance : DistanceValue; }
    action def CheckBoundary { out atBoundary : Boolean; }
    action def CheckBattery { out charge : ChargeLevel; }
    action def AvoidObstacle;
    action def TurnAtBoundary;
    action def ReturnToDock;
    action def Recharge;
    action def MowForward;
    action def SetWheelSpeeds { in leftSpeed : DriveSpeed; in rightSpeed : DriveSpeed; }
    action def SetBladeHeight { in height : BladeHeightValue; }

    part def Wheel {
        attribute speed : DriveSpeed;
        attribute direction : ScalarValues::Real;
    }

    part def ElectricMotor {
        port cmdPort { in attribute speed : DriveSpeed; }
        action setSpeed { in speed : DriveSpeed; }
    }

    part def DriveSystem {
        part leftMotor : ElectricMotor;
        part rightMotor : ElectricMotor;
        part leftWheel : Wheel;
        part rightWheel : Wheel;
        port driveControlPort {
            in attribute leftSpeed : DriveSpeed;
            in attribute rightSpeed : DriveSpeed;
        }
        perform action moveForward : MowForward;
        perform action turnMower : TurnMower;
        perform action stopMower : StopMower;
    }

    part def Blade {
        attribute rotationalSpeed : ScalarValues::Real;
    }

    part def CuttingDeck {
        part blades[3] : Blade;
        attribute bladeHeight : BladeHeightValue;
        port deckControlPort {
            in attribute engage : Boolean;
            in attribute height : BladeHeightValue;
        }
        perform action cutGrass : CutGrass;
        perform action setHeight : SetBladeHeight;
    }

    part def UltrasonicSensor {
        port sensorPort {
            out attribute distance : DistanceValue;
            out attribute obstaclePresent : Boolean;
        }
        perform action scanForObstacles : ScanForObstacles;
    }

    part def BoundaryWireSensor {
        port sensorPort {
            out attribute boundaryDetected : Boolean;
        }
        perform action checkBoundary : CheckBoundary;
    }

    part def BumpSensor {
        port sensorPort {
            out attribute contactDetected : Boolean;
        }
    }

    part def GrassHeightSensor {
        port sensorPort {
            out attribute height : GrassHeightValue;
        }
        perform action measureHeight { out h : GrassHeightValue; }
    }

    part def SensorArray {
        part ultrasonicSensor : UltrasonicSensor;
        part boundaryWireSensor : BoundaryWireSensor;
        part frontBumpSensor : BumpSensor;
        part rearBumpSensor : BumpSensor;
        part grassHeightSensor : GrassHeightSensor;
    }

    part def BatterySystem {
        attribute chargeLevel : ChargeLevel;
        port chargePort { in attribute power : PowerOutput; }
        port levelPort { out attribute level : ChargeLevel; }
        perform action monitorCharge : MonitorCharge;
    }

    part def ChargingDock {
        port dockingPort {
            in attribute requestDocking : Boolean;
            out attribute powerOutput : PowerOutput;
            out attribute dockingComplete : Boolean;
        }
        perform action supplyPower { out power : PowerOutput; }
    }

    state def MowerOperationalStates;

    part def NavigationControlUnit {
        port sensorInputPort {
            in attribute obstacleDistance : DistanceValue;
            in attribute obstaclePresent : Boolean;
            in attribute boundaryDetected : Boolean;
            in attribute bumpDetected : Boolean;
            in attribute grassHeight : GrassHeightValue;
        }
        port batteryMonitorPort {
            in attribute chargeLevel : ChargeLevel;
        }
        port driveControlPort {
            out attribute leftSpeed : DriveSpeed;
            out attribute rightSpeed : DriveSpeed;
        }
        port deckControlPort {
            out attribute bladeEngaged : Boolean;
            out attribute bladeHeight : BladeHeightValue;
        }
        port dockingPort {
            out attribute requestDocking : Boolean;
            in attribute dockingComplete : Boolean;
        }

        exhibit state operationalStates : MowerOperationalStates {
            entry; then idle;
            state idle;
            accept StartMowingSignal
                then mowing;
            state mowing {
                do action mowLawn : MowLawn;
            }
            accept ObstacleDetectedSignal
                then obstacleAvoidance;
            accept BoundaryDetectedSignal
                then boundaryTurn;
            accept LowBatterySignal
                then navigatingToDock;
            accept StopMowingSignal
                then idle;
            state obstacleAvoidance {
                entry action stopMower : StopMower;
                do action turnMower : TurnMower;
                exit action findClearPath : FindClearPath;
            }
            accept AvoidanceCompleteSignal
                then mowing;
            state boundaryTurn {
                entry action turnAround : TurnAround;
            }
            accept TurnCompleteSignal
                then mowing;
            state navigatingToDock {
                do action navigateToDock : NavigateToDock;
            }
            accept DockingCompleteSignal
                then recharging;
            state recharging {
                do action waitForFullCharge : WaitForFullCharge;
            }
            accept BatteryFullSignal
                then undocking;
            state undocking {
                do action undock : Undock;
            }
            accept UndockingCompleteSignal
                then mowing;
        }
    }

    part def RoboticMower {
        part battery : BatterySystem;
        part driveSystem : DriveSystem;
        part cuttingDeck : CuttingDeck;
        part sensorArray : SensorArray;
        part navigationControlUnit : NavigationControlUnit;
        port powerInputPort { in attribute power : PowerOutput; }

        connect powerInputPort to battery.chargePort;
        connect battery.levelPort to navigationControlUnit.batteryMonitorPort;
        connect sensorArray.ultrasonicSensor.sensorPort to navigationControlUnit.sensorInputPort;
        connect sensorArray.boundaryWireSensor.sensorPort to navigationControlUnit.sensorInputPort;
        connect sensorArray.frontBumpSensor.sensorPort to navigationControlUnit.sensorInputPort;
        connect sensorArray.rearBumpSensor.sensorPort to navigationControlUnit.sensorInputPort;
        connect sensorArray.grassHeightSensor.sensorPort to navigationControlUnit.sensorInputPort;
        connect navigationControlUnit.driveControlPort to driveSystem.driveControlPort;
        connect navigationControlUnit.deckControlPort to cuttingDeck.deckControlPort;
    }

    part lawnMowerSystem {
        part mower : RoboticMower;
        part chargingDock : ChargingDock;

        connect mower.navigationControlUnit.dockingPort to chargingDock.dockingPort;
        connect chargingDock.dockingPort to mower.powerInputPort;
    }

    action def AutonomousMowingSequence {
        in mower : RoboticMower;
        loop action mowingCycle {
            action scanForObstacles : ScanForObstacles {
                out obstaclePresent;
            }
            then if scanForObstacles.obstaclePresent {
                action avoidObstacle : AvoidObstacle;
            }
            then action checkBoundary : CheckBoundary {
                out atBoundary;
            }
            then if checkBoundary.atBoundary {
                action turnAtBoundary : TurnAtBoundary;
            }
            then action checkBattery : CheckBattery {
                out charge;
            }
            then if checkBattery.charge < 15 {
                action returnToDock : ReturnToDock;
                then action recharge : Recharge;
                then done;
            }
            then action mowForward : MowForward;
        }
    }

    requirement def AutonomousOperationRequirement {
        doc "The mower shall operate autonomously to maintain the lawn without human intervention.";
    }

    requirement def ObstacleAvoidanceRequirement {
        doc "The mower shall detect obstacles using ultrasonic and bump sensors and perform avoidance maneuvers.";
    }

    requirement def BoundaryConfinementRequirement {
        doc "The mower shall stay within the designated lawn area defined by the boundary wire signal.";
    }

    requirement def SelfRechargeRequirement {
        doc "The mower shall automatically return to the charging dock when battery charge drops below 15 percent and resume mowing when fully charged.";
    }

    requirement autonomousOperation : AutonomousOperationRequirement;
    requirement obstacleAvoidance : ObstacleAvoidanceRequirement;
    requirement boundaryConfinement : BoundaryConfinementRequirement;
    requirement selfRecharge : SelfRechargeRequirement;
}
