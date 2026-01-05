package 'Carbon Paste Electrode System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ElectrochemicalConcentration :> ISQ::amountOfSubstanceConcentrationValue {
		attribute unit = SI::mol / SI::L;
	}
	
	attribute def ElectrodePotential :> ISQ::electricPotentialValue;
	
	attribute def ElectrodeCurrent :> ISQ::electricCurrentValue;
	
	attribute def ScanRate :> ScalarValues::Real {
		doc /* Potential scan rate in V/s */
	}
	
	item def AnalyteSolution {
		attribute concentration : ElectrochemicalConcentration;
		attribute volume :> ISQ::volumeValue;
		attribute pH :> ScalarValues::Real;
	}
	
	item def ElectrochemicalData {
		attribute potentials : ElectrodePotential[*];
		attribute currents : ElectrodeCurrent[*];
		attribute peakCurrent : ElectrodeCurrent;
		attribute peakPotential : ElectrodePotential;
	}
	
	item def ElectronTransfer {
		attribute transferRate :> ISQ::frequencyValue;
		attribute direction :> ScalarValues::String;
	}
	
	port def ElectricalInterface {
		in attribute appliedPotential : ElectrodePotential;
		out attribute measuredCurrent : ElectrodeCurrent;
	}
	
	port def SolutionInterface {
		in item solution : AnalyteSolution;
		out item electronFlow : ElectronTransfer;
	}
	
	part def GraphitePowder {
		attribute particleSize :> ISQ::lengthValue;
		attribute purity :> ScalarValues::Real;
		attribute electricalConductivity :> ISQ::electricalConductivityValue;
	}
	
	part def BinderMaterial {
		attribute viscosity :> ScalarValues::Real;
		attribute volumeFraction :> ScalarValues::Real;
	}
	
	part def CarbonPasteMixture {
		attribute graphiteRatio :> ScalarValues::Real;
		attribute binderRatio :> ScalarValues::Real;
		attribute totalConductivity :> ISQ::electricalConductivityValue;
		
		part graphite : GraphitePowder {
			attribute particleSize = 5.0e-6 [SI::m];
			attribute purity = 99.9;
		}
		
		part binder : BinderMaterial {
			attribute viscosity = 0.5;
			attribute volumeFraction = 0.3;
		}
	}
	
	part def WorkingElectrode {
		attribute surfaceArea :> ISQ::areaValue;
		attribute activeArea :> ISQ::areaValue;
		
		part paste : CarbonPasteMixture {
			attribute graphiteRatio = 0.7;
			attribute binderRatio = 0.3;
		}
		
		port electrical : ElectricalInterface;
		port electrochemical : SolutionInterface;
	}
	
	part def ReferenceElectrode {
		attribute referencePotential : ElectrodePotential;
		port electrical : ElectricalInterface;
	}
	
	part def CounterElectrode {
		attribute surfaceArea :> ISQ::areaValue;
		port electrical : ElectricalInterface;
	}
	
	part def Potentiostat {
		attribute controlPrecision : ElectrodePotential;
		attribute currentRange : ElectrodeCurrent;
		
		port workingPort : ElectricalInterface;
		port referencePort : ElectricalInterface;
		port counterPort : ElectricalInterface;
		
		action def ApplyPotential {
			in targetPotential : ElectrodePotential;
			out actualPotential : ElectrodePotential;
		}
		
		action def MeasureCurrent {
			out current : ElectrodeCurrent;
		}
	}
	
	part def ElectrochemicalCell {
		attribute cellVolume :> ISQ::volumeValue;
		attribute temperature :> ISQ::temperatureValue;
		
		part working : WorkingElectrode {
			attribute surfaceArea = 7.0e-5 [SI::m^2];
			attribute activeArea = 5.0e-5 [SI::m^2];
		}
		
		part reference : ReferenceElectrode {
			attribute referencePotential = 0.0 [SI::V];
		}
		
		part counter : CounterElectrode {
			attribute surfaceArea = 1.0e-4 [SI::m^2];
		}
		
		port solutionPort : SolutionInterface;
	}
	
	action def OxidationReaction {
		in attribute potential : ElectrodePotential;
		in item analyte : AnalyteSolution;
		out item electrons : ElectronTransfer;
		out attribute current : ElectrodeCurrent;
	}
	
	action def ReductionReaction {
		in attribute potential : ElectrodePotential;
		in item analyte : AnalyteSolution;
		out item electrons : ElectronTransfer;
		out attribute current : ElectrodeCurrent;
	}
	
	action def PerformVoltammetricScan {
		in attribute startPotential : ElectrodePotential;
		in attribute endPotential : ElectrodePotential;
		in attribute scanRate : ScanRate;
		in attribute stepSize : ElectrodePotential;
		out attribute voltammogram : ElectrochemicalData;
		
		private attribute currentPotential : ElectrodePotential;
		private attribute recordedPotentials : ElectrodePotential[*] := ( );
		private attribute recordedCurrents : ElectrodeCurrent[*] := ( );
		
		first start;
		then assign currentPotential := startPotential;
		then merge scanLoop;
		then decide;
			if currentPotential <= endPotential then applyStep;
			if currentPotential > endPotential then finalizeScan;
		action applyStep {
			action setPotential {
				out potential = currentPotential;
			}
			then action measureResponse {
				in potential = currentPotential;
				out measuredCurrent : ElectrodeCurrent;
			}
			then assign recordedPotentials := recordedPotentials->append(currentPotential);
			then assign recordedCurrents := recordedCurrents->append(measureResponse.measuredCurrent);
			then assign currentPotential := currentPotential + stepSize;
		}
		then scanLoop;
		action finalizeScan {
			assign voltammogram.potentials := recordedPotentials;
			assign voltammogram.currents := recordedCurrents;
		}
		then done;
	}
	
	action def PerformElectrochemicalDetection {
		doc /* 
		The carbon paste electrode system performs electrochemical detection by 
		applying controlled potential sweeps to the working electrode surface, 
		inducing oxidation or reduction reactions with electroactive analyte species 
		in solution, and measuring the resulting faradaic current response to 
		determine analyte concentration through quantitative electroanalysis.
		*/
		
		in item testSolution : AnalyteSolution;
		in attribute scanParameters : ScanRate;
		out attribute detectionResult : ElectrochemicalData;
		out attribute quantifiedConcentration : ElectrochemicalConcentration;
		
		first start;
		then action prepareSurface {
			doc /* Condition and clean the electrode surface */
		}
		then action equilibrate {
			doc /* Allow solution to equilibrate at open circuit potential */
			in item solution = testSolution;
		}
		then action performScan : PerformVoltammetricScan {
			in startPotential = -0.8 [SI::V];
			in endPotential = 0.8 [SI::V];
			in scanRate = scanParameters;
			in stepSize = 0.005 [SI::V];
			out voltammogram;
		}
		then action analyzeRedox {
			in data = performScan.voltammogram;
			action oxidize : OxidationReaction {
				in potential;
				in analyte = testSolution;
				out electrons;
				out current;
			}
			then action reduce : ReductionReaction {
				in potential;
				in analyte = testSolution;
				out electrons;
				out current;
			}
		}
		then action extractPeakData {
			in voltammogram = performScan.voltammogram;
			out peakCurrent : ElectrodeCurrent;
			out peakPotential : ElectrodePotential;
		}
		then action calculateConcentration {
			in peakCurrent = extractPeakData.peakCurrent;
			out concentration : ElectrochemicalConcentration;
		}
		then assign detectionResult := performScan.voltammogram;
		then assign quantifiedConcentration := calculateConcentration.concentration;
		then done;
	}
	
	part carbonPasteElectrodeSystem {
		doc /* 
		A carbon paste electrode system for electrochemical analysis and detection.
		The system enables quantitative determination of electroactive analyte 
		concentrations through controlled potential voltammetry, converting chemical 
		information into measurable electrical signals via heterogeneous electron 
		transfer reactions at the electrode-solution interface.
		*/
		
		part cell : ElectrochemicalCell {
			attribute cellVolume = 1.0e-5 [SI::m^3];
			attribute temperature = 298.15 [SI::K];
		}
		
		part instrument : Potentiostat {
			attribute controlPrecision = 0.001 [SI::V];
			attribute currentRange = 1.0e-3 [SI::A];
		}
		
		connect instrument.workingPort to cell.working.electrical;
		connect instrument.referencePort to cell.reference.electrical;
		connect instrument.counterPort to cell.counter.electrical;
		
		perform action detection : PerformElectrochemicalDetection {
			in testSolution;
			in scanParameters;
			out detectionResult;
			out quantifiedConcentration;
		}
		
		part workingElectrode : WorkingElectrode = cell.working {
			perform detection.analyzeRedox.oxidize;
			perform detection.analyzeRedox.reduce;
		}
		
		part controller : Potentiostat = instrument {
			perform detection.performScan;
		}
	}
	
	requirement def ElectrochemicalPerformanceRequirement;
	
	requirement def SensitivityRequirement :> ElectrochemicalPerformanceRequirement;
	
	requirement def StabilityRequirement :> ElectrochemicalPerformanceRequirement;
	
	requirement primaryFunction : ElectrochemicalPerformanceRequirement {
		doc /* 
		The carbon paste electrode system shall perform quantitative electrochemical 
		detection of electroactive analyte species in solution by applying controlled 
		potential sweeps and measuring the resulting faradaic current response.
		*/
		
		subject system : carbonPasteElectrodeSystem;
		
		require constraint functionalCapability {
			doc /* System shall detect and quantify electroactive species */
		}
	}
	
	requirement sensitivity : SensitivityRequirement {
		doc /* 
		The system shall achieve a detection limit of 1.0 microM or lower for 
		standard electroactive analytes under optimized conditions.
		*/
		
		subject detectionAction : carbonPasteElectrodeSystem.detection;
		
		require constraint detectionLimit {
			attribute minimumConcentration : ElectrochemicalConcentration;
			minimumConcentration <= 1.0e-6 [SI::mol / SI::L];
		}
	}
	
	requirement stability : StabilityRequirement {
		doc /* 
		The electrode response shall remain stable with signal drift less than 
		5% over a continuous measurement period of 2 hours.
		*/
		
		subject electrode : carbonPasteElectrodeSystem.cell.working;
		
		require constraint responseStability {
			attribute maximumDrift :> ScalarValues::Real;
			attribute measurementDuration :> ISQ::timeValue;
			maximumDrift <= 5.0;
			measurementDuration >= 7200.0 [SI::s];
		}
	}
	
	requirement reproducibility : ElectrochemicalPerformanceRequirement {
		doc /* 
		The system shall provide reproducible measurements with relative standard 
		deviation not exceeding 3% for replicate analyses.
		*/
		
		subject detectionProcess : carbonPasteElectrodeSystem.detection;
		
		require constraint measurementPrecision {
			attribute relativeStandardDeviation :> ScalarValues::Real;
			relativeStandardDeviation <= 3.0;
		}
	}
}
