package SchiotzTonometer {

    import ScalarValues::*;

    // ============ Value Types ============

    value def MassValue :> Real {
        doc /* Mass in grams (g). */
        attribute unit : String = "g";
    }

    value def LengthValue :> Real {
        doc /* Length in millimetres (mm). */
        attribute unit : String = "mm";
    }

    value def ForceValue :> Real {
        doc /* Force in millinewtons (mN). */
        attribute unit : String = "mN";
    }

    value def PressureValue :> Real {
        doc /* Pressure in millimetres of mercury (mmHg). */
        attribute unit : String = "mmHg";
    }

    value def DisplacementValue :> Real {
        doc /* Linear displacement in millimetres (mm). */
        attribute unit : String = "mm";
    }

    value def ScaleMarkValue :> Real {
        doc /* Dimensionless calibrated scale mark, range 0 to 20. */
    }

    value def LeverRatioValue :> Real {
        doc /* Mechanical amplification ratio of the lever mechanism. */
    }

    // ============ Item Definitions ============

    item def PlungerDisplacementSignal {
        doc /* Signal representing the raw small displacement of the plunger. */
        attribute displacement : DisplacementValue;
    }

    item def AmplifiedDisplacementSignal {
        doc /* Signal representing the amplified displacement output by the lever. */
        attribute displacement : DisplacementValue;
    }

    item def PointerPositionSignal {
        doc /* Signal representing the pointer position on the calibrated scale. */
        attribute mark : ScaleMarkValue;
    }

    item def RawReading {
        doc /* Operator reading combining scale mark and applied weight. */
        attribute scaleMark : ScaleMarkValue;
        attribute appliedWeight : MassValue;
    }

    item def IOPResult {
        doc /* Final converted IOP result in mmHg. */
        attribute iop : PressureValue;
        attribute scaleMark : ScaleMarkValue;
        attribute appliedWeight : MassValue;
    }

    // ============ Port Definitions ============

    port def CorneaIndentationApplyPort {
        doc /* Port through which the plunger applies force to the cornea. */
        out appliedForce : ForceValue;
        in indentation : DisplacementValue;
    }

    port def CorneaResponsePort {
        doc /* Port on the patient's eye responding to applied force with indentation. */
        in appliedForce : ForceValue;
        out indentation : DisplacementValue;
    }

    port def PlungerDisplacementOutPort {
        out displacement : PlungerDisplacementSignal;
    }

    port def PlungerDisplacementInPort {
        in displacement : PlungerDisplacementSignal;
    }

    port def AmplifiedDisplacementOutPort {
        out displacement : AmplifiedDisplacementSignal;
    }

    port def AmplifiedDisplacementInPort {
        in displacement : AmplifiedDisplacementSignal;
    }

    port def PointerPositionOutPort {
        out position : PointerPositionSignal;
    }

    port def PointerPositionInPort {
        in position : PointerPositionSignal;
    }

    port def WeightAttachmentPort {
        doc /* Mechanical attachment interface on the plunger for an interchangeable weight. */
        in attachedMass : MassValue;
    }

    port def WeightMountPort {
        doc /* Mechanical attachment interface on a weight to be added to the plunger. */
        out attachedMass : MassValue;
    }

    // ============ Connection Definitions ============

    connection def PlungerDisplacementFlow {
        end source : PlungerDisplacementOutPort;
        end target : PlungerDisplacementInPort;
    }

    connection def AmplifiedDisplacementFlow {
        end source : AmplifiedDisplacementOutPort;
        end target : AmplifiedDisplacementInPort;
    }

    connection def PointerReadingFlow {
        end source : PointerPositionOutPort;
        end target : PointerPositionInPort;
    }

    connection def WeightMountFlow {
        end source : WeightMountPort;
        end target : WeightAttachmentPort;
    }

    connection def CorneaInteractionFlow {
        end source : CorneaIndentationApplyPort;
        end target : CorneaResponsePort;
    }

    // ============ Action Definitions ============

    action def ConvertReadingToIOP {
        doc /* Convert a scale reading and applied weight into an IOP value via the standardized Schiøtz conversion table. */
        in scaleMark : ScaleMarkValue;
        in appliedWeight : MassValue;
        out iop : PressureValue;
    }

    action def IndentCornea {
        doc /* Apply the weighted plunger force to the cornea and capture the resulting indentation. */
        in appliedForce : ForceValue;
        out indentation : DisplacementValue;
    }

    // ============ Requirements ============

    requirement def IOPMeasurementRequirement {
        doc /* The tonometer shall measure intraocular pressure by indentation of the cornea and provide a value in mmHg. */
        subject tonometer : SchiotzTonometerAssembly;
        attribute targetMin : PressureValue = 0.0;
        attribute targetMax : PressureValue = 80.0;
        constraint { tonometer.measuredIOP >= targetMin and tonometer.measuredIOP <= targetMax }
    }

    requirement def InterchangeableWeightSetRequirement {
        doc /* The tonometer shall be supplied with interchangeable weights of 5.5 g, 7.5 g, and 10.0 g. */
        subject tonometer : SchiotzTonometerAssembly;
        constraint { tonometer.availableWeights == (5.5, 7.5, 10.0) }
    }

    requirement def ScaleCalibrationRequirement {
        doc /* The calibrated scale shall display pointer position from 0 to 20 marks. */
        subject tonometer : SchiotzTonometerAssembly;
        constraint { tonometer.calibratedScale.minMark == 0.0 }
        constraint { tonometer.calibratedScale.maxMark == 20.0 }
    }

    requirement def LeverAmplificationRequirement {
        doc /* The lever mechanism shall amplify plunger displacement by at least a factor of 2. */
        subject tonometer : SchiotzTonometerAssembly;
        attribute minRatio : LeverRatioValue = 2.0;
        constraint { tonometer.leverMechanism.leverRatio >= minRatio }
    }

    requirement def FootplateStabilityRequirement {
        doc /* The footplate shall provide a stable concave base with a central aperture for the plunger. */
        subject tonometer : SchiotzTonometerAssembly;
        constraint { tonometer.footplate.curvatureRadius > 0.0 }
        constraint { tonometer.footplate.apertureDiameter > 0.0 }
    }

    requirement def HousingFrameStructuralRequirement {
        doc /* The housing frame shall rigidly hold all moving components in proper alignment. */
        subject tonometer : SchiotzTonometerAssembly;
        constraint { tonometer.housingFrame.material == "stainless steel" }
    }

    // ============ Part Definitions ============

    part def Footplate {
        doc /* Curved base that rests gently on the surface of the patient's eye. */
        attribute curvatureRadius : LengthValue = 15.0;
        attribute apertureDiameter : LengthValue = 3.0;
        attribute surfaceFinish : String = "polished concave";
    }

    part def Plunger {
        doc /* Precisely weighted plunger that indents the cornea through the footplate aperture. */
        attribute baseMass : MassValue = 5.5;
        attribute addedMass : MassValue = 0.0;
        attribute totalMass : MassValue;
        constraint { totalMass == baseMass + addedMass }
        attribute length : LengthValue = 50.0;
        attribute currentDisplacement : DisplacementValue;
        attribute appliedForce : ForceValue;

        port weightAttachmentPort : WeightAttachmentPort;
        port corneaIndentPort : CorneaIndentationApplyPort;
        port displacementOut : PlungerDisplacementOutPort;
    }

    part def InterchangeableWeight {
        doc /* Generic supplementary weight added to the plunger to vary the indentation force. */
        attribute mass : MassValue;
        constraint { mass in (5.5, 7.5, 10.0) }
        port weightMountPort : WeightMountPort;
    }

    part def Weight5_5g :> InterchangeableWeight {
        doc /* The 5.5 g supplementary weight. */
        redefines mass = 5.5;
    }

    part def Weight7_5g :> InterchangeableWeight {
        doc /* The 7.5 g supplementary weight. */
        redefines mass = 7.5;
    }

    part def Weight10_0g :> InterchangeableWeight {
        doc /* The 10.0 g supplementary weight. */
        redefines mass = 10.0;
    }

    part def WeightSet {
        doc /* Standard set of interchangeable weights supplied with the tonometer. */
        part weight5_5g : Weight5_5g;
        part weight7_5g : Weight7_5g;
        part weight10_0g : Weight10_0g;
    }

    part def LeverMechanism {
        doc /* Mechanical lever that amplifies the small plunger displacement to a readable pointer movement. */
        attribute leverRatio : LeverRatioValue = 2.0;
        attribute shortArm : LengthValue = 10.0;
        attribute longArm : LengthValue = 20.0;
        attribute pivotFriction : ForceValue = 0.1;

        port displacementIn : PlungerDisplacementInPort;
        port displacementOut : AmplifiedDisplacementOutPort;

        action amplify {
            doc /* Amplify the input displacement by the lever ratio. */
            in displacement : DisplacementValue;
            out amplified : DisplacementValue;
        }
    }

    part def Pointer {
        doc /* Pointer driven by the amplified lever movement. */
        attribute position : ScaleMarkValue;
        attribute length : LengthValue = 40.0;

        port displacementIn : AmplifiedDisplacementInPort;
        port positionOut : PointerPositionOutPort;
    }

    part def CalibratedScale {
        doc /* Calibrated scale with marks from 0 to 20 indicating amplified pointer position. */
        attribute minMark : ScaleMarkValue = 0.0;
        attribute maxMark : ScaleMarkValue = 20.0;
        attribute graduationInterval : ScaleMarkValue = 0.5;
        attribute material : String = "engraved metal";

        port readingIn : PointerPositionInPort;
    }

    part def HousingFrame {
        doc /* Structural frame that holds all components in alignment. */
        attribute material : String = "stainless steel";
        attribute mass : MassValue = 200.0;
        attribute height : LengthValue = 120.0;
    }

    part def PatientEye {
        doc /* The patient's eye being examined, providing corneal resistance against the plunger. */
        attribute cornealRadius : LengthValue = 7.8;
        attribute internalPressure : PressureValue;
        attribute cornealElasticity : Real = 0.5;

        port corneaInterface : CorneaResponsePort;
    }

    part def SchiotzTonometerAssembly {
        doc /* Schiøtz tonometer: complete mechanical assembly for measuring intraocular pressure by corneal indentation. */

        attribute measuredIOP : PressureValue;
        attribute currentScaleMark : ScaleMarkValue;
        attribute selectedWeight : MassValue = 5.5;
        attribute availableWeights : MassValue[3] = (5.5, 7.5, 10.0);

        part footplate : Footplate;
        part plunger : Plunger;
        part leverMechanism : LeverMechanism;
        part pointer : Pointer;
        part calibratedScale : CalibratedScale;
        part housingFrame : HousingFrame;
        part weightSet : WeightSet;
        part patientEye : PatientEye;

        connection plungerToLever : PlungerDisplacementFlow connect plunger.displacementOut to leverMechanism.displacementIn;
        connection leverToPointer : AmplifiedDisplacementFlow connect leverMechanism.displacementOut to pointer.displacementIn;
        connection pointerToScale : PointerReadingFlow connect pointer.positionOut to calibratedScale.readingIn;
        connection plungerToEye : CorneaInteractionFlow connect plunger.corneaIndentPort to patientEye.corneaInterface;
        connection weightToPlunger : WeightMountFlow connect weightSet.weight5_5g.weightMountPort to plunger.weightAttachmentPort;

        state tonometerStates {
            state idle {
                doc /* Tonometer at rest, ready for measurement. */
            }
            state positioning {
                doc /* Operator carefully places the tonometer on the eye. */
            }
            state measuring {
                doc /* Weighted plunger indents the cornea; displacement is being measured. */
            }
            state reading {
                doc /* Pointer indicates the amplified position; operator reads the scale and looks up IOP. */
            }

            transition idle to positioning when operatorPlacesTonometerOnEye;
            transition positioning to measuring when corneaContactEstablished;
            transition measuring to reading when plungerDisplacementStable;
            transition reading to idle when operatorLiftsTonometer;
        }

        action convertReadingToIOP : ConvertReadingToIOP {
            doc /* Look up the final IOP from the scale reading and the applied weight. */
        }

        satisfy iopReq : IOPMeasurementRequirement;
        satisfy weightSetReq : InterchangeableWeightSetRequirement;
        satisfy scaleReq : ScaleCalibrationRequirement;
        satisfy leverReq : LeverAmplificationRequirement;
        satisfy footplateReq : FootplateStabilityRequirement;
        satisfy housingReq : HousingFrameStructuralRequirement;
    }

}
