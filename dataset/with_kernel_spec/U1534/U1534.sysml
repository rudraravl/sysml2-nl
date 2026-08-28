package WheelAndAxleLiftingSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import VerificationCases::*;
    
    attribute def EfficiencyValue :> ScalarValues::Real;
    
    port def InputForcePort {
        attribute appliedForce : ISQ::ForceValue;
    }
    
    port def RotationPort {
        attribute torque : ISQ::TorqueValue;
        attribute angularVelocity : ISQ::angularVelocity;
    }
    
    port def LiftingCablePort {
        attribute linearForce : ISQ::ForceValue;
        attribute displacement : ISQ::LengthValue;
    }
    
    part def Wheel {
        doc /* Large wheel where operator applies input force to generate torque */
        attribute radius : ISQ::LengthValue = 0.5[m];
        attribute inertia : ISQ::momentOfInertia;
        
        port inputForce : InputForcePort;
        port outputRotation : RotationPort;
        
        action applyForce {
            in appliedForce : ISQ::ForceValue;
            in wheelRadius : ISQ::LengthValue;
            out generatedTorque : ISQ::TorqueValue;
        }
        
        action rotate {
            in torque : ISQ::TorqueValue;
            in inertia : ISQ::momentOfInertia;
            out angularVelocity : ISQ::angularVelocity;
        }
        
        state machine WheelState {
            state stationary;
            state rotating;
            transition t1 : stationary -> rotating {
                guard { inputForce.appliedForce > 0[N] }
            }
            transition t2 : rotating -> stationary {
                guard { inputForce.appliedForce == 0[N] }
            }
        }
    }
    
    part def Axle {
        doc /* Smaller-diameter axle fixed to wheel center, converts torque to linear force */
        attribute radius : ISQ::LengthValue = 0.1[m];
        attribute inertia : ISQ::momentOfInertia;
        
        port inputRotation : RotationPort;
        port outputCable : LiftingCablePort;
        
        action transmitTorque {
            in torque : ISQ::TorqueValue;
            in axleRadius : ISQ::LengthValue;
            out linearForce : ISQ::ForceValue;
        }
        
        state machine AxleState {
            state idle;
            state spinning;
            transition t1 : idle -> spinning {
                guard { inputRotation.torque > 0[N*m] }
            }
            transition t2 : spinning -> idle {
                guard { inputRotation.torque == 0[N*m] }
            }
        }
    }
    
    part def Load {
        doc /* Object to be lifted, attached to axle via cable */
        attribute mass : ISQ::MassValue = 75[kg];
        attribute weight : ISQ::ForceValue = mass * 9.81[m/s^2];
        attribute height : ISQ::LengthValue = 0[m];
        
        port loadCable : LiftingCablePort;
        
        action beLifted {
            in liftingForce : ISQ::ForceValue;
            in loadWeight : ISQ::ForceValue;
            out netForce : ISQ::ForceValue;
            out acceleration : ISQ::acceleration;
        }
        
        state machine LoadState {
            state onGround;
            state lifted;
            state inMotion;
            transition t1 : onGround -> inMotion {
                guard { loadCable.linearForce > weight }
            }
            transition t2 : inMotion -> lifted {
                guard { height > 0[m] }
            }
            transition t3 : lifted -> inMotion {
                guard { loadCable.linearForce != weight }
            }
            transition t4 : lifted -> onGround {
                guard { height == 0[m] }
            }
        }
    }
    
    part def LiftingSystem {
        doc /* Complete wheel and axle lifting system providing mechanical advantage */
        part wheel : Wheel {
            :>> radius = 0.5[m];
        }
        part axle : Axle {
            :>> radius = 0.1[m];
        }
        part load : Load {
            :>> mass = 75[kg];
        }
        
        connect wheel.outputRotation to axle.inputRotation;
        connect axle.outputCable to load.loadCable;
        
        attribute mechanicalAdvantage : ScalarValues::Real = wheel.radius / axle.radius;
        attribute efficiency : EfficiencyValue = 0.90;
        attribute inputForceApplied : ISQ::ForceValue;
        attribute outputLiftingForce : ISQ::ForceValue;
        
        state machine SystemState {
            state idle;
            state engaged;
            state lifting;
            state holding;
            transition t1 : idle -> engaged {
                guard { inputForceApplied > 0[N] }
            }
            transition t2 : engaged -> lifting {
                guard { outputLiftingForce > load.weight }
            }
            transition t3 : lifting -> holding {
                guard { outputLiftingForce == load.weight and load.height > 0[m] }
            }
            transition t4 : holding -> lifting {
                guard { outputLiftingForce > load.weight }
            }
            transition t5 : holding -> idle {
                guard { inputForceApplied == 0[N] and load.height == 0[m] }
            }
            transition t6 : lifting -> idle {
                guard { inputForceApplied == 0[N] and load.height == 0[m] }
            }
            transition t7 : engaged -> idle {
                guard { inputForceApplied == 0[N] }
            }
            transition t8 : holding -> engaged {
                guard { inputForceApplied > 0[N] and outputLiftingForce != load.weight }
            }
            transition t9 : lifting -> engaged {
                guard { inputForceApplied > 0[N] and outputLiftingForce <= load.weight }
            }
        }
    }
    
    requirement def ForceMagnificationRequirement {
        doc /* The system shall multiply input force by at least 5 times through mechanical advantage. */
        subject system : LiftingSystem;
        attribute mechanicalAdvantage : ScalarValues::Real = system.mechanicalAdvantage;
        require constraint { mechanicalAdvantage >= 5.0 }
    }
    
    requirement def LoadCapacityRequirement {
        doc /* The system shall be capable of lifting loads up to 100 kg. */
        subject system : LiftingSystem;
        attribute maxLoad : ISQ::MassValue = 100[kg];
        attribute actualLoad : ISQ::MassValue = system.load.mass;
        require constraint { actualLoad <= maxLoad }
    }
    
    requirement def EfficiencyRequirement {
        doc /* The system shall operate with at least 85% efficiency to minimize energy loss. */
        subject system : LiftingSystem;
        attribute efficiency : EfficiencyValue = system.efficiency;
        require constraint { efficiency >= 0.85 }
    }
    
    requirement liftingSystemSpecification {
        doc /* Overall performance requirements for the wheel and axle lifting system. */
        subject sys : LiftingSystem;
        requirement magnification : ForceMagnificationRequirement {
            subject = sys;
        }
        requirement capacity : LoadCapacityRequirement {
            subject = sys;
        }
        requirement efficiency : EfficiencyRequirement {
            subject = sys;
        }
    }
    
    verification def ForceMagnificationTest {
        doc /* Verification case to validate force magnification against requirements */
        subject testSystem : LiftingSystem;
        objective magnificationObjective {
            verify ForceMagnificationRequirement;
        }
        
        action applyTestForce {
            in part testSys : LiftingSystem = testSystem;
            in testForce : ISQ::ForceValue = 20[N];
            out measuredOutputForce : ISQ::ForceValue;
        }
        
        action evaluateMagnification {
            in mechanicalAdv : ScalarValues::Real = testSystem.mechanicalAdvantage;
            out verdict : VerdictKind = PassIf(mechanicalAdv >= 5.0);
        }
        
        return finalVerdict : VerdictKind = evaluateMagnification.verdict;
    }
    
    part liftingSystemConfig : LiftingSystem {
        doc /* Specific configuration for 75 kg lifting task with standard wheel and axle */
        part wheel : Wheel {
            :>> radius = 0.5[m];
        }
        part axle : Axle {
            :>> radius = 0.1[m];
        }
        part load : Load {
            :>> mass = 75[kg];
        }
    }
    
    analysis def LiftingAnalysis {
        doc /* Analysis to determine minimum input force required for lifting the configured load */
        subject analysisSystem : LiftingSystem = liftingSystemConfig;
        requirement systemRequirements : liftingSystemSpecification;
        
        return requiredInputForce : ISQ::ForceValue;
        
        action calculateRequiredForce {
            in loadMass : ISQ::MassValue = analysisSystem.load.mass;
            in mechAdv : ScalarValues::Real = analysisSystem.mechanicalAdvantage;
            in efficiency : EfficiencyValue = analysisSystem.efficiency;
            out minInputForce : ISQ::ForceValue;
        }
        
        objective liftingObjective {
            verify ForceMagnificationRequirement;
            verify LoadCapacityRequirement;
            verify EfficiencyRequirement;
        }
    }
}
