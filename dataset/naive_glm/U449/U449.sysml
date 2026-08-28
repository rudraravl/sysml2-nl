package WartenbergWheelSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    item def TactileStimulus {
        attribute pinPointPressure : Force;
    }
    
    item def DermatomeMap;

    port def MechanicalMountPort;
    
    port def RotationPort {
        attribute angularVelocity : Real;
    }
    
    port def SkinContactPort {
        attribute appliedNormalForce : Force;
        out tactileStimulus : TactileStimulus;
    }

    part def Handle {
        attribute mass : Mass = 25[g];
        attribute length : Length = 120[mm];
        attribute isErgonomic : Boolean = true;
        port mountPort : MechanicalMountPort;
    }

    part def Axle {
        attribute frictionCoefficient : Real = 0.02;
        port upperMount : MechanicalMountPort;
        port lowerRotation : RotationPort;
    }

    part def Pin {
        attribute tipRadius : Length = 0.5[mm];
        attribute isBlunt : Boolean = true;
        attribute spacing : Length = 7.85[mm];
        port tipContact : SkinContactPort;
    }

    part def Wheel {
        attribute diameter : Length = 50[mm];
        attribute pinCount : Integer = 20;
        port hubPort : RotationPort;
        port perimeterPort : SkinContactPort;
        
        part pins[pinCount] : Pin;
    }

    part def WartenbergWheelDevice {
        attribute totalMass : Mass = 45[g];
        attribute maxSafeForce : Force = 2.5[N];
        
        port patientContact : SkinContactPort;
        
        part handle : Handle;
        part axle : Axle;
        part wheel : Wheel;
        
        connection handleToAxle connect handle.mountPort to axle.upperMount;
        connection axleToWheel connect axle.lowerRotation to wheel.hubPort;
        connection skinContactInterface connect wheel.perimeterPort to patientContact;
        
        attribute isPositioned : Boolean = false;
        attribute isRolling : Boolean = false;
        attribute isLifted : Boolean = false;
        
        state deviceStates {
            state Ready;
            state PositionedOnSkin;
            state ActivelyStimulating;
            
            transition ready_to_positioned from Ready to PositionedOnSkin when isPositioned;
            transition positioned_to_stimulating from PositionedOnSkin to ActivelyStimulating when isRolling;
            transition stimulating_to_ready from ActivelyStimulating to Ready when isLifted;
        }
    }

    requirement def NeurologicalAssessmentRequirement {
        doc /* The device shall test a patient's sensory nerve function by providing controlled tactile stimulation to the skin. */
        subject device : WartenbergWheelDevice;
        constraint { device.patientContact.tactileStimulus->notEmpty() }
    }

    requirement def PinCountRequirement {
        doc /* The wheel shall be studded with approximately 20 evenly-spaced pins. */
        subject device : WartenbergWheelDevice;
        constraint { device.wheel.pinCount == 20 }
    }

    requirement def BluntTipSafetyRequirement {
        doc /* The pins shall have blunt tips to prevent piercing or damaging the patient's skin. */
        subject device : WartenbergWheelDevice;
        constraint { device.wheel.pins->forAll(p | p.isBlunt == true) }
        constraint { device.wheel.pins->forAll(p | p.tipRadius >= 0.4[mm]) }
    }

    requirement def MaxForceLimitRequirement {
        doc /* The applied force shall not exceed strict safety limits to prevent skin damage. */
        subject device : WartenbergWheelDevice;
        constraint { device.patientContact.appliedNormalForce <= device.maxSafeForce }
    }

    requirement def LightweightDesignRequirement {
        doc /* The device shall be lightweight and portable for easy clinical use. */
        subject device : WartenbergWheelDevice;
        constraint { device.totalMass <= 50[g] }
    }

    requirement def DermatomeMappingRequirement {
        doc /* The stimulus delivered shall be consistent and repeatable to map out dermatomes and identify potential neurological deficits. */
        subject device : WartenbergWheelDevice;
        attribute deliverConsistentStimulus : Boolean = true;
        constraint { deliverConsistentStimulus == true }
    }

    action def PerformExamination {
        in practitionerForce : Force;
        out dermatomeMap : DermatomeMap;
        
        part instrument : WartenbergWheelDevice;
        
        action positionDevice;
        action rollDevice;
        action evaluateSensation;
        
        first positionDevice;
        then rollDevice;
        then evaluateSensation;
    }
}
