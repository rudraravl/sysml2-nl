package 'Programmable Matter System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ReconfigurationCommand;
    attribute def ShapeDescriptor;
    attribute def ModuleState;
    attribute def BondingSignal;
    
    value def Position3D {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }
    
    value def Orientation3D {
        attribute roll : Real;
        attribute pitch : Real;
        attribute yaw : Real;
    }
    
    enum def UnitState {
        idle;
        bonding;
        unbonding;
        moving;
        sensing;
    }
    
    enum def BondType {
        mechanical;
        magnetic;
        electrostatic;
    }
    
    item def ShapeConfiguration {
        attribute targetPositions : Position3D[*] ordered;
        attribute targetOrientations : Orientation3D[*] ordered;
        attribute formationTime : TimeValue;
    }
    
    port def CommandPort {
        in command : ReconfigurationCommand;
        out acknowledgment : Boolean;
    }
    
    port def DataPort {
        in sensorData : Real;
        out statusData : Real;
    }
    
    port def PowerPort {
        in powerSupply : PowerValue;
        out powerDemand : PowerValue;
    }
    
    port def BondingPort {
        in bondRequest : BondingSignal;
        out bondResponse : BondingSignal;
    }
    
    part def ModularUnit {
        attribute currentPosition : Position3D;
        attribute currentOrientation : Orientation3D;
        attribute operationalState : UnitState;
        attribute energyReserve : EnergyValue;
        attribute unitMass : MassValue;
        
        port commandInterface : CommandPort;
        port dataInterface : DataPort;
        port powerInterface : PowerPort;
        port bondingInterface[6] : BondingPort;
        
        part actuationSystem {
            attribute maxForce : ForceValue;
            attribute maxVelocity : SpeedValue;
            attribute actuationPrecision : LengthValue;
        }
        
        part sensingSystem {
            attribute proximityRange : LengthValue;
            attribute orientationAccuracy : Real;
            attribute updateRate : FrequencyValue;
        }
        
        part processingUnit {
            attribute computationCapacity : FrequencyValue;
            attribute memorySize : Real;
        }
        
        part bondingMechanism {
            attribute bondStrength : ForceValue;
            attribute bondingSpeed : TimeValue;
            attribute bondType : BondType;
        }
        
        part communicationModule {
            attribute transmissionRange : LengthValue;
            attribute dataRate : Real;
        }
    }
    
    part def ControlSystem {
        attribute planningHorizon : TimeValue;
        attribute optimizationCriteria : String;
        
        port commandOutput[*] : CommandPort;
        port dataInput[*] : DataPort;
        
        part shapeAnalyzer {
            attribute analysisAlgorithm : String;
        }
        
        part pathPlanner {
            attribute planningStrategy : String;
            attribute collisionAvoidance : Boolean;
        }
        
        part coordinationEngine {
            attribute synchronizationProtocol : String;
            attribute conflictResolution : String;
        }
    }
    
    part def EnergySystem {
        attribute totalCapacity : EnergyValue;
        attribute outputVoltage : ElectricPotentialValue;
        attribute distributionEfficiency : Real;
        
        port powerOutput[*] : PowerPort;
    }
    
    action def SenseEnvironment {
        in proximityData : Real;
        in orientationData : Orientation3D;
        out environmentalModel : Real;
    }
    
    action def PlanReconfiguration {
        in currentConfig : Position3D[*];
        in targetConfig : ShapeConfiguration;
        out movementPlan : ReconfigurationCommand[*];
    }
    
    action def ExecuteMovement {
        in moveCommand : ReconfigurationCommand;
        in startPosition : Position3D;
        out endPosition : Position3D;
        out energyUsed : EnergyValue;
    }
    
    action def EstablishBond {
        in neighborUnit : ModularUnit;
        in bondStrength : ForceValue;
        out bondSuccess : Boolean;
        out bondEnergy : EnergyValue;
    }
    
    action def ReleaseBond {
        in bondIdentifier : Integer;
        out releaseSuccess : Boolean;
    }
    
    action def CommunicateState {
        in localState : UnitState;
        in neighborPorts : BondingPort[*];
        out broadcastData : Real;
    }
    
    action def ReconfigureShape {
        in targetShape : ShapeConfiguration;
        in availableUnits : ModularUnit[*];
        out achievedConfiguration : Position3D[*];
        out totalEnergy : EnergyValue;
        
        first start;
        then merge planningCycle;
        
        then action sense : SenseEnvironment {
            in proximityData;
            in orientationData;
            out environmentalModel;
        }
        
        then action plan : PlanReconfiguration {
            in currentConfig;
            in targetConfig = targetShape;
            out movementPlan;
        }
        
        then decide;
            if plan.movementPlan->notEmpty() then executeSequence;
            if plan.movementPlan->isEmpty() then finalize;
        
        action executeSequence {
            first start;
            then merge coordinationCycle;
            
            then action communicate : CommunicateState {
                in localState;
                in neighborPorts;
                out broadcastData;
            }
            
            then action release : ReleaseBond {
                in bondIdentifier;
                out releaseSuccess;
            }
            
            then action move : ExecuteMovement {
                in moveCommand;
                in startPosition;
                out endPosition;
                out energyUsed;
            }
            
            then action bond : EstablishBond {
                in neighborUnit;
                in bondStrength;
                out bondSuccess;
                out bondEnergy;
            }
            
            then decide;
                if bond.bondSuccess then coordinationCycle;
                if not bond.bondSuccess then planningCycle;
        }
        
        action finalize;
        then done;
    }
    
    state def UnitLifecycle {
        entry; then idle;
        
        state idle;
        
        transition first accept receivedCommand : ReconfigurationCommand
            then active;
        
        state active {
            entry; then moving;
            
            state bonding;
            state unbonding;
            state moving;
            state sensing;
        }
        
        transition accept taskComplete
            then idle;
    }
    
    part programmableMatterSystem {
        doc /*
            A programmable matter system capable of autonomous physical reconfiguration.
            The system transforms its macroscopic shape by coordinating the movement and
            bonding of numerous modular units in response to digital commands, enabling
            adaptive functionality for applications such as dynamic tooling, reconfigurable
            structures, and morphing devices.
        */
        
        attribute systemMass : MassValue;
        attribute moduleCount : Integer;
        attribute maxReconfigurationTime : TimeValue;
        attribute operatingTemperatureRange : ThermodynamicTemperatureValue[2];
        attribute workspaceVolume : VolumeValue;
        
        part modules : ModularUnit[200];
        part controller : ControlSystem;
        part powerSupply : EnergySystem;
        
        connection communicationNetwork 
            connect modules.bondingInterface to modules.bondingInterface;
        
        connection controlLinks 
            connect controller.commandOutput to modules.commandInterface;
        
        connection dataLinks 
            connect modules.dataInterface to controller.dataInput;
        
        connection powerDistribution 
            connect powerSupply.powerOutput to modules.powerInterface;
        
        perform action reconfigure : ReconfigureShape {
            in targetShape;
            in availableUnits = programmableMatterSystem::modules;
            out achievedConfiguration;
            out totalEnergy;
        }
        
        part :>> modules[1] {
            :>> currentPosition {
                :>> x = 0.0[mm];
                :>> y = 0.0[mm];
                :>> z = 0.0[mm];
            }
            :>> energyReserve = 50.0[J];
            :>> unitMass = 10.0[g];
        }
    }
    
    requirement def <'REQ-PM-001'> ShapeReconfigurationCapability {
        doc /*
            The programmable matter system shall reconfigure from any valid initial
            configuration to any specified target configuration within the maximum
            reconfiguration time limit.
        */
        
        subject system : programmableMatterSystem;
        
        require constraint {
            system.reconfigure.totalEnergy <= system.powerSupply.totalCapacity
        }
        
        require constraint {
            system.maxReconfigurationTime <= 120.0[s]
        }
    }
    
    requirement def <'REQ-PM-002'> ModuleConnectivity {
        doc /*
            Each modular unit shall maintain communication and bonding capability
            with at least four neighboring units during reconfiguration to ensure
            structural integrity and coordination.
        */
        
        subject module : ModularUnit;
        
        require constraint {
            module.bondingInterface->size() >= 4
        }
    }
    
    requirement def <'REQ-PM-003'> EnergyEfficiency {
        doc /*
            The system shall complete a full reconfiguration cycle using no more
            than 75% of the total available energy capacity to maintain operational
            reserve for subsequent tasks.
        */
        
        subject system : programmableMatterSystem;
        
        require constraint {
            system.reconfigure.totalEnergy <= 0.75 * system.powerSupply.totalCapacity
        }
    }
    
    requirement def <'REQ-PM-004'> BondingStrength {
        doc /*
            Inter-module bonds shall withstand forces up to 15 times the weight
            of a single module to ensure structural stability during reconfiguration
            and operational loading.
        */
        
        subject unit : ModularUnit;
        
        require constraint {
            unit.bondingMechanism.bondStrength >= 15.0 * unit.unitMass * 9.81[m/s^2]
        }
    }
    
    requirement def <'REQ-PM-005'> PositioningAccuracy {
        doc /*
            Each modular unit shall achieve positioning accuracy within 0.5mm
            of the target position to ensure precise shape formation.
        */
        
        subject unit : ModularUnit;
        
        require constraint {
            unit.actuationSystem.actuationPrecision <= 0.5[mm]
        }
    }
    
    requirement systemRequirements {
        doc /* 
            Top-level requirements for the programmable matter system defining
            reconfiguration capability, connectivity, energy efficiency, structural
            integrity, and positioning accuracy.
        */
        
        requirement reconfigCapability : ShapeReconfigurationCapability;
        requirement connectivity : ModuleConnectivity;
        requirement energyEfficiency : EnergyEfficiency;
        requirement bondStrength : BondingStrength;
        requirement positioningAccuracy : PositioningAccuracy;
    }
}
