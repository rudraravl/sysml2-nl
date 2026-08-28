package BiomimeticFinSystem {
    private import SI::*;
    private import ScalarValues::*;

    item def MotionCommand {
        attribute targetAngle :> ISQ::planeAngle;
        attribute targetVelocity :> ISQ::angularVelocity;
        attribute oscillationFrequency :> ISQ::frequency;
    }

    item def AngleFeedback {
        attribute currentAngle :> ISQ::planeAngle;
        attribute currentVelocity :> ISQ::angularVelocity;
    }

    item def TorqueCommand {
        attribute torque :> ISQ::torque;
        attribute direction : Integer;
    }

    item def ThrustOutput {
        attribute thrust :> ISQ::force;
    }

    part def FinBlade {
        attribute length :> ISQ::length;
        attribute width :> ISQ::length;
        attribute mass :> ISQ::mass;
        attribute rigidity : Real;
        attribute generatedThrust :> ISQ::force;
        
        port motionPort {
            in torqueCommand : TorqueCommand;
        }
        port feedbackPort {
            out angleFeedback : AngleFeedback;
        }
        port thrustPort {
            out thrustOutput : ThrustOutput;
        }
        
        action finBehavior {
            action receiveTorque accept TorqueCommand via motionPort;
            then action sendFeedback send new AngleFeedback() to feedbackPort;
            then action sendThrust send new ThrustOutput() to thrustPort;
        }
    }

    part def Motor {
        attribute mass :> ISQ::mass;
        attribute maxTorque :> ISQ::torque;
        
        port controlPort {
            in torqueCommand : TorqueCommand;
        }
        port mechanicalPort {
            out mechanicalTorque : TorqueCommand;
        }
        
        action motorBehavior {
            action receiveControl accept TorqueCommand via controlPort;
            then action sendTorque send new TorqueCommand() to mechanicalPort;
        }
    }

    part def AngleSensor {
        attribute mass :> ISQ::mass;
        attribute accuracy :> ISQ::planeAngle;
        
        port measurementPort {
            in physicalMotion : AngleFeedback;
        }
        port dataPort {
            out angleFeedback : AngleFeedback;
        }
        
        action sensorBehavior {
            action receiveMotion accept AngleFeedback via measurementPort;
            then action sendData send new AngleFeedback() to dataPort;
        }
    }

    part def FinController {
        attribute mass :> ISQ::mass;
        attribute controlError :> ISQ::planeAngle;
        
        port commandPort {
            in motionCommand : MotionCommand;
        }
        port feedbackPort {
            in angleFeedback : AngleFeedback;
        }
        port controlPort {
            out torqueCommand : TorqueCommand;
        }
        
        action controlLoop {
            action receiveCommand accept MotionCommand via commandPort;
            then action receiveFeedback accept AngleFeedback via feedbackPort;
            then action sendControl send new TorqueCommand() to controlPort;
        }
        
        state machine controllerStates {
            state idle;
            state initializing;
            state active;
            
            transition from idle to initializing on trigger startCommand;
            transition from initializing to active on trigger calibrationComplete;
            transition from active to idle on trigger stopCommand;
        }
    }

    part def RoboticFin {
        attribute totalWeight :> ISQ::mass;
        
        port externalCommandPort {
            in motionCommand : MotionCommand;
        }
        port externalThrustPort {
            out thrustOutput : ThrustOutput;
        }
        
        part finController : FinController;
        part motor : Motor;
        part finBlade : FinBlade;
        part angleSensor : AngleSensor;
        
        bind externalCommandPort = finController.commandPort;
        bind externalThrustPort = finBlade.thrustPort;
        
        flow controlFlow of TorqueCommand 
            from finController.controlPort.torqueCommand to motor.controlPort.torqueCommand;
        flow mechanicalFlow of TorqueCommand 
            from motor.mechanicalPort.mechanicalTorque to finBlade.motionPort.torqueCommand;
        flow physicalMotionFlow of AngleFeedback 
            from finBlade.feedbackPort.angleFeedback to angleSensor.measurementPort.physicalMotion;
        flow feedbackFlow of AngleFeedback 
            from angleSensor.dataPort.angleFeedback to finController.feedbackPort.angleFeedback;
    }

    requirement def PerformanceRequirement {
        subject roboticFin : RoboticFin;
    }

    requirement def ThrustRequirement :> PerformanceRequirement {
        attribute minThrust :> ISQ::force;
        require constraint { roboticFin.finBlade.generatedThrust >= minThrust }
    }

    requirement def AccuracyRequirement :> PerformanceRequirement {
        attribute maxError :> ISQ::planeAngle;
        require constraint { roboticFin.finController.controlError <= maxError }
    }

    requirement def WeightRequirement :> PerformanceRequirement {
        attribute maxWeight :> ISQ::mass;
        require constraint { roboticFin.totalWeight <= maxWeight }
    }
    
    requirement systemRequirements {
        subject roboticFin : RoboticFin;
        requirement thrustReq : ThrustRequirement {
            minThrust = 50 [N];
        }
        requirement accuracyReq : AccuracyRequirement {
            maxError = 0.01 [rad];
        }
        requirement weightReq : WeightRequirement {
            maxWeight = 2.5 [kg];
        }
    }
}
