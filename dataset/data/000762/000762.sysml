package 'Serbian Barrel System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def BarrelCapacity :> VolumeValue;
	attribute def WaterLevel :> VolumeValue;
	attribute def StaveHeight :> LengthValue;
	attribute def FlowRate :> VolumeValue;
	attribute def StaveThickness :> LengthValue;
	
	item def Water {
		attribute volume : VolumeValue;
		attribute temperature : TemperatureValue;
	}
	
	item def Wood {
		attribute density : DensityValue;
		attribute moistureContent : Real;
	}
	
	part def Stave {
		attribute height : StaveHeight;
		attribute thickness : StaveThickness;
		attribute material : Wood;
		attribute isIntact : Boolean;
		attribute position : Integer;
	}
	
	part def MetalHoop {
		attribute diameter : LengthValue;
		attribute tension : ForceValue;
		attribute position : Integer;
	}
	
	part def CircularBase {
		attribute diameter : LengthValue;
		attribute area : AreaValue;
		attribute sealed : Boolean;
	}
	
	port def WaterInletPort {
		out item waterFlow : Water;
		attribute flowRate : FlowRate;
	}
	
	port def WaterOutletPort {
		in item waterFlow : Water;
		attribute flowRate : FlowRate;
	}
	
	port def OverflowPort {
		out item excessWater : Water;
	}
	
	connection def WaterFlowConnection {
		end source : WaterInletPort[1];
		end destination : WaterOutletPort[1];
	}
	
	part def SerbianBarrel {
		doc /* A Serbian barrel system demonstrating that overall capacity 
		       is constrained by the shortest stave, illustrating the principle 
		       that system performance is limited by the weakest component. */
		
		attribute totalCapacity : BarrelCapacity;
		attribute currentWaterLevel : WaterLevel;
		attribute effectiveHeight : StaveHeight;
		attribute numberOfStaves : Integer;
		attribute baseArea : AreaValue;
		
		part staves : Stave[24] {
			attribute height : StaveHeight;
			attribute thickness : StaveThickness;
			attribute isIntact : Boolean;
		}
		
		part hoops : MetalHoop[4] {
			attribute tension : ForceValue;
		}
		
		part base : CircularBase {
			attribute sealed : Boolean;
		}
		
		part top : CircularBase {
			attribute sealed = false;
		}
		
		port inlet : WaterInletPort {
			attribute flowRate : FlowRate;
		}
		
		port outlet : WaterOutletPort {
			attribute flowRate : FlowRate;
		}
		
		port overflow : OverflowPort;
		
		part waterBody : Water {
			attribute volume : WaterLevel;
		}
		
		assert constraint capacityDeterminedByShortestStave {
			doc /* The barrel's capacity is determined by the height of the shortest stave. */
			totalCapacity == effectiveHeight * baseArea
		}
		
		assert constraint waterCannotExceedCapacity {
			doc /* Water level cannot exceed the effective capacity. */
			currentWaterLevel <= totalCapacity
		}
		
		assert constraint structuralIntegrity {
			doc /* All hoops must maintain sufficient tension. */
			hoops->size() == 4
		}
	}
	
	state def BarrelOperationStates {
		in ref barrel : SerbianBarrel;
		
		entry; then empty;
		
		state empty {
			doc /* Barrel contains no water. */
		}
		transition emptyToFilling
			first empty
			accept at when barrel.inlet.flowRate > 0.0[L]
			then filling;
		
		state filling {
			doc /* Water is being added to the barrel. */
		}
		transition fillingToFull
			first filling
			accept at when barrel.currentWaterLevel >= barrel.totalCapacity
			then full;
		transition fillingToPartial
			first filling
			accept at when barrel.inlet.flowRate == 0.0[L]
			then partial;
		
		state partial {
			doc /* Barrel contains water below capacity. */
		}
		transition partialToFilling
			first partial
			accept at when barrel.inlet.flowRate > 0.0[L]
			then filling;
		transition partialToDraining
			first partial
			accept at when barrel.outlet.flowRate > 0.0[L]
			then draining;
		
		state full {
			doc /* Barrel is at maximum capacity determined by shortest stave. */
		}
		transition fullToDraining
			first full
			accept at when barrel.outlet.flowRate > 0.0[L]
			then draining;
		
		state draining {
			doc /* Water is being removed from the barrel. */
		}
		transition drainingToEmpty
			first draining
			accept at when barrel.currentWaterLevel <= 0.0[L]
			then empty;
		transition drainingToPartial
			first draining
			accept at when barrel.outlet.flowRate == 0.0[L]
			then partial;
	}
	
	action def AnalyzeStaveHeights {
		doc /* Determine the effective capacity by finding the shortest stave. */
		in staveHeights : StaveHeight[*];
		in baseArea : AreaValue;
		out minimumHeight : StaveHeight;
		out effectiveCapacity : BarrelCapacity;
		out limitingStaveIndex : Integer;
	}
	
	action def FillBarrel {
		doc /* Add water to the barrel at specified flow rate. */
		in flowRate : FlowRate;
		in currentLevel : WaterLevel;
		in capacity : BarrelCapacity;
		in deltaTime : TimeValue;
		out newLevel : WaterLevel;
		out overflow : Boolean;
	}
	
	action def DrainBarrel {
		doc /* Remove water from the barrel at specified flow rate. */
		in flowRate : FlowRate;
		in currentLevel : WaterLevel;
		in deltaTime : TimeValue;
		out newLevel : WaterLevel;
	}
	
	action def ManageOverflow {
		doc /* Handle excess water when barrel exceeds capacity. */
		in excessFlow : FlowRate;
		in capacity : BarrelCapacity;
		out excessVolume : VolumeValue;
	}
	
	action def InspectStaves {
		doc /* Check structural integrity of all staves. */
		in staves : Stave[*];
		out allIntact : Boolean;
		out damagedStaveIndices : Integer[*];
		out minimumHeight : StaveHeight;
	}
	
	action def OperateBarrelSystem {
		doc /* Primary operation demonstrating capacity limitation by weakest component. */
		in ref barrel : SerbianBarrel;
		
		first start;
		
		then action analyzeStructure : AnalyzeStaveHeights {
			in staveHeights = barrel.staves.height;
			in baseArea = barrel.baseArea;
			out minimumHeight;
			out effectiveCapacity;
			out limitingStaveIndex;
		}
		
		then merge operationCycle;
		
		then action inspectStructure : InspectStaves {
			in staves = barrel.staves;
			out allIntact;
			out damagedStaveIndices;
			out minimumHeight;
		}
		
		then decide;
			if inspectStructure.allIntact then continueOperation;
			else repairRequired;
		
		action repairRequired {
			doc /* Handle damaged staves and recalculate capacity. */
			then action recalculateCapacity : AnalyzeStaveHeights {
				in staveHeights = barrel.staves.height;
				in baseArea = barrel.baseArea;
				out minimumHeight;
				out effectiveCapacity;
			}
		}
		then operationCycle;
		
		action continueOperation {
			doc /* Normal filling and draining operations. */
			then action fillOperation : FillBarrel {
				in flowRate = barrel.inlet.flowRate;
				in currentLevel = barrel.currentWaterLevel;
				in capacity = barrel.totalCapacity;
				in deltaTime = 1.0[s];
				out newLevel;
				out overflow;
			}
			
			then decide;
				if fillOperation.overflow then handleExcess;
				else normalOperation;
			
			action handleExcess : ManageOverflow {
				in excessFlow = barrel.inlet.flowRate;
				in capacity = barrel.totalCapacity;
				out excessVolume;
			}
			then normalOperation;
			
			action normalOperation;
		}
		then operationCycle;
	}
	
	part serbianBarrel : SerbianBarrel {
		attribute numberOfStaves = 24;
		attribute baseArea = 0.5[m^2];
		
		perform action systemOperation : OperateBarrelSystem {
			in ref barrel = serbianBarrel;
		}
		
		exhibit state operationStates : BarrelOperationStates {
			in ref barrel = serbianBarrel;
		}
	}
	
	requirement def CapacityLimitationPrinciple {
		doc /* The system shall demonstrate that overall capacity is limited 
		       by the minimum capacity component, not average or maximum. */
		
		subject barrel : SerbianBarrel;
		
		require constraint minimumDeterminesCapacity {
			barrel.totalCapacity == barrel.effectiveHeight * barrel.baseArea
		}
	}
	
	requirement def StructuralIntegrityRequirement {
		doc /* All structural components must maintain integrity for safe operation. */
		
		subject barrel : SerbianBarrel;
		
		require constraint baseSealed {
			barrel.base.sealed == true
		}
	}
	
	requirement def OperationalSafetyRequirement {
		doc /* The system shall operate safely within physical constraints. */
		
		subject barrel : SerbianBarrel;
		
		require constraint waterLevelWithinCapacity {
			barrel.currentWaterLevel <= barrel.totalCapacity
		}
		
		require constraint positiveCapacity {
			barrel.totalCapacity > 0[L]
		}
	}
	
	requirement systemMission {
		doc /* The Serbian Barrel system shall demonstrate the fundamental principle 
		       that a system's overall performance and capacity is determined by its 
		       weakest or most limiting component, not by the average or strongest 
		       components. This serves as a model for understanding bottlenecks and 
		       constraints in complex systems. */
		
		subject system = serbianBarrel;
		
		require capacityPrinciple : CapacityLimitationPrinciple {
			subject barrel = serbianBarrel;
		}
		
		require structuralIntegrity : StructuralIntegrityRequirement {
			subject barrel = serbianBarrel;
		}
		
		require operationalSafety : OperationalSafetyRequirement {
			subject barrel = serbianBarrel;
		}
	}
}
