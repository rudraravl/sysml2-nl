package SugarPacketModel {
    import ISQ::*;
    import ISQBase::*;
    import ScalarValues::*;

    package ValueTypes {
        value type SugarMass :> MassValue;
        value type CrystalDiameter :> LengthValue;
        value type PurityFraction :> Real;
        value type SealTensileStrength :> PressureValue;
        value type PacketShelfLife :> TimeValue;
        value type PacketLength :> LengthValue;
        value type PacketWidth :> LengthValue;
        value type FilmThickness :> LengthValue;
        value type TearForce :> ForceValue;
        value type SealTemperature :> TemperatureValue;
        value type MoistureFraction :> Real;
    }

    package Items {
        item def RefinedWhiteSugar {
            attribute mass : SugarMass;
            attribute crystalSize : CrystalDiameter;
            attribute purity : PurityFraction;
            attribute moistureContent : MoistureFraction;
        }

        item def LaminatedPaperPolymer {
            attribute paperLayerThickness : FilmThickness;
            attribute polymerLayerThickness : FilmThickness;
            attribute oxygenBarrier : Boolean;
            attribute moistureBarrier : Boolean;
        }

        item def FilledEnvelope {
            attribute assembled : Boolean = true;
        }
    }

    package Ports {
        port def DispensePort {
            out item dispensedSugar : RefinedWhiteSugar;
        }

        port def TearNotchPort {
            attribute requiredTearForce : TearForce;
        }
    }

    package Parts {
        part def SugarContent {
            port dispensePort : Ports::DispensePort;
            item sugar : Items::RefinedWhiteSugar {
                attribute :>> mass = 4 [g];
                attribute :>> crystalSize = 0.5 [mm];
                attribute :>> purity = 0.999;
                attribute :>> moistureContent = 0.001;
            }
        }

        part def Seal {
            attribute tensileStrength : SealTensileStrength = 2.5 [MPa];
            attribute heatSealTemperature : SealTemperature = 160 [degC];
            attribute sealed : Boolean = true;
        }

        part def Packaging {
            port tearNotch : Ports::TearNotchPort {
                attribute :>> requiredTearForce = 5 [N];
            }
            attribute length : PacketLength = 75 [mm];
            attribute width : PacketWidth = 35 [mm];
            attribute filmThickness : FilmThickness = 0.08 [mm];
            attribute shelfLife : PacketShelfLife = 730 [d];
            item material : Items::LaminatedPaperPolymer {
                attribute :>> paperLayerThickness = 0.05 [mm];
                attribute :>> polymerLayerThickness = 0.03 [mm];
                attribute :>> oxygenBarrier = true;
                attribute :>> moistureBarrier = true;
            }
            part seal : Seal;
            part content : SugarContent;
            connection sealEnclosesContent connect seal to content;
        }

        part def SugarPacket {
            port tearNotch : Ports::TearNotchPort;
            port dispensePort : Ports::DispensePort;
            part packaging : Packaging;
            connection tearAccess connect packaging.tearNotch to tearNotch;
            connection dispenseAccess connect packaging.content.dispensePort to dispensePort;
            state machine lifecycle : Behaviors::SugarPacketLifecycleStateMachine;
        }
    }

    package Behaviors {
        event def QcPass;
        event def QcFail;
        event def Purchased;

        state def SugarPacketLifecycle;

        state machine SugarPacketLifecycleStateMachine {
            state Manufacturing;
            state QualityControl;
            state Warehousing;
            state Shipment;
            state Retail;
            state Consumed;
            state Rejected;
            transition first Manufacturing;
            transition then Manufacturing to QualityControl;
            transition QualityControl to Warehousing accept QcPass;
            transition QualityControl to Rejected accept QcFail;
            transition then Warehousing to Shipment;
            transition then Shipment to Retail;
            transition Retail to Consumed accept Purchased;
        }

        action def ManufacturingProcess {
            in bulkSugar : Items::RefinedWhiteSugar;
            in packagingMaterial : Items::LaminatedPaperPolymer;
            out packet : Parts::SugarPacket;
            action measureSugar {
                in bulk : Items::RefinedWhiteSugar;
                out portion : Items::RefinedWhiteSugar {
                    attribute :>> mass = 4 [g];
                }
            }
            action insertSugar {
                in portion : Items::RefinedWhiteSugar;
                in material : Items::LaminatedPaperPolymer;
                out filledEnvelope : Items::FilledEnvelope;
            }
            action heatSeal {
                in filledEnvelope : Items::FilledEnvelope;
                out sealedPacket : Parts::SugarPacket;
            }
            succession first measureSugar then insertSugar;
            succession first insertSugar then heatSeal;
        }

        action def QualityControlInspection {
            in packet : Parts::SugarPacket;
            out pass : Boolean;
            out fail : Boolean;
            action measureMass {
                in packet : Parts::SugarPacket;
                out massOK : Boolean;
            }
            action inspectSeal {
                in packet : Parts::SugarPacket;
                out sealOK : Boolean;
            }
            action evaluate {
                in massOK : Boolean;
                in sealOK : Boolean;
                out pass : Boolean;
                out fail : Boolean;
            }
            succession first measureMass then evaluate;
            succession first inspectSeal then evaluate;
        }
    }

    package Requirements {
        requirement def PortionMassRequirement {
            subject packet : Parts::SugarPacket;
            doc /* The sugar packet shall contain a pre-measured sugar portion of 4 g +/- 0.1 g. */;
            require packet.packaging.content.sugar.mass >= 3.9 [g];
            require packet.packaging.content.sugar.mass <= 4.1 [g];
        }

        requirement def BarrierRequirement {
            subject packet : Parts::SugarPacket;
            doc /* The packaging shall provide a barrier against moisture and oxygen. */;
            require packet.packaging.material.moistureBarrier == true;
            require packet.packaging.material.oxygenBarrier == true;
        }

        requirement def EasyOpenRequirement {
            subject packet : Parts::SugarPacket;
            doc /* The seal shall be openable by a consumer with a tear force not exceeding 10 N. */;
            require packet.tearNotch.requiredTearForce <= 10 [N];
        }

        requirement def SealIntegrityRequirement {
            subject packet : Parts::SugarPacket;
            doc /* The seal shall maintain integrity during shipping and handling. */;
            require packet.packaging.seal.tensileStrength >= 2.0 [MPa];
            require packet.packaging.seal.sealed == true;
        }

        requirement def ShelfLifeRequirement {
            subject packet : Parts::SugarPacket;
            doc /* The packet shall maintain sugar quality for at least 730 days. */;
            require packet.packaging.shelfLife >= 730 [d];
        }

        requirement def SugarPurityRequirement {
            subject packet : Parts::SugarPacket;
            doc /* The sugar content shall be refined white sugar with purity >= 0.995. */;
            require packet.packaging.content.sugar.purity >= 0.995;
        }

        requirement def MoisturePreventionRequirement {
            subject packet : Parts::SugarPacket;
            doc /* The sugar moisture content shall remain below 0.5 percent to prevent clumping. */;
            require packet.packaging.content.sugar.moistureContent <= 0.005;
        }
    }
}
