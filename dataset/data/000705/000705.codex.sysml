package NasopharyngealAirwaySystem {

    value def Length_mm :> ScalarValues::Real {
        unit = "mm";
    }

    value def Diameter_mm :> ScalarValues::Real {
        unit = "mm";
    }

    value def Pressure_kPa :> ScalarValues::Real {
        unit = "kPa";
    }

    value def Flow_L_per_min :> ScalarValues::Real {
        unit = "L/min";
    }

    value def Force_N :> ScalarValues::Real {
        unit = "N";
    }

    value def Angle_deg :> ScalarValues::Real {
        unit = "deg";
    }

    value def Time_s :> ScalarValues::Real {
        unit = "s";
    }

    item def RespiratoryGas {
        attribute oxygenFraction : ScalarValues::Real;
        attribute carbonDioxideFraction : ScalarValues::Real;
        attribute temperature : ScalarValues::Real;
        attribute humidity : ScalarValues::Real;
    }

    item def Lubricant {
        attribute waterSoluble : ScalarValues::Boolean = true;
        attribute sterile : ScalarValues::Boolean = true;
    }

    item def Secretion {
        attribute viscosity : ScalarValues::Real;
        attribute volume : ScalarValues::Real;
    }

    item def PatientNasalPassage {
        attribute nareDiameter : Diameter_mm;
        attribute nostrilToNasopharynxDepth : Length_mm;
        attribute mucosalSensitivity : ScalarValues::Real;
        attribute obstructionRisk : ScalarValues::Real;
    }

    port def GasPort {
        in item inspiredGas : RespiratoryGas;
        out item expiredGas : RespiratoryGas;
        attribute flowRate : Flow_L_per_min;
        attribute pressure : Pressure_kPa;
    }

    port def TissueContactPort {
        in item patientPassage : PatientNasalPassage;
        attribute contactForce : Force_N;
        attribute contactArea : ScalarValues::Real;
    }

    port def LubricationPort {
        in item lubricant : Lubricant;
    }

    part def RetentionFlange {
        attribute outerWidth : Length_mm;
        attribute thickness : Length_mm;
        attribute flexibility : ScalarValues::Real;
        attribute preventsCompleteInsertion : ScalarValues::Boolean = true;

        port nareContact : TissueContactPort;
    }

    part def ProximalOpening {
        attribute openingDiameter : Diameter_mm;
        attribute edgeRadius : Length_mm;

        port ambientGasPort : GasPort;
    }

    part def DistalOpening {
        attribute openingDiameter : Diameter_mm;
        attribute bevelAngle : Angle_deg;

        port pharyngealGasPort : GasPort;
        port pharyngealTissueContact : TissueContactPort;
    }

    part def CurvedTubeBody {
        attribute overallLength : Length_mm;
        attribute innerDiameter : Diameter_mm;
        attribute outerDiameter : Diameter_mm;
        attribute wallThickness : Length_mm;
        attribute curvatureRadius : Length_mm;
        attribute kinkResistance : ScalarValues::Real;
        attribute materialBiocompatible : ScalarValues::Boolean = true;
        attribute radiopaque : ScalarValues::Boolean = false;

        port proximalGasPort : GasPort;
        port distalGasPort : GasPort;
        port nasalTissueContact : TissueContactPort;
        port lubricantReceiver : LubricationPort;
    }

    part def InternalLumen {
        attribute hydraulicDiameter : Diameter_mm;
        attribute unobstructedLength : Length_mm;
        attribute minimumCrossSectionArea : ScalarValues::Real;
        attribute secretionTolerance : ScalarValues::Real;

        port proximalFlow : GasPort;
        port distalFlow : GasPort;
    }

    connection def ContinuousAirPassage {
        end proximal : GasPort;
        end distal : GasPort;
    }

    connection def TubeTissueInterface {
        end tubeSurface : TissueContactPort;
        end nasalPassage : TissueContactPort;
    }

    part def NasopharyngealAirway {
        attribute deviceLength : Length_mm;
        attribute nominalInternalDiameter : Diameter_mm;
        attribute nominalExternalDiameter : Diameter_mm;
        attribute insertionDepthLimit : Length_mm;
        attribute maximumRecommendedContactForce : Force_N;
        attribute primaryFunction : ScalarValues::String =
            "Maintain a patent passage between the nostril and nasopharynx to support unobstructed spontaneous ventilation.";

        part flange : RetentionFlange {
            attribute outerWidth = 28.0;
            attribute thickness = 3.0;
            attribute flexibility = 0.65;
        }

        part proximalOpening : ProximalOpening {
            attribute openingDiameter = nominalInternalDiameter;
            attribute edgeRadius = 1.0;
        }

        part tubeBody : CurvedTubeBody {
            attribute overallLength = deviceLength;
            attribute innerDiameter = nominalInternalDiameter;
            attribute outerDiameter = nominalExternalDiameter;
            attribute wallThickness = (nominalExternalDiameter - nominalInternalDiameter) / 2.0;
            attribute curvatureRadius = 55.0;
            attribute kinkResistance = 0.85;
        }

        part lumen : InternalLumen {
            attribute hydraulicDiameter = nominalInternalDiameter;
            attribute unobstructedLength = deviceLength;
            attribute minimumCrossSectionArea = 3.14159 * nominalInternalDiameter * nominalInternalDiameter / 4.0;
            attribute secretionTolerance = 0.40;
        }

        part distalOpening : DistalOpening {
            attribute openingDiameter = nominalInternalDiameter;
            attribute bevelAngle = 35.0;
        }

        port ambientInterface : GasPort;
        port patientInterface : GasPort;
        port nasalContact : TissueContactPort;
        port lubricationInterface : LubricationPort;

        connection proximalToLumen : ContinuousAirPassage connect
            proximalOpening.ambientGasPort to lumen.proximalFlow;

        connection lumenToDistal : ContinuousAirPassage connect
            lumen.distalFlow to distalOpening.pharyngealGasPort;

        connection bodyProximalToLumen : ContinuousAirPassage connect
            tubeBody.proximalGasPort to lumen.proximalFlow;

        connection bodyDistalToLumen : ContinuousAirPassage connect
            tubeBody.distalGasPort to lumen.distalFlow;

        connection externalAmbientPath : ContinuousAirPassage connect
            ambientInterface to proximalOpening.ambientGasPort;

        connection externalPatientPath : ContinuousAirPassage connect
            patientInterface to distalOpening.pharyngealGasPort;

        connection tubeToNasalTissue : TubeTissueInterface connect
            nasalContact to tubeBody.nasalTissueContact;

        connection flangeToNare : TubeTissueInterface connect
            nasalContact to flange.nareContact;
    }

    action def SelectAirwaySize {
        in item patientPassage : PatientNasalPassage;
        out selectedLength : Length_mm;
        out selectedDiameter : Diameter_mm;

        objective {
            selectedLength <= patientPassage.nostrilToNasopharynxDepth;
            selectedDiameter <= patientPassage.nareDiameter;
        }
    }

    action def LubricateAirway {
        inout airway : NasopharyngealAirway;
        in item lubricant : Lubricant;

        objective {
            lubricant.waterSoluble == true;
            lubricant.sterile == true;
        }
    }

    action def InsertAirway {
        inout airway : NasopharyngealAirway;
        in item patientPassage : PatientNasalPassage;
        out insertionComplete : ScalarValues::Boolean;

        objective {
            airway.insertionDepthLimit <= patientPassage.nostrilToNasopharynxDepth;
            airway.maximumRecommendedContactForce <= 12.0;
        }
    }

    action def MaintainAirwayPatency {
        inout airway : NasopharyngealAirway;
        in item inspiredGas : RespiratoryGas;
        out item expiredGas : RespiratoryGas;
        out achievedFlow : Flow_L_per_min;

        objective {
            achievedFlow >= 5.0;
            airway.lumen.minimumCrossSectionArea > 0.0;
        }
    }

    action def RemoveAirway {
        inout airway : NasopharyngealAirway;
        out removed : ScalarValues::Boolean;
    }

    state def AirwayLifecycle {
        state packaged;
        state selected;
        state lubricated;
        state inserted;
        state maintainingPatency;
        state removed;

        entry; then packaged;

        transition selectSize
            first packaged
            accept SelectAirwaySize
            then selected;

        transition lubricate
            first selected
            accept LubricateAirway
            then lubricated;

        transition insert
            first lubricated
            accept InsertAirway
            then inserted;

        transition establishPatency
            first inserted
            accept MaintainAirwayPatency
            then maintainingPatency;

        transition removeFromPatient
            first maintainingPatency
            accept RemoveAirway
            then removed;
    }

    requirement def PrimaryFunctionRequirement {
        subject airway : NasopharyngealAirway;

        require constraint {
            airway.primaryFunction ==
            "Maintain a patent passage between the nostril and nasopharynx to support unobstructed spontaneous ventilation."
        }
    }

    requirement def LumenContinuityRequirement {
        subject airway : NasopharyngealAirway;

        require constraint {
            airway.lumen.hydraulicDiameter == airway.nominalInternalDiameter;
            airway.lumen.unobstructedLength == airway.deviceLength;
            airway.lumen.minimumCrossSectionArea > 0.0;
        }
    }

    requirement def RetentionRequirement {
        subject airway : NasopharyngealAirway;

        require constraint {
            airway.flange.preventsCompleteInsertion == true;
            airway.flange.outerWidth > airway.nominalExternalDiameter;
        }
    }

    requirement def BiocompatibilityRequirement {
        subject airway : NasopharyngealAirway;

        require constraint {
            airway.tubeBody.materialBiocompatible == true;
        }
    }

    requirement def AirflowSupportRequirement {
        subject airway : NasopharyngealAirway;

        require constraint {
            airway.nominalInternalDiameter >= 5.0;
            airway.nominalInternalDiameter <= 9.0;
            airway.deviceLength >= 80.0;
            airway.deviceLength <= 180.0;
        }
    }

    requirement def PatientProtectionRequirement {
        subject airway : NasopharyngealAirway;

        require constraint {
            airway.maximumRecommendedContactForce <= 12.0;
            airway.proximalOpening.edgeRadius >= 0.5;
            airway.distalOpening.bevelAngle >= 20.0;
            airway.distalOpening.bevelAngle <= 45.0;
        }
    }

    part def NasopharyngealAirwaySystem {
        part patientPassage : PatientNasalPassage {
            attribute nareDiameter = 8.0;
            attribute nostrilToNasopharynxDepth = 120.0;
            attribute mucosalSensitivity = 0.60;
            attribute obstructionRisk = 0.75;
        }

        part airway : NasopharyngealAirway {
            attribute deviceLength = 110.0;
            attribute nominalInternalDiameter = 7.0;
            attribute nominalExternalDiameter = 9.5;
            attribute insertionDepthLimit = 105.0;
            attribute maximumRecommendedContactForce = 10.0;
        }

        item roomAir : RespiratoryGas {
            attribute oxygenFraction = 0.21;
            attribute carbonDioxideFraction = 0.0004;
            attribute temperature = 22.0;
            attribute humidity = 0.45;
        }

        item exhaledGas : RespiratoryGas {
            attribute oxygenFraction = 0.16;
            attribute carbonDioxideFraction = 0.04;
            attribute temperature = 34.0;
            attribute humidity = 0.95;
        }

        item sterileGel : Lubricant {
            attribute waterSoluble = true;
            attribute sterile = true;
        }

        perform action sizing : SelectAirwaySize {
            in item patientPassage = patientPassage;
            out selectedLength = airway.deviceLength;
            out selectedDiameter = airway.nominalInternalDiameter;
        }

        perform action lubrication : LubricateAirway {
            inout airway = airway;
            in item lubricant = sterileGel;
        }

        perform action insertion : InsertAirway {
            inout airway = airway;
            in item patientPassage = patientPassage;
            out insertionComplete = true;
        }

        perform action ventilationSupport : MaintainAirwayPatency {
            inout airway = airway;
            in item inspiredGas = roomAir;
            out item expiredGas = exhaledGas;
            out achievedFlow = 12.0;
        }

        assert requirement PrimaryFunctionRequirement {
            subject airway = airway;
        }

        assert requirement LumenContinuityRequirement {
            subject airway = airway;
        }

        assert requirement RetentionRequirement {
            subject airway = airway;
        }

        assert requirement BiocompatibilityRequirement {
            subject airway = airway;
        }

        assert requirement AirflowSupportRequirement {
            subject airway = airway;
        }

        assert requirement PatientProtectionRequirement {
            subject airway = airway;
        }
    }
}