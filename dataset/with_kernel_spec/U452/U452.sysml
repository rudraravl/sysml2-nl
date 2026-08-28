package WeightedBlanketSystem {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	value type PercentValue :> Real;

	item def Pressure {
		attribute magnitude : PressureValue;
	}

	value type PressureValue :> Real;

	item def GlassBeads {
		attribute mass : MassValue;
	}

	part def CottonFabric {
		attribute breathability : Real;
	}

	part def PolyesterFabric {
		attribute breathability : Real;
	}

	port def PressurePort {
		out pressure : Pressure;
	}

	part def Compartment {
		attribute mass : MassValue;
		part fill : GlassBeads;
	}

	part def User {
		attribute bodyMass : MassValue;
		port pressureIn ~ PressurePort;
	}

	part def WeightedBlanket {
		attribute totalMass : MassValue;
		part outerLayer : CottonFabric;
		part innerLayer : PolyesterFabric;
		part compartments : Compartment[0..*];
		port pressureOut : PressurePort;

		action def ProvideTherapy {
			out pressure : Pressure;
		}

		state def Lifecycle {
			state stored;
			state ready;
			state inUse {
				entry action {
					doc /* Begin applying deep pressure therapy to the user. */
				}
				do action : ProvideTherapy;
			}
			state maintenance;
			transition t1 : stored -> ready;
			transition t2 : ready -> inUse;
			transition t3 : inUse -> ready;
			transition t4 : ready -> maintenance;
			transition t5 : maintenance -> stored;
		}

		state lifecycle : Lifecycle;
	}

	requirement def TotalWeightRequirement {
		subject blanket : WeightedBlanket;
		subject user : User;
		attribute targetPercent : PercentValue = 0.10;
		constraint {
			blanket.totalMass == targetPercent * user.bodyMass
		}
	}

	requirement def UniformDistributionRequirement {
		subject blanket : WeightedBlanket;
		constraint {
			forall c1 in blanket.compartments, c2 in blanket.compartments {
				c1.mass == c2.mass
			}
		}
	}

	requirement def BreathabilityRequirement {
		subject blanket : WeightedBlanket;
		attribute minBreathability : Real = 0.5;
		constraint {
			blanket.outerLayer.breathability >= minBreathability
		}
	}

	part def WeightedBlanketAssembly {
		part user : User {
			attribute :>> bodyMass = 70[kg];
		}
		part blanket : WeightedBlanket {
			attribute :>> totalMass = 7[kg];
			part outerLayer : CottonFabric {
				attribute :>> breathability = 0.8;
			}
			part innerLayer : PolyesterFabric {
				attribute :>> breathability = 0.6;
			}
			part compartments : Compartment[100] {
				attribute :>> mass = 0.07[kg];
				part fill : GlassBeads {
					attribute :>> mass = 0.07[kg];
				}
			}
		}
		connect blanket.pressureOut to user.pressureIn;

		requirement totalWeight : TotalWeightRequirement {
			subject blanket = blanket;
			subject user = user;
		}

		requirement uniformDistribution : UniformDistributionRequirement {
			subject blanket = blanket;
		}

		requirement breathability : BreathabilityRequirement {
			subject blanket = blanket;
		}
	}

	part assembly : WeightedBlanketAssembly;
}
