package AutonomousPoolCleaner {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        item def ElectricalPower;
        item def DirtyWater;
        item def CleanWater;
        item def Debris;

        attribute def ChargeValue :> ScalarValues::Real;
        attribute def DistanceValue :> ScalarValues::Real;
        attribute def SpeedValue :> ScalarValues::Real;
        attribute def RotationalSpeedValue :> ScalarValues::Real;
        attribute def FlowRateValue :> ScalarValues::Real;
        attribute def FilterFullnessValue :> ScalarValues::Real;

        attribute def StartSignal;
        attribute def LowBatterySignal;
        attribute def FilterFullSignal;
        attribute def DockedSignal;
        attribute def MaintenanceCompleteSignal;

        port def PowerOutPort {
            out power : ElectricalPower;
        }
        port def PowerInPort {
            in power : ElectricalPower;
        }
        port def ControlOutPort {
            out cmd : ScalarValues::Boolean;
        }
        port def ControlInPort {
            in cmd : ScalarValues::Boolean;
        }
        port def SensorOutPort {
            out distance : DistanceValue;
        }
        port def SensorInPort {
            in distance : DistanceValue;
        }
        port def DirtyWaterInPort {
            in water : DirtyWater;
        }
        port def DirtyWaterOutPort {
            out water : DirtyWater;
        }
        port def CleanWaterOutPort {
            out water : CleanWater;
        }

        action def ScrubAction;
        action def SuctionAction;
        action def FilterWaterAction;
        action def NavigateAction;
        action def RechargeAction;
        action def DetectAction;
        action def DriveAction;

        part def BatterySystem {
            attribute charge : ChargeValue;
            port powerOut : PowerOutPort;
            port powerIn : PowerInPort;
            perform action recharge : RechargeAction;
        }

        part def MotorDrive {
            port powerIn : PowerInPort;
            port controlIn : ControlInPort;
            attribute speed : SpeedValue;
            perform action drive : DriveAction;
        }

        part def BrushAssembly {
            port powerIn : PowerInPort;
            port controlIn : ControlInPort;
            attribute rotationSpeed : RotationalSpeedValue;
            perform action scrub : ScrubAction;
        }

        part def HydraulicPump {
            port powerIn : PowerInPort;
            port controlIn : ControlInPort;
            port waterIn : DirtyWaterInPort;
            port waterOut : DirtyWaterOutPort;
            attribute flowRate : FlowRateValue;
            perform action suction : SuctionAction;
        }

        part def DebrisFilter {
            port waterIn : DirtyWaterInPort;
            port waterOut : CleanWaterOutPort;
            attribute fullness : FilterFullnessValue;
            perform action filterWater : FilterWaterAction;
        }

        part def ProximitySensors {
            port dataOut : SensorOutPort;
            perform action detect : DetectAction;
        }

        part def NavigationController {
            port sensorIn : SensorInPort;
            port motorOut : ControlOutPort;
            port brushOut : ControlOutPort;
            port pumpOut : ControlOutPort;
            perform action navigate : NavigateAction;
        }

        part def DockingStation {
            port powerOut : PowerOutPort;
        }

        state def CleanerStates;

        part def RoboticPoolCleaner {
            attribute atDock : ScalarValues::Boolean;
            part battery : BatterySystem;
            part motorDrive : MotorDrive;
            part brushAssembly : BrushAssembly;
            part hydraulicPump : HydraulicPump;
            part debrisFilter : DebrisFilter;
            part proximitySensors : ProximitySensors;
            part navController : NavigationController;

            connect battery.powerOut to motorDrive.powerIn;
            connect battery.powerOut to brushAssembly.powerIn;
            connect battery.powerOut to hydraulicPump.powerIn;
            connect proximitySensors.dataOut to navController.sensorIn;
            connect navController.motorOut to motorDrive.controlIn;
            connect navController.brushOut to brushAssembly.controlIn;
            connect navController.pumpOut to hydraulicPump.controlIn;
            connect hydraulicPump.waterOut to debrisFilter.waterIn;

            exhibit state cleanerStates : CleanerStates {
                entry; then idle;
                state idle;
                accept StartSignal then cleaning;
                state cleaning parallel {
                    state scrubbing {
                        do brushAssembly.scrub;
                    }
                    state suctioning {
                        do hydraulicPump.suction;
                    }
                    state filtering {
                        do debrisFilter.filterWater;
                    }
                    state navigating {
                        do navController.navigate;
                    }
                }
                accept when battery.charge < 10.0
                    then returningToDock;
                accept when debrisFilter.fullness > 90.0
                    then returningToDock;
                state returningToDock {
                    do navController.navigate;
                }
                accept DockedSignal then docked;
                state docked {
                    do battery.recharge;
                }
                accept MaintenanceCompleteSignal then idle;
            }
        }

        requirement def AutonomousCleaningRequirement {
            doc /* The robot shall autonomously navigate and clean the pool without human intervention. */
        }

        requirement def ObstacleAvoidanceRequirement {
            doc /* The robot shall detect obstacles and walls to prevent collisions using proximity sensors. */
        }

        requirement def SelfMaintenanceRequirement {
            doc /* The robot shall return to the docking station when battery is low or filter is full. */
        }

        requirement def SurfaceScrubbingRequirement {
            doc /* The robot shall scrub pool surfaces to dislodge dirt, algae, and other debris. */
        }

        requirement def DebrisFiltrationRequirement {
            doc /* The robot shall suction dirty water, filter debris, and return clean water to the pool. */
        }
    }

    public import Definitions::*;

    package Usages {
        private import Definitions::*;

        part poolCleanerSystem {
            part robot : RoboticPoolCleaner;
            part dock : DockingStation;
            connect dock.powerOut to robot.battery.powerIn;

            requirement autonomousCleaning : AutonomousCleaningRequirement;
            requirement obstacleAvoidance : ObstacleAvoidanceRequirement;
            requirement selfMaintenance : SelfMaintenanceRequirement;
            requirement surfaceScrubbing : SurfaceScrubbingRequirement;
            requirement debrisFiltration : DebrisFiltrationRequirement;

            satisfy autonomousCleaning by robot;
            satisfy obstacleAvoidance by robot;
            satisfy selfMaintenance by robot;
            satisfy surfaceScrubbing by robot;
            satisfy debrisFiltration by robot;
        }
    }
}
