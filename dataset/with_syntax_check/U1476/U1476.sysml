package 'Pulley System' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def RopeLength :> ISQ::LengthValue;
    attribute def LoadMass :> ISQ::MassValue;
    attribute def EffortForce :> ISQ::ForceValue;
    attribute def LoadForce :> ISQ::ForceValue;
    attribute def MechanicalAdvantage :> ScalarValues::Real;
    attribute def EfficiencyFactor :> ScalarValues::Real;
    
    item def Rope {
        attribute totalLength : RopeLength;
        attribute tensileStrength : ISQ::ForceValue;
        attribute currentTension : ISQ::ForceValue;
    }
    
    item def Wheel {
        attribute diameter : ISQ::LengthValue;
        attribute radius : ISQ::LengthValue;
        attribute rotationAngle : ISQ::AngleValue;
    }
    
    item def Axle {
        attribute diameter : ISQ::LengthValue;
        attribute bearingFriction : ScalarValues::Real;
    }
    
    item def Load {
        attribute mass : LoadMass;
        attribute weight : LoadForce;
        attribute position : ISQ::LengthValue;
        attribute velocity : ISQ::SpeedValue;
    }
    
    part def Pulley {
        part wheel : Wheel;
        part axle : Axle;
        part mountingPoint;
        
        attribute mechanicalAdvantage : MechanicalAdvantage;
        attribute efficiency : EfficiencyFactor;
        
        port effortPort {
            in effortForce : EffortForce;
            in effortDisplacement : ISQ::LengthValue;
        }
        
        port loadPort {
            out loadForce : LoadForce;
            out loadDisplacement : ISQ::LengthValue;
        }
    }
    
    part def FixedPulley :> Pulley {
        attribute :>> mechanicalAdvantage = 1.0;
        attribute :>> efficiency = 0.95;
    }
    
    part def MovablePulley :> Pulley {
        attribute :>> mechanicalAdvantage = 2.0;
        attribute :>> efficiency = 0.90;
    }
    
    part def CompoundPulleySystem {
        doc /* A mechanical system that uses fixed and movable pulleys to lift loads by redirecting and amplifying applied force. */
        
        part fixedPulley : FixedPulley;
        part movablePulley : MovablePulley;
        part rope : Rope;
        part load : Load;
        
        attribute systemMechanicalAdvantage : MechanicalAdvantage;
        attribute totalEfficiency : EfficiencyFactor;
        
        connection ropeConnection1 connect 
            fixedPulley.effortPort to movablePulley.loadPort;
        connection ropeConnection2 connect 
            movablePulley.effortPort to load;
    }
    
    action def ApplyEffortForce {
        in effortForce : EffortForce;
        in pulledDistance : ISQ::LengthValue;
        out workDone : ISQ::EnergyValue;
    }
    
    action def TransmitForce {
        in inputForce : EffortForce;
        in mechanicalAdvantage : MechanicalAdvantage;
        in efficiency : EfficiencyFactor;
        out outputForce : LoadForce;
    }
    
    action def LiftLoad {
        in loadWeight : LoadForce;
        in liftHeight : ISQ::LengthValue;
        out potentialEnergyGained : ISQ::EnergyValue;
    }
    
    action def CalculateMechanicalAdvantage {
        in loadForce : LoadForce;
        in effortForce : EffortForce;
        out mechanicalAdvantage : MechanicalAdvantage;
    }
    
    action def OperatePulleySystem {
        in attribute appliedEffort : EffortForce;
        in attribute loadMass : LoadMass;
        in attribute desiredLiftHeight : ISQ::LengthValue;
        out attribute finalLoadPosition : ISQ::LengthValue;
        out attribute totalWorkInput : ISQ::EnergyValue;
        
        private attribute currentLoadPosition : ISQ::LengthValue := 0.0;
        private attribute currentEffort : EffortForce := appliedEffort;
        
        first start;
        then merge checkPosition;
        
        then decide;
            if currentLoadPosition < desiredLiftHeight then applyForce;
            if currentLoadPosition >= desiredLiftHeight then complete;
        
        action applyForce : ApplyEffortForce {
            in effortForce = currentEffort;
            in pulledDistance = 0.1;
            out workDone;
        }
        
        then action transmit : TransmitForce {
            in inputForce = currentEffort;
            in mechanicalAdvantage = 2.0;
            in efficiency = 0.90;
            out outputForce;
        }
        
        then action lift : LiftLoad {
            in loadWeight = transmit.outputForce;
            in liftHeight = 0.05;
            out potentialEnergyGained;
        }
        
        then assign currentLoadPosition := currentLoadPosition + 0.05;
        then checkPosition;
        
        action complete {
            assign finalLoadPosition := currentLoadPosition;
        }
        then done;
    }
    
    attribute def LoadAttachedEvent;
    attribute def EffortAppliedEvent;
    attribute def TargetHeightReachedEvent;
    attribute def ReleaseLoadEvent;
    attribute def LoadDetachedEvent;
    
    state def PulleySystemStates {
        attribute systemStatus : ScalarValues::String;
        
        entry; then idle;
        
        state idle;
        accept LoadAttachedEvent;
        then loading;
        
        state loading;
        accept EffortAppliedEvent;
        then lifting;
        
        state lifting {
            do action continuousLift : OperatePulleySystem;
        }
        accept TargetHeightReachedEvent;
        then holding;
        
        state holding;
        accept ReleaseLoadEvent;
        then lowering;
        
        state lowering;
        accept LoadDetachedEvent;
        then idle;
    }
    
    requirement def PulleySystemRequirement {
        doc /* The pulley system shall provide mechanical advantage to reduce the effort force required to lift loads. */
        
        subject pulleySystem : CompoundPulleySystem;
        
        require constraint mechanicalAdvantageRequirement {
            pulleySystem.systemMechanicalAdvantage >= 2.0
        }
        
        require constraint efficiencyRequirement {
            pulleySystem.totalEfficiency >= 0.85
        }
        
        require constraint safetyRequirement {
            pulleySystem.rope.currentTension <= pulleySystem.rope.tensileStrength
        }
    }
    
    requirement <'PULL-001'> liftLoadRequirement : PulleySystemRequirement {
        doc /* The pulley system shall lift loads by redirecting and amplifying applied effort force through mechanical advantage. */
        
        assume constraint loadAttached {
            doc /* A load is securely attached to the movable pulley. */
        }
        
        assume constraint ropeIntact {
            doc /* The rope is continuous and properly threaded through all pulleys. */
        }
        
        require constraint forceReduction {
            doc /* The effort force required shall be reduced by the mechanical advantage factor. */
        }
        
        require constraint heightCorrelation {
            doc /* The load lift height shall be proportional to the effort displacement divided by mechanical advantage. */
        }
    }
    
    part pulleySystemInstance : CompoundPulleySystem {
        perform action operateSystem : OperatePulleySystem {
            in appliedEffort = 100.0;
            in loadMass = 20.0;
            in desiredLiftHeight = 2.0;
            out finalLoadPosition;
            out totalWorkInput;
        }
        
        exhibit state systemBehavior : PulleySystemStates;
        
        part :>> fixedPulley {
            part :>> wheel {
                attribute :>> diameter = 0.15;
                attribute :>> radius = 0.075;
            }
            part :>> axle {
                attribute :>> diameter = 0.02;
                attribute :>> bearingFriction = 0.05;
            }
        }
        
        part :>> movablePulley {
            part :>> wheel {
                attribute :>> diameter = 0.15;
                attribute :>> radius = 0.075;
            }
            part :>> axle {
                attribute :>> diameter = 0.02;
                attribute :>> bearingFriction = 0.05;
            }
        }
        
        part :>> rope {
            attribute :>> totalLength = 10.0;
            attribute :>> tensileStrength = 5000.0;
        }
        
        part :>> load {
            attribute :>> mass = 20.0;
            attribute :>> weight = 196.2;
        }
        
        attribute :>> systemMechanicalAdvantage = 2.0;
        attribute :>> totalEfficiency = 0.855;
        
        satisfy liftLoadRequirement;
    }
}
