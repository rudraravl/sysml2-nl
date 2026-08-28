package RTGSystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    // ---- Value Types ----
    valueType FuelMass :> Mass;
    valueType ThermalPower :> Power;
    valueType ElectricPower :> Power;
    valueType OutputVoltage :> ElectricPotential;
    valueType RadiatorArea :> Area;
    valueType TempDifferential :> Temperature;
    valueType MissionDuration :> Time;
    valueType ElapsedTime :> Time;
    valueType CoupleCount :> Integer;

    // ---- Item Types (flow items) ----
    item Heat;
    item RawElectricity;
    item ConditionedElectricity;

    // ---- Requirements ----
    requirement def RTGMissionRequirement {
        subject rtg : RTG;
        requirement LongLifeRequirement {
            doc "The RTG shall operate for at least 14 years."
            constraint { rtg.missionLife >= 14 [yr] }
        }
        requirement InitialPowerRequirement {
            doc "The RTG shall produce at least 131 W at beginning of life."
            constraint { rtg.currentOutput >= 131 [W] }
        }
        requirement EndOfLifePowerRequirement {
            doc "The RTG shall produce at least 100 W at end of mission life."
            constraint { rtg.currentOutput >= 100 [W] }
        }
        requirement ConditionedVoltageRequirement {
            doc "The RTG shall provide a conditioned output voltage of 28 V."
            constraint { rtg.powerConditioning.outputVoltage == 28 [V] }
        }
    }

    // ---- Radioisotope Heat Source ----
    part def RadioisotopeHeatSource {
        attribute fuelMass : FuelMass = 4.8 [kg];
        attribute initialThermalPower : ThermalPower = 2000 [W];
        attribute currentThermalPower : ThermalPower;
        attribute halfLife : Time = 87.7 [yr];
        attribute decayFactor : Real;

        in port coolantIn : Heat;
        out port heatOut : Heat;

        action decay {
            // Thermal power decreases exponentially with fuel half-life
            decision produceHeat {
                currentThermalPower = initialThermalPower * (0.5) ** (elapsedTime / halfLife);
            }
        }
    }

    // ---- Thermoelectric Converter Module ----
    part def ThermoelectricConverterModule {
        attribute numberOfCouples : CoupleCount = 144;
        attribute conversionEfficiency : Real = 0.065;
        attribute hotSideTemp : Temperature;
        attribute coldSideTemp : Temperature;
        attribute tempDifferential : TempDifferential;
        attribute rawPower : ElectricPower;

        in port heatIn : Heat;
        out port wasteHeatOut : Heat;
        out port rawPowerOut : RawElectricity;

        action convertThermalToElectric {
            decision generateVoltage {
                tempDifferential = hotSideTemp - coldSideTemp;
                rawPower = conversionEfficiency * (heatIn.flowRate);
            }
        }
    }

    // ---- Heat Rejection System ----
    part def HeatRejectionSystem {
        attribute radiatorArea : RadiatorArea = 1.2 [m2];
        attribute emissivity : Real = 0.85;
        attribute radiatorTemp : Temperature;
        attribute spaceTemp : Temperature = 3 [K];

        in port heatIn : Heat;

        action radiateHeat {
            // Stefan-Boltzmann radiation: Q = eps * sigma * A * (T^4 - Tspace^4)
            decision rejectWasteHeat {
                heatIn.flowRate = emissivity * 5.67e-8 [W/(m2*K4)] * radiatorArea * (radiatorTemp**4 - spaceTemp**4);
            }
        }
    }

    // ---- Power Conditioning Unit ----
    part def PowerConditioningUnit {
        attribute outputVoltage : OutputVoltage = 28 [V];
        attribute regulationEfficiency : Real = 0.92;
        attribute conditionedPower : ElectricPower;

        in port rawIn : RawElectricity;
        out port condOut : ConditionedElectricity;

        action regulate {
            decision conditionPower {
                conditionedPower = regulationEfficiency * (rawIn.power);
            }
        }
    }

    // ---- RTG Top-Level Assembly ----
    part def RTG {
        attribute missionLife : MissionDuration = 14 [yr];
        attribute elapsedTime : ElapsedTime;
        attribute initialOutput : ElectricPower = 131 [W];
        attribute currentOutput : ElectricPower;
        attribute endOfLifeOutput : ElectricPower = 100 [W];
        attribute operationalStatus : String;

        part heatSource : RadioisotopeHeatSource {
            attribute elapsedTime redefines RTG::elapsedTime;
        }
        part converter : ThermoelectricConverterModule;
        part heatRejection : HeatRejectionSystem;
        part powerConditioning : PowerConditioningUnit;

        // External interfaces
        out port spacecraftPower : ConditionedElectricity;

        // Internal connections
        connection heatToConverter connect heatSource.heatOut to converter.heatIn;
        connection wasteHeatToRadiator connect converter.wasteHeatOut to heatRejection.heatIn;
        connection rawToConditioning connect converter.rawPowerOut to powerConditioning.rawIn;
        connection conditionedToSpacecraft connect powerConditioning.condOut to spacecraftPower;

        // Operational State Machine
        stateMachine RTGOperationalStates {
            initial start;
            state Off;
            state NominalOperation;
            state DegradedOutput;
            state CriticalLowPower;
            state Shutdown;

            transition activate
                from Off to NominalOperation
                when { currentOutput >= 120 [W] }
                send Heat to heatSource.coolantIn;

            transition degrade
                from NominalOperation to DegradedOutput
                when { currentOutput < 120 [W] and currentOutput >= 110 [W] };

            transition critical
                from DegradedOutput to CriticalLowPower
                when { currentOutput < 110 [W] and currentOutput >= 100 [W] };

            transition shutdown
                from CriticalLowPower to Shutdown
                when { currentOutput < 100 [W] or elapsedTime >= missionLife };

            // Entry behaviors
            entry NominalOperation {
                operationalStatus = "Nominal Operation";
            }
            entry DegradedOutput {
                operationalStatus = "Degraded Output";
            }
            entry CriticalLowPower {
                operationalStatus = "Critical Low Power";
            }
            entry Shutdown {
                operationalStatus = "Shutdown";
            }
        }

        // Continuous behavior: power decay over mission life
        action computeOutput {
            decision updatePower {
                currentOutput = initialOutput * (0.5) ** (elapsedTime / heatSource.halfLife);
            }
        }

        // Requirement satisfaction
        satisfy RTGMissionRequirement {
            subject rtg = Self;
        }
    }

    // ---- Item flow extensions ----
    item Heat {
        attribute flowRate : ThermalPower;
    }
    item RawElectricity {
        attribute power : ElectricPower;
    }
    item ConditionedElectricity {
        attribute power : ElectricPower;
        attribute voltage : OutputVoltage;
    }
}
