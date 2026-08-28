package UtilityBootSystem {
	private import ScalarValues::*;
	private import ISQ::*;

	item def ImpactForce;
	item def WaterExposure;
	item def ThermalLoad;
	item def Terrain;

	attribute def TreadDepth :> LengthValue;
	attribute def MaterialThickness :> LengthValue;
	attribute def WearIndex :> Real;

	attribute def 'Ready for Use';
	attribute def 'Stand';
	attribute def 'Walk';
	attribute def 'Run';
	attribute def 'Rest';
	attribute def 'Clean';
	attribute def 'Finish Cleaning';
	attribute def 'Maintain';
	attribute def 'Finish Maintenance';

	port def GroundInterface {
		out terrain : Terrain;
		in gripForce : Real;
	}

	port def FootInterface {
		in footPressure : PressureValue;
		out supportForce : PressureValue;
		out comfortLevel : Real;
	}

	port def EnvironmentInterface {
		in impact : ImpactForce;
		in water : WaterExposure;
		in thermal : ThermalLoad;
		out protectionLevel : Real;
	}

	part def Sole {
		attribute material : String = "Rubber Composite";
		attribute treadPattern : String = "Multi-directional deep tread";
		attribute treadDepth : TreadDepth;
		port groundPort : GroundInterface;
		perform action 'grip ground' {
			in t : Terrain;
			out g : Real;
		}
	}

	part def Upper {
		attribute material : String = "Reinforced Full-Grain Leather";
		attribute thickness : MaterialThickness;
		port envPort : EnvironmentInterface;
		perform action 'protect foot' {
			in i : ImpactForce;
			in w : WaterExposure;
			in th : ThermalLoad;
			out p : Real;
		}
	}

	part def Lining {
		attribute material : String = "Moisture-wicking Synthetic";
		attribute paddingThickness : MaterialThickness;
		perform action 'manage moisture' {
			in w : WaterExposure;
		}
	}

	part def Insole {
		attribute material : String = "Cushioned Foam";
		perform action 'provide arch support' {
			in p : PressureValue;
			out s : PressureValue;
		}
	}

	part def LacingSystem {
		attribute laceType : String = "Speed-Lacing";
		perform action 'secure fit';
	}

	action def 'Provide Stability' {
		in terrain : Terrain;
		in weight : MassValue;
		out traction : Real;
		out pressureDistribution : PressureValue;
	}

	action def 'Regulate Temperature' {
		in externalTemp : TemperatureValue;
		out internalTemp : TemperatureValue;
	}

	action def 'Monitor Wear' {
		out currentWear : WearIndex;
	}

	part def Boot {
		port footPort : FootInterface;
		port envPort : EnvironmentInterface;
		port groundPort : GroundInterface;

		part sole : Sole;
		part upper : Upper;
		part lining : Lining;
		part insole : Insole;
		part lacingSystem : LacingSystem;

		attribute wearLevel : WearIndex = 0.0;
		attribute maxWearLevel : WearIndex = 100.0;

		perform action 'protect foot';
		perform action 'provide stability' : 'Provide Stability';
		perform action 'regulate temperature' : 'Regulate Temperature';
		perform action 'monitor wear' : 'Monitor Wear';

		exhibit state 'boot lifecycle' {
			entry; then New;
			state New;
			accept 'Ready for Use' then Ready;
			state Ready;
			accept 'Stand' then Standing;
			state Standing {
				do 'provide stability';
			}
			accept 'Walk' then Walking;
			state Walking {
				do 'provide stability';
			}
			accept 'Run' then Running;
			state Running {
				do 'provide stability';
			}
			accept 'Rest' then Ready;
			accept 'Clean' then Cleaning;
			accept 'Maintain' then Maintenance;
			state Cleaning;
			accept 'Finish Cleaning' then Ready;
			state Maintenance;
			accept 'Finish Maintenance' then Ready;
			accept when wearLevel >= maxWearLevel then Retired;
			state Retired;
		}
	}

	requirement def ProtectionRequirement {
		doc /* The boot shall protect the foot from external impacts, water, and temperature extremes. */
	}

	requirement def StabilityRequirement {
		doc /* The boot shall provide stability by gripping the ground and distributing pressure evenly. */
	}

	requirement def ComfortRequirement {
		doc /* The boot shall regulate internal temperature and provide comfort and arch support. */
	}

	requirement def DurabilityRequirement {
		doc /* The boot shall monitor wear and tear and reach a retired state when no longer serviceable. */
	}

	requirement protectionReq : ProtectionRequirement;
	requirement stabilityReq : StabilityRequirement;
	requirement comfortReq : ComfortRequirement;
	requirement durabilityReq : DurabilityRequirement;

	part bootInstance : Boot {
		connect sole.groundPort to groundPort;
		connect upper.envPort to envPort;
		satisfy protectionReq by 'protect foot';
		satisfy stabilityReq by 'provide stability';
		satisfy comfortReq by 'regulate temperature';
		satisfy durabilityReq by 'monitor wear';
	}
}
