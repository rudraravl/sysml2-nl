package 'Materials Analysis System' {
	private import ISQ::*;
	private import ScalarValues::*;

	package 'Value Types' {
		attribute def ThermalConductivityValue :> Real;
		attribute def SpecificHeatCapacityValue :> Real;
		attribute def VolumeFlowRateValue :> Real;
		attribute def ConductivityValue :> Real;
		attribute def ResistivityValue :> Real;
		attribute def MagnificationValue :> Real;
	}

	package 'Material Types' {
		private import 'Value Types'::*;

		enum def LatticeType { cubic; tetragonal; orthorhombic; hexagonal; monoclinic; triclinic; }
		enum def PreparationState { raw; prepared; analyzed; archived; }

		item def MaterialSpecimen {
			attribute specimenId : String;
			attribute materialName : String;
			attribute preparationState : PreparationState := PreparationState::raw;
		}

		item def CrystalStructure {
			attribute latticeType : LatticeType;
			attribute latticeSpacing : ISQ::LengthValue;
			attribute spaceGroup : String;
		}

		item def Micrograph {
			attribute imageId : String;
			attribute magnification : MagnificationValue;
			attribute grainSize : ISQ::LengthValue;
			attribute phaseDistribution : String;
		}

		item def MechanicalProperties {
			attribute yieldStrength : ISQ::PressureValue;
			attribute ultimateStrength : ISQ::PressureValue;
			attribute elasticModulus : ISQ::PressureValue;
			attribute hardness : ISQ::PressureValue;
			attribute elongationAtBreak : Real;
		}

		item def ThermalProperties {
			attribute meltingPoint : ISQ::ThermodynamicTemperatureValue;
			attribute heatCapacity : SpecificHeatCapacityValue;
			attribute thermalConductivity : ThermalConductivityValue;
		}

		item def ElectricalProperties {
			attribute conductivity : ConductivityValue;
			attribute resistivity : ResistivityValue;
		}

		item def RawData {
			attribute source : String;
			attribute timestamp : String;
			attribute payload : String;
		}

		item def MaterialProfile {
			attribute profileId : String;
			attribute specimenId : String;
			ref item crystalStructure : CrystalStructure;
			ref item micrograph : Micrograph;
			ref item mechanicalProperties : MechanicalProperties;
			ref item thermalProperties : ThermalProperties;
			ref item electricalProperties : ElectricalProperties;
		}
	}

	package 'Interfaces' {
		private import 'Material Types'::*;
		private import 'Value Types'::*;

		port def SpecimenPort {
			ref item specimen : MaterialSpecimen;
		}
		port def PowerPort {
			attribute voltage : ISQ::ElectricPotentialValue;
			attribute current : ISQ::ElectricCurrentValue;
		}
		port def VacuumPort {
			attribute pressure : ISQ::PressureValue;
		}
		port def CoolantPort {
			attribute flowRate : VolumeFlowRateValue;
			attribute temperature : ISQ::ThermodynamicTemperatureValue;
		}
		port def DataPort {
			ref item data : RawData;
		}
		port def ReportPort {
			ref item profile : MaterialProfile;
		}
		port def CommandPort {
			attribute command : String;
		}
	}

	package 'Instruments' {
		private import 'Interfaces'::*;
		private import 'Material Types'::*;

		part def AnalyticalInstrument {
			port specimenPort : SpecimenPort;
			port powerPort : PowerPort;
			port dataPort : DataPort;
			attribute instrumentId : String;
			attribute status : String := "idle";
		}

		part def XRayDiffractometer :> AnalyticalInstrument {
			port vacuumPort : VacuumPort;
			attribute crystalStructure : CrystalStructure;
		}

		part def ScanningElectronMicroscope :> AnalyticalInstrument {
			port vacuumPort : VacuumPort;
			attribute micrograph : Micrograph;
		}

		part def UniversalTestingMachine :> AnalyticalInstrument {
			attribute mechanicalProperties : MechanicalProperties;
		}

		part def DifferentialScanningCalorimeter :> AnalyticalInstrument {
			port coolantPort : CoolantPort;
			attribute thermalProperties : ThermalProperties;
		}

		part def FourPointProbe :> AnalyticalInstrument {
			attribute electricalProperties : ElectricalProperties;
		}
	}

	package 'Support' {
		private import 'Interfaces'::*;

		part def PowerSupply {
			port powerOut : PowerPort;
			attribute outputVoltage : ISQ::ElectricPotentialValue;
			attribute outputCurrent : ISQ::ElectricCurrentValue;
		}

		part def VacuumSystem {
			port vacuumOut : VacuumPort;
			attribute basePressure : ISQ::PressureValue;
			attribute pumpCapacity : VolumeFlowRateValue;
		}

		part def CoolantSystem {
			port coolantOut : CoolantPort;
			attribute supplyTemperature : ISQ::ThermodynamicTemperatureValue;
			attribute flowRate : VolumeFlowRateValue;
		}

		part def SpecimenPreparationStation {
			port specimenIn : SpecimenPort;
			port specimenOut : SpecimenPort;
			attribute preparedSpecimenCount : Integer := 0;
		}
	}

	package 'Control & Data' {
		private import 'Interfaces'::*;
		private import 'Material Types'::*;

		part def CentralController {
			port commandPort : CommandPort;
			port reportPort : ReportPort;
			attribute specimenLoaded : Boolean := false;
			attribute preparationDone : Boolean := false;
			attribute analysisComplete : Boolean := false;
			attribute reportIssued : Boolean := false;
			attribute reset : Boolean := false;

			state machine controlStates {
				initial;
				state idle;
				state preparing;
				state analyzing;
				state reporting;
				state complete;
				transition first initial then idle;
				transition first idle then preparing when specimenLoaded;
				transition first preparing then analyzing when preparationDone;
				transition first analyzing then reporting when analysisComplete;
				transition first reporting then complete when reportIssued;
				transition first complete then idle when reset;
			}
		}

		calc def AggregateProfile {
			in crystalStructure : CrystalStructure;
			in micrograph : Micrograph;
			in mechanicalProperties : MechanicalProperties;
			in thermalProperties : ThermalProperties;
			in electricalProperties : ElectricalProperties;
			return profile : MaterialProfile;
		}

		part def DataAcquisitionSystem {
			port dataIn : DataPort;
			port reportOut : ReportPort;
			attribute aggregatedProfile : MaterialProfile;
		}
	}

	package 'Behaviors' {
		private import 'Material Types'::*;

		action def CharacterizeMaterial {
			in item specimen : MaterialSpecimen;
			action prepare;
			then xrdScan;
			action xrdScan;
			then semScan;
			action semScan;
			then stressTest;
			action stressTest;
			then thermalScan;
			action thermalScan;
			then electricalTest;
			action electricalTest;
			then aggregate;
			action aggregate;
			out item profile : MaterialProfile;
		}
	}

	package 'Integrated System' {
		private import 'Value Types'::*;
		private import 'Material Types'::*;
		private import 'Interfaces'::*;
		private import 'Instruments'::*;
		private import 'Support'::*;
		private import 'Control & Data'::*;
		private import 'Behaviors'::*;

		part def MaterialsAnalysisLab {
			attribute labId : String;

			perform action characterizeMaterial[*] ordered references CharacterizeMaterial;

			part controller : CentralController;
			part preparationStation : SpecimenPreparationStation {
				perform characterizeMaterial.prepare;
			}
			part xrd : XRayDiffractometer {
				perform characterizeMaterial.xrdScan;
			}
			part sem : ScanningElectronMicroscope {
				perform characterizeMaterial.semScan;
			}
			part utm : UniversalTestingMachine {
				perform characterizeMaterial.stressTest;
			}
			part dsc : DifferentialScanningCalorimeter {
				perform characterizeMaterial.thermalScan;
			}
			part probe : FourPointProbe {
				perform characterizeMaterial.electricalTest;
			}
			part das : DataAcquisitionSystem {
				perform characterizeMaterial.aggregate;
			}
			part power : PowerSupply;
			part vacuum : VacuumSystem;
			part coolant : CoolantSystem;

			connection powerToXRD connect power.powerOut to xrd.powerPort;
			connection powerToSEM connect power.powerOut to sem.powerPort;
			connection powerToUTM connect power.powerOut to utm.powerPort;
			connection powerToDSC connect power.powerOut to dsc.powerPort;
			connection powerToProbe connect power.powerOut to probe.powerPort;

			connection vacuumToXRD connect vacuum.vacuumOut to xrd.vacuumPort;
			connection vacuumToSEM connect vacuum.vacuumOut to sem.vacuumPort;

			connection coolantToDSC connect coolant.coolantOut to dsc.coolantPort;

			connection prepToXRD connect preparationStation.specimenOut to xrd.specimenPort;
			connection xrdToSEM connect xrd.specimenPort to sem.specimenPort;
			connection semToUTM connect sem.specimenPort to utm.specimenPort;
			connection utmToDSC connect utm.specimenPort to dsc.specimenPort;
			connection dscToProbe connect dsc.specimenPort to probe.specimenPort;

			connection xrdData connect xrd.dataPort to das.dataIn;
			connection semData connect sem.dataPort to das.dataIn;
			connection utmData connect utm.dataPort to das.dataIn;
			connection dscData connect dsc.dataPort to das.dataIn;
			connection probeData connect probe.dataPort to das.dataIn;

			connection reportToController connect das.reportOut to controller.reportPort;
		}
	}

	package 'Requirements' {
		private import 'Integrated System'::*;
		private import 'Instruments'::*;
		private import 'Support'::*;
		private import 'Control & Data'::*;
		private import 'Material Types'::*;

		requirement def CharacterizationRequirement {
			subject lab : MaterialsAnalysisLab;
			require {
				lab.characterizeMaterial.profile.specimenId <> "";
			}
		}

		requirement def CrystalStructureAnalysisRequirement {
			subject xrd : XRayDiffractometer;
			require {
				xrd.crystalStructure.latticeSpacing > 0 [m];
			}
		}

		requirement def MicrostructureAnalysisRequirement {
			subject sem : ScanningElectronMicroscope;
			require {
				sem.micrograph.magnification >= 100;
			}
		}

		requirement def MechanicalTestRequirement {
			subject utm : UniversalTestingMachine;
			require {
				utm.mechanicalProperties.ultimateStrength > 0 [Pa];
			}
		}

		requirement def ThermalAnalysisRequirement {
			subject dsc : DifferentialScanningCalorimeter;
			require {
				dsc.thermalProperties.meltingPoint > 0 [K];
			}
		}

		requirement def ElectricalTestRequirement {
			subject probe : FourPointProbe;
			require {
				probe.electricalProperties.resistivity > 0;
			}
		}

		requirement def VacuumPerformanceRequirement {
			subject vac : VacuumSystem;
			require {
				vac.basePressure < 1e-3 [Pa];
			}
		}

		requirement def DataIntegrationRequirement {
			subject das : DataAcquisitionSystem;
			require {
				das.aggregatedProfile.crystalStructure.latticeSpacing > 0 [m];
				das.aggregatedProfile.mechanicalProperties.ultimateStrength > 0 [Pa];
				das.aggregatedProfile.thermalProperties.meltingPoint > 0 [K];
			}
		}
	}
}
