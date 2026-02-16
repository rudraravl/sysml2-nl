package RedoxElectrodeSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ElectricPotentialValue :> ISQ::ElectricPotentialDifferenceValue {
		attribute :>> num : Real;
		attribute :>> mRef : ElectricPotentialUnit;
	}
	
	attribute def CurrentDensityValue :> ScalarValues::Real {
		attribute :>> num : Real;
		attribute mRef : CurrentDensityUnit;
	}
	
	attribute def ConcentrationValue :> ScalarValues::Real {
		attribute :>> num : Real;
		attribute mRef : ConcentrationUnit;
	}
	
	attribute def ElectricPotentialUnit :> SI::VoltUnit;
	attribute def CurrentDensityUnit;
	attribute def ConcentrationUnit;
	
	item def Electrolyte {
		attribute oxidizedSpeciesConcentration : ConcentrationValue;
		attribute reducedSpeciesConcentration : ConcentrationValue;
		attribute pH : Real;
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
	}
	
	item def ElectronTransfer {
		attribute numberOfElectrons : Integer;
		attribute transferRate : Real;
	}
	
	port def ElectricalPort {
		attribute potential : ElectricPotentialValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	port def ElectrolytePort {
		in item electrolyte : Electrolyte;
		out item reactionProducts : Electrolyte;
	}
	
	part def RedoxElectrode {
		attribute surfaceArea : ISQ::AreaValue;
		attribute standardPotential : ElectricPotentialValue;
		attribute actualPotential : ElectricPotentialValue;
		
		port electricalInterface : ElectricalPort;
		port electrolyteInterface : ElectrolytePort;
		
		part activeSurface {
			attribute catalyticActivity : Real;
			attribute roughnessFactor : Real;
		}
		
		part electronConductor {
			attribute conductivity : Real;
			attribute resistance : Real;
		}
	}
	
	part def CounterElectrode {
		port electricalInterface : ElectricalPort;
		port electrolyteInterface : ElectrolytePort;
	}
	
	part def ReferenceElectrode {
		attribute referencePotential : ElectricPotentialValue;
		port electricalInterface : ElectricalPort;
	}
	
	part def Potentiostat {
		port workingElectrodePort : ElectricalPort;
		port counterElectrodePort : ElectricalPort;
		port referenceElectrodePort : ElectricalPort;
		
		attribute setPointPotential : ElectricPotentialValue;
		attribute measuredCurrent : ISQ::ElectricCurrentValue;
	}
	
	part def ElectrolyteReservoir {
		port outlet : ElectrolytePort;
		attribute volume : ISQ::VolumeValue;
		attribute composition : Electrolyte;
	}
	
	action def OxidationReaction {
		in reducedSpecies : Electrolyte;
		in appliedPotential : ElectricPotentialValue;
		out oxidizedSpecies : Electrolyte;
		out electronFlow : ElectronTransfer;
	}
	
	action def ReductionReaction {
		in oxidizedSpecies : Electrolyte;
		in appliedPotential : ElectricPotentialValue;
		out reducedSpecies : Electrolyte;
		out electronFlow : ElectronTransfer;
	}
	
	action def MeasureElectrodePotential {
		in referenceValue : ElectricPotentialValue;
		out electrodePotential : ElectricPotentialValue;
	}
	
	action def ControlPotential {
		in targetPotential : ElectricPotentialValue;
		in measuredPotential : ElectricPotentialValue;
		out adjustedCurrent : ISQ::ElectricCurrentValue;
	}
	
	action def PerformRedoxCycle {
		first start;
		then action initializeSystem {
			out initialPotential : ElectricPotentialValue;
			out initialElectrolyte : Electrolyte;
		}
		then merge cycleLoop;
		then action measurePotential : MeasureElectrodePotential {
			in referenceValue;
			out electrodePotential;
		}
		then decide;
			if measurePotential.electrodePotential.num > 0.0 then performReduction;
			if measurePotential.electrodePotential.num <= 0.0 then performOxidation;
		action performOxidation : OxidationReaction {
			in reducedSpecies = initializeSystem.initialElectrolyte;
			in appliedPotential = measurePotential.electrodePotential;
			out oxidizedSpecies;
			out electronFlow;
		}
		then action controlOxidation : ControlPotential {
			in targetPotential;
			in measuredPotential = measurePotential.electrodePotential;
			out adjustedCurrent;
		}
		then cycleLoop;
		action performReduction : ReductionReaction {
			in oxidizedSpecies = initializeSystem.initialElectrolyte;
			in appliedPotential = measurePotential.electrodePotential;
			out reducedSpecies;
			out electronFlow;
		}
		then action controlReduction : ControlPotential {
			in targetPotential;
			in measuredPotential = measurePotential.electrodePotential;
			out adjustedCurrent;
		}
		then cycleLoop;
	}
	
	state def ElectrodeOperatingStates {
		entry; then idle;
		
		state idle;
			
		state oxidizing {
			do action oxidize : OxidationReaction;
		}
			
		state reducing {
			do action reduce : ReductionReaction;
		}
		
		transition idle_to_oxidizing
			first idle
			accept PotentialApplied
			then oxidizing;
		
		transition oxidizing_to_idle
			first oxidizing
			accept PotentialRemoved
			then idle;
			
		transition idle_to_reducing
			first idle
			accept PotentialApplied
			then reducing;
		
		transition reducing_to_idle
			first reducing
			accept PotentialRemoved
			then idle;
	}
	
	requirement def ElectrochemicalPerformanceRequirement {
		doc /* The redox electrode system shall facilitate reversible electron transfer reactions 
		       at the electrode-electrolyte interface with controlled potential and measurable current response. */
		
		subject redoxSystem : RedoxElectrodeSystem;
		
		require constraint potentialControl {
			doc /* The system shall maintain electrode potential within ±10 mV of the set point. */
		}
		
		require constraint currentMeasurement {
			doc /* The system shall measure current with resolution better than 1 nanoampere. */
		}
		
		require constraint reversibility {
			doc /* The redox reactions shall be reversible with efficiency greater than 95%. */
		}
	}
	
	requirement def StabilityRequirement {
		doc /* The electrode potential shall remain stable over continuous operation. */
		
		require constraint driftLimit {
			doc /* Potential drift shall not exceed 5 mV per hour during operation. */
		}
	}
	
	connection def ElectricalConnection {
		end port1 : ElectricalPort;
		end port2 : ElectricalPort;
	}
	
	connection def ElectrolyteConnection {
		end port1 : ElectrolytePort;
		end port2 : ElectrolytePort;
	}
	
	part def RedoxElectrodeSystem {
		part workingElectrode : RedoxElectrode;
		part counterElectrode : CounterElectrode;
		part referenceElectrode : ReferenceElectrode;
		part potentiostat : Potentiostat;
		part electrolyteReservoir : ElectrolyteReservoir;
	}
	
	part redoxElectrodeSystem : RedoxElectrodeSystem {
		
		part :>> workingElectrode {
			attribute :>> surfaceArea = 1.0 [SI::mm2];
			attribute :>> standardPotential {
				attribute :>> num = 0.0;
			}
			
			perform action redoxOperation[*] ordered references redoxCycle;
			
			exhibit state electrodeState : ElectrodeOperatingStates;
		}
		
		part :>> counterElectrode;
		
		part :>> referenceElectrode {
			attribute :>> referencePotential {
				attribute :>> num = 0.0;
			}
		}
		
		part :>> potentiostat {
			attribute :>> setPointPotential {
				attribute :>> num = 0.5;
			}
			
			perform redoxOperation.measurePotential;
			perform redoxOperation.controlOxidation;
			perform redoxOperation.controlReduction;
		}
		
		part :>> electrolyteReservoir {
			attribute :>> volume = 100.0 [SI::mL];
			attribute :>> composition {
				attribute :>> oxidizedSpeciesConcentration {
					attribute :>> num = 0.1;
				}
				attribute :>> reducedSpeciesConcentration {
					attribute :>> num = 0.1;
				}
				attribute :>> pH = 7.0;
				attribute :>> temperature {
					attribute :>> num = 298.15;
				}
			}
		}
		
		connection electricalCircuit1 : ElectricalConnection connect
			potentiostat.workingElectrodePort to workingElectrode.electricalInterface;
			
		connection electricalCircuit2 : ElectricalConnection connect
			potentiostat.counterElectrodePort to counterElectrode.electricalInterface;
			
		connection electricalCircuit3 : ElectricalConnection connect
			potentiostat.referenceElectrodePort to referenceElectrode.electricalInterface;
			
		connection electrolyteFlow1 : ElectrolyteConnection connect
			electrolyteReservoir.outlet to workingElectrode.electrolyteInterface;
			
		connection electrolyteFlow2 : ElectrolyteConnection connect
			electrolyteReservoir.outlet to counterElectrode.electrolyteInterface;
	}
	
	action redoxCycle : PerformRedoxCycle {
		in referenceValue = redoxElectrodeSystem.referenceElectrode.referencePotential;
		in targetPotential = redoxElectrodeSystem.potentiostat.setPointPotential;
	}
	
	requirement systemPerformance : ElectrochemicalPerformanceRequirement {
		subject system = redoxElectrodeSystem;
	}
	
	requirement systemStability : StabilityRequirement;
	
	requirement <'REQ-001'> primaryFunction {
		doc /* The redox electrode system shall enable controlled electrochemical reactions 
		       by facilitating electron transfer between the electrode and chemical species in solution,
		       thereby converting chemical energy to electrical energy or vice versa through 
		       oxidation-reduction processes at the electrode-electrolyte interface. */
		       
		assume constraint electrolytePresent {
			doc /* Electrolyte with active redox species must be present at the electrode interface. */
		}
		
		assume constraint potentialControlAvailable {
			doc /* A potentiostat must be available to control and measure electrode potential. */
		}
		
		require systemPerformance;
		require systemStability;
	}
}
