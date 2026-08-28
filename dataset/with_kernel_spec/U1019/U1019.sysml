package ContinuousTrackSystemModel {
    public import Definitions::*;
    public import ISQ::*;
    public import ScalarValues::*;

    package Definitions {
        public import AttributeDefinitions::*;
        public import ItemDefinitions::*;
        public import PortDefinitions::*;
        public import ActionDefinitions::*;
        public import PartDefinitions::*;
        public import StateDefinitions::*;
        public import RequirementDefinitions::*;

        package AttributeDefinitions {
            attribute def Tension :> ISQ::force;
            attribute def WearRate :> ScalarValues::Real;
            attribute def TerrainCondition :> ScalarValues::Real;
            attribute def OverloadCondition :> ScalarValues::Boolean;
            
            attribute def StartTensioning;
            attribute def DriveCommand;
            attribute def BrakeCommand;
            attribute def ParkCommand;
            attribute def MaintenanceSignal;
            attribute def MaintenanceComplete;
        }

        package ItemDefinitions {
            item def TrackLink {
                attribute mass :> ISQ::mass;
            }
            item def TrackPad {
                attribute material : ScalarValues::String;
                attribute frictionCoefficient : ScalarValues::Real;
            }
        }

        package PortDefinitions {
            port def PowerInputPort {
                in torque :> ISQ::torque;
                in speed :> ISQ::speed;
            }
            port def TensionFeedbackPort {
                out tension : Tension;
            }
            port def StatusPort {
                out wearRate : WearRate;
                out overload : OverloadCondition;
                out maintenanceRequired : ScalarValues::Boolean;
            }
        }

        package ActionDefinitions {
            action def CalculateTraction {
                in weight :> ISQ::mass;
                in terrain : TerrainCondition;
                out traction :> ISQ::force;
            }
            action def DistributeLoad {
                in weight :> ISQ::mass;
                out loadPerWheel :> ISQ::force;
            }
            action def EvaluateWear {
                in speed :> ISQ::speed;
                in terrain : TerrainCondition;
                out wearRate : WearRate;
            }
            action def AdjustTension {
                in currentTension : Tension;
                out adjustment : Tension;
            }
        }

        package PartDefinitions {
            part def ContinuousTrackSystem {
                attribute totalWeight :> ISQ::mass;
                attribute tension : Tension;
                attribute wearRate : WearRate;
                attribute overload : OverloadCondition;
                
                port powerInput : PowerInputPort;
                port statusOut : StatusPort;
                
                part trackFrame : TrackFrame;
                part driveSprocket : DriveSprocket {
                    port powerIn : PowerInputPort;
                }
                part frontIdler : IdlerWheel;
                part rearIdler : IdlerWheel;
                part roadWheels : RoadWheel[8];
                part trackChain : TrackChain;
                part tensioner : TensioningMechanism {
                    port tensionFeedback : TensionFeedbackPort;
                }
                part controller : TrackController;
                
                connection powerConn connect powerInput to driveSprocket.powerIn;
                connection tensionFeedbackConn connect tensioner.tensionFeedback to controller.tensionInput;
                
                perform action calculateTraction : CalculateTraction;
                perform action distributeLoad : DistributeLoad;
                perform action evaluateWear : EvaluateWear;
                perform action adjustTension : AdjustTension;
                
                exhibit state systemStates : TrackSystemStates;
                
                satisfy TensionControl by systemStates;
                satisfy WearMonitoring by systemStates;
                satisfy WeightDistribution by systemStates;
            }

            part def TrackFrame {
                attribute material : ScalarValues::String = "High-Strength Steel";
                attribute mass :> ISQ::mass;
            }

            part def DriveSprocket {
                attribute teethCount : ScalarValues::Integer;
                attribute diameter :> ISQ::length;
            }

            part def IdlerWheel {
                attribute diameter :> ISQ::length;
                attribute position : ScalarValues::String;
            }

            part def RoadWheel {
                attribute diameter :> ISQ::length;
                part suspension : Suspension;
            }

            part def Suspension {
                attribute springRate :> ISQ::force;
                attribute dampingCoefficient : ScalarValues::Real;
            }

            part def TrackChain {
                part links : TrackLink[120];
                part pads : TrackPad[120];
            }

            part def TensioningMechanism {
                attribute currentTension : Tension;
                port tensionFeedback : TensionFeedbackPort;
            }

            part def TrackController {
                port tensionInput : TensionFeedbackPort;
                attribute maintenanceRequired : ScalarValues::Boolean;
            }
        }

        package StateDefinitions {
            state def TrackSystemStates {
                entry action initial;
                state parked;
                state tensioned {
                    do AdjustTension;
                }
                state driving {
                    do CalculateTraction;
                    do DistributeLoad;
                    do EvaluateWear;
                }
                state braking;
                state maintenance;
                
                transition initial then parked;
                transition parked_to_tensioned
                    first parked
                    accept StartTensioning
                    then tensioned;
                transition tensioned_to_driving
                    first tensioned
                    accept DriveCommand
                    then driving;
                transition driving_to_braking
                    first driving
                    accept BrakeCommand
                    then braking;
                transition braking_to_driving
                    first braking
                    accept DriveCommand
                    then driving;
                transition driving_to_parked
                    first driving
                    accept ParkCommand
                    then parked;
                transition parked_to_maintenance
                    first parked
                    accept MaintenanceSignal
                    then maintenance;
                transition tensioned_to_maintenance
                    first tensioned
                    accept MaintenanceSignal
                    then maintenance;
                transition driving_to_maintenance
                    first driving
                    accept MaintenanceSignal
                    then maintenance;
                transition braking_to_maintenance
                    first braking
                    accept MaintenanceSignal
                    then maintenance;
                transition maintenance_to_parked
                    first maintenance
                    accept MaintenanceComplete
                    then parked;
            }
        }

        package RequirementDefinitions {
            requirement def TensionControl {
                doc /* The system shall maintain track tension within the specified range. */
                attribute minTension : Tension = 5000 [N];
                attribute maxTension : Tension = 15000 [N];
                subject trackSystem : ContinuousTrackSystem;
                constraint { trackSystem.tension >= minTension and trackSystem.tension <= maxTension }
            }
            requirement def WearMonitoring {
                doc /* The system shall monitor wear and signal for service if exceeded. */
                attribute maxWearRate : WearRate = 0.05;
                subject trackSystem : ContinuousTrackSystem;
                constraint { trackSystem.wearRate <= maxWearRate }
            }
            requirement def WeightDistribution {
                doc /* The system shall distribute the vehicle's weight over a large surface area. */
                subject trackSystem : ContinuousTrackSystem;
            }
        }
    }
}
