package EpiduralCatheterPlacement {

    import ScalarValues::*;

    // ─── Value Types ───
    value type Length :> Real { unit 'mm'; }
    value type Pressure :> Real { unit 'kPa'; }
    value type Force :> Real { unit 'N'; }
    value type Volume :> Real { unit 'mL'; }
    value type Angle :> Real { unit 'deg'; }
    value type Diameter :> Real { unit 'mm'; }
    value type FlowRate :> Real { unit 'mL/hr'; }
    value type MassConcentration :> Real { unit 'mg/mL'; }

    // ─── Item Definitions ───
    item def Saline {
        attribute density : Real = 1.005;
    }

    item def Air {
        attribute density : Real = 0.0012;
    }

    item def AnestheticAgent {
        attribute name : String = "Bupivacaine";
        attribute concentration : MassConcentration = 2.5;
    }

    // ─── Port Definitions ───
    port def HubConnection {
        attribute connected : Boolean = false;
    }

    port def CatheterPort {
        attribute catheterInserted : Boolean = false;
    }

    port def FluidPort {
        in item fluid : Saline;
        attribute pressure : Pressure = 0.0;
    }

    // ─── Patient Anatomy ───
    part def TissueLayer {
        attribute name : String;
        attribute resistance : Pressure;
        attribute thickness : Length;
    }

    part def PatientAnatomy {
        part skin : TissueLayer {
            attribute name : String = "Skin";
            attribute resistance : Pressure = 20.0;
            attribute thickness : Length = 3.0;
        }
        part subcutaneousTissue : TissueLayer {
            attribute name : String = "Subcutaneous Tissue";
            attribute resistance : Pressure = 15.0;
            attribute thickness : Length = 15.0;
        }
        part supraspinousLigament : TissueLayer {
            attribute name : String = "Supraspinous Ligament";
            attribute resistance : Pressure = 60.0;
            attribute thickness : Length = 5.0;
        }
        part interspinousLigament : TissueLayer {
            attribute name : String = "Interspinous Ligament";
            attribute resistance : Pressure = 70.0;
            attribute thickness : Length = 10.0;
        }
        part ligamentumFlavum : TissueLayer {
            attribute name : String = "Ligamentum Flavum";
            attribute resistance : Pressure = 80.0;
            attribute thickness : Length = 6.0;
        }
        part epiduralSpace : TissueLayer {
            attribute name : String = "Epidural Space";
            attribute resistance : Pressure = 5.0;
            attribute thickness : Length = 4.0;
        }
        part duraMater : TissueLayer {
            attribute name : String = "Dura Mater";
            attribute resistance : Pressure = 100.0;
            attribute thickness : Length = 0.8;
        }
    }

    // ─── Needle Components ───
    part def NeedleHub {
        port outPort : HubConnection;
        attribute material : String = "Polycarbonate";
        attribute luerLockType : String = "Luer-Lok";
    }

    part def NeedleShaft {
        port inPort : HubConnection;
        port outPort : HubConnection;
        attribute length : Length = 80.0;
        attribute outerDiameter : Diameter = 1.65;
        attribute innerDiameter : Diameter = 1.35;
        attribute depthGradations : Boolean = true;
        attribute gradationInterval : Length = 5.0;
        attribute material : String = "Stainless Steel";
    }

    part def HuberTip {
        port inPort : HubConnection;
        attribute bevelAngle : Angle = 30.0;
        attribute tipRadius : Diameter = 0.5;
        attribute designType : String = "Curved Huber";
        attribute tissueSeparationDesign : Boolean = true;
    }

    part def RemovableStylet {
        attribute length : Length = 95.0;
        attribute diameter : Diameter = 1.2;
        attribute material : String = "Stainless Steel";
        attribute inserted : Boolean = true;
        attribute removable : Boolean = true;
    }

    part def TuohyNeedleAssembly {
        attribute needleLength : Length = 90.0;
        attribute needleGauge : Real = 16.0;
        attribute outerDiameter : Diameter = 1.65;
        attribute innerDiameter : Diameter = 1.35;
        attribute insertionDepth : Length = 0.0;
        attribute fullyWithdrawn : Boolean = false;

        port hubPort : HubConnection;
        port catheterPort : CatheterPort;

        part hub : NeedleHub;
        part shaft : NeedleShaft;
        part bevelTip : HuberTip;
        part stylet : RemovableStylet;

        connection hubToShaft connect hub.outPort to shaft.inPort;
        connection shaftToTip connect shaft.outPort to bevelTip.inPort;
    }

    // ─── Syringe Components ───
    part def SyringeBarrel {
        port plungerPort : HubConnection;
        port fluidPort : FluidPort;
        attribute volume : Volume = 10.0;
        attribute material : String = "Polypropylene";
        attribute currentFillVolume : Volume = 5.0;
    }

    part def SyringePlunger {
        port barrelPort : HubConnection;
        attribute position : Length = 50.0;
        attribute forceApplied : Force = 0.0;
        attribute movable : Boolean = false;
        attribute sealType : String = "Rubber O-ring";
    }

    part def LossOfResistanceSyringe {
        attribute barrelVolume : Volume = 10.0;
        attribute currentVolume : Volume = 5.0;
        attribute plungerForce : Force = 0.0;
        attribute resistanceLevel : Pressure = 0.0;
        attribute lossOfResistanceDetected : Boolean = false;

        port syringePort : HubConnection;
        port fluidPort : FluidPort;

        part barrel : SyringeBarrel;
        part plunger : SyringePlunger;
        item saline : Saline;

        connection plungerToBarrel connect plunger.barrelPort to barrel.plungerPort;
    }

    // ─── Catheter Components ───
    part def CatheterBody {
        attribute length : Length = 900.0;
        attribute diameter : Diameter = 0.85;
        attribute material : String = "Nylon/Polyurethane";
        attribute flexibilityRating : String = "High";
        attribute radiopaque : Boolean = true;
        attribute tipDesign : String = "Closed soft tip with lateral holes";
    }

    part def CatheterFixation {
        attribute type : String = "Adhesive transparent dressing";
        attribute secured : Boolean = false;
    }

    part def EpiduralCatheter {
        attribute totalLength : Length = 900.0;
        attribute outerDiameter : Diameter = 0.85;
        attribute material : String = "Nylon/Polyurethane";
        attribute insertedDepth : Length = 0.0;
        attribute secured : Boolean = false;
        attribute connectedToPump : Boolean = false;

        port proximalPort : CatheterPort;
        port distalPort : CatheterPort;

        part catheterBody : CatheterBody;
        part fixationDevice : CatheterFixation;
    }

    // ─── Anesthesia Pump ───
    part def AnesthesiaPump {
        attribute flowRate : FlowRate = 5.0;
        attribute reservoirVolume : Volume = 100.0;
        attribute pumpType : String = "Elastomeric continuous infusion";
        attribute active : Boolean = false;

        port pumpPort : CatheterPort;
        item anesthetic : AnestheticAgent;
    }

    // ─── Clinician ───
    part def Clinician {
        attribute role : String = "Anesthesiologist";
        attribute tactileSensitivity : Real = 1.0;
        attribute gloved : Boolean = true;
    }

    // ─── System Definition ───
    part def EpiduralPlacementSystem {
        part tuohyNeedle : TuohyNeedleAssembly;
        part lorSyringe : LossOfResistanceSyringe;
        part epiduralCatheter : EpiduralCatheter;
        part anesthesiaPump : AnesthesiaPump;
        part patientAnatomy : PatientAnatomy;
        part clinician : Clinician;

        connection needleSyringeConnection
            connect lorSyringe.syringePort to tuohyNeedle.hubPort;
        connection catheterThroughNeedle
            connect epiduralCatheter.proximalPort to tuohyNeedle.catheterPort;
        connection catheterToPump
            connect epiduralCatheter.distalPort to anesthesiaPump.pumpPort;

        exhibit state machine procedureStateMachine {
            entry; then PreparingEquipment;

            state PreparingEquipment {
                // Prepare equipment: attach syringe to needle hub, remove stylet
                entry action {
                    tuohyNeedle.stylet.inserted = false;
                    lorSyringe.syringePort.connected = true;
                    tuohyNeedle.hubPort.connected = true;
                    lorSyringe.currentVolume = 5.0;
                }
                transition done to AdvancingNeedle;
            }

            state AdvancingNeedle {
                // Advance needle through skin, subcutaneous tissue, and spinal ligaments
                // Apply constant gentle pressure to syringe plunger
                entry action {
                    lorSyringe.plunger.forceApplied = 2.0;
                    lorSyringe.plunger.movable = false;
                    lorSyringe.resistanceLevel = 80.0;
                    tuohyNeedle.insertionDepth = 39.0;
                }
                transition if (lorSyringe.resistanceLevel < 10.0) to LossOfResistanceDetected;
            }

            state LossOfResistanceDetected {
                // Needle tip exits ligamentum flavum into epidural space
                // Sudden loss of resistance; plunger gives way easily
                entry action {
                    lorSyringe.plunger.movable = true;
                    lorSyringe.plunger.position = 45.0;
                    lorSyringe.lossOfResistanceDetected = true;
                    lorSyringe.resistanceLevel = 5.0;
                }
                transition done to DetachingSyringe;
            }

            state DetachingSyringe {
                // Detach the loss-of-resistance syringe from the needle hub
                entry action {
                    lorSyringe.syringePort.connected = false;
                    tuohyNeedle.hubPort.connected = false;
                }
                transition done to ThreadingCatheter;
            }

            state ThreadingCatheter {
                // Thread the epidural catheter through the hollow Tuohy needle
                // Advance a few centimeters beyond the needle tip
                entry action {
                    epiduralCatheter.insertedDepth = 50.0;
                    epiduralCatheter.proximalPort.catheterInserted = true;
                    tuohyNeedle.catheterPort.catheterInserted = true;
                }
                transition if (epiduralCatheter.insertedDepth >= 40.0) to WithdrawingNeedle;
            }

            state WithdrawingNeedle {
                // Carefully withdraw the Tuohy needle over the catheter
                entry action {
                    tuohyNeedle.fullyWithdrawn = true;
                    tuohyNeedle.insertionDepth = 0.0;
                }
                transition done to SecuringCatheter;
            }

            state SecuringCatheter {
                // Secure the external end of the catheter to the patient's back
                entry action {
                    epiduralCatheter.secured = true;
                    epiduralCatheter.fixationDevice.secured = true;
                }
                transition done to ConnectingPump;
            }

            state ConnectingPump {
                // Connect the catheter to the anesthesia pump for continuous delivery
                entry action {
                    epiduralCatheter.distalPort.catheterInserted = true;
                    anesthesiaPump.pumpPort.catheterInserted = true;
                    epiduralCatheter.connectedToPump = true;
                    anesthesiaPump.active = true;
                }
                transition done to ProcedureComplete;
            }

            state ProcedureComplete {
                // Epidural catheter placement procedure is complete
                // Catheter is in epidural space, secured, and connected to pump
            }
        }
    }

    // ─── Requirements ───
    requirement def EpiduralSafetyRequirement {
        doc /* The system shall safely access the epidural space without puncturing the dura mater. */
        attribute maxDuraPenetrationRisk : Real = 0.0;
        attribute duraIntact : Boolean = true;
    }

    requirement def TuohyNeedleDesignRequirement {
        doc /* The Tuohy needle shall feature a curved Huber tip to separate tissue layers rather than puncture them. */
        attribute bevelAngleMin : Angle = 25.0;
        attribute bevelAngleMax : Angle = 35.0;
        attribute tipDesign : String = "Curved Huber";
        attribute tissueSeparationDesign : Boolean = true;
    }

    requirement def DepthGradationRequirement {
        doc /* The needle shaft shall have depth gradations for precise insertion tracking. */
        attribute gradationInterval : Length = 5.0;
        attribute gradationsPresent : Boolean = true;
    }

    requirement def StyletRequirement {
        doc /* The needle shall include a removable stylet to prevent tissue clogging during initial insertion. */
        attribute styletPresent : Boolean = true;
        attribute styletRemovable : Boolean = true;
    }

    requirement def LossOfResistanceDetectionRequirement {
        doc /* The syringe shall provide tactile feedback when the needle tip enters the epidural space. */
        attribute resistanceThreshold : Pressure = 10.0;
        attribute plungerGivesWay : Boolean = true;
        attribute tactileFeedbackProvided : Boolean = true;
    }

    requirement def CatheterPlacementRequirement {
        doc /* The catheter shall be threaded 3-5 cm beyond the needle tip into the epidural space. */
        attribute minInsertionDepth : Length = 30.0;
        attribute maxInsertionDepth : Length = 50.0;
    }

    requirement def CatheterSecurementRequirement {
        doc /* The catheter shall be secured to the patient's back after needle withdrawal. */
        attribute secured : Boolean = true;
        attribute fixationType : String = "Adhesive transparent dressing";
    }

    requirement def ContinuousAnesthesiaRequirement {
        doc /* The system shall support continuous anesthetic delivery via pump connection. */
        attribute pumpConnected : Boolean = true;
        attribute minFlowRate : FlowRate = 1.0;
        attribute maxFlowRate : FlowRate = 20.0;
    }

    requirement def NeedleGaugeRequirement {
        doc /* The Tuohy needle shall be of appropriate gauge for epidural placement. */
        attribute gaugeMin : Real = 16.0;
        attribute gaugeMax : Real = 18.0;
    }

    requirement def SyringeVolumeRequirement {
        doc /* The loss-of-resistance syringe shall hold sufficient saline or air for tactile feedback. */
        attribute minVolume : Volume = 3.0;
        attribute maxVolume : Volume = 10.0;
    }

    requirement def CatheterFlexibilityRequirement {
        doc /* The epidural catheter shall be flexible enough to navigate the epidural space without kinking. */
        attribute flexibilityRating : String = "High";
        attribute radiopaque : Boolean = true;
    }

    requirement epiduralProcedureReq : EpiduralSafetyRequirement;
    requirement needleDesignReq : TuohyNeedleDesignRequirement;
    requirement depthGradReq : DepthGradationRequirement;
    requirement styletReq : StyletRequirement;
    requirement lorDetectionReq : LossOfResistanceDetectionRequirement;
    requirement catheterPlacementReq : CatheterPlacementRequirement;
    requirement catheterSecurementReq : CatheterSecurementRequirement;
    requirement continuousAnesthesiaReq : ContinuousAnesthesiaRequirement;
    requirement needleGaugeReq : NeedleGaugeRequirement;
    requirement syringeVolumeReq : SyringeVolumeRequirement;
    requirement catheterFlexibilityReq : CatheterFlexibilityRequirement;
}
