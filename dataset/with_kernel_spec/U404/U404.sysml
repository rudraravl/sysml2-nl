package SugarPacketSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def Purity :> Real;
	attribute def TransmissionRate :> Real;

	item def RefinedWhiteSugar {
		attribute mass :> ISQ::mass;
		attribute purity : Purity;
		attribute crystalSize :> ISQ::length;
	}

	item def LaminatedPaperPolymer {
		attribute oxygenTransmissionRate : TransmissionRate;
		attribute moistureVaporTransmissionRate : TransmissionRate;
	}

	part def Seal {
		attribute sealStrength :> ISQ::force;
		attribute sealIntact : Boolean;
	}

	part def Packaging {
		part material : LaminatedPaperPolymer;
		part seal : Seal;
		attribute shelfLife :> ISQ::time;
	}

	part def SugarPacket {
		part sugarContents : RefinedWhiteSugar;
		part packaging : Packaging;
		port dispensingPort {
			out item dispensedSugar : RefinedWhiteSugar;
		}
		binding dispensingPort.dispensedSugar = sugarContents;
	}

	state machine def SugarPacketLifecycle {
		state Manufactured;
		state QualityControlled;
		state Warehoused;
		state Shipped;
		state Retailed;
		state Purchased;
		state Consumed;
		transition from Manufactured to QualityControlled;
		transition from QualityControlled to Warehoused;
		transition from Warehoused to Shipped;
		transition from Shipped to Retailed;
		transition from Retailed to Purchased;
		transition from Purchased to Consumed;
	}

	requirement def MassRequirement {
		attribute massActual :> ISQ::mass;
		attribute massTarget :> ISQ::mass;
		attribute massTolerance :> ISQ::mass;
		doc /* The actual mass shall be within tolerance of the target mass. */
		require constraint { massActual >= massTarget - massTolerance and massActual <= massTarget + massTolerance }
	}

	requirement def SealIntegrityRequirement {
		attribute sealStrength :> ISQ::force;
		attribute minStrength :> ISQ::force;
		attribute maxStrength :> ISQ::force;
		doc /* The seal shall be strong enough for shipping but weak enough for consumer tear. */
		require constraint { sealStrength >= minStrength and sealStrength <= maxStrength }
	}

	requirement def PurityRequirement {
		attribute purity : Purity;
		attribute minPurity : Purity;
		doc /* The sugar purity shall meet or exceed the minimum threshold. */
		require constraint { purity >= minPurity }
	}

	requirement def ShelfLifeRequirement {
		attribute shelfLife :> ISQ::time;
		attribute minShelfLife :> ISQ::time;
		doc /* The packaging shall preserve sugar quality for the minimum shelf life. */
		require constraint { shelfLife >= minShelfLife }
	}

	requirement def MoistureBarrierRequirement {
		attribute moistureVaporTransmissionRate : TransmissionRate;
		attribute maxTransmissionRate : TransmissionRate;
		doc /* The packaging material shall limit moisture vapor transmission to prevent clumping. */
		require constraint { moistureVaporTransmissionRate <= maxTransmissionRate }
	}

	requirement def OxygenBarrierRequirement {
		attribute oxygenTransmissionRate : TransmissionRate;
		attribute maxTransmissionRate : TransmissionRate;
		doc /* The packaging material shall limit oxygen transmission to preserve quality. */
		require constraint { oxygenTransmissionRate <= maxTransmissionRate }
	}

	action def ManufacturePacket {
		in item sugarIn : RefinedWhiteSugar;
		in item packagingMaterial : LaminatedPaperPolymer;
		out item packetOut : SugarPacket;
		action measureSugar {
			in item sugar : RefinedWhiteSugar;
			out item measuredSugar : RefinedWhiteSugar;
		}
		then action insertSugar {
			in item sugar : RefinedWhiteSugar = measureSugar.measuredSugar;
			in item material : LaminatedPaperPolymer = packagingMaterial;
			out item filledPackaging : Packaging;
		}
		then action heatSeal {
			in item packaging : Packaging = insertSugar.filledPackaging;
			out item sealedPacket : SugarPacket;
		}
		binding packetOut = heatSeal.sealedPacket;
	}

	action def QualityControl {
		in item packetIn : SugarPacket;
		out item packetOut : SugarPacket;
		action inspectMass {
			in item packet : SugarPacket;
			out massMeasured :> ISQ::mass;
		}
		then action inspectSeal {
			in item packet : SugarPacket;
			out sealIntact : Boolean;
		}
		binding packetOut = packetIn;
	}

	action def WarehouseStorage {
		in item packetIn : SugarPacket;
		out item packetOut : SugarPacket;
		binding packetOut = packetIn;
	}

	action def Ship {
		in item packetIn : SugarPacket;
		out item packetOut : SugarPacket;
		binding packetOut = packetIn;
	}

	action def RetailDisplay {
		in item packetIn : SugarPacket;
		out item packetOut : SugarPacket;
		binding packetOut = packetIn;
	}

	action def Consume {
		in item packet : SugarPacket;
		action openPacket {
			in item pkt : SugarPacket = packet;
			out item openedPacket : SugarPacket;
		}
		then action dispenseSugar {
			in item pkt : SugarPacket = openPacket.openedPacket;
			out item dispensedSugar : RefinedWhiteSugar;
		}
	}

	requirement packetMassRequirement : MassRequirement {
		subject packet : SugarPacket;
		:>> massActual = packet.sugarContents.mass;
		:>> massTarget = 0.004 [SI::kg];
		:>> massTolerance = 0.0002 [SI::kg];
	}

	requirement packetSealRequirement : SealIntegrityRequirement {
		subject packet : SugarPacket;
		:>> sealStrength = packet.packaging.seal.sealStrength;
		:>> minStrength = 5 [SI::N];
		:>> maxStrength = 30 [SI::N];
	}

	requirement sugarPurityRequirement : PurityRequirement {
		subject sugar : RefinedWhiteSugar;
		:>> purity = sugar.purity;
		:>> minPurity = 0.995;
	}

	requirement packetShelfLifeRequirement : ShelfLifeRequirement {
		subject packet : SugarPacket;
		:>> shelfLife = packet.packaging.shelfLife;
		:>> minShelfLife = 63072000 [SI::s];
	}

	requirement packagingMoistureBarrierRequirement : MoistureBarrierRequirement {
		subject material : LaminatedPaperPolymer;
		:>> moistureVaporTransmissionRate = material.moistureVaporTransmissionRate;
		:>> maxTransmissionRate = 0.5;
	}

	requirement packagingOxygenBarrierRequirement : OxygenBarrierRequirement {
		subject material : LaminatedPaperPolymer;
		:>> oxygenTransmissionRate = material.oxygenTransmissionRate;
		:>> maxTransmissionRate = 0.5;
	}

	part sugarPacket : SugarPacket {
		part :>> sugarContents : RefinedWhiteSugar {
			:>> mass = 0.004 [SI::kg];
			:>> purity = 0.998;
			:>> crystalSize = 0.0005 [SI::m];
		}
		part :>> packaging : Packaging {
			part :>> material : LaminatedPaperPolymer {
				:>> oxygenTransmissionRate = 0.3;
				:>> moistureVaporTransmissionRate = 0.2;
			}
			part :>> seal : Seal {
				:>> sealStrength = 15 [SI::N];
				:>> sealIntact = true;
			}
			:>> shelfLife = 63072000 [SI::s];
		}
	}

	action packetLifecycle {
		action manufacture : ManufacturePacket {
			in item :>> sugarIn : RefinedWhiteSugar {
				:>> mass = 0.004 [SI::kg];
				:>> purity = 0.998;
				:>> crystalSize = 0.0005 [SI::m];
			}
			in item :>> packagingMaterial : LaminatedPaperPolymer {
				:>> oxygenTransmissionRate = 0.3;
				:>> moistureVaporTransmissionRate = 0.2;
			}
		}
		then action qualityControl : QualityControl {
			in item :>> packetIn = manufacture.packetOut;
		}
		then action warehouse : WarehouseStorage {
			in item :>> packetIn = qualityControl.packetOut;
		}
		then action shipment : Ship {
			in item :>> packetIn = warehouse.packetOut;
		}
		then action retail : RetailDisplay {
			in item :>> packetIn = shipment.packetOut;
		}
		then action consumption : Consume {
			in item :>> packet = retail.packetOut;
		}
	}
}
