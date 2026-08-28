package StructuralSteelTrussSystem {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	item def SteelMaterial {
		doc
		/*
		 * Steel material with yield strength and elastic modulus.
		 */
		attribute yieldStrength : PressureValue = 250e6 [Pa];
		attribute elasticModulus : PressureValue = 200e9 [Pa];
	}

	part def Node {
		port p;
	}

	part def Support {
		port p;
	}

	part def LoadApplication {
		port p;
		attribute magnitude : ForceValue = 0 [N];
	}

	part def SteelMember {
		port startPort;
		port endPort;
		attribute length : LengthValue;
		attribute crossSectionArea : AreaValue;
		attribute material : SteelMaterial;
	}

	part def BottomChordMember :> SteelMember;
	part def TopChordMember :> SteelMember;
	part def DiagonalMember :> SteelMember;

	action def 'Perform Structural Analysis' {
		doc
		/*
		 * Computes the maximum member stress and overall truss deflection
		 * for the currently applied load.
		 */
		in appliedLoad : ForceValue;
		out maxStress : PressureValue;
		out maxDeflection : LengthValue;
	}

	action def 'Send Overstress Alert';

	attribute def 'Load Applied Signal';
	attribute def 'Load Removed Signal';

	state def 'Truss States';

	part def TrussAssembly {
		doc
		/*
		 * A 6-meter steel truss assembled from 13 steel members connected
		 * at 8 joints, anchored at two support nodes, and carrying a
		 * downward load applied to a lower-chord node.
		 */
		attribute span : LengthValue = 6.0 [m];
		attribute maxLoad : ForceValue = 100000 [N];
		attribute currentLoad : ForceValue = 0 [N];
		attribute allowableStress : PressureValue = 166666666.7 [Pa];
		attribute allowableDeflection : LengthValue = 0.025 [m];

		part steel : SteelMaterial;

		action 'perform structural analysis': 'Perform Structural Analysis';
		action 'send overstress alert': 'Send Overstress Alert';

		part n1 : Node;
		part n2 : Node;
		part n3 : Node;
		part n4 : Node;
		part n5 : Node;
		part n6 : Node;
		part n7 : Node;
		part n8 : Node;

		part support1 : Support;
		connect support1.p to n1.p;

		part support2 : Support;
		connect support2.p to n4.p;

		part appliedLoad : LoadApplication;
		connect appliedLoad.p to n2.p;

		part m_bc1 : BottomChordMember {
			attribute length = 2.0 [m];
			attribute crossSectionArea = 0.004 [m^2];
			attribute material = steel;
		}
		connect m_bc1.startPort to n1.p;
		connect m_bc1.endPort to n2.p;

		part m_bc2 : BottomChordMember {
			attribute length = 2.0 [m];
			attribute crossSectionArea = 0.004 [m^2];
			attribute material = steel;
		}
		connect m_bc2.startPort to n2.p;
		connect m_bc2.endPort to n3.p;

		part m_bc3 : BottomChordMember {
			attribute length = 2.0 [m];
			attribute crossSectionArea = 0.004 [m^2];
			attribute material = steel;
		}
		connect m_bc3.startPort to n3.p;
		connect m_bc3.endPort to n4.p;

		part m_tc1 : TopChordMember {
			attribute length = 2.0 [m];
			attribute crossSectionArea = 0.003 [m^2];
			attribute material = steel;
		}
		connect m_tc1.startPort to n5.p;
		connect m_tc1.endPort to n6.p;

		part m_tc2 : TopChordMember {
			attribute length = 2.0 [m];
			attribute crossSectionArea = 0.003 [m^2];
			attribute material = steel;
		}
		connect m_tc2.startPort to n6.p;
		connect m_tc2.endPort to n7.p;

		part m_tc3 : TopChordMember {
			attribute length = 2.0 [m];
			attribute crossSectionArea = 0.003 [m^2];
			attribute material = steel;
		}
		connect m_tc3.startPort to n7.p;
		connect m_tc3.endPort to n8.p;

		part m_d1 : DiagonalMember {
			attribute length = 2.236 [m];
			attribute crossSectionArea = 0.002 [m^2];
			attribute material = steel;
		}
		connect m_d1.startPort to n1.p;
		connect m_d1.endPort to n5.p;

		part m_d2 : DiagonalMember {
			attribute length = 2.236 [m];
			attribute crossSectionArea = 0.002 [m^2];
			attribute material = steel;
		}
		connect m_d2.startPort to n2.p;
		connect m_d2.endPort to n5.p;

		part m_d3 : DiagonalMember {
			attribute length = 2.236 [m];
			attribute crossSectionArea = 0.002 [m^2];
			attribute material = steel;
		}
		connect m_d3.startPort to n2.p;
		connect m_d3.endPort to n6.p;

		part m_d4 : DiagonalMember {
			attribute length = 2.236 [m];
			attribute crossSectionArea = 0.002 [m^2];
			attribute material = steel;
		}
		connect m_d4.startPort to n3.p;
		connect m_d4.endPort to n6.p;

		part m_d5 : DiagonalMember {
			attribute length = 2.236 [m];
			attribute crossSectionArea = 0.002 [m^2];
			attribute material = steel;
		}
		connect m_d5.startPort to n3.p;
		connect m_d5.endPort to n7.p;

		part m_d6 : DiagonalMember {
			attribute length = 2.236 [m];
			attribute crossSectionArea = 0.002 [m^2];
			attribute material = steel;
		}
		connect m_d6.startPort to n4.p;
		connect m_d6.endPort to n7.p;

		part m_d7 : DiagonalMember {
			attribute length = 2.236 [m];
			attribute crossSectionArea = 0.002 [m^2];
			attribute material = steel;
		}
		connect m_d7.startPort to n4.p;
		connect m_d7.endPort to n8.p;

		exhibit state 'truss states': 'Truss States' {
			entry; then unloaded;

			state unloaded;
			accept 'Load Applied Signal'
				then loading;

			state loading {
				entry 'perform structural analysis' {
					in appliedLoad = currentLoad;
					out maxStress;
					out maxDeflection;
				}
			}
			accept when 'perform structural analysis'.maxStress <= allowableStress and
					 'perform structural analysis'.maxDeflection <= allowableDeflection
				then operational;
			accept when 'perform structural analysis'.maxStress > allowableStress or
					 'perform structural analysis'.maxDeflection > allowableDeflection
				then overstressed;

			state operational;
			accept 'Load Removed Signal'
				then unloaded;

			state overstressed {
				entry 'send overstress alert';
			}
			accept 'Load Removed Signal'
				then unloaded;
		}

		assert constraint spanConstraint {
			span == 6.0 [m]
		}
		assert constraint loadConstraint {
			maxLoad == 100000 [N]
		}
		assert constraint safetyConstraint {
			allowableStress < steel.yieldStrength and
			allowableDeflection < 0.03 [m]
		}
	}

	part truss : TrussAssembly;

	requirement def 'Span Requirement' {
		doc
		/*
		 * The truss shall span a distance of 6 meters.
		 */
		attribute requiredSpan : LengthValue = 6.0 [m];
	}

	requirement def 'Load Requirement' {
		doc
		/*
		 * The truss shall safely support a load of up to 100,000 Newtons.
		 */
		attribute requiredLoad : ForceValue = 100000 [N];
	}

	requirement def 'Configuration Requirement' {
		doc
		/*
		 * The truss shall be assembled from 13 steel members connected at 8 joints.
		 */
		attribute requiredMemberCount : Natural = 13;
		attribute requiredJointCount : Natural = 8;
	}

	requirement def 'Safety Requirement' {
		doc
		/*
		 * Structural analysis shall keep the maximum member stress and overall
		 * deflection within the specified allowable limits.
		 */
		attribute maxAllowableStress : PressureValue = 166666666.7 [Pa];
		attribute maxAllowableDeflection : LengthValue = 0.025 [m];
	}

	requirement spanReq : 'Span Requirement';
	requirement loadReq : 'Load Requirement';
	requirement configReq : 'Configuration Requirement';
	requirement safetyReq : 'Safety Requirement';

	satisfy spanReq by truss;
	satisfy loadReq by truss;
	satisfy configReq by truss;
	satisfy safetyReq by truss;
}
