package 'Materials Science Characterization System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def CrystalStructure {
        attribute latticeType : String;
        attribute latticeParameter : LengthValue;
        attribute spaceGroup : String;
    }
    
    attribute def MechanicalProperties {
        attribute yieldStrength : PressureValue;
        attribute ultimateTensileStrength : PressureValue;
        attribute elasticModulus : PressureValue;
        attribute hardness : PressureValue;
        attribute fractureToughness : Real;
    }
    
    attribute def ThermalProperties {
        attribute meltingPoint : ThermodynamicTemperatureValue;
        attribute thermalConductivity : Real;
        attribute specificHeatCapacity : Real;
        attribute thermalExpansionCoefficient : Real;
    }
    
    attribute def ElectricalProperties {
        attribute electricalConductivity : Real;
        attribute resistivity : Real;
        attribute bandGap : Real;
    }
    
    attribute def ChemicalComposition {
        attribute elementSymbol : String[1..*];
        attribute atomicPercent : Real[1..*];
        attribute weightPercent : Real[1..*];
    }
    
    item def MaterialSpecimen {
        attribute sampleID : String;
        attribute composition : ChemicalComposition;
        attribute mass : MassValue;
        attribute dimensions : LengthValue[3];
        attribute surfaceFinish : String;
    }
    
    item def CharacterizedMaterial {
        attribute sampleID : String;
        attribute composition : ChemicalComposition;
        attribute crystalStructure : CrystalStructure;
        attribute mechanicalProps : MechanicalProperties;
        attribute thermalProps : ThermalProperties;
        attribute electricalProps : ElectricalProperties;
        attribute microstructureImage : String;
    }
    
    port def SpecimenInputPort {
        in item specimen : MaterialSpecimen;
    }
    
    port def DataOutputPort {
        out item characterizedData : CharacterizedMaterial;
    }
    
    port def VacuumPort {
        in attribute targetPressure : PressureValue;
        out attribute actualPressure : PressureValue;
    }
    
    port def PowerPort {
        in attribute voltage : Real;
        in attribute current : Real;
    }
    
    port def CoolingPort {
        in attribute coolantFlow : Real;
        out attribute temperature : ThermodynamicTemperatureValue;
    }
    
    part def XRayDiffractometer {
        port powerIn : PowerPort;
        port vacuumControl : VacuumPort;
        port coolingIn : CoolingPort;
        
        attribute xrayWavelength : LengthValue;
        attribute detectorResolution : Real;
        attribute scanRange : Real[2];
        
        action def PerformXRDAnalysis {
            in specimen : MaterialSpecimen;
            out crystalData : CrystalStructure;
            out diffractionPattern : Real[*];
        }
    }
    
    part def ScanningElectronMicroscope {
        port powerIn : PowerPort;
        port vacuumControl : VacuumPort;
        
        attribute acceleratingVoltage : Real;
        attribute magnificationRange : Real[2];
        attribute resolution : LengthValue;
        
        action def PerformSEMImaging {
            in specimen : MaterialSpecimen;
            out microstructureData : String;
            out grainSize : LengthValue;
            out phaseDistribution : Real[*];
        }
    }
    
    part def UniversalTestingMachine {
        port powerIn : PowerPort;
        
        attribute maxLoad : ForceValue;
        attribute crossheadSpeed : Real;
        attribute strainGaugeAccuracy : Real;
        
        action def PerformTensileTest {
            in specimen : MaterialSpecimen;
            out mechanicalData : MechanicalProperties;
            out stressStrainCurve : Real[*];
        }
    }
    
    part def DifferentialScanningCalorimeter {
        port powerIn : PowerPort;
        port coolingIn : CoolingPort;
        
        attribute temperatureRange : ThermodynamicTemperatureValue[2];
        attribute heatingRate : Real;
        attribute sensitivity : Real;
        
        action def PerformThermalAnalysis {
            in specimen : MaterialSpecimen;
            out thermalData : ThermalProperties;
            out heatFlowCurve : Real[*];
        }
    }
    
    part def FourPointProbe {
        port powerIn : PowerPort;
        
        attribute probeSpacing : LengthValue;
        attribute currentRange : Real;
        attribute voltageResolution : Real;
        
        action def MeasureElectricalProperties {
            in specimen : MaterialSpecimen;
            out electricalData : ElectricalProperties;
        }
    }
    
    part def DataAcquisitionSystem {
        port dataInputs : DataOutputPort[5];
        port consolidatedOutput : DataOutputPort;
        
        action def AggregateData {
            in crystalData : CrystalStructure;
            in mechanicalData : MechanicalProperties;
            in thermalData : ThermalProperties;
            in electricalData : ElectricalProperties;
            in microstructureData : String;
            out completeCharacterization : CharacterizedMaterial;
        }
    }
    
    requirement def StructuralCharacterizationRequirement {
        doc /* The system shall determine the crystal structure and microstructure 
               of material specimens with sufficient resolution to identify phases 
               and defects. */
        
        require constraint {
            doc /* XRD resolution shall be better than 0.01 degrees 2-theta */
        }
        
        require constraint {
            doc /* SEM resolution shall be better than 5 nanometers */
        }
    }
    
    requirement def MechanicalTestingRequirement {
        doc /* The system shall measure mechanical properties including strength, 
               modulus, and hardness according to ASTM standards. */
        
        require constraint {
            doc /* Load measurement accuracy shall be within ±0.5% of reading */
        }
        
        require constraint {
            doc /* Strain measurement accuracy shall be within ±1% */
        }
    }
    
    requirement def ThermalAnalysisRequirement {
        doc /* The system shall characterize thermal properties over a wide 
               temperature range with high sensitivity. */
        
        require constraint {
            doc /* Temperature range shall be -50°C to 1500°C */
        }
        
        require constraint {
            doc /* Heat flow sensitivity shall be better than 0.2 μW */
        }
    }
    
    requirement def DataIntegrationRequirement {
        doc /* The system shall integrate data from all characterization techniques 
               into a comprehensive material profile. */
        
        require constraint {
            doc /* Data correlation accuracy shall be within 95% confidence interval */
        }
    }
    
    action def ComprehensiveMaterialCharacterization {
        in specimen : MaterialSpecimen;
        out characterizedMaterial : CharacterizedMaterial;
        
        first start;
        
        then action prepareSpecimen {
            in inputSpecimen = specimen;
            out preparedSpecimen : MaterialSpecimen;
        }
        
        then action structuralCharacterization {
            in sample = prepareSpecimen.preparedSpecimen;
            out crystalStructure : CrystalStructure;
            out microstructure : String;
            
            action xrdAnalysis : XRayDiffractometer::PerformXRDAnalysis {
                in specimen = sample;
                out crystalData;
                out diffractionPattern;
            }
            
            action semImaging : ScanningElectronMicroscope::PerformSEMImaging {
                in specimen = sample;
                out microstructureData;
                out grainSize;
                out phaseDistribution;
            }
            
            then assign crystalStructure := xrdAnalysis.crystalData;
            then assign microstructure := semImaging.microstructureData;
        }
        
        then action mechanicalCharacterization {
            in sample = prepareSpecimen.preparedSpecimen;
            out mechanicalProperties : MechanicalProperties;
            
            action tensileTest : UniversalTestingMachine::PerformTensileTest {
                in specimen = sample;
                out mechanicalData;
                out stressStrainCurve;
            }
            
            then assign mechanicalProperties := tensileTest.mechanicalData;
        }
        
        then action thermalCharacterization {
            in sample = prepareSpecimen.preparedSpecimen;
            out thermalProperties : ThermalProperties;
            
            action dscAnalysis : DifferentialScanningCalorimeter::PerformThermalAnalysis {
                in specimen = sample;
                out thermalData;
                out heatFlowCurve;
            }
            
            then assign thermalProperties := dscAnalysis.thermalData;
        }
        
        then action electricalCharacterization {
            in sample = prepareSpecimen.preparedSpecimen;
            out electricalProperties : ElectricalProperties;
            
            action probeTest : FourPointProbe::MeasureElectricalProperties {
                in specimen = sample;
                out electricalData;
            }
            
            then assign electricalProperties := probeTest.electricalData;
        }
        
        then action integrateData : DataAcquisitionSystem::AggregateData {
            in crystalData = structuralCharacterization.crystalStructure;
            in mechanicalData = mechanicalCharacterization.mechanicalProperties;
            in thermalData = thermalCharacterization.thermalProperties;
            in electricalData = electricalCharacterization.electricalProperties;
            in microstructureData = structuralCharacterization.microstructure;
            out completeCharacterization;
        }
        
        then assign characterizedMaterial := integrateData.completeCharacterization;
        
        then done;
    }
    
    part characterizationSystem : MaterialCharacterizationSystem {
        doc /* 
            This system performs comprehensive multi-scale characterization of 
            material specimens to determine their structural, mechanical, thermal, 
            and electrical properties through integrated analytical techniques.
            
            The primary function is to transform unknown material specimens into 
            fully characterized materials with complete property profiles by 
            coordinating multiple advanced characterization instruments and 
            consolidating their outputs into unified material data.
        */
        
        port specimenInput : SpecimenInputPort;
        port dataOutput : DataOutputPort;
        
        part xrd : XRayDiffractometer {
            attribute xrayWavelength = 1.5406e-10 [SI::m];
            attribute detectorResolution = 0.01;
            attribute scanRange = (5.0, 90.0);
        }
        
        part sem : ScanningElectronMicroscope {
            attribute acceleratingVoltage = 20000.0;
            attribute magnificationRange = (100.0, 500000.0);
            attribute resolution = 2.0e-9 [SI::m];
        }
        
        part utm : UniversalTestingMachine {
            attribute maxLoad = 100000.0 [SI::N];
            attribute crossheadSpeed = 0.001;
            attribute strainGaugeAccuracy = 0.005;
        }
        
        part dsc : DifferentialScanningCalorimeter {
            attribute temperatureRange = (223.15 [SI::K], 1773.15 [SI::K]);
            attribute heatingRate = 10.0;
            attribute sensitivity = 0.2e-6;
        }
        
        part probe : FourPointProbe {
            attribute probeSpacing = 1.0e-3 [SI::m];
            attribute currentRange = 1.0e-3;
            attribute voltageResolution = 1.0e-6;
        }
        
        part dataSystem : DataAcquisitionSystem;
        
        part processController {
            perform action characterizationProcess : ComprehensiveMaterialCharacterization;
        }
        
        connection xrdToData connect xrd to dataSystem.dataInputs[0];
        connection semToData connect sem to dataSystem.dataInputs[1];
        connection utmToData connect utm to dataSystem.dataInputs[2];
        connection dscToData connect dsc to dataSystem.dataInputs[3];
        connection probeToData connect probe to dataSystem.dataInputs[4];
        connection dataToOutput connect dataSystem.consolidatedOutput to dataOutput;
        
        satisfy StructuralCharacterizationRequirement;
        satisfy MechanicalTestingRequirement;
        satisfy ThermalAnalysisRequirement;
        satisfy DataIntegrationRequirement;
    }
    
    requirement <'MAT-SYS-001'> systemCapabilityRequirement {
        doc /* 
            The Materials Science Characterization System shall provide comprehensive 
            multi-technique analysis of material specimens to determine their complete 
            property profile including structural, mechanical, thermal, and electrical 
            characteristics with high accuracy and reproducibility.
        */
        
        require StructuralCharacterizationRequirement;
        require MechanicalTestingRequirement;
        require ThermalAnalysisRequirement;
        require DataIntegrationRequirement;
        
        require constraint {
            doc /* Total characterization time shall not exceed 24 hours per specimen */
        }
        
        require constraint {
            doc /* System shall maintain calibration within ±2% over 6 months */
        }
        
        require constraint {
            doc /* Measurement repeatability shall be within 95% confidence interval */
        }
    }
}
