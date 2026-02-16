package ClaytronicsSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def Position3D {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }
    
    attribute def ElectromagneticFieldStrength : MagneticFieldStrengthValue {
        doc /* Strength of electromagnetic field for inter-catom bonding */
    }
    
    attribute def ReconfigurationRate : FrequencyValue {
        doc /* Rate at which the ensemble can reconfigure its shape */
    }
    
    attribute def CatomIdentifier : Integer {
        doc /* Unique identifier for each catom in the ensemble */
    }
    
    attribute def ShapeDescriptor {
        doc /* Geometric description of target shape */
        attribute vertices : Position3D[*];
        attribute complexity : Real;
    }
    
    enum def MessageType {
        enum positionUpdate;
        enum bondRequest;
        enum bondRelease;
        enum shapeCommand;
        enum statusQuery;
    }
    
    enum def BondState {
        enum unbonded;
        enum bonding;
        enum bonded;
        enum releasing;
    }
    
    enum def CatomOperationalState {
        enum idle;
        enum moving;
        enum bonded;
        enum reconfiguring;
        enum failed;
    }
    
    item def CommunicationSignal {
        attribute senderId : CatomIdentifier;
        attribute receiverId : CatomIdentifier;
        attribute messageType : MessageType;
        attribute payload : String;
    }
    
    port def CommunicationPort {
        out signal : CommunicationSignal;
        in command : CommunicationSignal;
    }
    
    port def ElectromagneticPort {
        attribute fieldStrength : ElectromagneticFieldStrength;
        attribute isActive : Boolean;
    }
    
    port def PowerPort {
        in powerIn : PowerValue;
        out powerOut : PowerValue;
    }
    
    part def Catom {
        doc /* 
            Cylindrical Atom (Catom): A modular robotic unit capable of 
            electromagnetic bonding and locomotion via controlled movement 
            around neighboring catoms.
        */
        
        attribute id : CatomIdentifier;
        attribute currentPosition : Position3D;
        attribute targetPosition : Position3D;
        attribute operationalState : CatomOperationalState;
        attribute batteryLevel : EnergyValue;
        attribute mass : MassValue;
        
        port commPort : CommunicationPort[6] {
            doc /* Six communication ports for hexagonal lattice neighbors */
        }
        
        port emPort : ElectromagneticPort[6] {
            doc /* Six electromagnetic bonding ports */
        }
        
        port power : PowerPort;
        
        part processor {
            doc /* Onboard computation for local decision making */
            attribute processingPower : PowerValue;
        }
        
        part actuator {
            doc /* Electromagnetic actuator for movement and bonding */
            attribute maxFieldStrength : ElectromagneticFieldStrength;
        }
        
        part sensor {
            doc /* Sensors for detecting neighbors and position */
            attribute detectionRange : LengthValue;
        }
        
        part powerSupply {
            attribute capacity : EnergyValue;
            attribute currentCharge : EnergyValue;
        }
    }
    
    state def CatomStateMachine {
        entry; then idle;
        
        state idle {
            entry action initializeSensors {
                doc /* Initialize sensors and await commands */
            }
            accept shapeCmd : CommunicationSignal;
            transition to reconfiguring;
        }
        
        state reconfiguring {
            entry action calculatePath {
                doc /* Calculate movement path */
            }
            
            state unbonding {
                entry action releaseBonds {
                    doc /* Release electromagnetic bonds */
                }
                transition to moving;
            }
            
            state moving {
                entry action executeLocomotion {
                    doc /* Execute locomotion around pivot catom */
                }
                transition to bonding;
            }
            
            state bonding {
                entry action establishBonds {
                    doc /* Establish electromagnetic bonds */
                }
                transition to stable;
            }
            
            transition first unbonding;
            transition unbonding to moving;
            transition moving to bonding;
            transition bonding to stable;
        }
        
        state stable {
            entry action maintainPosition {
                doc /* Maintain position and bonds */
            }
            accept newShapeCmd : CommunicationSignal;
            transition to reconfiguring;
        }
        
        state failed {
            entry action reportFailure {
                doc /* Report failure and await recovery */
            }
        }
        
        transition idle to reconfiguring;
        transition reconfiguring to stable;
        transition stable to reconfiguring;
        transition reconfiguring to failed;
    }
    
    part def EnsembleController {
        doc /* 
            Centralized controller managing the collective behavior 
            of the catom ensemble for shape reconfiguration.
        */
        
        attribute targetShape : ShapeDescriptor;
        attribute currentConfiguration : Position3D[*];
        attribute numberOfCatoms : Integer;
        
        port controlPort : CommunicationPort[*];
        port powerIn : PowerPort;
        
        part shapeAlgorithm {
            doc /* Algorithm for computing target catom positions */
        }
        
        part coordinationEngine {
            doc /* Coordinates movement to avoid collisions */
        }
        
        part monitoringSystem {
            doc /* Monitors ensemble health and progress */
        }
    }
    
    action def SenseEnvironment {
        in currentPos : Position3D;
        out neighbors : CatomIdentifier[*];
        out bondStates : BondState[*];
    }
    
    action def ComputeNextMove {
        in currentPos : Position3D;
        in targetPos : Position3D;
        in neighbors : CatomIdentifier[*];
        out movementVector : Position3D;
        out requiredBonds : CatomIdentifier[*];
    }
    
    action def ExecuteBonding {
        in targetCatom : CatomIdentifier;
        in fieldStrength : ElectromagneticFieldStrength;
        out bondEstablished : Boolean;
    }
    
    action def ExecuteUnbonding {
        in bondedCatom : CatomIdentifier;
        out bondReleased : Boolean;
    }
    
    action def PerformLocomotion {
        in movementVector : Position3D;
        in pivotCatom : CatomIdentifier;
        out newPosition : Position3D;
    }
    
    action def CatomBehavior {
        in catom : Catom;
        in targetPos : Position3D;
        
        first start;
        then merge checkState;
        
        action sense : SenseEnvironment {
            in currentPos = catom.currentPosition;
            out neighbors;
            out bondStates;
        }
        
        then decide;
            if sense.neighbors->size() == 0 then handleIsolated;
            if sense.neighbors->size() > 0 then computeMove;
        
        action handleIsolated {
            doc /* Wait for neighbors or broadcast position */
        }
        then checkState;
        
        action computeMove : ComputeNextMove {
            in currentPos = catom.currentPosition;
            in targetPos = targetPos;
            in neighbors = sense.neighbors;
            out movementVector;
            out requiredBonds;
        }
        
        then decide;
            if computeMove.requiredBonds->size() > 0 then establishBonds;
            if computeMove.requiredBonds->size() == 0 then executeMove;
        
        action establishBonds {
            for bondTarget in computeMove.requiredBonds {
                action bond : ExecuteBonding {
                    in targetCatom = bondTarget;
                    in fieldStrength;
                    out bondEstablished;
                }
            }
        }
        then executeMove;
        
        action executeMove : PerformLocomotion {
            in movementVector = computeMove.movementVector;
            in pivotCatom;
            out newPosition;
        }
        
        then action releaseBonds {
            for bondedNeighbor in sense.neighbors {
                action unbond : ExecuteUnbonding {
                    in bondedCatom = bondedNeighbor;
                    out bondReleased;
                }
            }
        }
        
        then action updatePosition {
            assign catom.currentPosition := executeMove.newPosition;
        }
        
        then decide;
            if catom.currentPosition == targetPos then reachTarget;
            if catom.currentPosition != targetPos then checkState;
        
        action reachTarget;
        then done;
    }
    
    action def EnsembleReconfiguration {
        in controller : EnsembleController;
        in catoms : Catom[*];
        in targetShape : ShapeDescriptor;
        
        first start;
        
        action computeConfiguration {
            in shape = targetShape;
            out targetPositions : Position3D[*];
        }
        
        then action assignTargets {
            doc /* Assign each catom a target position */
            attribute assignments : Position3D[*];
        }
        
        then action coordinateMovement {
            for catom in catoms parallel {
                action moveCatom : CatomBehavior {
                    in catom = catom;
                    in targetPos;
                }
            }
        }
        
        then action verifyShape {
            in finalPositions : Position3D[*];
            out shapeAchieved : Boolean;
        }
        
        then decide;
            if verifyShape.shapeAchieved then complete;
            if !verifyShape.shapeAchieved then refineConfiguration;
        
        action refineConfiguration {
            doc /* Adjust positions for catoms that missed targets */
        }
        then coordinateMovement;
        
        action complete;
        then done;
    }
    
    connection def CommunicationConnection {
        end source : CommunicationPort;
        end target : CommunicationPort;
    }
    
    part def ClaytronicsSystem {
        doc /* 
            A programmable matter system composed of numerous microscopic 
            robotic units (catoms) that collectively form a reconfigurable 
            ensemble capable of dynamically changing shape and appearance.
        */
        
        attribute systemCapacity : Integer;
        attribute reconfigurationSpeed : ReconfigurationRate;
        attribute operatingVolume : VolumeValue;
        
        part catoms : Catom[1000..*] {
            doc /* Ensemble of catoms forming the programmable matter */
            attribute mass = 0.001[SI::kg];
            attribute batteryLevel = 100[SI::J];
        }
        
        part controller : EnsembleController {
            doc /* Manages collective reconfiguration */
            attribute numberOfCatoms = 1000;
        }
        
        connection catom_to_controller : CommunicationConnection[*] 
            connect catoms.commPort to controller.controlPort;
        
        perform action reconfigure : EnsembleReconfiguration {
            in controller = controller;
            in catoms = catoms;
            in targetShape;
        }
    }
    
    requirement def SystemRequirements {
        doc /* High-level requirements for Claytronics system */
        
        requirement <'REQ-001'> reconfigurationCapability {
            doc /* 
                The system shall reconfigure from any valid shape to any 
                other valid shape within the operating volume.
            */
            
            subject system : ClaytronicsSystem;
            
            require constraint {
                system.reconfigurationSpeed >= 1.0[SI::Hz]
            }
        }
        
        requirement <'REQ-002'> catomCoordination {
            doc /* 
                Individual catoms shall coordinate movement to avoid 
                collisions and maintain ensemble connectivity.
            */
            
            subject catom : Catom;
        }
        
        requirement <'REQ-003'> shapeStability {
            doc /* 
                The ensemble shall maintain target shape stability through 
                electromagnetic bonding between adjacent catoms.
            */
            
            subject system : ClaytronicsSystem;
        }
        
        requirement <'REQ-004'> scalability {
            doc /* 
                The system shall support ensembles of at least 1000 catoms 
                with graceful performance degradation as size increases.
            */
            
            subject system : ClaytronicsSystem;
            
            require constraint {
                system.systemCapacity >= 1000
            }
        }
    }
    
    requirement primaryFunction : SystemRequirements {
        doc /* 
            Primary Function: The Claytronics system shall enable dynamic 
            3D shape formation and reconfiguration through coordinated 
            movement and electromagnetic bonding of modular robotic units, 
            creating programmable matter capable of assuming arbitrary 
            physical forms on demand.
        */
        
        assume constraint validOperatingConditions {
            doc /* System operates within specified environmental parameters */
        }
        
        require reconfigurationCapability;
        require catomCoordination;
        require shapeStability;
        require scalability;
    }
    
    part claytronicsSystem : ClaytronicsSystem;
}
