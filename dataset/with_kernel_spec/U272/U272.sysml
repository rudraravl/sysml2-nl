package EndotrachealIntubationSystem {
    public import Definitions::*;
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    package Definitions {
        item def Oxygen;
        item def Secretion;
        item def ExhaledCO2;

        port def OxygenPort;
        port def VentilationPort;
        port def SuctionPort;
        port def AirwayPort;

        interface def OxygenInterface {
            end supplier : OxygenPort;
            end consumer : OxygenPort;
        }
        interface def VentilationInterface {
            end supplier : VentilationPort;
            end consumer : VentilationPort;
        }
        interface def SuctionInterface {
            end supplier : SuctionPort;
            end consumer : SuctionPort;
        }
        interface def AirwayInterface {
            end tubeEnd : AirwayPort;
            end patientAirway : AirwayPort;
        }

        part def Patient {
            attribute spO2 : Real;
            attribute co2Detected : Boolean;
            attribute breathSoundsBilateral : Boolean;
            attribute chestRiseSymmetric : Boolean;
            attribute airwayClear : Boolean;
            port airwayPort : AirwayPort;
            port suctionPort : SuctionPort;
        }

        part def EndotrachealTube {
            attribute diameter :> ISQ::length;
            attribute insertionDepth :> ISQ::length;
            part cuff {
                attribute pressure :> ISQ::pressure;
                attribute inflated : Boolean;
            }
            port proximalPort : VentilationPort;
            port distalPort : AirwayPort;
        }

        part def Laryngoscope {
            part blade;
            part light {
                attribute on : Boolean;
            }
        }

        part def OxygenSource {
            attribute concentration : Real;
            port oxygenOutPort : OxygenPort;
        }

        part def VentilationBag {
            port oxygenInPort : OxygenPort;
            port tubeOutPort : VentilationPort;
        }

        part def SuctionDevice {
            port suctionPort : SuctionPort;
        }

        part def Clinician;

        part def IntubationEquipment {
            part ett : EndotrachealTube;
            part laryngoscope : Laryngoscope;
            part oxygenSource : OxygenSource;
            part ventilationBag : VentilationBag;
            part suctionDevice : SuctionDevice;
        }

        part def IntubationSystem {
            part clinician : Clinician;
            part equipment : IntubationEquipment;
            ref part patient : Patient;
        }

        requirement def CuffPressureRequirement {
            attribute actualPressure :> ISQ::pressure;
            attribute pressureMin :> ISQ::pressure = 2000 [Pa];
            attribute pressureMax :> ISQ::pressure = 3000 [Pa];
            doc /* The cuff pressure shall be between 20 and 30 cmH2O to prevent tracheal ischemia while ensuring an adequate seal. */
            require constraint { actualPressure >= pressureMin and actualPressure <= pressureMax }
        }

        requirement def PlacementConfirmationRequirement {
            attribute co2Detected : Boolean;
            attribute breathSoundsBilateral : Boolean;
            attribute chestRiseSymmetric : Boolean;
            doc /* Tube placement shall be confirmed by exhaled CO2 detection, bilateral breath sounds, and symmetric chest rise. */
            require constraint { co2Detected and breathSoundsBilateral and chestRiseSymmetric }
        }

        requirement def PreoxygenationRequirement {
            attribute spO2 : Real;
            doc /* The patient shall be pre-oxygenated with 100 percent oxygen to achieve SpO2 above 90. */
            require constraint { spO2 > 90 }
        }

        action def AssessPatient {
            in ref part patient : Patient;
            out needIntubation : Boolean;
        }
        action def Preoxygenate {
            in ref part patient : Patient;
            in ref part oxygenSource : OxygenSource;
            out oxygenated : Boolean;
        }
        action def PositionHead {
            in ref part patient : Patient;
            out positioned : Boolean;
        }
        action def VisualizeLarynx {
            in ref part patient : Patient;
            in ref part laryngoscope : Laryngoscope;
            out vocalCordsVisible : Boolean;
        }
        action def InsertTube {
            in ref part patient : Patient;
            in ref part ett : EndotrachealTube;
            out tubeInserted : Boolean;
        }
        action def InflateCuff {
            in ref part ett : EndotrachealTube;
            out cuffInflated : Boolean;
        }
        action def ConfirmPlacement {
            in ref part patient : Patient;
            in ref part ett : EndotrachealTube;
            out placementConfirmed : Boolean;
        }
        action def RemoveTube {
            in ref part ett : EndotrachealTube;
            out tubeRemoved : Boolean;
        }
        action def SecureTube {
            in ref part ett : EndotrachealTube;
            out tubeSecured : Boolean;
        }
        action def VentilatePatient {
            in ref part patient : Patient;
            in ref part ventilationBag : VentilationBag;
            out ventilating : Boolean;
        }
        action def PerformIntubation {
            in ref part patient : Patient;
            in ref part equipment : IntubationEquipment;
            out success : Boolean;
        }

        state def IntubationStateMachine {
            state ready;
            state assessing;
            state preoxygenating;
            state positioning;
            state visualizing;
            state inserting;
            state inflating;
            state confirming;
            state securing;
            state ventilating;
            state completed;
            state failed;

            transition first ready then assessing;
            transition first assessing then preoxygenating;
            transition first preoxygenating then positioning;
            transition first positioning then visualizing;
            transition first visualizing then inserting;
            transition first inserting then inflating;
            transition first inflating then confirming;
            transition first confirming then securing;
            transition first securing then ventilating;
            transition first ventilating then completed;
            transition first confirming then failed;
            transition first failed then ready;
        }
    }

    package Usages {
        private import Definitions::*;

        requirement cuffPressureRequirement : CuffPressureRequirement;
        requirement placementConfirmationRequirement : PlacementConfirmationRequirement;
        requirement preoxygenationRequirement : PreoxygenationRequirement;

        part intubationSystem : IntubationSystem {
            part clinician : Clinician;

            part equipment : IntubationEquipment {
                part ett : EndotrachealTube {
                    attribute :>> diameter = 8.0 [mm];
                    attribute :>> insertionDepth = 23 [cm];
                    part :>> cuff {
                        attribute :>> pressure = 0 [Pa];
                        attribute :>> inflated = false;
                    }
                }
                part laryngoscope : Laryngoscope {
                    part :>> light {
                        attribute :>> on = false;
                    }
                }
                part oxygenSource : OxygenSource {
                    attribute :>> concentration = 100.0;
                }
                part ventilationBag : VentilationBag;
                part suctionDevice : SuctionDevice;
            }

            ref part patient : Patient {
                attribute :>> spO2 = 85.0;
                attribute :>> co2Detected = false;
                attribute :>> breathSoundsBilateral = false;
                attribute :>> chestRiseSymmetric = false;
                attribute :>> airwayClear = false;
            }

            interface : OxygenInterface connect
                supplier ::> equipment.oxygenSource.oxygenOutPort to
                consumer ::> equipment.ventilationBag.oxygenInPort;

            interface : VentilationInterface connect
                supplier ::> equipment.ventilationBag.tubeOutPort to
                consumer ::> equipment.ett.proximalPort;

            interface : AirwayInterface connect
                tubeEnd ::> equipment.ett.distalPort to
                patientAirway ::> patient.airwayPort;

            interface : SuctionInterface connect
                supplier ::> equipment.suctionDevice.suctionPort to
                consumer ::> patient.suctionPort;

            perform action performIntubation : PerformIntubation {
                in ref part :>> patient = intubationSystem.patient;
                in ref part :>> equipment = intubationSystem.equipment;

                action assessPatient : AssessPatient {
                    in ref part :>> patient;
                    out needIntubation : Boolean;
                }
                then action preoxygenate : Preoxygenate {
                    in ref part :>> patient;
                    in ref part :>> oxygenSource = equipment.oxygenSource;
                    out oxygenated : Boolean;
                }
                then action positionHead : PositionHead {
                    in ref part :>> patient;
                    out positioned : Boolean;
                }
                then action visualizeLarynx : VisualizeLarynx {
                    in ref part :>> patient;
                    in ref part :>> laryngoscope = equipment.laryngoscope;
                    out vocalCordsVisible : Boolean;
                }
                then action insertTube : InsertTube {
                    in ref part :>> patient;
                    in ref part :>> ett = equipment.ett;
                    out tubeInserted : Boolean;
                }
                then action inflateCuff : InflateCuff {
                    in ref part :>> ett = equipment.ett;
                    out cuffInflated : Boolean;
                }
                then action confirmPlacement : ConfirmPlacement {
                    in ref part :>> patient;
                    in ref part :>> ett = equipment.ett;
                    out placementConfirmed : Boolean;
                }
                then action secureTube : SecureTube {
                    in ref part :>> ett = equipment.ett;
                    out tubeSecured : Boolean;
                }
                then action ventilatePatient : VentilatePatient {
                    in ref part :>> patient;
                    in ref part :>> ventilationBag = equipment.ventilationBag;
                    out ventilating : Boolean;
                }
            }

            state intubationStateMachine : IntubationStateMachine;

            satisfy cuffPressureRequirement;
            satisfy placementConfirmationRequirement;
            satisfy preoxygenationRequirement;
        }
    }
}
