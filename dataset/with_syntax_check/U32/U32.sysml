package 'Adams Clasp Orthodontic System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def RetentiveForce :> ForceValue {
        doc /* Force exerted by clasp to retain appliance on tooth */
    }

    attribute def WireDeflection :> LengthValue {
        doc /* Deflection of clasp wire from neutral position */
    }

    attribute def ClaspAngle :> AngleValue {
        doc /* Angular position of clasp arms relative to base */
    }

    attribute def SpringStiffness :> Real {
        doc /* Stiffness coefficient of wire material in N/mm */
    }

    attribute def ClaspState;
    attribute def PassiveState :> ClaspState;
    attribute def ActiveState :> ClaspState;
    attribute def EngagedState :> ClaspState;

    item def WireArm {
        doc /* Arrowhead-shaped wire arm that engages tooth undercut */
        attribute length : LengthValue;
        attribute diameter : LengthValue;
        attribute material : String;
        attribute deflection : WireDeflection;
        port armContact : MechanicalContact;
    }

    item def BridgeWire {
        doc /* Connecting wire spanning across tooth surface */
        attribute span : LengthValue;
        attribute clearance : LengthValue;
        port mesialContact : MechanicalContact;
        port distalContact : MechanicalContact;
    }

    item def ToothUndercut {
        doc /* Anatomical feature providing mechanical retention */
        attribute depth : LengthValue;
        attribute location : String;
    }

    item def ApplianceBase {
        doc /* Acrylic base plate of removable appliance */
        attribute thickness : LengthValue;
        attribute area : AreaValue;
    }

    port def MechanicalContact {
        doc /* Interface for mechanical force transmission */
        in item contactForce : ForceValue;
        out item reactionForce : ForceValue;
        in item displacement : LengthValue;
    }

    port def RetentionInterface {
        doc /* Interface for retention engagement */
        in item undercutDepth : LengthValue;
        out item retentiveForce : RetentiveForce;
        out item engaged : Boolean;
    }

    part def AdamsClaspAssembly {
        doc /* Complete Adams clasp retention mechanism */

        attribute currentState : ClaspState;
        attribute totalRetentiveForce : RetentiveForce;
        attribute wireStiffness : SpringStiffness;

        part mesialArm : WireArm {
            attribute length = 12.0 [mm];
            attribute diameter = 0.7 [mm];
            attribute material = "stainless steel 0.7mm";
            attribute deflection : WireDeflection;
        }

        part distalArm : WireArm {
            attribute length = 12.0 [mm];
            attribute diameter = 0.7 [mm];
            attribute material = "stainless steel 0.7mm";
            attribute deflection : WireDeflection;
        }

        part bridge : BridgeWire {
            attribute span = 8.0 [mm];
            attribute clearance = 0.5 [mm];
        }

        part baseConnection {
            doc /* Embedded connection to appliance base */
            attribute embedmentDepth : LengthValue;
        }

        port mesialContact : MechanicalContact;
        port distalContact : MechanicalContact;
        port mesialRetention : RetentionInterface;
        port distalRetention : RetentionInterface;

        connection mesialConnection connect mesialArm.armContact to bridge.mesialContact;
        connection distalConnection connect distalArm.armContact to bridge.distalContact;
    }

    part def Tooth {
        doc /* Tooth structure with retention features */

        attribute toothNumber : String;
        attribute surfaceArea : AreaValue;

        part mesialUndercut : ToothUndercut {
            attribute depth = 0.5 [mm];
            attribute location = "mesial";
        }

        part distalUndercut : ToothUndercut {
            attribute depth = 0.5 [mm];
            attribute location = "distal";
        }

        port mesialSurface : RetentionInterface;
        port distalSurface : RetentionInterface;
    }

    part def RemovableAppliance {
        doc /* Removable orthodontic appliance with Adams clasp */

        part base : ApplianceBase {
            attribute thickness = 2.0 [mm];
            attribute area : AreaValue;
        }

        part clasp : AdamsClaspAssembly {
            attribute wireStiffness = 180.0;
        }

        connection claspToBase connect clasp.baseConnection to base;
    }

    action def CalculateRetentiveForce {
        in wireDeflection : WireDeflection;
        in stiffness : SpringStiffness;
        in undercutDepth : LengthValue;
        out retentiveForce : RetentiveForce;
    }

    action def DeflectArm {
        in appliedForce : ForceValue;
        in armLength : LengthValue;
        in stiffness : SpringStiffness;
        out deflection : WireDeflection;
        out resistanceForce : ForceValue;
    }

    action def EngageUndercut {
        in armDeflection : WireDeflection;
        in undercutDepth : LengthValue;
        out engaged : Boolean;
        out lockingForce : RetentiveForce;
    }

    action def ReleaseFromUndercut {
        in separatingForce : ForceValue;
        in currentRetention : RetentiveForce;
        out released : Boolean;
        out residualDeflection : WireDeflection;
    }

    state def ClaspEngagementStates {
        entry; then passive;

        state passive {
            doc /* Clasp at rest, not engaging tooth */
        }

        state activating {
            doc /* Clasp arms being deflected during insertion */
        }

        state active {
            doc /* Clasp arms deflected, ready to engage */
        }

        state engaging {
            doc /* Clasp arms entering undercut areas */
        }

        state engaged {
            doc /* Clasp fully seated in undercuts, providing retention */
        }

        state releasing {
            doc /* Clasp being removed from undercuts */
        }

        transition passiveToActivating
            first passive
            then activating;

        transition activatingToActive
            first activating
            then active;

        transition activeToEngaging
            first active
            then engaging;

        transition engagingToEngaged
            first engaging
            then engaged;

        transition engagedToReleasing
            first engaged
            then releasing;

        transition releasingToPassive
            first releasing
            then passive;

        transition engagingToActivating
            first engaging
            then activating;
    }

    action def ProvideRetention {
        doc /* Primary function: Provide mechanical retention for removable appliance */

        in targetTooth : Tooth;
        in appliance : RemovableAppliance;
        in insertionForce : ForceValue;
        in removalForce : ForceValue;
        out achievedRetention : RetentiveForce;
        out retentionSuccess : Boolean;

        first start;
        then merge readyForInsertion;

        then action insertAppliance {
            doc /* Insert appliance and deflect clasp arms */
            action deflectMesialArm : DeflectArm {
                in appliedForce = insertionForce;
                in armLength = appliance.clasp.mesialArm.length;
                in stiffness = appliance.clasp.wireStiffness;
                out deflection;
                out resistanceForce;
            }

            action deflectDistalArm : DeflectArm {
                in appliedForce = insertionForce;
                in armLength = appliance.clasp.distalArm.length;
                in stiffness = appliance.clasp.wireStiffness;
                out deflection;
                out resistanceForce;
            }
        }

        then action positionOverTooth {
            doc /* Position deflected clasp over tooth undercuts */
        }

        then action releaseClaspArms {
            doc /* Release insertion force allowing arms to engage undercuts */
            action engageMesial : EngageUndercut {
                in armDeflection : WireDeflection;
                in undercutDepth = targetTooth.mesialUndercut.depth;
                out engaged;
                out lockingForce;
            }

            action engageDistal : EngageUndercut {
                in armDeflection : WireDeflection;
                in undercutDepth = targetTooth.distalUndercut.depth;
                out engaged;
                out lockingForce;
            }
        }

        then decide;
            if releaseClaspArms.engageMesial.engaged then maintainRetention;
            if !releaseClaspArms.engageMesial.engaged then readyForInsertion;

        action maintainRetention {
            doc /* Maintain retention force during appliance wear */
            action calculateMesialForce : CalculateRetentiveForce {
                in wireDeflection : WireDeflection;
                in stiffness = appliance.clasp.wireStiffness;
                in undercutDepth = targetTooth.mesialUndercut.depth;
                out retentiveForce;
            }

            action calculateDistalForce : CalculateRetentiveForce {
                in wireDeflection : WireDeflection;
                in stiffness = appliance.clasp.wireStiffness;
                in undercutDepth = targetTooth.distalUndercut.depth;
                out retentiveForce;
            }

            action sumForces {
                assign retentionSuccess := true;
            }
        }
        then holdInPlace;

        merge holdInPlace;
        then accept removalCommand;

        then action removeAppliance : ReleaseFromUndercut {
            in separatingForce = removalForce;
            in currentRetention : RetentiveForce;
            out released;
            out residualDeflection;
        }

        then done;
    }

    requirement def ClaspPerformanceRequirements {
        doc /* Performance requirements for Adams clasp system */

        requirement <'REQ-AC-001'> adequateRetention {
            doc /* Clasp shall provide sufficient retentive force to resist dislodgement */
        }

        requirement <'REQ-AC-002'> bilateralEngagement {
            doc /* Both mesial and distal arms shall engage undercuts simultaneously */
        }

        requirement <'REQ-AC-003'> insertionForceLimit {
            doc /* Force required for insertion shall not exceed patient comfort threshold */
        }

        requirement <'REQ-AC-004'> removalForceLimit {
            doc /* Force required for removal shall be within patient capability */
        }

        requirement <'REQ-AC-005'> undercutEngagement {
            doc /* Clasp arms shall engage minimum undercut depth */
        }
    }

    part adamsClaspSystem {
        doc /*
            Adams Clasp Orthodontic Retention System
            
            Primary Function: Provide secure, removable mechanical retention for 
            orthodontic appliances by utilizing bilateral wire arms that engage 
            mesial and distal undercut areas on a tooth. The clasp arms are 
            deflected during insertion, then spring back to lock into the undercuts, 
            generating controlled retentive force that resists appliance displacement 
            during function while allowing intentional removal by the patient or clinician.
        */

        part appliance : RemovableAppliance {
            part clasp : AdamsClaspAssembly {
                attribute wireStiffness = 180.0;
                attribute totalRetentiveForce : RetentiveForce;
            }
        }

        part anchorTooth : Tooth {
            attribute toothNumber = "Upper Right First Molar";
            attribute surfaceArea = 120.0 [mm^2];
        }

        connection mesialEngagement connect
            appliance.clasp.mesialRetention to anchorTooth.mesialSurface;

        connection distalEngagement connect
            appliance.clasp.distalRetention to anchorTooth.distalSurface;

        perform action primaryFunction : ProvideRetention {
            in targetTooth = anchorTooth;
            in appliance = appliance;
            in insertionForce = 15.0 [N];
            in removalForce = 18.0 [N];
            out achievedRetention;
            out retentionSuccess;
        }

        satisfy ClaspPerformanceRequirements::adequateRetention;
        satisfy ClaspPerformanceRequirements::bilateralEngagement;
        satisfy ClaspPerformanceRequirements::insertionForceLimit;
        satisfy ClaspPerformanceRequirements::removalForceLimit;
        satisfy ClaspPerformanceRequirements::undercutEngagement;
    }
}
