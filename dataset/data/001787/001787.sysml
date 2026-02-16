package 'Gasoline Combustion System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ChemicalComposition {
        attribute octaneRating : Real;
        attribute vaporPressure : PressureValue;
        attribute density : DensityValue;
        attribute specificEnergy : SpecificEnergyValue;
    }
    
    attribute def CombustionProperties {
        attribute airFuelRatio : Real;
        attribute ignitionTemperature : ThermodynamicTemperatureValue;
        attribute flameSpeed : SpeedValue;
        attribute combustionEfficiency : Real;
    }
    
    attribute def EmissionLevels {
        attribute co2 : MassFlowRateValue;
        attribute co : MassFlowRateValue;
        attribute nox : MassFlowRateValue;
        attribute unburntHC : MassFlowRateValue;
    }
    
    item def Gasoline {
        attribute composition : ChemicalComposition {
            attribute octaneRating = 91.0;
            attribute vaporPressure = 62.0 [SI::kPa];
            attribute density = 0.74 [kg/L];
            attribute specificEnergy = 46.4 [MJ/kg];
        }
        attribute combustionProps : CombustionProperties {
            attribute airFuelRatio = 14.7;
            attribute ignitionTemperature = 553.0 [K];
            attribute flameSpeed = 0.37 [m/s];
            attribute combustionEfficiency = 0.85;
        }
    }
    
    item def Air {
        attribute oxygenContent : Real = 0.21;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute pressure : PressureValue;
    }
    
    item def ExhaustGas {
        attribute temperature : ThermodynamicTemperatureValue;
        attribute pressure : PressureValue;
        attribute emissions : EmissionLevels;
    }
    
    port def FuelSupplyPort {
        out attribute fuelFlow : VolumeFlowRateValue;
        out attribute fuelPressure : PressureValue;
    }
    
    port def AirIntakePort {
        in attribute airFlow : MassFlowRateValue;
        in attribute airPressure : PressureValue;
    }
    
    port def ExhaustPort {
        out attribute exhaustFlow : MassFlowRateValue;
        out attribute exhaustTemp : ThermodynamicTemperatureValue;
    }
    
    port def MechanicalOutputPort {
        out attribute power : PowerValue;
        out attribute torque : TorqueValue;
        out attribute speed : AngularVelocityValue;
    }
    
    part def FuelTank {
        attribute capacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        port fuelOut : ~FuelSupplyPort;
        
        assert constraint levelConstraint {
            currentLevel >= 0.0 [L] and currentLevel <= capacity
        }
    }
    
    part def FuelPump {
        port fuelIn : FuelSupplyPort;
        port fuelOut : ~FuelSupplyPort;
        attribute operatingPressure : PressureValue;
        attribute flowCapacity : VolumeFlowRateValue;
        
        action def PumpFuel {
            in requiredFlow : VolumeFlowRateValue;
            out deliveredFlow : VolumeFlowRateValue;
            out outputPressure : PressureValue;
        }
    }
    
    part def FuelInjector {
        port fuelIn : FuelSupplyPort;
        attribute injectionTiming : TimeValue;
        attribute sprayAngle : Real;
        attribute injectionPressure : PressureValue;
        
        action def InjectFuel {
            in fuelPressure : PressureValue;
            in duration : TimeValue;
            out fuelMass : MassValue;
        }
    }
    
    part def AirFilter {
        port airIn : AirIntakePort;
        port airOut : ~AirIntakePort;
        attribute filterEfficiency : Real;
        attribute pressureDrop : PressureValue;
    }
    
    part def Throttle {
        port airIn : AirIntakePort;
        port airOut : ~AirIntakePort;
        attribute position : Real;
        attribute maxFlow : MassFlowRateValue;
    }
    
    part def CombustionChamber {
        port fuelIn : FuelSupplyPort;
        port airIn : AirIntakePort;
        port exhaustOut : ~ExhaustPort;
        port powerOut : ~MechanicalOutputPort;
        
        attribute volume : VolumeValue;
        attribute compressionRatio : Real;
        attribute cylinderTemp : ThermodynamicTemperatureValue;
        attribute cylinderPressure : PressureValue;
        
        state combustionCycle {
            entry; then intake;
            
            state intake {
                entry assign cylinderPressure := 0.8 [SI::bar];
                entry assign cylinderTemp := 320.0 [K];
            }
            
            transition intakeToCompression
                first intake
                then compression;
            
            state compression {
                entry assign cylinderPressure := compressionRatio * 0.8 [SI::bar];
                entry assign cylinderTemp := 650.0 [K];
            }
            
            transition compressionToPower
                first compression
                then power;
            
            state power {
                entry assign cylinderPressure := 75.0 [SI::bar];
                entry assign cylinderTemp := 2400.0 [K];
            }
            
            transition powerToExhaust
                first power
                then exhaust;
            
            state exhaust {
                entry assign cylinderPressure := 1.3 [SI::bar];
                entry assign cylinderTemp := 900.0 [K];
            }
            
            transition exhaustToIntake
                first exhaust
                then intake;
        }
    }
    
    part def IgnitionSystem {
        attribute sparkTiming : Real;
        attribute sparkEnergy : EnergyValue;
        
        action def GenerateSpark {
            in timing : TimeValue;
            out ignitionEvent : Boolean;
        }
    }
    
    part def ExhaustManifold {
        port exhaustIn : ExhaustPort;
        port exhaustOut : ~ExhaustPort;
        attribute backPressure : PressureValue;
    }
    
    part def CatalyticConverter {
        port exhaustIn : ExhaustPort;
        port exhaustOut : ~ExhaustPort;
        attribute conversionEfficiency : Real;
        attribute operatingTemp : ThermodynamicTemperatureValue;
        
        action def ReduceEmissions {
            in rawEmissions : EmissionLevels;
            in efficiency : Real;
            out cleanedEmissions : EmissionLevels;
        }
    }
    
    action def MixFuelAndAir {
        in fuelMass : MassValue;
        in airMass : MassValue;
        in targetRatio : Real;
        out mixtureQuality : Real;
        out totalEnergy : EnergyValue;
    }
    
    action def IgniteAndCombust {
        in mixtureEnergy : EnergyValue;
        in sparkTiming : TimeValue;
        in efficiency : Real;
        out peakPressure : PressureValue;
        out peakTemperature : ThermodynamicTemperatureValue;
        out releasedEnergy : EnergyValue;
    }
    
    action def ConvertToPower {
        in pressure : PressureValue;
        in volume : VolumeValue;
        in crankAngle : Real;
        out mechanicalWork : EnergyValue;
        out instantTorque : TorqueValue;
    }
    
    action def ExpelExhaust {
        in exhaustMass : MassValue;
        in exhaustTemp : ThermodynamicTemperatureValue;
        in combustionProducts : EmissionLevels;
        out exhaustGas : ExhaustGas;
    }
    
    action def GenerateMechanicalPower {
        in fuelFlow : VolumeFlowRateValue;
        in airFlow : MassFlowRateValue;
        in fuelProperties : Gasoline;
        out powerOutput : PowerValue;
        out exhaustOutput : ExhaustGas;
        
        first start;
        
        then action mixPhase : MixFuelAndAir {
            in fuelMass : MassValue;
            in airMass : MassValue;
            in targetRatio = fuelProperties.combustionProps.airFuelRatio;
            out mixtureQuality : Real;
            out totalEnergy : EnergyValue;
        }
        
        then action combustPhase : IgniteAndCombust {
            in mixtureEnergy = mixPhase.totalEnergy;
            in sparkTiming : TimeValue;
            in efficiency = fuelProperties.combustionProps.combustionEfficiency;
            out peakPressure : PressureValue;
            out peakTemperature : ThermodynamicTemperatureValue;
            out releasedEnergy : EnergyValue;
        }
        
        then action powerPhase : ConvertToPower {
            in pressure = combustPhase.peakPressure;
            in volume : VolumeValue;
            in crankAngle : Real;
            out mechanicalWork : EnergyValue;
            out instantTorque : TorqueValue;
        }
        
        then action exhaustPhase : ExpelExhaust {
            in exhaustMass : MassValue;
            in exhaustTemp = combustPhase.peakTemperature;
            in combustionProducts : EmissionLevels;
            out exhaustGas : ExhaustGas;
        }
        
        then done;
    }
    
    part gasolineEngine {
        doc /* 
            A gasoline-powered internal combustion engine system that converts 
            the chemical energy stored in gasoline fuel into mechanical power 
            through a controlled four-stroke combustion cycle. The system intakes 
            air and fuel, mixes them in precise ratios, ignites the mixture to 
            generate high-pressure gases, and converts the resulting expansion 
            into rotational mechanical energy while managing exhaust emissions.
        */
        
        attribute fuelType : Gasoline;
        
        part fuelTank : FuelTank {
            attribute capacity = 55.0 [L];
            attribute currentLevel = 40.0 [L];
        }
        
        part fuelPump : FuelPump {
            attribute operatingPressure = 350.0 [SI::kPa];
            attribute flowCapacity = 3.5 [L/min];
        }
        
        part injector : FuelInjector[4] {
            attribute injectionTiming = 2.5 [SI::ms];
            attribute sprayAngle = 15.0;
            attribute injectionPressure = 300.0 [SI::kPa];
        }
        
        part airFilter : AirFilter {
            attribute filterEfficiency = 0.99;
            attribute pressureDrop = 2.0 [SI::kPa];
        }
        
        part throttle : Throttle {
            attribute position = 0.6;
            attribute maxFlow = 180.0 [kg/h];
        }
        
        part cylinder : CombustionChamber[4] {
            attribute volume = 0.5 [L];
            attribute compressionRatio = 11.0;
            attribute cylinderTemp = 320.0 [K];
            attribute cylinderPressure = 1.0 [SI::bar];
            
            perform action powerGeneration : GenerateMechanicalPower;
            exhibit state combustionCycle;
        }
        
        part ignition : IgnitionSystem {
            attribute sparkTiming = 15.0;
            attribute sparkEnergy = 50.0 [SI::mJ];
        }
        
        part exhaustManifold : ExhaustManifold {
            attribute backPressure = 1.8 [SI::bar];
        }
        
        part catalyticConverter : CatalyticConverter {
            attribute conversionEfficiency = 0.92;
            attribute operatingTemp = 673.0 [K];
        }
        
        connect fuelTank.fuelOut to fuelPump.fuelIn;
        connect fuelPump.fuelOut to injector.fuelIn;
        
        connect airFilter.airOut to throttle.airIn;
        connect throttle.airOut to cylinder.airIn;
        
        connect cylinder.exhaustOut to exhaustManifold.exhaustIn;
        connect exhaustManifold.exhaustOut to catalyticConverter.exhaustIn;
    }
    
    requirement def EnergyConversionRequirement {
        doc /* The system shall efficiently convert chemical energy in gasoline to mechanical power. */
        
        subject engine : gasolineEngine;
        
        require constraint thermalEfficiency {
            0.30 >= 0.25
        }
    }
    
    requirement def EmissionControlRequirement {
        doc /* The system shall minimize harmful emissions through catalytic conversion. */
        
        subject engine : gasolineEngine;
        
        require constraint catalyticEfficiency {
            engine.catalyticConverter.conversionEfficiency >= 0.90
        }
    }
    
    requirement def FuelSystemRequirement {
        doc /* The fuel system shall maintain proper pressure and flow for optimal combustion. */
        
        subject engine : gasolineEngine;
        
        require constraint fuelPressureRange {
            engine.fuelPump.operatingPressure >= 250.0 [SI::kPa] and
            engine.fuelPump.operatingPressure <= 400.0 [SI::kPa]
        }
        
        require constraint airFuelRatio {
            engine.fuelType.combustionProps.airFuelRatio >= 14.0 and
            engine.fuelType.combustionProps.airFuelRatio <= 15.5
        }
    }
    
    requirement def CompressionRequirement {
        doc /* The combustion chamber shall maintain adequate compression ratio for efficiency. */
        
        subject engine : gasolineEngine;
        
        require constraint compressionRatioRange {
            engine.cylinder.compressionRatio >= 9.0 and
            engine.cylinder.compressionRatio <= 12.0
        }
    }
    
    requirement gasolineEngineRequirements {
        doc /* Top-level requirements for gasoline combustion engine system. */
        
        require energyConversionReq : EnergyConversionRequirement;
        require emissionControlReq : EmissionControlRequirement;
        require fuelSystemReq : FuelSystemRequirement;
        require compressionReq : CompressionRequirement;
    }
}
