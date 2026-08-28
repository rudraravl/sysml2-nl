package EpiduralCatheterPlacementSystem {

    package ItemDefinitions {
        item def Saline {
            attribute volume : Real;
        }
        item def Air {
            attribute volume : Real;
        }
        item def Anesthetic {
            attribute concentration : Real;
            attribute volume : Real;
        }
        item def TissueLayer;
        item def Skin :> TissueLayer;
        item def SubcutaneousTissue :> TissueLayer;
        item def LigamentumFlavum :> TissueLayer;
        item def DuraMater :> TissueLayer;
        item def EpiduralSpace :> TissueLayer {
            attribute pressure : Real = 5.0;
        }
    }

    package PortDefinitions {
        private import ItemDefinitions::*;

        port def HubConnection {
            in item fluid : Saline;
            in item air : Air;
            in item anesthetic : Anesthetic;
            out item resistanceFeedback : Real;
        }
        port def TissueInterface {
            out item tissueResistance : Real;
        }
        port def PumpConnection {
            out item anesthetic : Anesthetic;
            attribute flowRate : Real;
        }
        port def CatheterConnection {
            in item anesthetic : Anesthetic;
        }
    }

    package PartDefinitions {
        private import ItemDefinitions::*;
        private import PortDefinitions::*;

        part def HuberTip {
            attribute curvatureAngle : Real = 30.0;
            port tipPort : TissueInterface;
        }

        part def Stylet {
            attribute length : Real;
        }

        part def NeedleShaft {
            attribute length : Real = 8.0;
            attribute outerDiameter : Real = 0.18;
            attribute depthGradations : Real[*] = (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0);
        }

        part def NeedleHub {
            port hubPort : HubConnection;
        }

        part def TuohyNeedle {
            part hub : NeedleHub;
            part shaft : NeedleShaft;
            part tip : HuberTip;
            part stylet : Stylet;
            port hubPort : HubConnection = hub.hubPort;
            port tipPort : TissueInterface = tip.tipPort;
        }

        part def SyringePlunger {
            attribute appliedForce : Real;
            attribute displacement : Real;
        }

        part def SyringeBarrel {
            attribute capacity : Real = 10.0;
            item contents : Saline[0..1];
            item airContents : Air[0..1];
        }

        part def LossOfResistanceSyringe {
            part plunger : SyringePlunger;
            part barrel : SyringeBarrel;
            port syringePort : ~HubConnection;
            attribute currentResistance : Real;
        }

        part def CatheterTube {
            attribute length : Real = 90.0;
            attribute outerDiameter : Real = 0.1;
            attribute insertionDepth : Real;
        }

        part def EpiduralCatheter {
            part tube : CatheterTube;
            port proximalPort : CatheterConnection;
            port distalPort : TissueInterface;
        }

        part def AnesthesiaPump {
            port pumpPort : ~PumpConnection;
            attribute flowRate : Real;
            attribute reservoirVolume : Real;
        }

        part def Patient {
            part skin : Skin;
            part subcutaneousTissue : SubcutaneousTissue;
            part ligamentumFlavum : LigamentumFlavum;
            part epiduralSpace : EpiduralSpace;
            part duraMater : DuraMater;
            port skinEntry : TissueInterface;
            port epiduralAccess : TissueInterface;
        }
    }

    package ConnectionDefinitions {
        private import PartDefinitions::*;
        private import PortDefinitions::*;

        connection def SyringeToNeedle {
            end syringeEnd : ~HubConnection;
            end needleEnd : HubConnection;
        }

        connection def CatheterToPump {
            end catheterEnd : CatheterConnection;
            end pumpEnd : ~PumpConnection;
        }

        connection def NeedleToTissue {
            end needleEnd : TissueInterface;
            end tissueEnd : TissueInterface;
        }
    }

    package Requirements {
        private import PartDefinitions::*;

        requirement def SafeEpiduralAccess {
            doc /* The system shall safely access the epidural space without puncturing the dura mater. */
            subject patient : Patient;
            constraint { doc /* Dura mater shall remain intact after needle placement. */ }
        }

        requirement def LossOfResistanceFeedback {
            doc /* The system shall provide clear tactile loss-of-resistance feedback upon entering the epidural space. */
            subject syringe : LossOfResistanceSyringe;
            constraint { doc /* Plunger resistance shall drop significantly upon entering the epidural space. */ }
        }

        requirement def CatheterPlacement {
            doc /* The catheter shall be threaded through the needle and advanced beyond the tip into the epidural space. */
            subject catheter : EpiduralCatheter;
            constraint { doc /* Catheter shall be secured within the epidural space after needle withdrawal. */ }
        }

        requirement def ContinuousAnesthesiaDelivery {
            doc /* The system shall enable continuous delivery of anesthetic through the catheter via a pump. */
            subject pump : AnesthesiaPump;
            constraint { doc /* Pump shall deliver anesthetic at a controlled, adjustable flow rate. */ }
        }
    }

    package StateMachineDefinitions {
        state machine def ProcedureStates {
            state EquipmentPrepared;
            state NeedleAdvancing;
            state EpiduralSpaceLocated;
            state CatheterThreaded;
            state NeedleWithdrawn;
            state AnesthesiaActive;
            transition from EquipmentPrepared to NeedleAdvancing;
            transition from NeedleAdvancing to EpiduralSpaceLocated;
            transition from EpiduralSpaceLocated to CatheterThreaded;
            transition from CatheterThreaded to NeedleWithdrawn;
            transition from NeedleWithdrawn to AnesthesiaActive;
        }
    }

    package ProcedureModel {
        private import ItemDefinitions::*;
        private import PortDefinitions::*;
        private import PartDefinitions::*;
        private import ConnectionDefinitions::*;
        private import Requirements::*;
        private import StateMachineDefinitions::*;

        part epiduralSystem {

            part patient : Patient;
            part needle : TuohyNeedle;
            part syringe : LossOfResistanceSyringe;
            part catheter : EpiduralCatheter;
            part pump : AnesthesiaPump;

            connection syringeNeedleConn : SyringeToNeedle[0..1]
                connect syringe.syringePort to needle.hubPort;

            connection catheterPumpConn : CatheterToPump[0..1]
                connect catheter.proximalPort to pump.pumpPort;

            connection needleTissueConn : NeedleToTissue[0..1]
                connect needle.tipPort to patient.skinEntry;

            flow salineFlow
                from syringe.syringePort.fluid
                to needle.hubPort.fluid;

            flow resistanceFeedbackFlow
                from needle.tipPort.tissueResistance
                to syringe.syringePort.resistanceFeedback;

            flow anestheticDeliveryFlow
                from pump.pumpPort.anesthetic
                to catheter.proximalPort.anesthetic;

            satisfy SafeEpiduralAccess by patient;
            satisfy LossOfResistanceFeedback by syringe;
            satisfy CatheterPlacement by catheter;
            satisfy ContinuousAnesthesiaDelivery by pump;

            perform action performProcedure {

                action prepareEquipment {
                    doc /* Attach loss-of-resistance syringe to Tuohy needle hub. */
                    abstract ref :>> syringeNeedleConn[1];
                }

                then action advanceNeedle {
                    doc /* Advance needle through skin, subcutaneous tissue, and ligamentum flavum. */
                    action penetrateSkin {
                        abstract ref :>> needleTissueConn[1];
                    }
                    then action penetrateSubcutaneousTissue;
                    then action penetrateLigamentumFlavum {
                        doc /* Apply constant pressure to syringe plunger; plunger cannot move due to high resistance. */
                    }
                }

                then action detectLossOfResistance {
                    doc /* Needle tip exits ligamentum flavum into epidural space; plunger gives way suddenly. */
                    attribute plungerDisplacement : Real;
                    attribute resistanceDrop : Real;
                }

                then action detachSyringe {
                    doc /* Remove syringe from needle hub after confirming epidural space entry. */
                    abstract ref :>> syringeNeedleConn[0];
                }

                then action threadCatheter {
                    doc /* Thread epidural catheter through hollow Tuohy needle and advance beyond tip. */
                    action insertCatheterThroughNeedle;
                    then action advanceCatheterBeyondTip {
                        doc /* Advance catheter a few centimeters beyond needle tip into epidural space. */
                    }
                }

                then action withdrawNeedle {
                    doc /* Carefully withdraw Tuohy needle over catheter, leaving catheter in place. */
                }

                then action secureAndConnect {
                    doc /* Secure catheter to patient's back and connect to anesthesia pump. */
                    action secureCatheterToPatient;
                    then action connectToPump {
                        abstract ref :>> catheterPumpConn[1];
                    }
                    then action initiateAnesthesiaDelivery {
                        doc /* Begin controlled continuous infusion of anesthetic agent. */
                    }
                }
            }

            state machine : ProcedureStates;
        }
    }
}
