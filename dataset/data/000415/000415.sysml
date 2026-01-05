package XenobotBiologicalSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ChemicalGradient {
        attribute concentration : Real;
        attribute direction : Real;
    }
    
    attribute def CellularCommand;
    attribute def EnvironmentalSignal;
    
    item def BiologicalCell {
        attribute cellType : String;
        attribute metabolicRate : Real;
        attribute viability : Real;
    }
    
    item def ContractileCell :> BiologicalCell {
        attribute contractionFrequency : FrequencyValue;
        attribute contractionAmplitude : Real;
    }
    
    item def CiliatedCell :> BiologicalCell {
        attribute ciliaBeatFrequency : FrequencyValue;
        attribute ciliaLength : LengthValue;
    }
    
    item def TherapeuticPayload {
        attribute drugMass : MassValue;
        attribute releaseRate : Real;
        attribute potency : Real;
    }
    
    port def ChemicalSensorPort {
        in environmentalGradient : ChemicalGradient;
        out sensedSignal : EnvironmentalSignal;
    }
    
    port def MotorPort {
        in motorCommand : CellularCommand;
        out propulsionForce : ForceValue;
    }
    
    port def PayloadPort {
        inout payload : TherapeuticPayload;
        out releaseStatus : Boolean;
    }
    
    part def ChemotaxisSensor {
        attribute sensitivity : Real;
        port sensorInterface : ChemicalSensorPort;
        
        action detectGradient {
            in gradient : ChemicalGradient;
            out signal : EnvironmentalSignal;
        }
    }
    
    part def LocomotionModule {
        attribute propulsionEfficiency : Real;
        port motorInterface : MotorPort;
        part contractileCells : ContractileCell[50..200];
        part ciliatedCells : CiliatedCell[100..400];
        
        action generatePropulsion {
            in command : CellularCommand;
            out force : ForceValue;
        }
    }
    
    part def PayloadCarrier {
        attribute carryingCapacity : MassValue;
        port payloadInterface : PayloadPort;
        
        action securePayload {
            in drug : TherapeuticPayload;
            out secured : Boolean;
        }
        
        action releasePayload {
            in releaseSignal : EnvironmentalSignal;
            out released : TherapeuticPayload;
        }
    }
    
    part def XenobotOrganism {
        attribute bodySize : LengthValue;
        attribute totalCellCount : Real;
        attribute energyLevel : EnergyValue;
        attribute currentPosition : LengthValue;
        
        part chemotaxis : ChemotaxisSensor;
        part locomotion : LocomotionModule;
        part carrier : PayloadCarrier;
        
        connection sensorToMotor 
            connect chemotaxis.sensorInterface.sensedSignal 
            to locomotion.motorInterface.motorCommand;
    }
    
    action def NavigateToTarget {
        in gradient : ChemicalGradient;
        in currentPos : LengthValue;
        out displacement : LengthValue;
        out velocity : SpeedValue;
    }
    
    action def DeliverTherapeutic {
        in payload : TherapeuticPayload;
        in targetLocation : LengthValue;
        out deliveryComplete : Boolean;
    }
    
    state def XenobotOperationalStates {
        entry; then searching;
        
        state searching {
            entry; 
        }
        
        state navigating {
            entry;
        }
        
        state delivering {
            entry;
        }
        
        state depleted {
            entry;
        }
        
        transition searching_to_navigating
            first searching
            accept gradientDetected : ChemicalGradient
            if gradientDetected.concentration > 0.1
            then navigating;
            
        transition navigating_to_delivering
            first navigating
            accept targetReached : Boolean
            then delivering;
            
        transition delivering_to_searching
            first delivering
            accept payloadReleased : Boolean
            then searching;
            
        transition any_to_depleted
            first navigating
            accept energyDepleted : Boolean
            then depleted;
    }
    
    part xenobotSystem : XenobotOrganism {
        attribute mode : String;
        
        perform action therapeuticDeliveryMission {
            first start;
            then merge continueMission;
            
            action senseEnvironment {
                out signal : EnvironmentalSignal;
            }
            
            then decide;
                if senseEnvironment.signal.intensity > 0.5 then navigate;
                if senseEnvironment.signal.intensity <= 0.5 then continueMission;
            
            action navigate : NavigateToTarget {
                in gradient;
                in currentPos = currentPosition;
                out displacement;
                out velocity;
            }
            
            then assign currentPosition := currentPosition + navigate.displacement;
            
            then checkTargetProximity;
            
            action checkTargetProximity {
                out atTarget : Boolean;
            }
            
            then decide;
                if checkTargetProximity.atTarget then deliverPayload;
                if not checkTargetProximity.atTarget then continueMission;
            
            action deliverPayload : DeliverTherapeutic {
                in payload;
                in targetLocation = currentPosition;
                out deliveryComplete;
            }
            
            then missionComplete;
            
            action missionComplete {
                out success : Boolean;
            }
            
            then done;
        }
        
        exhibit state operationalBehavior : XenobotOperationalStates;
    }
    
    requirement def XenobotMissionRequirement {
        doc /* The xenobot shall autonomously navigate through biological 
               environments to locate disease sites and deliver therapeutic 
               payloads with precision. */
        
        require navigationCapability : NavigationRequirement;
        require deliveryCapability : PayloadDeliveryRequirement;
        require biocompatibilityCapability : BiocompatibilityRequirement;
    }
    
    requirement navigationCapability : NavigationRequirement {
        doc /* The xenobot shall navigate autonomously using chemotaxis 
               to follow chemical gradients toward target sites. */
        
        subject navigator : XenobotOrganism;
        
        require constraint {
            navigator.chemotaxis.sensitivity >= 0.2
        }
        
        require constraint {
            navigator.locomotion.propulsionEfficiency >= 0.4
        }
    }
    
    requirement deliveryCapability : PayloadDeliveryRequirement {
        doc /* The xenobot shall carry and release therapeutic payloads 
               at designated target locations. */
        
        subject deliverySystem : PayloadCarrier;
        
        require constraint {
            deliverySystem.carryingCapacity >= 0.0001 [kg]
        }
    }
    
    requirement biocompatibilityCapability : BiocompatibilityRequirement {
        doc /* The xenobot shall be composed entirely of biological cells 
               that are biocompatible and biodegradable. */
        
        subject bioSystem : XenobotOrganism;
        
        require constraint {
            bioSystem.locomotion.contractileCells.viability >= 0.8
        }
        
        require constraint {
            bioSystem.locomotion.ciliatedCells.viability >= 0.8
        }
    }
    
    requirement def NavigationRequirement;
    requirement def PayloadDeliveryRequirement;
    requirement def BiocompatibilityRequirement;
    
    action xenobotPrimaryFunction : DeliverTherapeutic {
        doc /* Primary Function: The xenobot autonomously navigates through 
               aqueous biological environments using chemotaxis to detect and 
               follow chemical gradients, transporting therapeutic payloads to 
               disease sites where it releases the treatment with spatial precision. */
        
        in payload : TherapeuticPayload {
            attribute drugMass = 0.0001 [kg];
            attribute releaseRate = 0.5;
            attribute potency = 0.95;
        }
        
        in targetLocation : LengthValue = 5.0 [mm];
        
        first start;
        then action detectChemicalSignature {
            out gradientFound : ChemicalGradient;
        }
        then action navigateToDiseaseSite : NavigateToTarget {
            in gradient = detectChemicalSignature.gradientFound;
            in currentPos;
            out displacement;
            out velocity;
        }
        then action verifyTargetLocation {
            out locationConfirmed : Boolean;
        }
        then action releaseTherapeutic {
            out released : TherapeuticPayload;
        }
        then action confirmDelivery {
            out deliveryComplete : Boolean;
        }
        then done;
        
        out deliveryComplete : Boolean;
    }
}
