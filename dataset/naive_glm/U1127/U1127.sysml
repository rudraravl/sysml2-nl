package EnergyAbsorptionSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====

    value type ForceValue :> Real {
        unit N;
    }

    value type TemperatureValue :> Real {
        unit 'K';
    }

    value type DeformationValue :> Real {
        unit 'm';
    }

    value type EnergyValue :> Real {
        unit J;
    }

    value type ThermalFluxValue :> Real {
        unit 'W';
    }

    value type StrainValue :> Real {
        unit '1';
    }

    value type StressValue :> Real {
        unit Pa;
    }

    value type AreaValue :> Real {
        unit 'm^2';
    }

    value type LengthValue :> Real {
        unit 'm';
    }

    value type MassValue :> Real {
        unit 'kg';
    }

    value type BooleanStatus :> Boolean;

    // ===== Item Types =====

    item def ImpactForce {
        attribute magnitude : ForceValue;
        attribute duration : TimeValue;
    }

    item def ThermalLoad {
        attribute heatFlux : ThermalFluxValue;
        attribute sourceTemp : TemperatureValue;
    }

    item def SensorReading {
        attribute measuredForce : ForceValue;
        attribute measuredDeformation : DeformationValue;
        attribute measuredTemperature : TemperatureValue;
        attribute timestamp : TimeValue;
    }

    item def FaultSignal {
        attribute faultType : String;
        attribute severity : Integer;
        attribute timestamp : TimeValue;
    }

    item def ResidualForce {
        attribute magnitude : ForceValue;
    }

    // ===== Block Definitions =====

    block ProtectiveEnclosure {
        attribute material : String = "Steel";
        attribute thickness : LengthValue = 0.005;
        attribute surfaceArea : AreaValue = 0.04;
        attribute yieldStrength : StressValue = 250000000.0;

        port in impactInput : ImpactForce;
        port out distributedForce : ForceValue;

        action distributeForce {
            in impact : ImpactValue = impactInput;
            out distributed : ForceValue = distributedForce;
            // Distributes blunt force evenly across foam surface
        }
    }

    block MetalFoamCore {
        attribute material : String = "AluminumAlloyFoam";
        attribute porosity : Real = 0.85;
        attribute initialLength : LengthValue = 0.10;
        attribute currentLength : LengthValue;
        attribute plateauStress : StressValue = 5000000.0;
        attribute densificationStrain : StrainValue = 0.7;
        attribute elasticModulus : StressValue = 100000000.0;
        attribute thermalConductivity : Real = 150.0; // W/(m·K)
        attribute absorbedEnergy : EnergyValue;
        attribute permanentDeformation : DeformationValue;
        attribute currentTemperature : TemperatureValue;
        attribute maxOperatingTemp : TemperatureValue = 573.15; // 300°C
        attribute maxDeformation : DeformationValue = 0.07; // 70% of 0.10m

        port in appliedForce : ForceValue;
        port in heatInput : ThermalLoad;
        port out residualForce : ResidualForce;
        port out dissipatedHeat : ThermalFluxValue;
        port out deformationState : DeformationValue;
        port out temperatureState : TemperatureValue;

        state def FoamCrushingBehavior {
            attribute totalAbsorbedEnergy : EnergyValue;

            state Intact {
                entry {
                    permanentDeformation = 0;
                    absorbedEnergy = 0;
                    currentLength = initialLength;
                }
            }

            state ElasticPhase {
                // Spring-like initial compression
                entry {
                    // Foam compresses elastically, force proportional to strain
                }
                do {
                    // Absorb small amount of energy, recoverable
                }
            }

            state PlateauPhase {
                // Long near-constant force crushing — bulk energy absorption
                entry {
                    // Transition from elastic to plateau at yield
                }
                do {
                    // Progressive crushing at plateauStress
                    // absorbedEnergy += plateauStress * crossSectionArea * deltaStrain
                }
            }

            state DensificationPhase {
                // Fully compacted — force rises sharply
                entry {
                    // Foam cells fully collapsed
                }
                do {
                    // Minimal additional energy absorption
                    // Force rises steeply
                }
            }

            state Compromised {
                // Foam fully densified, no more absorption capacity
                entry {
                    // System requires replacement
                }
            }

            transition Intact -> ElasticPhase
                when appliedForce.magnitude > 0;

            transition ElasticPhase -> PlateauPhase
                when appliedForce.magnitude >= plateauStress * 0.04;

            transition PlateauPhase -> DensificationPhase
                when permanentDeformation >= maxDeformation;

            transition DensificationPhase -> Compromised
                when permanentDeformation >= maxDeformation * 0.99;

            transition ElasticPhase -> Intact
                when appliedForce.magnitude == 0 and permanentDeformation == 0;
        }

        action dissipateHeat {
            in heat : ThermalLoad = heatInput;
            out dissipated : ThermalFluxValue = dissipatedHeat;
            // Conducts heat through aluminum foam and radiates to environment
        }
    }

    block MountingBracket {
        attribute material : String = "Steel";
        attribute attachmentCount : Integer = 4;
        attribute boltDiameter : LengthValue = 0.012;
        attribute maxLoadPerBolt : ForceValue = 50000.0;

        port in residualForce : ResidualForce;
        port out transferredForce : ForceValue;

        action transferResidualForce {
            in residual : ResidualForce = residualForce;
            out transferred : ForceValue = transferredForce;
            // Transfers residual forces to protected structure
        }
    }

    block SensorArray {
        attribute samplingRate : Real = 100.0; // Hz
        attribute forceRange : ForceValue = 200000.0;
        attribute tempRange : TemperatureValue = 673.15;
        attribute deformationRange : DeformationValue = 0.10;

        port in deformationInput : DeformationValue;
        port in temperatureInput : TemperatureValue;
        port in forceInput : ForceValue;
        port out sensorData : SensorReading;
        port out faultSignal : FaultSignal;

        attribute safeDeformationLimit : DeformationValue = 0.06;
        attribute safeTemperatureLimit : TemperatureValue = 523.15; // 250°C

        action monitorSystem {
            in deformation : DeformationValue = deformationInput;
            in temperature : TemperatureValue = temperatureInput;
            in force : ForceValue = forceInput;
            out reading : SensorReading = sensorData;
            out fault : FaultSignal = faultSignal;

            if deformation > safeDeformationLimit {
                fault.faultType = "ExcessiveDeformation";
                fault.severity = 2;
            }
            if temperature > safeTemperatureLimit {
                fault.faultType = "OverTemperature";
                fault.severity = 2;
            }
        }

        state def SensorHealthStateMachine {
            state Operational;
            state Warning;
            state Faulted;

            transition Operational -> Warning
                when deformationInput > safeDeformationLimit or temperatureInput > safeTemperatureLimit;

            transition Warning -> Faulted
                when deformationInput > safeDeformationLimit * 1.1 or temperatureInput > safeTemperatureLimit * 1.1;

            transition Warning -> Operational
                when deformationInput <= safeDeformationLimit and temperatureInput <= safeTemperatureLimit;

            transition Faulted -> Operational
                when false; // Manual reset required
        }
    }

    // ===== Top-level System =====

    block EnergyAbsorptionUnit {
        attribute systemMass : MassValue = 5.5;
        attribute overallDimensions : LengthValue[3] = #(0.20, 0.20, 0.11);
        attribute mountingPoints : Integer = 4;

        port in externalImpact : ImpactForce;
        port in thermalSource : ThermalLoad;
        port out systemFaultSignal : FaultSignal;
        port out systemSensorData : SensorReading;
        port out forceToProtectedStructure : ForceValue;

        part enclosure : ProtectiveEnclosure {
            port in impactInput = externalImpact;
        }

        part foamCore : MetalFoamCore {
            port in appliedForce = enclosure.distributedForce;
            port in heatInput = thermalSource;
        }

        part bracket : MountingBracket {
            port in residualForce = foamCore.residualForce;
        }

        part sensors : SensorArray {
            port in deformationInput = foamCore.deformationState;
            port in temperatureInput = foamCore.temperatureState;
            port in forceInput = enclosure.distributedForce;
            port out faultSignal = systemFaultSignal;
            port out sensorData = systemSensorData;
        }

        connection enclosure.distributedForce to foamCore.appliedForce;
        connection foamCore.residualForce to bracket.residualForce;
        connection bracket.transferredForce to forceToProtectedStructure;
        connection foamCore.deformationState to sensors.deformationInput;
        connection foamCore.temperatureState to sensors.temperatureInput;
        connection enclosure.distributedForce to sensors.forceInput;
        connection sensors.faultSignal to systemFaultSignal;
        connection sensors.sensorData to systemSensorData;

        action operateSystem {
            // Continuous operation action
            in impact : ImpactForce = externalImpact;
            in heat : ThermalLoad = thermalSource;
            out data : SensorReading = systemSensorData;
            out fault : FaultSignal = systemFaultSignal;
            out residual : ForceValue = forceToProtectedStructure;

            perform enclosure.distributeForce;
            perform foamCore.dissipateHeat;
            perform bracket.transferResidualForce;
            perform sensors.monitorSystem;
        }
    }

    // ===== Requirements =====

    requirement def ImpactEnergyAbsorptionRequirement {
        subject absorber : EnergyAbsorptionUnit;
        attribute minAbsorbedEnergy : EnergyValue = 8000.0;
        attribute maxResidualForce : ForceValue = 15000.0;
        require {
            absorber.foamCore.absorbedEnergy >= minAbsorbedEnergy;
            absorber.forceToProtectedStructure <= maxResidualForce;
        }
    }

    requirement def ThermalManagementRequirement {
    subject thermalSystem : EnergyAbsorptionUnit;
    attribute maxOperatingTemp : TemperatureValue = 573.15;
    attribute minHeatDissipation : ThermalFluxValue = 50.0;
    require {
        thermalSystem.foamCore.currentTemperature <= maxOperatingTemp;
        thermalSystem.foamCore.dissipatedHeat >= minHeatDissipation;
    }
    }

    requirement def StructuralIntegrityMonitoringRequirement {
        subject monitor : EnergyAbsorptionUnit;
        attribute maxResponseTime : TimeValue = 0.1;
        require {
            monitor.sensors.samplingRate >= 100.0;
            monitor.systemFaultSignal.faultType != null implies monitor.sensors.deformationInput > monitor.sensors.safeDeformationLimit or monitor.sensors.temperatureInput > monitor.sensors.safeTemperatureLimit;
        }
    }

    requirement def MountingRequirement {
        subject mount : EnergyAbsorptionUnit;
        attribute requiredAttachmentPoints : Integer = 4;
        require {
            mount.bracket.attachmentCount == requiredAttachmentPoints;
            mount.bracket.maxLoadPerBolt >= 50000.0;
        }
    }

    requirement def ProgressiveCrushingRequirement {
        subject foam : MetalFoamCore;
        attribute plateauStressRange : StressValue[2] = #(3000000.0, 8000000.0);
        attribute densificationStrainMin : StrainValue = 0.6;
        require {
            foam.plateauStress >= plateauStressRange[1] and foam.plateauStress <= plateauStressRange[2];
            foam.densificationStrain >= densificationStrainMin;
        }
    }

    // ===== Satisfaction =====

    satisfaction ImpactEnergyAbsorptionRequirement by EnergyAbsorptionUnit::foamCore;
    satisfaction ThermalManagementRequirement by EnergyAbsorptionUnit::foamCore;
    satisfaction StructuralIntegrityMonitoringRequirement by EnergyAbsorptionUnit::sensors;
    satisfaction MountingRequirement by EnergyAbsorptionUnit::bracket;
    satisfaction ProgressiveCrushingRequirement by EnergyAbsorptionUnit::foamCore;
}
