package WeightedBlanketSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import NumericalFunctions::*;
    
    attribute def PressureValue :> Real;
    attribute def ComfortLevel :> Real;
    
    enum def BlanketState {
        stored;
        deployed;
        inUse;
        maintenance;
    }
    
    enum def FillMaterial {
        glassBeads;
        plasticPellets;
        steelBeads;
        organicGrains;
    }
    
    item def User {
        attribute bodyMass : MassValue;
        attribute stressLevel : Real;
        attribute comfortLevel : ComfortLevel;
    }
    
    part def WeightFiller {
        attribute fillMaterial : FillMaterial;
        attribute fillMass : MassValue;
        attribute distributionUniformity : Real;
    }
    
    part def FabricLayer {
        attribute material : String;
        attribute breathability : Real;
        attribute thermalConductivity : Real;
    }
    
    part def CompartmentGrid {
        attribute rows : Integer;
        attribute columns : Integer;
        attribute compartmentSize : LengthValue;
    }
    
    part def WeightedBlanket {
        attribute totalMass : MassValue;
        attribute dimensions : LengthValue[2];
        attribute appliedPressure : PressureValue;
        attribute currentState : BlanketState;
        
        part outerLayer : FabricLayer {
            attribute :>> material = "cotton";
            attribute :>> breathability = 0.85;
            attribute :>> thermalConductivity = 0.06;
        }
        
        part innerLayer : FabricLayer {
            attribute :>> material = "polyester";
            attribute :>> breathability = 0.70;
            attribute :>> thermalConductivity = 0.04;
        }
        
        part grid : CompartmentGrid {
            attribute :>> rows = 7;
            attribute :>> columns = 5;
            attribute :>> compartmentSize = 15.0 [cm];
        }
        
        part filler : WeightFiller[35] {
            attribute :>> fillMaterial = FillMaterial::glassBeads;
            attribute :>> fillMass = 0.2 [kg];
            attribute :>> distributionUniformity = 0.95;
        }
        
        assert constraint massDistribution {
            totalMass == sum(filler.fillMass)
        }
        
        assert constraint pressureCalculation {
            appliedPressure == totalMass / (dimensions[0] * dimensions[1])
        }
    }
    
    action def ApplyDeepPressure {
        in user : User;
        in blanket : WeightedBlanket;
        out stressReduction : Real;
        out comfortIncrease : ComfortLevel;
    }
    
    action def DistributeWeight {
        in totalWeight : MassValue;
        in gridLayout : CompartmentGrid;
        out uniformPressure : PressureValue;
    }
    
    action def MonitorComfort {
        in user : User;
        out currentComfort : ComfortLevel;
    }
    
    action def ProvideTherapeuticEffect {
        first start;
        then merge continuousMonitoring;
        
        then action monitorUser : MonitorComfort {
            in user : User;
            out comfort : ComfortLevel;
        }
        
        then action applyPressure : ApplyDeepPressure {
            in user : User;
            in blanket : WeightedBlanket;
            out reduction : Real;
        }
        
        then action distributeLoad : DistributeWeight {
            in totalWeight : MassValue;
            in gridLayout : CompartmentGrid;
            out pressure : PressureValue;
        }
        
        then decide;
            if monitorUser.comfort >= 0.80 then therapeuticGoalAchieved;
            if monitorUser.comfort < 0.80 then continuousMonitoring;
        
        action therapeuticGoalAchieved;
        then done;
    }
    
    state def BlanketLifecycle {
        entry; then idle;
        
        state idle;
        
        transition idle_to_ready
            first idle
            accept DeploymentRequest
            then ready;
        
        state ready;
        
        transition ready_to_active
            first ready
            accept UserContact
            then active;
        
        state active {
            do action provideTherapy : ProvideTherapeuticEffect;
        }
        
        transition active_to_ready
            first active
            accept UserRemoval
            then ready;
        
        transition ready_to_maintenance
            first ready
            accept MaintenanceRequired
            then maintenanceMode;
        
        state maintenanceMode;
        
        transition maintenance_to_idle
            first maintenanceMode
            accept MaintenanceComplete
            then idle;
    }
    
    requirement def TherapeuticEffectiveness {
        doc /* The weighted blanket shall provide therapeutic deep pressure 
             * stimulation to reduce stress and promote relaxation.
             */
        subject blanket : WeightedBlanket;
        require constraint {
            blanket.appliedPressure >= 0.05 and blanket.appliedPressure <= 0.15
        }
    }
    
    requirement def SafeWeightRatio {
        doc /* The blanket weight shall be approximately 10% of the user's 
             * body weight for safe and effective therapeutic use.
             */
        subject blanket : WeightedBlanket;
        subject user : User;
        require constraint {
            blanket.totalMass >= user.bodyMass * 0.08 and
            blanket.totalMass <= user.bodyMass * 0.12
        }
    }
    
    requirement def UniformWeightDistribution {
        doc /* Weight shall be uniformly distributed across all compartments 
             * to ensure consistent pressure application.
             */
        subject blanket : WeightedBlanket;
        require constraint {
            blanket.filler.distributionUniformity >= 0.90
        }
    }
    
    requirement def BreathabilityStandard {
        doc /* The blanket shall maintain adequate breathability to prevent 
             * overheating during extended use.
             */
        subject blanket : WeightedBlanket;
        require constraint {
            blanket.outerLayer.breathability >= 0.80
        }
    }
    
    part weightedBlanketSystem : WeightedBlanket {
        attribute :>> totalMass = 7.0 [kg];
        attribute :>> dimensions = (150.0 [cm], 200.0 [cm]);
        attribute :>> appliedPressure = 0.023;
        attribute :>> currentState = BlanketState::stored;
        
        perform action therapeuticUse : ProvideTherapeuticEffect;
        
        exhibit state blanketBehavior : BlanketLifecycle;
    }
    
    item targetUser : User {
        attribute :>> bodyMass = 70.0 [kg];
        attribute :>> stressLevel = 0.75;
        attribute :>> comfortLevel = 0.40;
    }
    
    satisfy TherapeuticEffectiveness by weightedBlanketSystem;
    satisfy SafeWeightRatio by weightedBlanketSystem, targetUser;
    satisfy UniformWeightDistribution by weightedBlanketSystem;
    satisfy BreathabilityStandard by weightedBlanketSystem;
    
    requirement <'REQ-WB-001'> primaryFunction {
        doc /* The weighted blanket system shall provide calming therapeutic 
             * effects through evenly distributed deep pressure stimulation, 
             * promoting relaxation and improved sleep quality for users 
             * experiencing stress or anxiety.
             */
        subject system :>> weightedBlanketSystem;
        subject user :>> targetUser;
        
        assume constraint userRequiresTherapy {
            user.stressLevel >= 0.50
        }
        
        require TherapeuticEffectiveness;
        require SafeWeightRatio;
        require UniformWeightDistribution;
        require BreathabilityStandard;
    }
}
