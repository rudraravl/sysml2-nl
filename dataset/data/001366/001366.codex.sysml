package BarrettTechnologyHighLevelModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Percent :> Real {
        range = "0.0..100.0";
    }

    attribute def Millisecond :> Real {
        unit = "ms";
    }

    attribute def Newton :> Real {
        unit = "N";
    }

    attribute def NewtonMeter :> Real {
        unit = "N*m";
    }

    attribute def Degree :> Real {
        unit = "deg";
    }

    attribute def Grams :> Real {
        unit = "g";
    }

    attribute def Volt :> Real {
        unit = "V";
    }

    attribute def Ampere :> Real {
        unit = "A";
    }

    item def ElectricalPower {
        attribute voltage : Volt;
        attribute current : Ampere;
    }

    item def MotionCommand {
        attribute targetAperture : Degree;
        attribute targetSpread : Degree;
        attribute closingForceLimit : Newton;
        attribute speedPercent : Percent;
    }

    item def TactileObservation {
        attribute contactDetected : Boolean;
        attribute normalForce : Newton;
        attribute slipDetected : Boolean;
    }

    item def JointState {
        attribute jointAngle : Degree;
        attribute jointVelocity : Degree;
        attribute jointTorque : NewtonMeter;
    }

    item def ObjectEstimate {
        attribute objectMass : Grams;
        attribute objectWidth : Real;
        attribute graspConfidence : Percent;
    }

    item def GraspStatus {
        attribute graspStable : Boolean;
        attribute holdingForce : Newton;
        attribute faultActive : Boolean;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def CommandInputPort {
        in item command : MotionCommand;
    }

    port def StatusOutputPort {
        out item status : GraspStatus;
        out item objectEstimate : ObjectEstimate;
    }

    port def JointDrivePort {
        out item driveCommand : MotionCommand;
        in item jointState : JointState;
    }

    port def TactileSensorPort {
        out item observation : TactileObservation;
    }

    part def BarrettHandSystem {
        doc /* High-level system based on Barrett Technology robotic manipulation products, such as the BarrettHand. Its primary function is to perform adaptive robotic grasping and secure object handling for manipulation tasks. */

        port powerPort : PowerInputPort;
        port commandPort : CommandInputPort;
        port statusPort : StatusOutputPort;

        attribute nominalSupplyVoltage : Volt = 24.0;
        attribute maximumContinuousCurrent : Ampere = 5.0;
        attribute maximumGripForce : Newton = 80.0;
        attribute commandCycleTime : Millisecond = 10.0;
        attribute handMass : Grams = 1180.0;

        part controller : EmbeddedGraspController;
        part palm : StructuralPalm;
        part finger1 : AdaptiveFinger;
        part finger2 : AdaptiveFinger;
        part finger3 : AdaptiveFinger;
        part spreadMechanism : FingerSpreadMechanism;
        part tactileSystem : TactileSensingSystem;
        part safetyMonitor : SafetyMonitor;

        connect powerPort.power to controller.powerPort.power;
        connect commandPort.command to controller.commandPort.command;
        connect controller.statusPort.status to statusPort.status;
        connect controller.statusPort.objectEstimate to statusPort.objectEstimate;

        connect controller.fingerDrive1.driveCommand to finger1.drivePort.driveCommand;
        connect controller.fingerDrive2.driveCommand to finger2.drivePort.driveCommand;
        connect controller.fingerDrive3.driveCommand to finger3.drivePort.driveCommand;
        connect controller.spreadDrive.driveCommand to spreadMechanism.drivePort.driveCommand;

        connect finger1.drivePort.jointState to controller.fingerDrive1.jointState;
        connect finger2.drivePort.jointState to controller.fingerDrive2.jointState;
        connect finger3.drivePort.jointState to controller.fingerDrive3.jointState;
        connect spreadMechanism.drivePort.jointState to controller.spreadDrive.jointState;

        connect finger1.tactilePort.observation to tactileSystem.sensorInput1.observation;
        connect finger2.tactilePort.observation to tactileSystem.sensorInput2.observation;
        connect finger3.tactilePort.observation to tactileSystem.sensorInput3.observation;
        connect tactileSystem.aggregateOutput.observation to controller.tactileInput.observation;

        connect safetyMonitor.safeCommandOut.command to controller.safeCommandIn.command;
        connect commandPort.command to safetyMonitor.commandIn.command;
    }

    part def EmbeddedGraspController {
        port powerPort : PowerInputPort;
        port commandPort : CommandInputPort;
        port safeCommandIn : CommandInputPort;
        port tactileInput : TactileSensorPort;
        port statusPort : StatusOutputPort;

        port fingerDrive1 : JointDrivePort;
        port fingerDrive2 : JointDrivePort;
        port fingerDrive3 : JointDrivePort;
        port spreadDrive : JointDrivePort;

        attribute loopPeriod : Millisecond = 10.0;
        attribute graspConfidenceThreshold : Percent = 85.0;
        attribute minimumHoldForce : Newton = 8.0;

        perform action interpretCommand;
        perform action coordinateFingerClosure;
        perform action estimateObject;
        perform action regulateHoldForce;
        perform action reportStatus;

        action interpretCommand {
            in item requestedCommand : MotionCommand;
            out item validatedCommand : MotionCommand;
        }

        action coordinateFingerClosure {
            in item validatedCommand : MotionCommand;
            in item tactileFeedback : TactileObservation;
            out item fingerCommand : MotionCommand;
        }

        action estimateObject {
            in item tactileFeedback : TactileObservation;
            in item jointFeedback : JointState;
            out item estimate : ObjectEstimate;
        }

        action regulateHoldForce {
            in item tactileFeedback : TactileObservation;
            out item correctedCommand : MotionCommand;
        }

        action reportStatus {
            in item estimate : ObjectEstimate;
            in item tactileFeedback : TactileObservation;
            out item status : GraspStatus;
        }

        state machine graspControlStateMachine {
            state idle;
            state awaitingCommand;
            state preshapeHand;
            state closingFingers;
            state detectingContact;
            state stabilizingGrip;
            state holdingObject;
            state releasingObject;
            state faulted;

            initial then idle;

            transition idleToAwaiting
                first idle
                then awaitingCommand;

            transition commandReceived
                first awaitingCommand
                then preshapeHand
                accept MotionCommand;

            transition preshapeComplete
                first preshapeHand
                then closingFingers
                if fingerDrive1.jointState.jointAngle >= 0.0;

            transition contactDetected
                first closingFingers
                then detectingContact
                if tactileInput.observation.contactDetected == true;

            transition contactValidated
                first detectingContact
                then stabilizingGrip
                if tactileInput.observation.normalForce >= 2.0;

            transition gripStable
                first stabilizingGrip
                then holdingObject
                if statusPort.status.graspStable == true;

            transition releaseRequested
                first holdingObject
                then releasingObject
                accept MotionCommand
                if commandPort.command.targetAperture > 70.0;

            transition releaseComplete
                first releasingObject
                then awaitingCommand;

            transition faultDetected
                first idle
                then faulted
                if statusPort.status.faultActive == true;

            transition recover
                first faulted
                then awaitingCommand
                accept MotionCommand;
        }
    }

    part def AdaptiveFinger {
        port drivePort : JointDrivePort;
        port tactilePort : TactileSensorPort;

        attribute maximumFlexion : Degree = 140.0;
        attribute maximumTipForce : Newton = 30.0;
        attribute reflectedInertia : Real = 0.006;

        part proximalLink : FingerLink {
            attribute length = 50.0;
        }

        part distalLink : FingerLink {
            attribute length = 70.0;
        }

        part tendonDrive : TendonDriveActuator;
        part jointEncoder : JointEncoder;
        part tactilePad : FingertipTactilePad;

        connect tendonDrive.drivePort.driveCommand to drivePort.driveCommand;
        connect tendonDrive.drivePort.jointState to drivePort.jointState;
        connect tactilePad.tactilePort.observation to tactilePort.observation;
    }

    part def FingerLink {
        attribute length : Real;
        attribute mass : Grams = 95.0;
        attribute allowableLoad : Newton = 100.0;
    }

    part def TendonDriveActuator {
        port drivePort : JointDrivePort;

        attribute stallTorque : NewtonMeter = 1.2;
        attribute continuousTorque : NewtonMeter = 0.45;
        attribute maximumSpeed : Degree = 180.0;
    }

    part def JointEncoder {
        attribute resolution : Degree = 0.1;
        attribute updatePeriod : Millisecond = 5.0;
    }

    part def FingertipTactilePad {
        port tactilePort : TactileSensorPort;

        attribute forceResolution : Newton = 0.1;
        attribute slipDetectionLatency : Millisecond = 25.0;
        attribute contactArea : Real = 320.0;
    }

    part def FingerSpreadMechanism {
        port drivePort : JointDrivePort;

        attribute minimumSpread : Degree = 0.0;
        attribute maximumSpread : Degree = 180.0;
        attribute nominalSpread : Degree = 90.0;
    }

    part def StructuralPalm {
        attribute palmWidth : Real = 100.0;
        attribute palmMass : Grams = 420.0;
        attribute mountingPatternDiameter : Real = 63.0;
    }

    part def TactileSensingSystem {
        port sensorInput1 : TactileSensorPort;
        port sensorInput2 : TactileSensorPort;
        port sensorInput3 : TactileSensorPort;
        port aggregateOutput : TactileSensorPort;

        attribute fusionPeriod : Millisecond = 10.0;
        attribute contactForceThreshold : Newton = 1.5;
        attribute slipConfidenceThreshold : Percent = 70.0;

        action fuseTactileInputs {
            in item fingertip1 : TactileObservation;
            in item fingertip2 : TactileObservation;
            in item fingertip3 : TactileObservation;
            out item aggregateObservation : TactileObservation;
        }
    }

    part def SafetyMonitor {
        port commandIn : CommandInputPort;
        port safeCommandOut : CommandInputPort;

        attribute maximumAllowedForce : Newton = 80.0;
        attribute maximumAllowedSpeed : Percent = 100.0;
        attribute overcurrentLimit : Ampere = 6.0;
        attribute shutdownLatency : Millisecond = 20.0;

        action limitCommand {
            in item requestedCommand : MotionCommand;
            out item safeCommand : MotionCommand;
        }

        action detectFault {
            in item power : ElectricalPower;
            in item status : GraspStatus;
            out item faultPresent : Boolean;
        }

        state machine safetyStateMachine {
            state normal;
            state limiting;
            state protectiveStop;

            initial then normal;

            transition forceLimitExceeded
                first normal
                then limiting
                if commandIn.command.closingForceLimit > maximumAllowedForce;

            transition commandLimited
                first limiting
                then normal;

            transition criticalFault
                first normal
                then protectiveStop
                if commandIn.command.speedPercent > maximumAllowedSpeed;

            transition resetAfterStop
                first protectiveStop
                then normal
                accept MotionCommand;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject hand : BarrettHandSystem;

        require constraint {
            hand.maximumGripForce >= 60.0
        }

        doc /* The system shall adaptively grasp, stabilize, hold, and release objects using coordinated multi-finger motion and tactile feedback. */
    }

    requirement def CommandResponseRequirement {
        subject controller : EmbeddedGraspController;

        require constraint {
            controller.loopPeriod <= 10.0
        }

        doc /* The embedded controller shall update grasp control commands at least every 10 ms during active grasping. */
    }

    requirement def SafeGripRequirement {
        subject safety : SafetyMonitor;

        require constraint {
            safety.maximumAllowedForce <= 80.0
        }

        doc /* The system shall limit commanded grip force to prevent excessive contact force on handled objects. */
    }

    requirement def TactileDetectionRequirement {
        subject tactile : TactileSensingSystem;

        require constraint {
            tactile.contactForceThreshold <= 2.0
        }

        doc /* The tactile sensing system shall detect fingertip contact at low force to support adaptive closure. */
    }

    requirement def ObjectHoldingRequirement {
        subject controller : EmbeddedGraspController;

        require constraint {
            controller.minimumHoldForce >= 5.0
        }

        doc /* The controller shall maintain sufficient hold force after grasp stabilization while monitoring for slip. */
    }

    satisfy PrimaryFunctionRequirement by BarrettHandSystem;
    satisfy CommandResponseRequirement by EmbeddedGraspController;
    satisfy SafeGripRequirement by SafetyMonitor;
    satisfy TactileDetectionRequirement by TactileSensingSystem;
    satisfy ObjectHoldingRequirement by EmbeddedGraspController;
}