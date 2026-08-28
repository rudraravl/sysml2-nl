package MedicalEyepatchSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types with Units ----

    value type LightTransmittanceValue :> Real {
        doc
        /*!
         * Fraction of incoming light transmitted through a material.
         * Expressed as a percentage from 0 to 100.
         */
    }

    value type LengthValue :> Real {
        doc /* A length measurement in millimeters. */
    }

    value type TensionValue :> Real {
        doc /* Tension force in newtons. */
    }

    value type PressureValue :> Real {
        doc /* Pressure applied to skin in kilopascals. */
    }

    value type MassValue :> Real {
        doc /* Mass in grams. */
    }

    value type CoverageAreaValue :> Real {
        doc /* Coverage area in square centimeters. */
    }

    // ---- Item Types ----

    item AmbientLight {
        doc /* Incident light striking the outer surface of the eyepatch. */
        attribute intensity : LightTransmittanceValue;
    }

    item BlockedLight :> AmbientLight {
        doc /* Light rejected by the occlusive pad. */
    }

    item TransmittedLight :> AmbientLight {
        doc /* Residual light passing through the occlusive pad. */
    }

    item ContactForce {
        doc /* Force applied to the wearer's skin by the cushion layer. */
        attribute magnitude : TensionValue;
    }

    item StrapTension {
        doc /* Tension maintained along the adjustable strap. */
        attribute magnitude : TensionValue;
    }

    // ---- Component Parts ----

    part def OcclusivePad {
        doc
        /*!
         * Core padding element that fits directly over the eye socket,
         * blocking at least 98 percent of incoming light.
         */

        attribute material : String = "Soft opaque foam";
        attribute thickness : LengthValue = 8.0;
        attribute width : LengthValue = 70.0;
        attribute height : LengthValue = 55.0;
        attribute coverageArea : CoverageAreaValue = 38.5;
        attribute mass : MassValue = 12.0;
        attribute maxTransmittance : LightTransmittanceValue = 2.0;

        port lightIn : AmbientLight;
        port lightOut : TransmittedLight;

        action block LightBlocking {
            in incoming : AmbientLight;
            out transmitted : TransmittedLight;
            doc /* Attenuates incoming light to below the maximum transmittance. */
        }
    }

    part def CushionLayer {
        doc
        /*!
         * Breathable soft interface attached to the inner rim of the
         * occlusive pad. Distributes pressure evenly over the skin.
         */

        attribute material : String = "Breathable hypoallergenic fabric";
        attribute breathability : Real = 0.85;
        attribute thickness : LengthValue = 2.5;
        attribute maxSkinPressure : PressureValue = 3.2;
        attribute distributedArea : CoverageAreaValue = 38.5;

        port skinInterface : ContactForce;

        action block PressureDistribution {
            in appliedForce : TensionValue;
            out distributedPressure : PressureValue;
            doc /* Spreads strap tension across the contact area. */
        }
    }

    part def AdjustableStrap {
        doc
        /*!
         * Elastic durable strap that secures the eyepatch to the wearer's
         * head. Length is adjustable to accommodate different head sizes.
         */

        attribute material : String = "Elastic woven band";
        attribute minLength : LengthValue = 380.0;
        attribute maxLength : LengthValue = 720.0;
        attribute currentLength : LengthValue = 560.0;
        attribute maxTension : TensionValue = 18.0;
        attribute minTension : TensionValue = 2.5;
        attribute comfortTension : TensionValue = 8.0;

        port strapEndA : StrapTension;
        port strapEndB : StrapTension;

        action block LengthAdjustment {
            in target : LengthValue;
            out adjusted : LengthValue;
            doc /* Adjusts the strap length within its allowed range. */
        }

        action block TensionApplication {
            in length : LengthValue;
            out tension : StrapTension;
            doc /* Converts strap length into tension based on elasticity. */
        }
    }

    // ---- System Part ----

    part def MedicalEyepatch {
        doc
        /*!
         * A medical eyepatch system that protects and shields an injured
         * or recovering eye by blocking ambient light and preventing
         * physical contact, while remaining secure and comfortable.
         */

        attribute serialNumber : String;
        attribute intendedUse : String = "Post-injury eye protection";

        part occlusivePad : OcclusivePad {
            redefines lightIn;
            redefines lightOut;
        }

        part cushionLayer : CushionLayer {
            redefines skinInterface;
        }

        part adjustableStrap : AdjustableStrap {
            redefines strapEndA;
            redefines strapEndB;
        }

        connection padToCushion {
            end : occlusivePad;
            end : cushionLayer;
            doc /* Cushion layer is bonded to the inner rim of the occlusive pad. */
        }

        connection strapToCushion {
            end : adjustableStrap.strapEndA;
            end : cushionLayer.skinInterface;
            doc /* Strap couples its tension into the cushion layer interface. */
        }

        connection padLightPath {
            end : occlusivePad.lightIn;
            end : occlusivePad.lightOut;
            doc /* Light attenuation path through the occlusive pad. */
        }

        // ---- Operational State Machine ----

        state def EyepatchLifecycle;

        state machine EyepatchLifecycleBehavior : EyepatchLifecycle {
            state idle {
                doc /* Eyepatch is not in use and stored. */
                entry action { MedicalEyepatch.adjustableStrap.currentLength = 480.0; }
            }

            state fitting {
                doc /* User positions pad over the eye and adjusts strap. */
                entry action {
                    MedicalEyepatch.adjustableStrap.currentLength =
                        MedicalEyepatch.adjustableStrap.comfortTension;
                }
                do action { MedicalEyepatch.adjustableStrap.LengthAdjustment(
                    MedicalEyepatch.adjustableStrap.comfortTension); }
            }

            state active {
                doc /* Eyepatch is secured and continuously protects the eye. */
                entry action { MedicalEyepatch.occlusivePad.LightBlocking(
                    AmbientLight{intensity = 100.0}); }
                do action { MonitorComfort(); }
                exit action { MedicalEyepatch.cushionLayer.PressureDistribution(
                    MedicalEyepatch.adjustableStrap.maxTension); }
            }

            state readjusting {
                doc /* Fit is too tight or too loose and requires readjustment. */
                entry action { MedicalEyepatch.adjustableStrap.LengthAdjustment(
                    MedicalEyepatch.adjustableStrap.comfortTension); }
            }

            state removed {
                doc /* Eyepatch is being taken off the wearer. */
                entry action { MedicalEyepatch.adjustableStrap.currentLength = 480.0; }
            }

            transition idle -> fitting when UserRequestsFit();
            transition fitting -> active when StrapSecured();
            transition active -> readjusting when FitDriftDetected();
            transition readjusting -> active when StrapReadjusted();
            transition active -> removed when UserRemovesPatch();
            transition removed -> idle when PatchCleaned();

            action UserRequestsFit { out done : Boolean; }
            action StrapSecured { out done : Boolean; }
            action FitDriftDetected { out done : Boolean; }
            action StrapReadjusted { out done : Boolean; }
            action UserRemovesPatch { out done : Boolean; }
            action PatchCleaned { out done : Boolean; }
            action MonitorComfort { out tensionOk : Boolean; }
        }

        attribute operationalState : EyepatchLifecycle = idle;
    }

    // ---- Requirements ----

    requirement def LightBlockingRequirement {
        doc /* The eyepatch shall block at least 98 percent of incoming ambient light. */
        subject eyepatch : MedicalEyepatch;
        objective { 
            eyepatch.occlusivePad.maxTransmittance <= 2.0 
        }
    }

    requirement def CoverageRequirement {
        doc /* The occlusive pad shall fully cover the wearer's eye socket. */
        subject pad : OcclusivePad;
        objective { 
            pad.coverageArea >= 35.0 
        }
    }

    requirement def ComfortRequirement {
        doc /* The cushion layer shall keep skin pressure below the irritation threshold. */
        subject cushion : CushionLayer;
        objective { 
            cushion.maxSkinPressure <= 3.5 
        }
    }

    requirement def StrapAdjustmentRequirement {
        doc /* The strap shall be adjustable to fit head circumferences between 380 and 720 mm. */
        subject strap : AdjustableStrap;
        objective { 
            strap.minLength <= 380.0 and 
            strap.maxLength >= 720.0 
        }
    }

    requirement def SecureFitRequirement {
        doc /* The eyepatch shall not slip during normal head movements. */
        subject eyepatch : MedicalEyepatch;
        objective { 
            eyepatch.adjustableStrap.maxTension >= 12.0 
        }
    }

    requirement def BreathingRequirement {
        doc /* The cushion layer shall be breathable to avoid moisture buildup. */
        subject cushion : CushionLayer;
        objective { 
            cushion.breathability >= 0.75 
        }
    }

    requirement EyepatchSystemRequirements {
        doc /* Top-level requirements for the medical eyepatch system. */
        satisfy LightBlockingRequirement;
        satisfy CoverageRequirement;
        satisfy ComfortRequirement;
        satisfy StrapAdjustmentRequirement;
        satisfy SecureFitRequirement;
        satisfy BreathingRequirement;
    }
}
