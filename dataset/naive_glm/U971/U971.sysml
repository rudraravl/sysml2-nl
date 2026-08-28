package AnimatronicCharacterSystem {
    import ISQ::*;
    import ScalarValues::*;

    value def Distance :> Real { unit 'm'; }
    value def Angle :> Real { unit 'deg'; }
    value def Torque :> Real { unit 'Nm'; }
    value def Temperature :> Real { unit 'degC'; }

    item def ProximityData {
        attribute distance : Distance;
        attribute visitorDetected : Boolean;
    }

    item def ServoCommand {
        attribute targetPosition : Angle;
        attribute maxTorque : Torque;
    }

    item def ServoFeedback {
        attribute currentPosition : Angle;
        attribute currentTorque : Torque;
        attribute currentTemperature : Temperature;
    }

    item def AudioCommand {
        attribute audioTrackId : String;
        attribute volume : Real;
        attribute play : Boolean;
    }

    port def ProximityOut {
        out data : ProximityData;
    }

    port def ServoCmdPort {
        in cmd : ServoCommand;
    }

    port def ServoFbPort {
        out fb : ServoFeedback;
    }

    port def AudioCmdPort {
        in cmd : AudioCommand;
    }

    part def ServoActuator {
        port cmdPort : ServoCmdPort;
        port fbPort : ServoFbPort;
        
        attribute maxTorqueLimit : Torque = 5.0;
        attribute maxTempLimit : Temperature = 70.0;
        
        attribute currentPosition : Angle = 0.0;
        attribute currentTorque : Torque = 0.0;
        attribute currentTemperature : Temperature = 25.0;
    }

    part def ProximitySensor {
        port outPort : ProximityOut;
        attribute maxRange : Distance = 5.0;
    }

    part def SpeakerSystem {
        port inPort : AudioCmdPort;
        attribute maxVolume : Real = 100.0;
    }

    part def ArticulatedJoint {
        part servo : ServoActuator;
        attribute jointName : String;
    }

    part def CharacterBody {
        part headJoint : ArticulatedJoint { :>> jointName = "head"; }
        part neckJoint : ArticulatedJoint { :>> jointName = "neck"; }
        part leftShoulderJoint : ArticulatedJoint { :>> jointName = "leftShoulder"; }
        part rightShoulderJoint : ArticulatedJoint { :>> jointName = "rightShoulder"; }
        part leftElbowJoint : ArticulatedJoint { :>> jointName = "leftElbow"; }
        part rightElbowJoint : ArticulatedJoint { :>> jointName = "rightElbow"; }
        part jawJoint : ArticulatedJoint { :>> jointName = "jaw"; }
        part leftEyeJoint : ArticulatedJoint { :>> jointName = "leftEye"; }
        part rightEyeJoint : ArticulatedJoint { :>> jointName = "rightEye"; }
    }

    state def ControllerStates {
        attribute visitorDetected : Boolean = false;
        attribute animationComplete : Boolean = false;
        attribute resetComplete : Boolean = false;

        state standby {
            entry action enterLowPowerMode;
            do action monitorSensors;
            transition to performance 
                when visitorDetected;
        }
        
        state performance {
            entry action selectAnimation;
            do action executeAnimation;
            transition to neutral 
                when animationComplete;
        }
        
        state neutral {
            entry action resetPosition;
            do action checkSystemHealth;
            transition to standby 
                when resetComplete;
        }
    }

    part def AnimationController {
        port sensorIn1 : ~ProximityOut;
        port sensorIn2 : ~ProximityOut;
        
        port servoCmdOut1 : ~ServoCmdPort;
        port servoCmdOut2 : ~ServoCmdPort;
        port servoCmdOut3 : ~ServoCmdPort;
        port servoCmdOut4 : ~ServoCmdPort;
        port servoCmdOut5 : ~ServoCmdPort;
        port servoCmdOut6 : ~ServoCmdPort;
        port servoCmdOut7 : ~ServoCmdPort;
        port servoCmdOut8 : ~ServoCmdPort;
        port servoCmdOut9 : ~ServoCmdPort;
        
        port servoFbIn1 : ~ServoFbPort;
        port servoFbIn2 : ~ServoFbPort;
        port servoFbIn3 : ~ServoFbPort;
        port servoFbIn4 : ~ServoFbPort;
        port servoFbIn5 : ~ServoFbPort;
        port servoFbIn6 : ~ServoFbPort;
        port servoFbIn7 : ~ServoFbPort;
        port servoFbIn8 : ~ServoFbPort;
        port servoFbIn9 : ~ServoFbPort;
        
        port audioOut : ~AudioCmdPort;
        
        exhibit state behavior : ControllerStates;
    }

    requirement def SafeOperation {
        subject servo : ServoActuator;
        requirement torqueLimit {
            constraint { servo.currentTorque <= servo.maxTorqueLimit }
        }
        requirement tempLimit {
            constraint { servo.currentTemperature <= servo.maxTempLimit }
        }
    }

    requirement def LongTermReliability {
        subject system : AnimatronicCharacter;
        requirement uptimeRequirement {
            constraint { system.uptime > 86400 }
        }
    }

    part def AnimatronicCharacter {
        attribute uptime : Integer;
        
        part controller : AnimationController;
        part body : CharacterBody;
        part sensor1 : ProximitySensor;
        part sensor2 : ProximitySensor;
        part speaker : SpeakerSystem;
        
        satisfy SafeOperation by body.headJoint.servo;
        satisfy SafeOperation by body.neckJoint.servo;
        satisfy SafeOperation by body.leftShoulderJoint.servo;
        satisfy SafeOperation by body.rightShoulderJoint.servo;
        satisfy SafeOperation by body.leftElbowJoint.servo;
        satisfy SafeOperation by body.rightElbowJoint.servo;
        satisfy SafeOperation by body.jawJoint.servo;
        satisfy SafeOperation by body.leftEyeJoint.servo;
        satisfy SafeOperation by body.rightEyeJoint.servo;
        
        satisfy LongTermReliability by AnimatronicCharacter;
        
        connect sensor1.outPort to controller.sensorIn1;
        connect sensor2.outPort to controller.sensorIn2;
        
        connect controller.servoCmdOut1 to body.headJoint.servo.cmdPort;
        connect controller.servoCmdOut2 to body.neckJoint.servo.cmdPort;
        connect controller.servoCmdOut3 to body.leftShoulderJoint.servo.cmdPort;
        connect controller.servoCmdOut4 to body.rightShoulderJoint.servo.cmdPort;
        connect controller.servoCmdOut5 to body.leftElbowJoint.servo.cmdPort;
        connect controller.servoCmdOut6 to body.rightElbowJoint.servo.cmdPort;
        connect controller.servoCmdOut7 to body.jawJoint.servo.cmdPort;
        connect controller.servoCmdOut8 to body.leftEyeJoint.servo.cmdPort;
        connect controller.servoCmdOut9 to body.rightEyeJoint.servo.cmdPort;
        
        connect body.headJoint.servo.fbPort to controller.servoFbIn1;
        connect body.neckJoint.servo.fbPort to controller.servoFbIn2;
        connect body.leftShoulderJoint.servo.fbPort to controller.servoFbIn3;
        connect body.rightShoulderJoint.servo.fbPort to controller.servoFbIn4;
        connect body.leftElbowJoint.servo.fbPort to controller.servoFbIn5;
        connect body.rightElbowJoint.servo.fbPort to controller.servoFbIn6;
        connect body.jawJoint.servo.fbPort to controller.servoFbIn7;
        connect body.leftEyeJoint.servo.fbPort to controller.servoFbIn8;
        connect body.rightEyeJoint.servo.fbPort to controller.servoFbIn9;
        
        connect controller.audioOut to speaker.inPort;
    }
}
