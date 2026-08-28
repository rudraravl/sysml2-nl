package MassSpringSystem {
    private import ISQ::*;
    private import ScalarValues::Real;

    attribute def SpringStiffnessValue :> Real;
    attribute def DampingCoefficientValue :> Real;

    port def MechanicalInterface {
        attribute position : LengthValue;
        attribute force : ForceValue;
    }

    part def FixedMountingPoint {
        attribute position : LengthValue;
        port mechanicalInterface : MechanicalInterface;
    }

    part def Mass {
        attribute mass : MassValue;
        attribute position : LengthValue;
        attribute velocity : SpeedValue;
        attribute acceleration : AccelerationValue;
        
        port mechanicalInterface : MechanicalInterface;
    }

    part def HelicalSpring {
        attribute stiffness : SpringStiffnessValue;
        attribute naturalLength : LengthValue;
        attribute elasticModulus : Real;
        attribute strength : Real;
        attribute maxCompression : LengthValue;
        attribute maxExtension : LengthValue;
        attribute damping : DampingCoefficientValue;
        attribute displacement : LengthValue;
        
        port mountEnd : MechanicalInterface;
        port massEnd : MechanicalInterface;
        
        exhibit state SpringStates {
            entry; then equilibrium;
            state equilibrium;
            transition equilibrium to compressed when displacement < 0 [m];
            transition equilibrium to extended when displacement > 0 [m];
            state compressed;
            transition compressed to equilibrium when displacement == 0 [m];
            transition compressed to extended when displacement > 0 [m];
            state extended;
            transition extended to equilibrium when displacement == 0 [m];
            transition extended to compressed when displacement < 0 [m];
        }
    }

    constraint def DampedOscillationDynamics {
        in pos : LengthValue;
        in vel : SpeedValue;
        in k : SpringStiffnessValue;
        in c : DampingCoefficientValue;
        in m : MassValue;
        in acc : AccelerationValue;
        
        acc == (-k * pos - c * vel) / m
    }

    action def SimulateDynamics {
        in massPosition : LengthValue;
        in massVelocity : SpeedValue;
        in springStiffness : SpringStiffnessValue;
        in damping : DampingCoefficientValue;
        in massValue : MassValue;
        out massAcceleration : AccelerationValue;
        
        assert constraint dynamics : DampedOscillationDynamics {
            in pos = massPosition;
            in vel = massVelocity;
            in k = springStiffness;
            in c = damping;
            in m = massValue;
            in acc = massAcceleration;
        }
    }

    part def MassSpringSystem {
        part mount : FixedMountingPoint;
        part mass : Mass;
        part spring : HelicalSpring;
        
        connection mountToSpring connect mount.mechanicalInterface to spring.mountEnd;
        connection springToMass connect spring.massEnd to mass.mechanicalInterface;
        
        action simulate : SimulateDynamics {
            in massPosition = mass.position;
            in massVelocity = mass.velocity;
            in springStiffness = spring.stiffness;
            in damping = spring.damping;
            in massValue = mass.mass;
            out massAcceleration = mass.acceleration;
        }
    }

    requirement def OscillationRequirement {
        subject system : MassSpringSystem;
        requirement exhibitHarmonicMotion {
            doc /* The system shall exhibit simple harmonic motion when the mass is displaced. */
        }
        requirement decayOscillation {
            doc /* The oscillation shall decay over time due to the damping factor. */
        }
    }
}
