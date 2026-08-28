package RadiationTherapySystem {

    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====

    value type Length :> Real {
        unit mm;
    }
    value type Position :> Real {
        unit mm;
    }
    value type PositionError :> Real {
        unit mm;
    }
    value type Velocity :> Real {
        unit 'mm/s';
    }
    value type Torque :> Real {
        unit 'mN*m';
    }
    value type Dose :> Real {
        unit 'Gy';
    }
    value type DoseRate :> Real {
        unit 'Gy/min';
    }
    value type Time :> Real {
        unit s;
    }
    value type LeafIndex :> Integer;
    value type PlanID :> String;

    // ===== Item Types =====

    item def TreatmentPlan {
        attribute id : PlanID;
        attribute leafTargets : Position[160] :> ordered;
        attribute prescribedDose : Dose;
        attribute doseRate : DoseRate;
        attribute duration : Time;
    }

    item def LeafCommand {
        attribute leafId : LeafIndex;
        attribute targetPosition : Position;
    }

    item def LeafFeedback {
        attribute leafId : LeafIndex;
        attribute measuredPosition : Position;
        attribute inTolerance : Boolean;
    }

    item def BeamControlSignal {
        attribute activate : Boolean;
        attribute doseRate : DoseRate;
    }

    item def InterlockStatus {
        attribute doorClosed : Boolean;
        attribute emergencyStopActive : Boolean;
        attribute allLeavesVerified : Boolean;
        attribute beamPermitted : Boolean;
    }

    // ===== Port Definitions =====

    port def PlanPort {
        out plan : TreatmentPlan;
    }

    port def CommandPort {
        out command : LeafCommand;
    }

    port def FeedbackPort {
        in feedback : LeafFeedback;
    }

    port def BeamControlPort {
        out signal : BeamControlSignal;
    }

    port def InterlockPort {
        out status : InterlockStatus;
    }

    port def DoorSensorPort {
        out doorClosed : Boolean;
    }

    port def EStopPort {
        out triggered : Boolean;
    }

    // ===== Leaf (individual) =====

    part def Leaf {
        attribute index : LeafIndex;
        attribute bank : String; // "left" or "right"
        attribute targetPosition : Position;
        attribute currentPosition : Position;
        attribute tolerance : PositionError = 0.1 [mm];

        port commandIn : CommandPort;
        port feedbackOut : FeedbackPort;

        part motor : Motor {
            attribute commandedTorque : Torque;
            attribute maxVelocity : Velocity = 50.0 ['mm/s'];
        }
        part sensor : PositionSensor {
            attribute resolution : PositionError = 0.01 [mm];
            attribute measuredPosition : Position;
        }

        action def MoveToTarget {
            in target : Position;
            in measured : Position;
            out torque : Torque;
        }

        action def VerifyPosition {
            in target : Position;
            in measured : Position;
            out inTolerance : Boolean;
        }

        exhibit state leafBehavior {
            entry; then Idle;
            state Idle;
            transition Idle -> Moving
                when commandIn.command.targetPosition changed;
            state Moving {
                // closed-loop control action
                do send commandIn.command;
            }
            transition Moving -> AtTarget
                when abs(sensor.measuredPosition - targetPosition) <= tolerance;
            state AtTarget;
            transition AtTarget -> Moving
                when commandIn.command.targetPosition changed;
        }

        connection motorToSensor connect motor to sensor;
    }

    part def Motor {
        attribute commandedTorque : Torque;
        attribute maxVelocity : Velocity = 50.0 ['mm/s'];
    }

    part def PositionSensor {
        attribute resolution : PositionError = 0.01 [mm];
        attribute measuredPosition : Position;
    }

    // ===== Multileaf Collimator =====

    part def MultileafCollimator {
        attribute leafCount : Integer = 160;
        attribute bankCount : Integer = 2;
        attribute leavesPerBank : Integer = 80;

        port commandIn : CommandPort;
        port feedbackOut : FeedbackPort;

        part leftBank : Leaf[80] {
            attribute bank = "left";
        }
        part rightBank : Leaf[80] {
            attribute bank = "right";
        }

        // Distribute commands to leaves
        connection distributeCommands connect commandIn to leftBank.commandIn;
        connection distributeCommandsRight connect commandIn to rightBank.commandIn;

        // Aggregate feedback
        connection aggregateFeedbackLeft connect leftBank.feedbackOut to feedbackOut;
        connection aggregateFeedbackRight connect rightBank.feedbackOut to feedbackOut;
    }

    // ===== Central Controller =====

    part def CentralController {
        port planIn : PlanPort;
        port commandOut : CommandPort;
        port feedbackIn : FeedbackPort;
        port interlockIn : InterlockPort;
        port beamControlOut : BeamControlPort;

        attribute currentPlan : TreatmentPlan;
        attribute allLeavesVerified : Boolean = false;

        action def LoadPlan {
            in plan : TreatmentPlan;
            out loaded : Boolean;
        }

        action def DispatchCommands {
            in targets : Position[160];
            out commands : LeafCommand[160];
        }

        action def MonitorPositions {
            in feedback : LeafFeedback[*];
            out verified : Boolean;
        }

        exhibit state controllerBehavior {
            entry; then Standby;
            state Standby {
                entry { allLeavesVerified = false; }
            }
            transition Standby -> PlanLoaded
                when planIn.plan received;
            state PlanLoaded {
                do LoadPlan;
            }
            transition PlanLoaded -> Positioning
                when currentPlan loaded;
            state Positioning {
                do DispatchCommands;
                do MonitorPositions;
            }
            transition Positioning -> Ready
                when allLeavesVerified == true;
            state Ready {
                do MonitorPositions;
            }
            transition Ready -> Treating
                when interlockIn.status.beamPermitted == true;
            state Treating {
                do MonitorPositions;
                do send beamControlOut.signal;
            }
            transition Treating -> Standby
                when treatment complete;
            transition Positioning -> Standby
                when interlockIn.status.emergencyStopActive == true;
            transition Ready -> Standby
                when interlockIn.status.emergencyStopActive == true;
            transition Treating -> Standby
                when interlockIn.status.emergencyStopActive == true;
        }
    }

    // ===== Radiation Source =====

    part def RadiationSource {
        port beamControlIn : BeamControlPort;
        port beamOut : BeamOutputPort;

        attribute isEmitting : Boolean = false;
        attribute currentDoseRate : DoseRate;
        attribute cumulativeDose : Dose;

        port def BeamOutputPort {
            out beamActive : Boolean;
            out doseRate : DoseRate;
        }

        exhibit state sourceBehavior {
            entry; then Off;
            state Off {
                entry { isEmitting = false; }
            }
            transition Off -> Emitting
                when beamControlIn.signal.activate == true;
            state Emitting {
                entry { isEmitting = true; }
                do emit beam;
            }
            transition Emitting -> Off
                when beamControlIn.signal.activate == false;
        }
    }

    // ===== Safety Interlock System =====

    part def SafetyInterlockSystem {
        port doorSensorIn : DoorSensorPort;
        port eStopIn : EStopPort;
        port feedbackIn : FeedbackPort;
        port interlockOut : InterlockPort;

        attribute doorClosed : Boolean;
        attribute emergencyStopActive : Boolean;
        attribute allLeavesVerified : Boolean = false;
        attribute beamPermitted : Boolean = false;

        action def EvaluateInterlocks {
            in door : Boolean;
            in estop : Boolean;
            in leavesOK : Boolean;
            out permit : Boolean;
        }

        exhibit state interlockBehavior {
            entry; then Checking;
            state Checking {
                do EvaluateInterlocks;
            }
            transition Checking -> Safe
                when (doorClosed == true
                    and emergencyStopActive == false
                    and allLeavesVerified == true);
            state Safe {
                entry { beamPermitted = true; }
            }
            transition Safe -> Checking
                when (doorClosed == false
                    or emergencyStopActive == true
                    or allLeavesVerified == false);
            transition Safe -> Tripped
                when emergencyStopActive == true;
            state Tripped {
                entry { beamPermitted = false; }
            }
            transition Tripped -> Checking
                when emergencyStopActive == false;
        }
    }

    // ===== Door Sensor =====

    part def DoorSensor {
        port doorOut : DoorSensorPort;
        attribute isClosed : Boolean;
    }

    part def EmergencyStop {
        port eStopOut : EStopPort;
        attribute triggered : Boolean = false;
    }

    // ===== Top-level System =====

    part def RadiationTherapySystem {
        part controller : CentralController;
        part mlc : MultileafCollimator;
        part source : RadiationSource;
        part interlock : SafetyInterlockSystem;
        part doorSensor : DoorSensor;
        part eStop : EmergencyStop;

        // Plan input to controller
        // (external plan source connects via controller.planIn)

        // Controller commands MLC
        connection cmdToMLC connect controller.commandOut to mlc.commandIn;

        // MLC feedback to controller
        connection feedbackToController connect mlc.feedbackOut to controller.feedbackIn;

        // MLC feedback to interlock (for leaf verification)
        connection feedbackToInterlock connect mlc.feedbackOut to interlock.feedbackIn;

        // Controller beam control to source
        connection beamControl connect controller.beamControlOut to source.beamControlIn;

        // Interlock status to controller
        connection interlockToController connect interlock.interlockOut to controller.interlockIn;

        // Door sensor to interlock
        connection doorToInterlock connect doorSensor.doorOut to interlock.doorSensorIn;

        // E-stop to interlock
        connection eStopToInterlock connect eStop.eStopOut to interlock.eStopIn;
    }

    // ===== Requirements =====

    requirement def TreatmentAccuracyRequirement {
        doc "Each leaf shall reach its target position within 0.1 mm accuracy."
        attribute tolerance : PositionError = 0.1 [mm];
        subject leaf : Leaf;
        objective {
            abs(leaf.sensor.measuredPosition - leaf.targetPosition) <= tolerance
        }
    }

    requirement def LeafCountRequirement {
        doc "The MLC shall consist of 160 leaves arranged in two opposing banks of 80."
        subject mlc : MultileafCollimator;
        objective {
            mlc.leafCount == 160
            and mlc.leavesPerBank == 80
            and mlc.bankCount == 2
        }
    }

    requirement def InterlockRequirement {
        doc "The radiation source shall not activate unless the door is closed, no e-stop is active, and all 160 leaves are verified in position."
        subject interlock : SafetyInterlockSystem;
        objective {
            interlock.beamPermitted == true
            implies (interlock.doorClosed == true
                and interlock.emergencyStopActive == false
                and interlock.allLeavesVerified == true)
        }
    }

    requirement def ContinuousMonitoringRequirement {
        doc "During treatment, leaf positions shall be monitored continuously to ensure accuracy and safety."
        subject controller : CentralController;
        objective {
            controller.controllerBehavior.Treating.do MonitorPositions
        }
    }

    requirement def PlanDrivenPositioningRequirement {
        doc "Leaf positions shall be dictated by a pre-loaded treatment plan specifying exact target positions for all 160 leaves."
        subject controller : CentralController;
        objective {
            controller.currentPlan.leafTargets.size == 160
        }
    }

    requirement def StandbyStartRequirement {
        doc "The system shall start in standby mode and transition through plan loading, positioning, and treatment states."
        subject system : RadiationTherapySystem;
        objective {
            system.controller.controllerBehavior.initial == Standby
        }
    }

    // ===== Satisfaction =====

    satisfaction mlcLeafCount : LeafCountRequirement {
        subject mlc : MultileafCollimator;
    }

    satisfaction interlockSafety : InterlockRequirement {
        subject interlock : SafetyInterlockSystem;
    }

    satisfaction leafAccuracy : TreatmentAccuracyRequirement {
        subject leaf : Leaf;
    }

    satisfaction continuousMonitor : ContinuousMonitoringRequirement {
        subject controller : CentralController;
    }

    satisfaction planDriven : PlanDrivenPositioningRequirement {
        subject controller : CentralController;
    }

    satisfaction standbyStart : StandbyStartRequirement {
        subject system : RadiationTherapySystem;
    }

}
